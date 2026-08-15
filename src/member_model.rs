//! `MemberModel` — a QAbstractListModel exposing members of a room or space.

use qmetaobject::*;
use std::cell::RefCell;
use std::sync::Arc;
use tokio::sync::Mutex;

/// Module-level singleton storage for MemberModel.
static SINGLETON: crate::singleton::QtSingleton<QPointer<MemberModel>> =
    crate::singleton::QtSingleton::new();

#[derive(Default, Clone, qmetaobject::SimpleListItem)]
pub struct MemberEntry {
    pub user_id: QString,
    pub display_name: QString,
    pub avatar_url: QString,
    pub presence: QString,    // "online" | "unavailable" | "offline"
    pub status_msg: QString,
    pub power_level: i64,     // 0 = normal, >0 = mod/admin
}

#[derive(QObject, Default)]
pub struct MemberModel {
    base: qt_base_class!(trait QAbstractListModel),
    entries: RefCell<Vec<MemberEntry>>,

    count: qt_property!(i64; READ count NOTIFY count_changed),
    count_changed: qt_signal!(),

    /// Emitted whenever the member list is refreshed.
    members_changed: qt_signal!(),
}

impl MemberModel {
    pub fn count(&self) -> i64 {
        self.entries.borrow().len() as i64
    }

    /// Pure async data fetching — does NOT take `&self` so the future is `Send`.
    pub async fn fetch_members(
        client: Arc<Mutex<matrix_sdk::Client>>,
        room_id: String,
    ) -> crate::errors::AppResult<Vec<MemberEntry>> {
        let c = client.lock().await;
        let rid: ruma::OwnedRoomId = room_id.parse()
            .map_err(|e: ruma::IdParseError| crate::errors::AppError::Other(e.to_string()))?;
        let room = c.get_room(&rid)
            .ok_or_else(|| crate::errors::AppError::RoomNotFound(room_id.clone()))?;
        drop(c);

        let members = room.members(matrix_sdk::RoomMemberships::JOIN).await?;

        let mut entries: Vec<MemberEntry> = members.iter().map(|m| {
            let power: i64 = match m.power_level() {
                ruma::events::room::power_levels::UserPowerLevel::Infinite => i64::MAX,
                ruma::events::room::power_levels::UserPowerLevel::Int(v) => v.into(),
                _ => 0,
            };
            MemberEntry {
                user_id: QString::from(m.user_id().as_str()),
                display_name: QString::from(m.display_name().unwrap_or_default()),
                avatar_url: m.avatar_url().map(|u| QString::from(u.to_string().as_str())).unwrap_or_default(),
                presence: QString::default(), // presence not available from room members directly
                status_msg: QString::default(),
                power_level: power,
            }
        }).collect();

        // Sort: admins first, then mods, then alphabetical
        entries.sort_by(|a, b| {
            b.power_level.cmp(&a.power_level)
                .then_with(|| a.display_name.to_string().to_lowercase().cmp(&b.display_name.to_string().to_lowercase()))
        });

        Ok(entries)
    }

    /// Apply pre-fetched entries on the Qt thread.
    pub fn apply_entries(&mut self, entries: Vec<MemberEntry>) {
        self.begin_reset_model();
        *self.entries.borrow_mut() = entries;
        self.end_reset_model();
        self.count_changed();
        self.members_changed();
    }

    /// Global singleton accessor.
    pub fn get() -> QPointer<MemberModel> {
        SINGLETON.get_or_init(|| QPointer::default()).clone()
    }

    pub fn singleton_ptr() -> QPointer<MemberModel> {
        Self::get()
    }
}

impl qmetaobject::QSingletonInit for MemberModel {
    fn init(&mut self) {
        SINGLETON.set(QPointer::from(&*self));
    }
}

impl qmetaobject::QAbstractListModel for MemberModel {
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
        MemberEntry::names().into_iter().enumerate()
            .map(|(i, name)| (qmetaobject::USER_ROLE + i as i32, name))
            .collect()
    }
}
