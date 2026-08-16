//! `MessageModel` — chronological list of events in a room.

use qmetaobject::*;
use std::cell::RefCell;

/// Module-level singleton storage for MessageModel.
static SINGLETON: crate::singleton::QtSingleton<QPointer<MessageModel>> =
    crate::singleton::QtSingleton::new();

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
    /// Tracks which room's messages are currently displayed so that
    /// stale async responses (from a previous room) can be discarded.
    current_room_id: RefCell<Option<String>>,

    count: qt_property!(i64; READ count NOTIFY count_changed),
    count_changed: qt_signal!(),

    /// Emitted when the room's history is fully (re)loaded.
    historyLoaded: qt_signal!(room_id: QString),
    /// Emitted when a single new event was appended.
    eventAppended: qt_signal!(event_id: QString),
}

/// Helper to extract a URL string from a MediaSource enum.
fn media_source_url(source: &matrix_sdk::ruma::events::room::MediaSource) -> Option<&str> {
    match source {
        matrix_sdk::ruma::events::room::MediaSource::Plain(uri) => Some(uri.as_str()),
        matrix_sdk::ruma::events::room::MediaSource::Encrypted(_) => None,
    }
}

impl MessageModel {
    pub fn count(&self) -> i64 {
        self.entries.borrow().len() as i64
    }

    /// Pure async data fetching — does NOT take `&self` so the future is `Send`.
    /// Returns the parsed message entries; the caller is responsible for
    /// applying them to the model on the Qt thread (e.g. via queued_callback).
    pub async fn fetch_messages(
        client: matrix_sdk::Client,
        room_id: String,
    ) -> crate::errors::AppResult<Vec<MessageEntry>> {
        ::log::info!("fetch_messages: loading messages for room={}", room_id);
        let rid: ruma::OwnedRoomId = room_id
            .parse()
            .map_err(|e: ruma::IdParseError| crate::errors::AppError::Other(e.to_string()))?;
        let room = client
            .get_room(&rid)
            .ok_or_else(|| crate::errors::AppError::RoomNotFound(room_id.clone()))?;

        let me = client
            .user_id()
            .map(|u| u.to_owned())
            .ok_or(crate::errors::AppError::NotLoggedIn)?;

        // Build a HashMap of user_id -> (display_name, avatar_url) from
        // the room's member cache so we can populate sender_display and
        // avatar_url for each message.
        let mut member_map: std::collections::HashMap<String, (String, String)> = std::collections::HashMap::new();
        match room.members(matrix_sdk::RoomMemberships::ACTIVE).await {
            Ok(members) => {
                for member in members {
                    let uid = member.user_id().to_string();
                    let display_name = member.display_name().unwrap_or("").to_string();
                    let avatar = member.avatar_url().map(|u| u.to_string()).unwrap_or_default();
                    member_map.insert(uid, (display_name, avatar));
                }
                ::log::info!("fetch_messages: loaded {} room members for display name lookup", member_map.len());
            }
            Err(e) => {
                ::log::warn!("fetch_messages: failed to load room members: {e}");
            }
        }

        let mut messages: Vec<MessageEntry> = Vec::new();

        // ── Use matrix-sdk-ui Timeline for proper E2EE decryption ──
        // The room.messages() API returns raw encrypted events that the SDK
        // cannot decrypt retroactively. The Timeline API from matrix-sdk-ui
        // handles decryption automatically by integrating with the crypto
        // machine that processes room keys received via sync.
        //
        // We create a temporary Timeline, paginate backwards, read the
        // (now decrypted) items, then drop the Timeline.
        use matrix_sdk_ui::timeline::{TimelineItemKind, TimelineBuilder};

        let timeline = match TimelineBuilder::new(&room).build().await {
            Ok(t) => {
                ::log::info!("fetch_messages: Timeline created for room={}", room_id);
                t
            }
            Err(e) => {
                ::log::warn!("fetch_messages: Timeline::build failed: {e} — falling back to room.messages()");
                // Fallback: use old room.messages() path (won't decrypt E2EE)
                return Self::fetch_messages_fallback(client, room_id, room.clone(), me.clone(), member_map).await;
            }
        };

        // Paginate backwards to load history
        match timeline.paginate_backwards(50).await {
            Ok(_hit_end) => ::log::info!("fetch_messages: Timeline pagination OK"),
            Err(e) => ::log::warn!("fetch_messages: Timeline pagination error: {e}"),
        }

        // Read items from the timeline
        let items = timeline.items().await;
        ::log::info!("fetch_messages: Timeline returned {} items", items.len());

        for item in items.iter() {
            let event_item = match item.kind() {
                TimelineItemKind::Event(ev) => ev,
                TimelineItemKind::Virtual(_) => continue,
            };

            let event_id_str = event_item.event_id()
                .map(|id| id.to_string())
                .unwrap_or_default();
            let sender_str = event_item.sender().to_string();
            let is_own = event_item.is_own();

            // Timestamp
            let ts_val = i64::try_from(event_item.timestamp().0).unwrap_or(0);

            // Display name and avatar from profile
            let (display_name, avatar_url) = {
                let profile = event_item.sender_profile();
                match profile {
                    matrix_sdk_ui::timeline::TimelineDetails::Ready(p) => {
                        let dn = p.display_name.as_deref().unwrap_or("").to_string();
                        let av = p.avatar_url.as_ref().map(|u| u.to_string()).unwrap_or_default();
                        (dn, av)
                    }
                    _ => member_map
                        .get(&sender_str)
                        .map(|(dn, av)| (dn.clone(), av.clone()))
                        .unwrap_or_default(),
                }
            };

            let mut entry = MessageEntry {
                event_id: QString::from(event_id_str.as_str()),
                ts: ts_val,
                sender: QString::from(sender_str.as_str()),
                sender_display: QString::from(display_name.as_str()),
                avatar_url: QString::from(avatar_url.as_str()),
                is_own,
                ..Default::default()
            };

            // Extract message content from TimelineItemContent
            use matrix_sdk_ui::timeline::TimelineItemContent;
            match event_item.content() {
                TimelineItemContent::MsgLike(msg_like) => {
                    use matrix_sdk_ui::timeline::MsgLikeKind;
                    match &msg_like.kind {
                        MsgLikeKind::Message(msg) => {
                            use matrix_sdk::ruma::events::room::message::MessageType;
                            match msg.msgtype() {
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
                                    entry.mxc_url = QString::from(media_source_url(&t.source).unwrap_or(""));
                                    entry.body = QString::from(t.body.as_str());
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(
                                        t.info.as_ref().and_then(|i| i.mimetype.as_deref()).unwrap_or("image/*")
                                    );
                                }
                                MessageType::Video(t) => {
                                    entry.kind = QString::from("video");
                                    entry.mxc_url = QString::from(media_source_url(&t.source).unwrap_or(""));
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(
                                        t.info.as_ref().and_then(|i| i.mimetype.as_deref()).unwrap_or("video/*")
                                    );
                                }
                                MessageType::File(t) => {
                                    entry.kind = QString::from("file");
                                    entry.mxc_url = QString::from(media_source_url(&t.source).unwrap_or(""));
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(
                                        t.info.as_ref().and_then(|i| i.mimetype.as_deref()).unwrap_or("application/octet-stream")
                                    );
                                    entry.file_size = t.info.as_ref()
                                        .and_then(|i| i.size)
                                        .map(|s| u64::from(s) as i64)
                                        .unwrap_or(0);
                                }
                                MessageType::Audio(t) => {
                                    entry.kind = QString::from("audio");
                                    entry.mxc_url = QString::from(media_source_url(&t.source).unwrap_or(""));
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(
                                        t.info.as_ref().and_then(|i| i.mimetype.as_deref()).unwrap_or("audio/*")
                                    );
                                }
                                _ => {
                                    entry.kind = QString::from("system");
                                    entry.body = QString::from("(unsupported message type)");
                                }
                            }
                        }
                        MsgLikeKind::Sticker(s) => {
                            entry.kind = QString::from("image");
                            entry.body = QString::from(s.content().body.as_str());
                            entry.mxc_url = QString::from(media_source_url(&s.content().source).unwrap_or(""));
                        }
                        MsgLikeKind::Redacted => {
                            entry.kind = QString::from("system");
                            entry.body = QString::from("(message deleted)");
                        }
                        MsgLikeKind::UnableToDecrypt(_) => {
                            entry.kind = QString::from("system");
                            entry.is_own = false;
                            entry.body = QString::from("🔒 Encrypted message (decryption pending)");
                        }
                        _ => {
                            entry.kind = QString::from("system");
                            entry.body = QString::from("(event)");
                        }
                    }
                }
                TimelineItemContent::MembershipChange(m) => {
                    entry.kind = QString::from("system");
                    entry.body = QString::from(m.user_id().to_string().as_str());
                }
                TimelineItemContent::ProfileChange(p) => {
                    entry.kind = QString::from("system");
                    let dn = p.displayname_change()
                        .and_then(|c| c.new.as_deref())
                        .unwrap_or("");
                    entry.body = QString::from(format!("changed display name to {}", dn));
                }
                _ => {
                    entry.kind = QString::from("system");
                    entry.body = QString::from("(event)");
                }
            }

            messages.push(entry);
        }

        let own_c = messages.iter().filter(|m| m.is_own).count();
        let other_c = messages.iter().filter(|m| !m.is_own && m.kind.to_string() != "system").count();
        let system_c = messages.iter().filter(|m| m.kind.to_string() == "system").count();
        let img_c = messages.iter().filter(|m| m.kind.to_string() == "image").count();
        ::log::info!(
            "fetch_messages: parsed {} messages for room={} (own={}, other={}, system={}, images={})",
            messages.len(), room_id, own_c, other_c, system_c, img_c
        );

        Ok(messages)
    }


    /// Fallback: fetch messages using room.messages() without Timeline decryption.
    /// Used when Timeline::build() fails (e.g., missing features).
    async fn fetch_messages_fallback(
        _client: matrix_sdk::Client,
        room_id: String,
        room: matrix_sdk::Room,
        me: ruma::OwnedUserId,
        member_map: std::collections::HashMap<String, (String, String)>,
    ) -> crate::errors::AppResult<Vec<MessageEntry>> {
        let mut messages: Vec<MessageEntry> = Vec::new();
        let mut options = matrix_sdk::room::MessagesOptions::backward();
        options.limit = 50u32.into();
        let result = room.messages(options).await?;

        let mut taken: Vec<_> = result.chunk.into_iter().take(50).collect();
        taken.reverse();

        for timeline_event in taken {
            use matrix_sdk::deserialized_responses::TimelineEventKind;
            use matrix_sdk::ruma::events::AnySyncTimelineEvent;

            let any_event: AnySyncTimelineEvent = match timeline_event.kind {
                TimelineEventKind::PlainText { event } => {
                    match event.deserialize() { Ok(e) => e, Err(_) => continue }
                }
                TimelineEventKind::UnableToDecrypt { event, .. } => {
                    match event.deserialize() { Ok(e) => e, Err(_) => continue }
                }
                TimelineEventKind::Decrypted(decrypted) => {
                    match decrypted.event.cast::<AnySyncTimelineEvent>().deserialize() {
                        Ok(e) => e, Err(_) => continue,
                    }
                }
            };

            let event_id_str = any_event.event_id().to_string();
            let sender_str = any_event.sender().to_string();
            let ts_val = u64::from(any_event.origin_server_ts().0) as i64;
            let is_own = any_event.sender() == me;

            let (display_name, avatar_url) = member_map
                .get(&sender_str)
                .map(|(dn, av)| (dn.clone(), av.clone()))
                .unwrap_or_default();

            let mut entry = MessageEntry {
                event_id: QString::from(event_id_str.as_str()),
                ts: ts_val,
                sender: QString::from(sender_str.as_str()),
                sender_display: QString::from(display_name.as_str()),
                avatar_url: QString::from(avatar_url.as_str()),
                is_own,
                ..Default::default()
            };

            use matrix_sdk::ruma::events::AnySyncMessageLikeEvent;
            match &any_event {
                AnySyncTimelineEvent::MessageLike(msg_like) => {
                    match msg_like {
                        AnySyncMessageLikeEvent::RoomMessage(msg) => {
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
                                    entry.mxc_url = QString::from(media_source_url(&t.source).unwrap_or(""));
                                    entry.body = QString::from(t.body.as_str());
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(
                                        t.info.as_ref().and_then(|i| i.mimetype.as_deref()).unwrap_or("image/*")
                                    );
                                }
                                MessageType::Video(t) => {
                                    entry.kind = QString::from("video");
                                    entry.mxc_url = QString::from(media_source_url(&t.source).unwrap_or(""));
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(
                                        t.info.as_ref().and_then(|i| i.mimetype.as_deref()).unwrap_or("video/*")
                                    );
                                }
                                MessageType::File(t) => {
                                    entry.kind = QString::from("file");
                                    entry.mxc_url = QString::from(media_source_url(&t.source).unwrap_or(""));
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(
                                        t.info.as_ref().and_then(|i| i.mimetype.as_deref()).unwrap_or("application/octet-stream")
                                    );
                                    entry.file_size = t.info.as_ref()
                                        .and_then(|i| i.size)
                                        .map(|s| u64::from(s) as i64)
                                        .unwrap_or(0);
                                }
                                MessageType::Audio(t) => {
                                    entry.kind = QString::from("audio");
                                    entry.mxc_url = QString::from(media_source_url(&t.source).unwrap_or(""));
                                    entry.file_name = QString::from(t.body.as_str());
                                    entry.mime_type = QString::from(
                                        t.info.as_ref().and_then(|i| i.mimetype.as_deref()).unwrap_or("audio/*")
                                    );
                                }
                                _ => {
                                    entry.kind = QString::from("system");
                                    entry.body = QString::from("(unsupported message type)");
                                }
                            }
                        }
                        AnySyncMessageLikeEvent::RoomEncrypted(_) => {
                            entry.kind = QString::from("system");
                            entry.is_own = false;
                            entry.body = QString::from("🔒 Encrypted message (decryption pending)");
                        }
                        _ => continue,
                    }
                }
                AnySyncTimelineEvent::State(_) => continue,
            }

            messages.push(entry);
        }

        let own_c = messages.iter().filter(|m| m.is_own).count();
        ::log::info!(
            "fetch_messages_fallback: parsed {} messages for room={} (own={})",
            messages.len(), room_id, own_c
        );
        Ok(messages)
    }

    /// Apply a pre-fetched list of entries on the Qt thread.
    /// Must only be called from the Qt event loop (e.g. inside a queued_callback).
    ///
    /// If `current_room_id` is set and differs from `room_id`, the
    /// response is discarded — the user has since switched to a
    /// different room and these entries are stale.
    pub fn apply_entries(&mut self, entries: Vec<MessageEntry>, room_id: &str) {
        // Guard against stale responses: if the user navigated to a
        // different room while the fetch was in flight, skip.
        let current = self.current_room_id.borrow().clone();
        if let Some(ref cur) = current {
            if cur != room_id {
                ::log::warn!(
                    "apply_entries: discarding stale response for {} (current: {})",
                    room_id, cur
                );
                return;
            }
        }
        let own_count = entries.iter().filter(|m| m.is_own).count();
        let other_count = entries.iter().filter(|m| !m.is_own && m.kind.to_string() != "system").count();
        let system_count = entries.iter().filter(|m| m.kind.to_string() == "system").count();
        ::log::info!(
            "MessageModel::apply_entries: {} messages for room={} (own={}, other={}, system={}), replacing {} existing",
            entries.len(), room_id, own_count, other_count, system_count, self.entries.borrow().len()
        );
        self.begin_reset_model();
        *self.entries.borrow_mut() = entries;
        self.end_reset_model();
        self.count_changed();
        self.historyLoaded(QString::from(room_id));
        ::log::info!("MessageModel::apply_entries: model reset complete, count={}", self.entries.borrow().len());
    }

    /// Set which room's messages are currently displayed.
    /// Called from `MatrixClient::loadRoomMessages` before the
    /// async fetch starts, so stale responses can be detected.
    pub fn set_current_room(&mut self, room_id: &str) {
        ::log::info!("MessageModel::set_current_room: {}", room_id);
        *self.current_room_id.borrow_mut() = Some(room_id.to_owned());
    }
}

/// Build a role-names HashMap from a SimpleListItem's Vec<QByteArray>.
fn role_names_from_vec(names: Vec<QByteArray>) -> std::collections::HashMap<i32, QByteArray> {
    names.into_iter().enumerate()
        .map(|(i, name)| (qmetaobject::USER_ROLE + i as i32, name))
        .collect()
}

impl MessageModel {
    /// Global singleton accessor.
    /// Returns the QPointer stored when the QML engine created the singleton.
    pub fn get() -> QPointer<MessageModel> {
        SINGLETON.get_or_init(|| QPointer::default()).clone()
    }

    /// Alias matching the naming convention used by MatrixClient.
    pub fn singleton_ptr() -> QPointer<MessageModel> {
        Self::get()
    }
}

impl qmetaobject::QSingletonInit for MessageModel {
    fn init(&mut self) {
        SINGLETON.set(QPointer::from(&*self));
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
        entries[i].get(role - qmetaobject::USER_ROLE)
    }
    fn role_names(&self) -> std::collections::HashMap<i32, QByteArray> {
        role_names_from_vec(MessageEntry::names())
    }
}
