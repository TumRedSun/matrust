//! Authentication helpers.
//!
//! `build_client` is the single entry point used by every login flow. It
//! constructs a `matrix_sdk::Client` with:
//!  - rustls (the only TLS backend in matrix-sdk 0.18+)
//!  - an optional **IPv6-only** HTTP transport (when `force_ipv6` is set)
//!  - a sqlite-backed state store under the user's data dir (when `use_store` is true)
//!
//! When restoring a session, `use_store` should be `false` to avoid crypto
//! store device-ID mismatches — the client uses an in-memory store instead,
//! and `restore_session()` can set up the identity without conflict.
//!
//! The IPv6 transport uses a custom `reqwest::dns::Resolve` implementation
//! backed by `hickory-resolver` that resolves only AAAA records and refuses
//! to dial IPv4 endpoints.

use anyhow::Result;
use matrix_sdk::Client;
use std::net::{IpAddr, Ipv6Addr, SocketAddr};
use std::sync::Arc;
use std::time::Duration;

pub async fn build_client(homeserver: &str, force_ipv6: bool, use_store: bool) -> Result<Client> {
    let hs: url::Url = homeserver.parse()?;

    // In matrix-sdk 0.18+, retry_timeout() was removed from RequestConfig.
    let mut builder = Client::builder()
        .homeserver_url(hs)
        .user_agent("matrix-client-rust-qt/0.1")
        .request_config(
            matrix_sdk::config::RequestConfig::default()
                .timeout(Duration::from_secs(30)),
        );

    if use_store {
        let data_dir = directories::ProjectDirs::from("dev", "matrixclient", "matrix-client")
            .map(|d| d.data_dir().to_path_buf())
            .unwrap_or_else(|| std::env::temp_dir().join("matrix-client"));
        std::fs::create_dir_all(&data_dir)?;
        let store_path = data_dir.join("sqlite");
        builder = builder.sqlite_store(&store_path, None);
    }

    if force_ipv6 {
        builder = builder.http_client(build_ipv6_only_http()?);
    }

    let client = builder.build().await?;
    Ok(client)
}

/// Build a default reqwest client (no custom DNS resolver).
fn _build_default_http() -> Result<reqwest::Client> {
    Ok(reqwest::ClientBuilder::new()
        .timeout(Duration::from_secs(30))
        .pool_idle_timeout(Duration::from_secs(90))
        .user_agent("matrix-client-rust-qt/0.1")
        .build()?)
}

/// Build a reqwest client that only resolves AAAA records and refuses to
/// connect to non-IPv6 endpoints. This is what powers the "Force IPv6"
/// option in the connection settings.
///
/// In hickory-resolver 0.26+:
/// - `TokioAsyncResolver` was removed; use `TokioResolver`
/// - `builder_tokio()?.build()` returns `Result` (need `?` on both)
fn build_ipv6_only_http() -> Result<reqwest::Client> {
    let resolver = hickory_resolver::TokioResolver::builder_tokio()?.build()?;
    Ok(reqwest::ClientBuilder::new()
        .timeout(Duration::from_secs(45))
        .pool_idle_timeout(Duration::from_secs(120))
        .user_agent("matrix-client-rust-qt/0.1 (ipv6-only)")
        .dns_resolver(Arc::new(Ipv6OnlyResolver { resolver }))
        .build()?)
}

// ---------------------------------------------------------------------------
// Custom DNS resolver that only returns AAAA (IPv6) records.
// ---------------------------------------------------------------------------

/// A `reqwest::dns::Resolve` implementation that resolves only IPv6
/// addresses using `hickory-resolver`.
struct Ipv6OnlyResolver {
    resolver: hickory_resolver::TokioResolver,
}

impl reqwest::dns::Resolve for Ipv6OnlyResolver {
    fn resolve(&self, name: reqwest::dns::Name) -> reqwest::dns::Resolving {
        let resolver = self.resolver.clone();
        let host = name.as_str().to_owned();
        Box::pin(async move {
            let lookup = resolver
                .ipv6_lookup(&host)
                .await
                .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;

            // In hickory-resolver 0.26: Lookup no longer has .iter().
            // Use .answers() -> &[Record] and extract IPs from AAAA RData.
            use hickory_proto::rr::RData;
            let addrs: Vec<SocketAddr> = lookup
                .answers()
                .iter()
                .filter_map(|record| {
                    if let RData::AAAA(aaaa) = record.data {
                        Some(Ipv6Addr::from(aaaa.0))
                    } else {
                        None
                    }
                })
                .map(|ip| SocketAddr::new(IpAddr::V6(ip), 0))
                .collect();

            if addrs.is_empty() {
                // reqwest 0.13 expects Box<dyn Error + Send + Sync>
                let err: Box<dyn std::error::Error + Send + Sync> =
                    format!("no AAAA records for {}", host).into();
                return Err(err);
            }

            // reqwest will replace port 0 with the actual port from the URL.
            Ok(Box::new(addrs.into_iter()) as reqwest::dns::Addrs)
        })
    }
}
