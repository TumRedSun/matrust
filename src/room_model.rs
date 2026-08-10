//! `RoomModel` — a QAbstractListModel exposing the user's joined rooms.

use qmetaobject::*;
use std::cell::RefCell;
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Default, Clone, qmetaobject::SimpleListItem)]
pub struct RoomEntry {
    pub room_id: QString,
    pub name: QString,
    pub avatar_url: QString,
    pub last_event: QString,
    pub last_event_ts: i64,
    pub unread_count: i64,
    pub highlight_count: i64,
    pub is_direct: bool,
    pub is_space: bool,
    pub has_unread: bool,
}

#[derive(QObject, Default)]
pub struct RoomModel {
    base: qt_base_class!(trait QAbstractListModel),
    // Interior-mutable so we can refresh from `&self`.
    entries: RefCell<Vec<RoomEntry>>,

    count: qt_property!(i64; READ count NOTIFY count_changed),
    count_changed: qt_signal!(),

    /// Emitted whenever the underlying list changes shape.
    rows_changed: qt_signal!(),
}

impl RoomModel {
    /// Pure async data fetching — does NOT take `&self` so the future is `Send`.
    /// Returns the room entries; the caller applies them on the Qt thread.
    pub async fn fetch_rooms(
        client: Arc<Mutex<matrix_sdk::Client>>,
    ) -> crate::errors::AppResult<Vec<RoomEntry>> {
        let c = client.lock().await;
        let rooms = c.rooms();
        drop(c);

        let mut new_entries: Vec<RoomEntry> = Vec::with_capacity(rooms.len());

        for room in rooms {
            if room.state() != matrix_sdk::RoomState::Joined {
                continue;
            }
            if room.is_space() {
                continue; // spaces go into SpaceModel
            }

            // In matrix-sdk 0.18+, display_name() returns RoomDisplayName
            // which implements Display.
            let display_name = room.display_name().await
                .map(|dn| dn.to_string())
                .unwrap_or_default();

            let avatar = room
                .avatar_url()
                .map(|u| u.to_string())
                .unwrap_or_default();

            // In matrix-sdk 0.18+, Room does not have a simple latest_event().
            // We use the unread notification counts as a proxy for activity.
            // The last_event text and timestamp are left empty/zero until
            // a proper timeline/event-cache-based approach is implemented.
            let last = QString::default();
            let last_ts: i64 = 0;

            let unread = room.unread_notification_counts();
            // In 0.18+, is_dm() is a synchronous method that checks cached
            // DM state.  direct_targets() is also available.
            let is_direct = room.is_dm() || room.direct_targets().len() > 0;

            new_entries.push(RoomEntry {
                room_id: QString::from(room.room_id().as_str()),
                name: QString::from(display_name.as_str()),
                avatar_url: QString::from(avatar.as_str()),
                last_event: last,
                last_event_ts: last_ts,
                unread_count: unread.notification_count as i64,
                highlight_count: unread.highlight_count as i64,
                is_direct,
                is_space: false,
                has_unread: unread.notification_count > 0,
            });
        }

        new_entries.sort_by(|a, b| b.last_event_ts.cmp(&a.last_event_ts));
        Ok(new_entries)
    }

    /// Apply pre-fetched entries on the Qt thread.
    /// Must only be called from the Qt event loop (e.g. inside a queued_callback).
    pub fn apply_entries(&mut self, entries: Vec<RoomEntry>) {
        self.begin_reset_model();
        *self.entries.borrow_mut() = entries;
        self.end_reset_model();
        self.count_changed();
        self.rows_changed();
    }

    pub fn count(&self) -> i64 {
        self.entries.borrow().len() as i64
    }
}

// QAbstractListModel glue.
impl qmetaobject::QAbstractListModel for RoomModel {
    fn row_count(&self) -> i32 {
        self.entries.borrow().len() as i32
    }
    fn data(&self, index: qmetaobject::QModelIndex, role: i32) -> qmetaobject::QVariant {
        let i = index.row() as usize;
        let entries = self.entries.borrow();
        if i >= entries.len() {
            return QVariant::default();
        }
        entries[i].get(role)
    }
    fn role_names(&self) -> std::collections::HashMap<i32, QByteArray> {
        RoomEntry::names().into_iter().enumerate()
            .map(|(i, name)| (qmetaobject::USER_ROLE + i as i32, name))
            .collect()
    }
}
