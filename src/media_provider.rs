//! Media fetch + cache helper for inline image/video preview.
//!
//! The QML `Image` component can't load encrypted bytes directly — we need
//! the Matrix SDK to decrypt them first. `MediaPlayer` similarly needs a
//! `file://` URL, not an `image://` URL.
//!
//! So instead of a QML image provider, we expose a method
//! `MatrixClient.requestMedia(sourceJson)` that:
//!   1. Hashes the sourceJson → cache file path.
//!   2. If the cache file exists, emits `mediaReady(sourceJson, path)` immediately.
//!   3. Otherwise, spawns a fetch on the Tokio runtime, writes the bytes
//!      to the cache file, then emits `mediaReady`.
//!
//! QML listens for `mediaReady` and sets `image.source = "file://" + path`
//! (or `video.source = ...`).
//!
//! Cache layout: `<cache_dir>/Rustrix/media/<sha256>.<ext>` where the
//! extension is guessed from the MIME type. The sha256 is of the
//! serialized `MediaSource` JSON (which includes key/IV/hashes for
//! encrypted sources, so plain and encrypted versions of the same URL
//! get distinct cache entries).

use std::io::Write;
use std::path::PathBuf;

use crate::errors::AppResult;

/// SHA-256 of the MediaSource JSON → cache file path (no extension yet).
fn cache_base_path(source_json: &str) -> PathBuf {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    h.update(source_json.as_bytes());
    let hash: String = h.finalize().iter().map(|b| format!("{b:02x}")).collect();
    let dir = crate::avatar_cache::cache_dir().join("media");
    let _ = std::fs::create_dir_all(&dir);
    dir.join(hash)
}

/// Append an extension based on the mime type. If we don't know the mime,
/// fall back to `.bin` — QML Image can still sniff the format from the
/// file contents in most cases.
fn cache_path_with_ext(base: &PathBuf, mime: &str) -> PathBuf {
    let ext = match mime {
        m if m.contains("png") => "png",
        m if m.contains("jpeg") || m.contains("jpg") => "jpg",
        m if m.contains("gif") => "gif",
        m if m.contains("webp") => "webp",
        m if m.contains("svg") => "svg",
        m if m.contains("bmp") => "bmp",
        m if m.contains("mp4") => "mp4",
        m if m.contains("webm") => "webm",
        m if m.contains("matroska") || m.contains("mkv") => "mkv",
        m if m.contains("quicktime") || m.contains("mov") => "mov",
        m if m.contains("avi") => "avi",
        m if m.contains("mpeg") => "mpg",
        m if m.contains("audio/mpeg") => "mp3",
        m if m.contains("ogg") => "ogg",
        m if m.contains("wav") => "wav",
        m if m.contains("flac") => "flac",
        m if m.contains("pdf") => "pdf",
        _ => "bin",
    };
    base.with_extension(ext)
}

/// Synchronous cache lookup — returns the cached file path if the bytes
/// are already on disk. Called on the Qt thread; must not block on network.
pub fn try_cache(source_json: &str, mime: &str) -> Option<PathBuf> {
    let base = cache_base_path(source_json);
    // Try the mime-derived path first.
    let with_ext = cache_path_with_ext(&base, mime);
    if with_ext.exists() {
        return Some(with_ext);
    }
    // Fall back: any file with the same stem (in case mime was unknown
    // when first cached but is known now, or vice versa).
    if let Some(stem) = base.file_name() {
        if let Ok(entries) = std::fs::read_dir(base.parent()?) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.starts_with(stem.to_str().unwrap_or("")) {
                        return Some(entry.path());
                    }
                }
            }
        }
    }
    None
}

/// Write fetched bytes to the cache for future lookups. Returns the path
/// the bytes were written to.
pub fn write_cache(source_json: &str, mime: &str, bytes: &[u8]) -> AppResult<PathBuf> {
    let base = cache_base_path(source_json);
    let path = cache_path_with_ext(&base, mime);
    let mut f = std::fs::File::create(&path)?;
    f.write_all(bytes)?;
    Ok(path)
}

/// Async fetch via the Matrix SDK. Transparently handles E2EE decryption
/// (the SDK uses the key/IV/hashes embedded in the encrypted MediaSource).
pub async fn fetch_media_bytes(source_json: &str) -> AppResult<Vec<u8>> {
    let source: matrix_sdk::ruma::events::room::MediaSource =
        serde_json::from_str(source_json)
            .map_err(|e| crate::errors::AppError::Other(format!("invalid media source JSON: {e}")))?;

    let client_arc = crate::MatrixClient::require_client().await?;
    let c = client_arc.lock().await;

    use matrix_sdk::media::{MediaRequestParameters, MediaFormat};
    let request_params = MediaRequestParameters {
        source,
        format: MediaFormat::File,
    };
    let bytes = c
        .media()
        .get_media_content(&request_params, true)
        .await?;
    Ok(bytes)
}
