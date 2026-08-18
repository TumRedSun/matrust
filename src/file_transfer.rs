//! File / image / video transfer: upload → mxc://, and download mxc:// → disk.

use matrix_sdk::ruma::OwnedRoomId;
use std::path::{Path, PathBuf};
use qmetaobject::QString;

use crate::errors::{AppError, AppResult};

/// Parse an mxc:// URI string into OwnedMxcUri.
#[allow(dead_code)]
fn parse_mxc(s: &str) -> AppResult<matrix_sdk::ruma::OwnedMxcUri> {
    s.try_into()
        .map_err(|e| AppError::Other(format!("invalid mxc URI '{}': {:?}", s, e)))
}

/// Send a local file as an attachment in `room_id`.
///
/// Uses `Room::send_attachment` from matrix-sdk, which automatically handles
/// encryption for E2EE rooms (encrypts the media file + sends the encryption
/// keys alongside the event so other participants can decrypt it).
///
/// Without this, sending media in an E2EE DM produced an unencrypted upload
/// referenced by an encrypted event — the receiver couldn't decrypt the file
/// and saw an empty bubble.
pub async fn send_attachment(
    room_id: String,
    local_path: String,
    mime: String,
    kind: String,
) -> AppResult<()> {
    let client_arc = crate::MatrixClient::require_client().await?;
    let c = client_arc.lock().await;

    let rid: OwnedRoomId = room_id
        .parse()
        .map_err(|e: ruma::IdParseError| AppError::Other(e.to_string()))?;
    let room = c
        .get_room(&rid)
        .ok_or_else(|| AppError::RoomNotFound(room_id.clone()))?;

    let path = Path::new(&local_path);
    if !path.exists() {
        return Err(AppError::File(format!("not found: {}", local_path)));
    }
    let bytes = std::fs::read(path)?;
    let file_name = path
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("file")
        .to_owned();

    // Infer the MIME type. The caller may pass an empty string (fileDialog
    // sends "") or a wildcard like "image/*". In both cases, fall back to
    // mime_guess so we get a concrete Content-Type for the upload.
    let mime_val: mime::Mime = if mime.is_empty() || mime.contains('*') {
        mime_guess::from_path(&local_path)
            .first()
            .unwrap_or(mime::APPLICATION_OCTET_STREAM)
    } else {
        mime.parse()
            .map_err(|e: mime::FromStrError| AppError::Other(e.to_string()))?
    };

    // Build the AttachmentConfig with type-specific metadata. For images and
    // videos we'd ideally populate dimensions/duration, but since we don't
    // decode the file here we just send an empty BaseImageInfo / BaseVideoInfo.
    // The server/client will still display the file correctly.
    use matrix_sdk::attachment::{AttachmentConfig, AttachmentInfo,
        BaseAudioInfo, BaseFileInfo, BaseImageInfo, BaseVideoInfo};

    let attachment_info = match kind.as_str() {
        "image" => AttachmentInfo::Image(BaseImageInfo::default()),
        "video" => AttachmentInfo::Video(BaseVideoInfo::default()),
        "audio" => AttachmentInfo::Audio(BaseAudioInfo::default()),
        _ => AttachmentInfo::File(BaseFileInfo::default()),
    };
    let config = AttachmentConfig::new().info(attachment_info);

    // `send_attachment` returns an IntoFuture (SendAttachment). Awaiting it
    // uploads the file, builds the appropriate message event content (plain
    // or encrypted based on the room's encryption state), and sends the
    // event — all in one call.
    room.send_attachment(file_name, &mime_val, bytes, config).await?;

    Ok(())
}

/// Download a media file by its serialized `MediaSource`.
///
/// `media_source_json` is the JSON-serialized form of
/// `matrix_sdk::ruma::events::room::MediaSource` — which can be either
/// `Plain(mxc_uri)` or `Encrypted(EncryptedFile { url, key, iv, hashes, ... })`.
/// For encrypted media the SDK uses the key/IV/hashes to decrypt the
/// downloaded bytes automatically.
///
/// Without this, downloading encrypted media from a DM failed because the
/// old `download_media` only accepted a plain `mxc://` string and built a
/// `MediaSource::Plain` from it — encrypted sources returned `None` in
/// `media_source_url()`, leaving `mxc_url` empty and the download button
/// broken.
pub async fn download_media(
    room_id: String,
    media_source_json: String,
    suggested_name: String,
) -> AppResult<()> {
    let client_arc = crate::MatrixClient::require_client().await?;
    let c = client_arc.lock().await;

    // Deserialize the MediaSource from JSON. This supports both Plain and
    // Encrypted sources.
    let source: matrix_sdk::ruma::events::room::MediaSource =
        serde_json::from_str(&media_source_json)
            .map_err(|e| AppError::Other(format!("invalid media source JSON: {e}")))?;

    use matrix_sdk::media::{MediaRequestParameters, MediaFormat};
    let request_params = MediaRequestParameters {
        source,
        format: MediaFormat::File,
    };
    let bytes = c
        .media()
        .get_media_content(&request_params, true)
        .await?;

    let dir = crate::avatar_cache::downloads_dir();
    std::fs::create_dir_all(&dir)?;
    let safe_name = sanitize(&suggested_name);
    let mut path: PathBuf = dir.join(if safe_name.is_empty() {
        format!("matrix-{}", uuid::Uuid::new_v4())
    } else {
        safe_name
    });

    // If a collision, append a number.
    let mut i = 1;
    while path.exists() {
        let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("file");
        let ext = path.extension().and_then(|s| s.to_str());
        let new_name = if let Some(ext) = ext {
            format!("{} ({}).{}", stem, i, ext)
        } else {
            format!("{} ({})", stem, i)
        };
        path = dir.join(new_name);
        i += 1;
    }
    std::fs::write(&path, &bytes)?;

    // Surface back to QML through a queued callback.
    let qptr = crate::MatrixClient::singleton_ptr();
    let p = path.to_string_lossy().to_string();
    let rid = room_id.clone();
    let mxc_url = media_source_json.clone();
    let cb = qmetaobject::queued_callback(move |_: ()| {
        if let Some(this) = qptr.as_pinned() {
            this.borrow_mut().emit_file_downloaded(
                QString::from(rid.as_str()),
                QString::from(mxc_url.as_str()),
                QString::from(p.as_str()),
            );
        }
    });
    cb(());

    Ok(())
}

/// Upload a local image as the user's avatar.
pub async fn set_avatar(
    client: std::sync::Arc<tokio::sync::Mutex<matrix_sdk::Client>>,
    local_path: String,
) -> AppResult<()> {
    let c = client.lock().await;
    let bytes = std::fs::read(&local_path)?;
    let mime = mime_guess::from_path(&local_path)
        .first()
        .unwrap_or(mime::IMAGE_PNG);
    let uploaded = c.media().upload(&mime, bytes, None).await?;
    c.account()
        .set_avatar_url(Some(&uploaded.content_uri))
        .await?;
    Ok(())
}

/// Set the user's profile banner.
///
/// Matrix has no standard "profile banner" field, so we store the banner
/// locally in the app cache directory (`<cache_dir>/matrix-client/banner.<ext>`).
/// The path is exposed to QML as a `file://` URL through `ProfileManager`.
///
/// The previous banner file (if any) is removed first so we don't accumulate
/// stale images with different extensions.
pub async fn set_banner(local_path: String) -> AppResult<String> {
    let src = Path::new(&local_path);
    if !src.exists() {
        return Err(AppError::File(format!("not found: {}", local_path)));
    }

    // Read the bytes up-front so we can validate the file is readable before
    // we touch the cache directory.
    let bytes = std::fs::read(src)?;

    // Determine the extension from the original filename; fall back to png.
    let ext = src
        .extension()
        .and_then(|s| s.to_str())
        .map(|s| s.to_ascii_lowercase())
        .filter(|s| matches!(s.as_str(), "png" | "jpg" | "jpeg" | "gif" | "webp" | "svg" | "bmp"))
        .unwrap_or_else(|| "png".to_string());

    let dir = crate::avatar_cache::cache_dir();
    std::fs::create_dir_all(&dir)?;

    // Remove any previous banner.* files so old extensions don't linger
    // (e.g. switching from banner.png to banner.jpg).
    if let Ok(entries) = std::fs::read_dir(&dir) {
        for entry in entries.flatten() {
            if let Some(name) = entry.file_name().to_str() {
                if name.starts_with("banner.") {
                    let _ = std::fs::remove_file(entry.path());
                }
            }
        }
    }

    let dst = dir.join(format!("banner.{}", ext));
    std::fs::write(&dst, &bytes)?;

    // Return a file:// URL that QML Image can load directly.
    let url = format!("file://{}", dst.to_string_lossy());
    Ok(url)
}

/// Return the cached banner URL, if any banner file exists in the cache dir.
pub fn cached_banner_url() -> Option<String> {
    let dir = crate::avatar_cache::cache_dir();
    let entries = std::fs::read_dir(&dir).ok()?;
    for entry in entries.flatten() {
        if let Some(name) = entry.file_name().to_str() {
            if name.starts_with("banner.") {
                let path = entry.path();
                return Some(format!("file://{}", path.to_string_lossy()));
            }
        }
    }
    None
}

fn sanitize(name: &str) -> String {
    name.chars()
        .filter(|c| !matches!(c, '/' | '\\'| '\0' | ':' | '*' | '?' | '"' | '<' | '>' | '|'))
        .collect::<String>()
        .trim()
        .to_owned()
}
