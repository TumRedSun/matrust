//! On-disk avatar cache. Files are written under
//! `<cache_dir>/Rustrix/avatars/<sha256>.<ext>` and surfaced to QML as
//! `file://` URLs.

use anyhow::Result;
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};

/// Migrate the old `matrix-client/` data directory to the new `Rustrix/`
/// location. This runs once on startup; if both directories exist, the
/// new one wins (we don't merge). Idempotent and silent on failure.
pub fn migrate_old_data_dir(new_base: &Path) {
    if new_base.exists() {
        return; // Already migrated (or fresh install)
    }
    // Look for the old `~/.local/share/matrix-client/` (or cache equivalent).
    let old_base = directories::ProjectDirs::from("dev", "matrixclient", "matrix-client")
        .map(|d| d.cache_dir().to_path_buf());
    if let Some(old) = old_base {
        if old.exists() {
            if let Some(parent) = new_base.parent() {
                let _ = std::fs::create_dir_all(parent);
            }
            let _ = std::fs::rename(&old, new_base);
            ::log::info!("Migrated data dir from {:?} to {:?}", old, new_base);
        }
    }
}

#[allow(dead_code)]
pub fn cache_dir() -> PathBuf {
    let base = directories::ProjectDirs::from("dev", "rustrix", "Rustrix")
        .map(|d| d.cache_dir().to_path_buf())
        .unwrap_or_else(|| std::env::temp_dir().join("Rustrix"));
    migrate_old_data_dir(&base);
    std::fs::create_dir_all(&base).ok();
    base
}

pub fn downloads_dir() -> PathBuf {
    let d = directories::UserDirs::new()
        .and_then(|u| u.download_dir().map(|p| p.to_path_buf()))
        .unwrap_or_else(|| std::env::temp_dir());
    d.join("Rustrix")
}

#[allow(dead_code)]
pub fn avatar_path_for(url: &str, ext: &str) -> Result<PathBuf> {
    let mut h = Sha256::new();
    h.update(url.as_bytes());
    // In sha2 0.11, finalize() returns an Array type that doesn't impl LowerHex.
    // Convert byte-by-byte instead.
    let hash: String = h.finalize().iter().map(|b| format!("{b:02x}")).collect();
    let dir = cache_dir().join("avatars");
    std::fs::create_dir_all(&dir)?;
    Ok(dir.join(format!("{}.{}", hash, ext)))
}

#[allow(dead_code)]
pub fn ext_of(mime: &str) -> &'static str {
    match mime {
        "image/png" => "png",
        "image/jpeg" => "jpg",
        "image/gif" => "gif",
        "image/webp" => "webp",
        "image/svg+xml" => "svg",
        _ => "bin",
    }
}

/// Ensure a path exists; returns the same path for chaining.
#[allow(dead_code)]
pub fn ensure_parent(p: &Path) -> Result<()> {
    if let Some(parent) = p.parent() {
        std::fs::create_dir_all(parent)?;
    }
    Ok(())
}
