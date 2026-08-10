//! `MessageModel` — chronological list of events in a room.

use qmetaobject::*;
use std::cell::RefCell;
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Default, Clone, qmetaobject::SimpleListItem)]
pub struct MessageEntry {
    pub event_id: QString,
    pub sender: QString,
    pub sender_display: QString,
    pub avatar_url: QString,
    pub body: QString,           // plain text fallback
    pub body_html: QString,      // rendered HTML for rich content
    pub ts: i64,                 // epoch millis
    pub is_own: bool,
    pub kind: QString,           // "text" | "image" | "video" | "file" | "audio" | "system"
    pub mxc_url: QString,        // mxc:// for media messages
    pub file_name: QString,
    pub file_size: i64,
    pub mime_type: QString,
    pub reply_to: QString,
    pub edited: bool,
    pub pending: bool,
    pub failed: bool,
}

#[derive(QObject, Default)]
pub struct MessageModel {
    base: qt_base_class!(trait QAbstractListModel),
    entries: RefCell<Vec<MessageEntry>>,
    current_room_id: RefCell<Option<String>>,

    count: qt_property!(i64; READ count NOTIFY count_changed),
    count_changed: qt_signal!(),

    /// Emitted when the room's history is fully (re)loaded.
    history_loaded: qt_signal!(room_id: QString),
    /// Emitted when a single new event was appended.
    event_appended: qt_signal!(event_id: QString),
}

impl MessageModel {
    pub fn count(&self) -> i64 {
        self.entries.borrow().len() as i64
    }

    pub async fn load_for_room(
        &self,
        client: Arc<Mutex<matrix_sdk::Client>>,
        room_id: String,
    ) -> crate::errors::AppResult<()> {
        let c = client.lock().await;
        let rid: ruma::OwnedRoomId = room_id
            .parse()
            .map_err(|e: ruma::IdParseError| crate::errors::AppError::Other(e.to_string()))?;
        let room = c
            .get_room(&rid)
            .ok_or_else(|| crate::errors::AppError::RoomNotFound(room_id.clone()))?;

        let me = c
            .user_id()
            .map(|u| u.to_owned())
            .ok_or(crate::errors::AppError::NotLoggedIn)?;

        let mut messages: Vec<MessageEntry> = Vec::new();

        // In matrix-sdk 0.18+, room.messages(MessagesOptions) is still
        // available for backward-compatible message fetching.
        let options = matrix_sdk::room::MessagesOptions::backward();
        let result = room.messages(options).await?;

        // result.chunk contains TimelineEvent items.
        // In 0.18+, TimelineEvent wraps a Raw<AnySyncTimelineEvent> (note:
        // Sync, not the old AnyTimelineEvent). We must deserialize the
        // raw event ourselves.
        let mut taken: Vec<_> = result.chunk.into_iter().take(50).collect();
        // Reverse for chronological order (backward query returns newest first).
        taken.reverse();

        for timeline_event in taken {
            // Deserialize the raw event.
            // In ruma 0.16 / matrix-sdk 0.18, the event is a
            // Raw<AnySyncTimelineEvent>. We deserialize it as
            // AnySyncMessageLikeEvent for message content extraction.
            use matrix_sdk::ruma::events::AnySyncTimelineEvent;
            let any_event: AnySyncTimelineEvent = match timeline_event.event.deserialize() {
                Ok(e) => e,
                Err(_) => continue,
            };

            // Extract common fields from the deserialized event.
            let event_id_str = any_event.event_id().to_string();
            let sender_str = any_event.sender().to_string();
            let ts_val = any_event.origin_server_ts().0 as i64;
            let is_own = any_event.sender() == me;

            let mut entry = MessageEntry {
                event_id: QString::from(event_id_str.as_str()),
                ts: ts_val,
                sender: QString::from(sender_str.as_str()),
                is_own,
                ..Default::default()
            };

            // Match on the event to extract content.
            // AnySyncTimelineEvent in ruma 0.16 can be split into
            // MessageLike and State variants.
            use matrix_sdk::ruma::events::AnySyncMessageLikeEvent;
            match &any_event {
                AnySyncTimelineEvent::MessageLike(msg_like) => {
                    match msg_like {
                        AnySyncMessageLikeEvent::RoomMessage(msg) => {
                            // Try to get the original (non-redacted) content.
                            let Some(original) = msg.as_original() else { continue };
                            use matrix_sdk::ruma::events::room::message::MessageType;
                            match &original.content.msgtype {
                                MessageType::Text(t) => {
                                    entry.kind = QString::from("text");
                                    entry.body = QString::from(t.body.as_str());
                                    if let Some(formatted) = &t.formatted {
                                        entry.body_html = QString::from(formatted.body.as_str());
                                    }
                                }
                                MessageType::Emote(t) => {
                                    entry.kind = QString::from("text");
                                    entry.body = QString::from(format!("* {}", t.body));
                                }
                                MessageType::Notice(t) => {
                                    entry.kind = QString::from("text");
                                    entry.body = QString::from(t.body.as_str());
                                }
                                MessageType::Image(t) => {
                                    entry.kind = QString::from("image");
                                    entry.mxc_url = QString::from(t.source.url().map(|u| u.as_str()).unwrap_or(""));
                                    entry.body = QString::from(t.body.as_str());
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(t.info.mimetype.as_deref().unwrap_or("image/*"));
                                }
                                MessageType::Video(t) => {
                                    entry.kind = QString::from("video");
                                    entry.mxc_url = QString::from(t.source.url().map(|u| u.as_str()).unwrap_or(""));
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(t.info.mimetype.as_deref().unwrap_or("video/*"));
                                }
                                MessageType::File(t) => {
                                    entry.kind = QString::from("file");
                                    entry.mxc_url = QString::from(t.source.url().map(|u| u.as_str()).unwrap_or(""));
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(t.info.mimetype.as_deref().unwrap_or("application/octet-stream"));
                                    entry.file_size = t.info.size.map(|s| s as i64).unwrap_or(0);
                                }
                                MessageType::Audio(t) => {
                                    entry.kind = QString::from("audio");
                                    entry.mxc_url = QString::from(t.source.url().map(|u| u.as_str()).unwrap_or(""));
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(t.info.mimetype.as_deref().unwrap_or("audio/*"));
                                }
                                _ => continue,
                            }
                        }
                        AnySyncMessageLikeEvent::RoomEncrypted(_) => {
                            entry.kind = QString::from("system");
                            entry.body = QString::from("🔒 Encrypted message (decryption pending)");
                        }
                        _ => continue,
                    }
                }
                AnySyncTimelineEvent::State(_) => continue,
            }

            messages.push(entry);
        }

        // Apply on the Qt thread via a queued callback.
        let qptr = QPointer::from(self);
        let rid_clone = room_id.clone();
        let cb = qmetaobject::queued_callback(move |entries: Vec<MessageEntry>| {
            if let Some(this) = qptr.as_ref() {
                this.begin_reset_model();
                *this.entries.borrow_mut() = entries;
                this.end_reset_model();
                this.count_changed();
                this.history_loaded(QString::from(rid_clone.as_str()));
            }
        });
        cb(messages);

        Ok(())
    }
}

impl qmetaobject::QAbstractListModel for MessageModel {
    fn row_count(&self) -> i32 {
        self.entries.borrow().len() as i32
    }
    fn data(&self, index: qmetaobject::QModelIndex, role: i32) -> qmetaobject::QVariant {
        let i = index.row() as usize;
        let entries = self.entries.borrow();
        if i >= entries.len() {
            return QVariant::default();
        }
        entries[i].to_qvariant(role)
    }
    fn role_names(&self) -> std::collections::HashMap<i32, QByteArray> {
        MessageEntry::role_names()
    }
}
