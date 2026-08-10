//! File / image / video transfer: upload → mxc://, and download mxc:// → disk.

use matrix_sdk::ruma::OwnedRoomId;
use std::path::{Path, PathBuf};
use qmetaobject::QString;

use crate::errors::{AppError, AppResult};

/// Parse an mxc:// URI string into OwnedMxcUri.
fn parse_mxc(s: &str) -> AppResult<matrix_sdk::ruma::OwnedMxcUri> {
    s.try_into()
        .map_err(|e| AppError::Other(format!("invalid mxc URI '{}': {:?}", s, e)))
}

/// Helper to extract a URL string from a MediaSource enum.
fn media_source_url(source: &matrix_sdk::ruma::events::room::MediaSource) -> Option<String> {
    match source {
        matrix_sdk::ruma::events::room::MediaSource::Plain(uri) => Some(uri.to_string()),
        matrix_sdk::ruma::events::room::MediaSource::Encrypted(_) => None,
    }
}

/// Send a local file as an attachment in `room_id`.
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
    let mime_val: mime::Mime = mime
        .parse()
        .map_err(|e: mime::FromStrError| AppError::Other(e.to_string()))?;

    use matrix_sdk::ruma::events::room::message::{
        AudioMessageEventContent, FileMessageEventContent, ImageMessageEventContent,
        MessageType, RoomMessageEventContent, VideoMessageEventContent,
    };

    let content = match kind.as_str() {
        "image" => {
            let uploaded = c.media().upload(&mime_val, bytes, None).await?;
            let mut img = ImageMessageEventContent::plain(file_name, uploaded.content_uri);
            img.info = Some(Box::new(ruma::events::room::ImageInfo::default()));
            RoomMessageEventContent::new(MessageType::Image(img))
        }
        "video" => {
            let uploaded = c.media().upload(&mime_val, bytes, None).await?;
            let mut v = VideoMessageEventContent::plain(file_name, uploaded.content_uri);
            v.info = Some(Box::new(ruma::events::room::message::VideoInfo::default()));
            RoomMessageEventContent::new(MessageType::Video(v))
        }
        "audio" => {
            let uploaded = c.media().upload(&mime_val, bytes, None).await?;
            let a = AudioMessageEventContent::plain(file_name, uploaded.content_uri);
            RoomMessageEventContent::new(MessageType::Audio(a))
        }
        _ => {
            let uploaded = c.media().upload(&mime_val, bytes, None).await?;
            let f = FileMessageEventContent::plain(file_name, uploaded.content_uri);
            RoomMessageEventContent::new(MessageType::File(f))
        }
    };

    let _ = room.send(content).await?;
    Ok(())
}

/// Download `mxc://` to a file in the user's Downloads directory and return
/// the local path via the `fileDownloaded` signal on `MatrixClient`.
pub async fn download_media(
    room_id: String,
    mxc: String,
    suggested_name: String,
) -> AppResult<()> {
    let client_arc = crate::MatrixClient::require_client().await?;
    let c = client_arc.lock().await;

    let uri = parse_mxc(&mxc)?;

    use matrix_sdk::media::{MediaRequestParameters, MediaFormat};
    use matrix_sdk::ruma::events::room::MediaSource;
    let request_params = MediaRequestParameters {
        source: MediaSource::Plain(uri),
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
    let mxc_url = mxc.clone();
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

fn sanitize(name: &str) -> String {
    name.chars()
        .filter(|c| !matches!(c, '/' | '\\'| '\0' | ':' | '*' | '?' | '"' | '<' | '>' | '|'))
        .collect::<String>()
        .trim()
        .to_owned()
}
