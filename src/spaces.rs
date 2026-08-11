//! `SpaceModel` — a tree model exposing Spaces → Rooms hierarchy.
//!
//! Currently a flat list per space; QML expands it into a tree using the
//! `parent_id` field. This keeps the Rust side simple and avoids
//! QAbstractItemModel's full 2D index machinery.
//!
//! In matrix-sdk 0.18+, Room::parent_spaces() is still available.
//! We determine the space→room relationship by checking each room's
//! parent_spaces() and matching against known space IDs.

use qmetaobject::*;
use std::cell::RefCell;
use std::sync::Arc;
use tokio::sync::Mutex;

/// Module-level singleton storage for SpaceModel.
static SINGLETON: crate::singleton::QtSingleton<QPointer<SpaceModel>> =
    crate::singleton::QtSingleton::new();

#[derive(Default, Clone, qmetaobject::SimpleListItem)]
pub struct SpaceEntry {
    pub id: QString,
    pub parent_id: QString,
    pub kind: QString,           // "space" | "room"
    pub name: QString,
    pub avatar_url: QString,
    pub unread: i64,
    pub highlight: i64,
    pub is_direct: bool,
    pub last_ts: i64,
}

#[derive(QObject, Default)]
pub struct SpaceModel {
    base: qt_base_class!(trait QAbstractListModel),
    entries: RefCell<Vec<SpaceEntry>>,

    count: qt_property!(i64; READ count NOTIFY count_changed),
    count_changed: qt_signal!(),
    tree_changed: qt_signal!(),
}

impl SpaceModel {
    pub fn count(&self) -> i64 {
        self.entries.borrow().len() as i64
    }

    /// Pure async data fetching — does NOT take `&self` so the future is `Send`.
    /// Returns the space entries; the caller applies them on the Qt thread.
    pub async fn fetch_spaces(
        client: Arc<Mutex<matrix_sdk::Client>>,
    ) -> crate::errors::AppResult<Vec<SpaceEntry>> {
        let c = client.lock().await;
        let rooms = c.rooms();
        drop(c);

        let mut out: Vec<SpaceEntry> = Vec::new();

        // First pass: collect spaces themselves.
        let spaces: Vec<_> = rooms
            .iter()
            .filter(|r| r.is_space() && r.state() == matrix_sdk::RoomState::Joined)
            .cloned()
            .collect();

        // Build a set of space IDs for quick lookup.
        let space_ids: std::collections::HashSet<String> = spaces
            .iter()
            .map(|s| s.room_id().to_string())
            .collect();

        for sp in &spaces {
            let name = sp.display_name().await
                .map(|dn| dn.to_string())
                .unwrap_or_default();
            let av = sp.avatar_url().map(|u| u.to_string()).unwrap_or_default();
            out.push(SpaceEntry {
                id: QString::from(sp.room_id().as_str()),
                parent_id: QString::default(),
                kind: QString::from("space"),
                name: QString::from(name.as_str()),
                avatar_url: QString::from(av.as_str()),
                unread: 0,
                highlight: 0,
                is_direct: false,
                last_ts: 0,
            });
        }

        // Second pass: determine which rooms belong to which spaces.
        // matrix-sdk 0.18+ still provides room.parent_spaces() which
        // returns a stream of parent space rooms.
        let mut assigned_rooms: std::collections::HashSet<String> = std::collections::HashSet::new();

        for room in &rooms {
            if room.is_space() || room.state() != matrix_sdk::RoomState::Joined {
                continue;
            }

            // Check parent_spaces() to see if this room belongs to any
            // of our known spaces.
            let mut matching_parents: Vec<String> = Vec::new();
            if let Ok(parent_stream) = room.parent_spaces().await {
                use futures::StreamExt;
                let mut stream = std::pin::pin!(parent_stream);
                while let Some(parent_result) = stream.next().await {
                    if let Ok(parent_space) = parent_result {
                        // In matrix-sdk 0.18, ParentSpace has variants:
                        // Reciprocal(Room), WithPowerlevel(Room),
                        // Illegitimate(Room), Unverifiable(OwnedRoomId).
                        let parent_id = match &parent_space {
                            matrix_sdk::room::ParentSpace::Reciprocal(room)
                            | matrix_sdk::room::ParentSpace::WithPowerlevel(room)
                            | matrix_sdk::room::ParentSpace::Illegitimate(room) => {
                                room.room_id().to_string()
                            }
                            matrix_sdk::room::ParentSpace::Unverifiable(id) => id.to_string(),
                        };
                        if space_ids.contains(&parent_id) {
                            matching_parents.push(parent_id);
                        }
                    }
                }
            }

            if !matching_parents.is_empty() {
                let name = room.display_name().await
                    .map(|dn| dn.to_string())
                    .unwrap_or_default();
                let av = room.avatar_url().map(|u| u.to_string()).unwrap_or_default();
                let unread = room.unread_notification_counts();
                let is_direct = room.is_dm() || room.direct_targets().len() > 0;

                for parent_id in matching_parents {
                    out.push(SpaceEntry {
                        id: QString::from(room.room_id().as_str()),
                        parent_id: QString::from(parent_id.as_str()),
                        kind: QString::from("room"),
                        name: QString::from(name.as_str()),
                        avatar_url: QString::from(av.as_str()),
                        unread: unread.notification_count as i64,
                        highlight: unread.highlight_count as i64,
                        is_direct,
                        last_ts: 0,
                    });
                }
                assigned_rooms.insert(room.room_id().to_string());
            }
        }

        // Rooms with no parent space (still appear at the top level).
        for r in &rooms {
            if r.is_space() || r.state() != matrix_sdk::RoomState::Joined {
                continue;
            }
            let rid = r.room_id().to_string();
            if assigned_rooms.contains(&rid) {
                continue;
            }
            let name = r.display_name().await
                .map(|dn| dn.to_string())
                .unwrap_or_default();
            let av = r.avatar_url().map(|u| u.to_string()).unwrap_or_default();
            let unread = r.unread_notification_counts();
            let is_direct = r.is_dm() || r.direct_targets().len() > 0;
            out.push(SpaceEntry {
                id: QString::from(r.room_id().as_str()),
                parent_id: QString::default(),
                kind: QString::from("room"),
                name: QString::from(name.as_str()),
                avatar_url: QString::from(av.as_str()),
                unread: unread.notification_count as i64,
                highlight: unread.highlight_count as i64,
                is_direct,
                last_ts: 0,
            });
        }

        out.sort_by(|a, b| {
            // Sort by kind (spaces first), then by name.
            let ka = if a.kind.to_string() == "space" { 0 } else { 1 };
            let kb = if b.kind.to_string() == "space" { 0 } else { 1 };
            ka.cmp(&kb).then_with(|| a.name.to_string().cmp(&b.name.to_string()))
        });

        Ok(out)
    }

    /// Apply pre-fetched entries on the Qt thread.
    /// Must only be called from the Qt event loop (e.g. inside a queued_callback).
    pub fn apply_entries(&mut self, entries: Vec<SpaceEntry>) {
        self.begin_reset_model();
        *self.entries.borrow_mut() = entries;
        self.end_reset_model();
        self.count_changed();
        self.tree_changed();
    }
}

impl SpaceModel {
    /// Global singleton accessor.
    /// Returns the QPointer stored when the QML engine created the singleton.
    pub fn get() -> QPointer<SpaceModel> {
        SINGLETON.get_or_init(|| QPointer::default()).clone()
    }

    /// Alias matching the naming convention used by MatrixClient.
    pub fn singleton_ptr() -> QPointer<SpaceModel> {
        Self::get()
    }
}

impl qmetaobject::QSingletonInit for SpaceModel {
    fn init(&mut self) {
        SINGLETON.set(QPointer::from(&*self));
    }
}

impl qmetaobject::QAbstractListModel for SpaceModel {
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
        SpaceEntry::names().into_iter().enumerate()
            .map(|(i, name)| (qmetaobject::USER_ROLE + i as i32, name))
            .collect()
    }
}
