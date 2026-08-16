//! `MatrixClient` — the central QML-facing singleton.
//!
//! Wraps `matrix_sdk::Client` and exposes:
//!  - token-based auto-login (`loginWithToken`)
//!  - password login (`loginWithPassword`)
//!  - IPv6-capable transport (forced via a custom reqwest builder)
//!  - room list, message sending, file/image/video upload & download
//!  - spaces hierarchy
//!  - profile read/write
//!
//! All async work happens on the shared Tokio runtime held by `Backend`.
//! Results are pushed to QML via Qt signals, so the UI thread never blocks.

use qmetaobject::*;
use std::cell::RefCell;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;

use crate::errors::AppResult;
use crate::room_model::{RoomModel, RoomEntry};
use crate::message_model::{MessageModel, MessageEntry};
use crate::spaces::{SpaceModel, SpaceEntry};
use crate::member_model::{MemberModel, MemberEntry};

/// Module-level singleton storage for MatrixClient.
static MATRIXCLIENT_SINGLETON: crate::singleton::QtSingleton<QPointer<MatrixClient>> =
    crate::singleton::QtSingleton::new();

/// Server-side configuration that survives restarts.
#[derive(serde::Serialize, serde::Deserialize, Clone, Default)]
pub struct SessionStore {
    pub homeserver: String,
    pub user_id: String,
    pub device_id: String,
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub force_ipv6: bool,
}

#[derive(QObject, Default)]
#[allow(non_snake_case)]
pub struct MatrixClient {
    base: qt_base_class!(trait QObject),

    inner: RefCell<Option<Arc<Mutex<matrix_sdk::Client>>>>,
    session: RefCell<Option<SessionStore>>,
    #[allow(dead_code)]
    session_path: RefCell<Option<PathBuf>>,

    /// True when fully synced and ready.
    ready: qt_property!(bool; NOTIFY readyChanged),
    /// True while a network call is in flight.
    busy: qt_property!(bool; NOTIFY busyChanged),
    /// Current user MXID, "" if logged out.
    userId: qt_property!(QString; NOTIFY userIdChanged),
    /// Last error message surfaced to the UI.
    lastError: qt_property!(QString; NOTIFY lastErrorChanged),

    readyChanged: qt_signal!(),
    busyChanged: qt_signal!(),
    userIdChanged: qt_signal!(),
    lastErrorChanged: qt_signal!(),

    /// Emitted with a JSON payload whenever a sync cycle completes.
    syncDone: qt_signal!(payload: QString),
    /// Emitted when login completes successfully.
    loggedIn: qt_signal!(user_id: QString),
    /// Emitted on logout.
    loggedOut: qt_signal!(),
    /// Emitted when a media download finishes. The third arg is the local
    /// filesystem path the file was saved to.
    fileDownloaded: qt_signal!(room_id: QString, mxc: QString, local_path: QString),
    /// Emitted after `setBanner` finishes copying the image to the cache dir.
    /// The argument is the `file://` URL of the new banner.
    bannerSet: qt_signal!(url: QString),
    /// Emitted when a user search completes. The argument is a JSON string:
    /// `[{user_id, display_name, avatar_url}, …]` (limited to 20 results).
    usersSearchDone: qt_signal!(results_json: QString),
    /// Emitted after `openDirectMessage` succeeds (or reuses an existing DM).
    /// The argument is the room id to switch to.
    dmOpened: qt_signal!(room_id: QString),
    /// Emitted after `leaveRoom` succeeds. The argument is the room id that
    /// was left/removed.
    roomLeft: qt_signal!(room_id: QString),

    // QML-callable method declarations
    autoLogin: qt_method!(fn(&self)),
    loginWithPassword: qt_method!(fn(&self, homeserver: QString, username: QString, password: QString, force_ipv6: bool)),
    loginWithToken: qt_method!(fn(&self, homeserver: QString, user_id: QString, device_id: QString, access_token: QString, force_ipv6: bool)),
    logout: qt_method!(fn(&self)),
    deleteAccount: qt_method!(fn(&self)),
    sendText: qt_method!(fn(&self, room_id: QString, body: QString)),
    sendFile: qt_method!(fn(&self, room_id: QString, local_path: QString, mime: QString, kind: QString)),
    downloadMedia: qt_method!(fn(&self, room_id: QString, mxc: QString, suggested_name: QString)),
    setDisplayName: qt_method!(fn(&self, name: QString)),
    setAvatar: qt_method!(fn(&self, local_path: QString)),
    setBanner: qt_method!(fn(&self, local_path: QString)),
    setForceIpv6: qt_method!(fn(&self, on: bool)),
    loadRoomMessages: qt_method!(fn(&self, room_id: QString)),
    loadRoomMembers: qt_method!(fn(&self, room_id: QString)),
    refreshRooms: qt_method!(fn(&self)),
    /// Search users by (partial) username/display name.
    /// Emits `usersSearchDone` with a JSON payload.
    searchUsers: qt_method!(fn(&self, query: QString)),
    /// Create (or open) a direct-message room with `user_id`.
    /// Emits `dmOpened(roomId)` when ready.
    openDirectMessage: qt_method!(fn(&self, user_id: QString)),
    /// Leave (and forget) a room. On success emits `roomLeft(roomId)`.
    leaveRoom: qt_method!(fn(&self, room_id: QString)),
}

impl MatrixClient {
    fn session_file_path() -> PathBuf {
        let base = directories::ProjectDirs::from("dev", "matrixclient", "matrix-client")
            .map(|d| d.data_dir().to_path_buf())
            .unwrap_or_else(|| std::env::temp_dir().join("matrix-client"));
        std::fs::create_dir_all(&base).ok();
        base.join("session.json")
    }

    fn set_busy(&mut self, on: bool) {
        self.busy = on;
        self.busyChanged();
    }

    fn set_error(&mut self, msg: impl Into<String>) {
        self.lastError = QString::from(msg.into().as_str());
        self.lastErrorChanged();
    }

    fn set_ready(&mut self, on: bool) {
        self.ready = on;
        self.readyChanged();
    }

    fn set_user_id(&mut self, id: impl Into<String>) {
        self.userId = QString::from(id.into().as_str());
        self.userIdChanged();
    }

    /// Public wrapper to emit the `file_downloaded` signal from outside this module.
    pub fn emit_file_downloaded(&self, room_id: QString, mxc: QString, local_path: QString) {
        self.fileDownloaded(room_id, mxc, local_path);
    }

    /// Public wrapper to emit the `banner_set` signal from outside this module.
    pub fn emit_banner_set(&self, url: QString) {
        self.bannerSet(url);
    }

    /// Public wrapper to emit the `users_search_done` signal.
    pub fn emit_users_search_done(&self, json: QString) {
        self.usersSearchDone(json);
    }

    /// Public wrapper to emit the `dm_opened` signal.
    pub fn emit_dm_opened(&self, room_id: QString) {
        self.dmOpened(room_id);
    }

    /// Public wrapper to emit the `room_left` signal.
    pub fn emit_room_left(&self, room_id: QString) {
        self.roomLeft(room_id);
    }

    /// Public wrapper to emit the `sync_done` signal from outside this module.
    pub fn emit_sync_done(&self, payload: QString) {
        self.syncDone(payload);
    }

    /// Public wrapper to emit the `logged_in` signal from outside this module.
    pub fn emit_logged_in(&self, user_id: QString) {
        self.loggedIn(user_id);
    }

    /// Public wrapper to emit the `logged_out` signal from outside this module.
    pub fn emit_logged_out(&self) {
        self.loggedOut();
    }

    /// Spawn a future on the Tokio runtime. Errors are forwarded to the UI
    /// via a `queued_callback` so the `QPointer` is never sent across threads
    /// (QPointer is !Send).
    fn spawn<F, T>(&self, fut: F)
    where
        F: std::future::Future<Output = AppResult<T>> + Send + 'static,
        T: Send + 'static,
    {
        let qptr = QPointer::from(&*self);
        let error_cb = qmetaobject::queued_callback(move |msg: String| {
            if let Some(this) = qptr.as_pinned() {
                this.borrow_mut().set_error(msg);
            }
        });
        let rt = crate::get_runtime();
        rt.spawn(async move {
            match fut.await {
                Ok(_) => {}
                Err(e) => {
                    ::log::warn!("async error: {e}");
                    error_cb(e.to_string());
                }
            }
        });
    }
}

// QML-callable methods.
#[allow(non_snake_case)]
impl MatrixClient {
    /// Try to resume a saved session (auto-login via stored session data).
    /// Called from QML on startup.
    pub fn autoLogin(&self) {
        let path = Self::session_file_path();
        ::log::info!("autoLogin: looking for saved session at {:?}", path);
        match std::fs::read_to_string(&path) {
            Ok(body) => match serde_json::from_str::<SessionStore>(&body) {
                Ok(sess) => {
                    ::log::info!("autoLogin: found session for user={} homeserver={}", sess.user_id, sess.homeserver);
                    let homeserver = sess.homeserver.clone();
                    let user_id = sess.user_id.clone();
                    let device_id = sess.device_id.clone();
                    let access_token = sess.access_token.clone();
                    let ipv6 = sess.force_ipv6;
                    self.spawn(async move {
                        ::log::info!("autoLogin: starting session restore");
                        Self::do_restore_session_with_full(
                            homeserver, user_id, device_id, access_token, ipv6,
                        ).await
                    });
                }
                Err(e) => {
                    if let Some(this) = QPointer::from(&*self).as_pinned() {
                        this.borrow_mut().set_error(format!("session corrupt: {e}"));
                    }
                }
            },
            Err(_) => {
                // No saved session — user needs to log in manually.
                if let Some(this) = QPointer::from(&*self).as_pinned() {
                    this.borrow_mut().set_ready(false);
                }
            }
        }
    }

    pub fn loginWithPassword(
        &self,
        homeserver: QString,
        username: QString,
        password: QString,
        force_ipv6: bool,
    ) {
        let homeserver = homeserver.to_string();
        let username = username.to_string();
        let password = password.to_string();
        {
            if let Some(this) = QPointer::from(&*self).as_pinned() {
                this.borrow_mut().set_busy(true);
            }
        }
        self.spawn(async move {
            Self::do_password_login(homeserver, username, password, force_ipv6).await
        });
    }

    pub fn loginWithToken(
        &self,
        homeserver: QString,
        user_id: QString,
        device_id: QString,
        access_token: QString,
        force_ipv6: bool,
    ) {
        let homeserver = homeserver.to_string();
        let user_id = user_id.to_string();
        let device_id = device_id.to_string();
        let access_token = access_token.to_string();
        {
            if let Some(this) = QPointer::from(&*self).as_pinned() {
                this.borrow_mut().set_busy(true);
            }
        }
        self.spawn(async move {
            Self::do_restore_session_with_full(homeserver, user_id, device_id, access_token, force_ipv6).await
        });
    }

    pub fn logout(&self) {
        let path = Self::session_file_path();
        let _ = std::fs::remove_file(&path);
        let client_arc = self.inner.borrow().clone();
        let qptr = QPointer::from(&*self);
        let logout_cb = qmetaobject::queued_callback(move |_: ()| {
            if let Some(this) = qptr.as_pinned() {
                let mut mc = this.borrow_mut();
                *mc.inner.borrow_mut() = None;
                *mc.session.borrow_mut() = None;
                mc.set_user_id(String::new());
                mc.set_ready(false);
                mc.emit_logged_out();
            }
        });
        let rt = crate::get_runtime();
        rt.spawn(async move {
            if let Some(c) = client_arc {
                let _ = c.lock().await.logout().await;
            }
            logout_cb(());
            let _: AppResult<()> = Ok(());
        });
    }

    pub fn sendText(&self, room_id: QString, body: QString) {
        let room_id = room_id.to_string();
        let body = body.to_string();
        self.spawn(async move {
            let client_arc = Self::require_client().await?;
            let c = client_arc.lock().await;
            let rid: ruma::OwnedRoomId = room_id.parse()
                .map_err(|e: ruma::IdParseError| crate::errors::AppError::Other(e.to_string()))?;
            let room = c
                .get_room(&rid)
                .ok_or_else(|| crate::errors::AppError::RoomNotFound(room_id.clone()))?;
            room.send(matrix_sdk::ruma::events::room::message::RoomMessageEventContent::text_markdown(body))
                .await?;
            AppResult::Ok(())
        });
    }

    pub fn sendFile(&self, room_id: QString, local_path: QString, mime: QString, kind: QString) {
        let room_id = room_id.to_string();
        let path = local_path.to_string();
        let mime = mime.to_string();
        let kind = kind.to_string();
        self.spawn(async move {
            crate::file_transfer::send_attachment(room_id, path, mime, kind).await
        });
    }

    pub fn downloadMedia(&self, room_id: QString, mxc: QString, suggested_name: QString) {
        let room_id = room_id.to_string();
        let mxc = mxc.to_string();
        let name = suggested_name.to_string();
        self.spawn(async move {
            crate::file_transfer::download_media(room_id, mxc, name).await
        });
    }

    pub fn setDisplayName(&self, name: QString) {
        let name = name.to_string();
        self.spawn(async move {
            let client_arc = Self::require_client().await?;
            let c = client_arc.lock().await;
            c.account().set_display_name(Some(&name)).await?;
            AppResult::Ok(())
        });
    }

    pub fn setAvatar(&self, local_path: QString) {
        let path = local_path.to_string();
        self.spawn(async move {
            let client_arc = Self::require_client().await?;
            crate::file_transfer::set_avatar(client_arc, path).await
        });
    }

    /// Set the user's profile banner (stored locally — Matrix has no standard
    /// banner field). After the file is copied to the cache directory we nudge
    /// `ProfileManager` so its `bannerUrl` property updates and the QML
    /// `Image` binding reloads.
    pub fn setBanner(&self, local_path: QString) {
        let path = local_path.to_string();
        let qptr = QPointer::from(&*self);
        let done_cb = qmetaobject::queued_callback(move |url: String| {
            if let Some(this) = qptr.as_pinned() {
                this.borrow().emit_banner_set(QString::from(url.as_str()));
                // Refresh ProfileManager so bannerUrl updates in QML.
                let pm = crate::profile::ProfileManager::get();
                if let Some(pm) = pm.as_pinned() {
                    pm.borrow().refresh();
                }
            }
        });
        self.spawn(async move {
            let url = crate::file_transfer::set_banner(path).await?;
            done_cb(url);
            AppResult::Ok(())
        });
    }

    pub fn setForceIpv6(&self, on: bool) {
        if let Some(s) = self.session.borrow_mut().as_mut() {
            s.force_ipv6 = on;
            self.persist_session();
        }
    }

    pub fn loadRoomMessages(&self, room_id: QString) {
        let room_id_str = room_id.to_string();
        ::log::info!("loadRoomMessages: room={} (current model count={})", room_id_str, MessageModel::get().as_pinned().map(|m| m.borrow().count()).unwrap_or(-1));
        let model = MessageModel::get();
        // Mark this room as the current target so stale responses
        // from a previous room are discarded by apply_entries.
        if let Some(m) = model.as_pinned() {
            m.borrow_mut().set_current_room(&room_id_str);
        }
        let client_arc = match self.inner.borrow().clone() {
            Some(c) => c,
            None => return,
        };
        let rid_for_signal = room_id_str.clone();
        let cb = qmetaobject::queued_callback(move |entries: Vec<MessageEntry>| {
            if let Some(m) = model.as_pinned() {
                m.borrow_mut().apply_entries(entries, &rid_for_signal);
            }
        });
        self.spawn(async move {
            let entries = MessageModel::fetch_messages(client_arc, room_id_str).await?;
            cb(entries);
            AppResult::Ok(())
        });
    }

    pub fn refreshRooms(&self) {
        ::log::info!("refreshRooms: starting room refresh");
        let rooms_ptr = RoomModel::get();
        let spaces_ptr = SpaceModel::get();
        let client_arc = match self.inner.borrow().clone() {
            Some(c) => c,
            None => {
                ::log::warn!("refreshRooms: no client available, skipping");
                return;
            }
        };
        let rooms_cb = qmetaobject::queued_callback(move |entries: Vec<RoomEntry>| {
            ::log::info!("refreshRooms: applying {} room entries to RoomModel", entries.len());
            if let Some(r) = rooms_ptr.as_pinned() {
                r.borrow_mut().apply_entries(entries);
            } else {
                ::log::warn!("refreshRooms: RoomModel QPointer is null, dropping entries");
            }
        });
        let spaces_cb = qmetaobject::queued_callback(move |entries: Vec<SpaceEntry>| {
            if let Some(s) = spaces_ptr.as_pinned() {
                s.borrow_mut().apply_entries(entries);
            }
        });
        self.spawn(async move {
            let room_entries = RoomModel::fetch_rooms(client_arc.clone()).await?;
            rooms_cb(room_entries);
            let space_entries = SpaceModel::fetch_spaces(client_arc).await?;
            spaces_cb(space_entries);
            AppResult::Ok(())
        });
    }

    /// Deactivate (permanently delete) the current account.
    /// This is irreversible — the server will remove all account data.
    pub fn deleteAccount(&self) {
        let client_arc = match self.inner.borrow().clone() {
            Some(c) => c,
            None => return,
        };
        let qptr = QPointer::from(&*self);
        let deleted_cb = qmetaobject::queued_callback(move |_: ()| {
            if let Some(this) = qptr.as_pinned() {
                let mut mc = this.borrow_mut();
                *mc.inner.borrow_mut() = None;
                *mc.session.borrow_mut() = None;
                mc.set_user_id(String::new());
                mc.set_ready(false);
                mc.emit_logged_out();
            }
        });
        self.spawn(async move {
            let c = client_arc.lock().await;
            // Matrix v3 account deactivation endpoint
            use matrix_sdk::ruma::api::client::account::deactivate::v3::Request as DeactivateRequest;
            let request = DeactivateRequest::new();
            c.send(request).await?;
            drop(c);
            // Remove saved session
            let path = Self::session_file_path();
            let _ = std::fs::remove_file(&path);
            deleted_cb(());
            AppResult::Ok(())
        });
    }

    /// Load members for a room/space and populate MemberModel.
    pub fn loadRoomMembers(&self, room_id: QString) {
        let room_id_str = room_id.to_string();
        let model = MemberModel::get();
        let client_arc = match self.inner.borrow().clone() {
            Some(c) => c,
            None => return,
        };
        let cb = qmetaobject::queued_callback(move |entries: Vec<MemberEntry>| {
            if let Some(m) = model.as_pinned() {
                m.borrow_mut().apply_entries(entries);
            }
        });
        self.spawn(async move {
            let entries = MemberModel::fetch_members(client_arc, room_id_str).await?;
            cb(entries);
            AppResult::Ok(())
        });
    }

    /// Search users by (partial) username/display name using the
    /// `/_matrix/client/v3/user_directory/search` endpoint.
    ///
    /// Emits `usersSearchDone(json)` with up to 20 results:
    ///   `[{"user_id":"@alice:…","display_name":"Alice","avatar_url":"mxc://…"}, …]`
    /// `avatar_url` is omitted when the user has no avatar.
    pub fn searchUsers(&self, query: QString) {
        let q = query.to_string();
        if q.trim().is_empty() {
            // Empty query → empty results so the dialog can hide the list.
            let qptr = QPointer::from(&*self);
            let empty_cb = qmetaobject::queued_callback(move |_: ()| {
                if let Some(this) = qptr.as_pinned() {
                    this.borrow().emit_users_search_done(QString::from("[]"));
                }
            });
            empty_cb(());
            return;
        }
        let qptr = QPointer::from(&*self);
        let results_cb = qmetaobject::queued_callback(move |json: String| {
            if let Some(this) = qptr.as_pinned() {
                this.borrow().emit_users_search_done(QString::from(json.as_str()));
            }
        });
        self.spawn(async move {
            let client_arc = Self::require_client().await?;
            let c = client_arc.lock().await;
            use matrix_sdk::ruma::api::client::user_directory::search_users::v3::Request as SearchUsersRequest;
            // The Request::new() takes the search_term as its only argument.
            let mut req = SearchUsersRequest::new(q);
            req.limit = 20u32.into();
            let resp = c.send(req).await?;
            // Serialize to JSON manually so QML can JSON.parse it.
            let mut arr = String::from("[");
            for (i, u) in resp.results.iter().enumerate() {
                if i > 0 { arr.push(','); }
                arr.push_str("{\"user_id\":");
                arr.push_str(&serde_json::to_string(&u.user_id.to_string())?);
                arr.push_str(",\"display_name\":");
                let dn = u.display_name.as_deref().unwrap_or("");
                arr.push_str(&serde_json::to_string(dn)?);
                arr.push_str(",\"avatar_url\":");
                let av = u.avatar_url.as_ref().map(|u| u.to_string()).unwrap_or_default();
                arr.push_str(&serde_json::to_string(&av)?);
                arr.push('}');
            }
            arr.push(']');
            results_cb(arr);
            AppResult::Ok(())
        });
    }

    /// Open (or create) a direct-message room with `user_id`.
    ///
    /// 1. If we already share a DM room with this user, switch to it.
    /// 2. Otherwise call `/_matrix/client/v3/createRoom` with `is_direct:true`
    ///    and invite the user.
    ///
    /// Emits `dmOpened(roomId)` on success.
    pub fn openDirectMessage(&self, user_id: QString) {
        let target = user_id.to_string();
        let qptr = QPointer::from(&*self);
        let opened_cb = qmetaobject::queued_callback(move |room_id: String| {
            if let Some(this) = qptr.as_pinned() {
                this.borrow().emit_dm_opened(QString::from(room_id.as_str()));
            }
        });
        self.spawn(async move {
            let client_arc = Self::require_client().await?;
            let c = client_arc.lock().await;

            // Parse target user id.
            let target_uid: ruma::OwnedUserId = target.parse().map_err(|e: ruma::IdParseError|
                crate::errors::AppError::Other(e.to_string()))?;

            // Look for an existing DM room with this user.
            // A room is a DM if `room.is_dm()` returns true and `direct_targets()`
            // contains the target user id.
            let mut found_room: Option<String> = None;
            for room in c.rooms() {
                if room.state() != matrix_sdk::RoomState::Joined {
                    continue;
                }
                if room.is_space() {
                    continue;
                }
                let targets = room.direct_targets();
                if targets.iter().any(|t| t == &target_uid) {
                    found_room = Some(room.room_id().to_string());
                    break;
                }
            }

            if let Some(rid) = found_room {
                drop(c);
                opened_cb(rid);
                return AppResult::Ok(());
            }

            // No existing DM — create a new one.
            use matrix_sdk::ruma::api::client::room::create_room::v3::Request as CreateRoomRequest;
            use matrix_sdk::ruma::api::client::room::create_room::v3::RoomPreset;

            let mut req = CreateRoomRequest::new();
            req.is_direct = true;
            // ruma 0.16 create_room::v3::Request uses `invite: Vec<UserId>`,
            // not `invited_users`.
            req.invite.push(target_uid.clone());
            // `preset` is Option<RoomPreset>; `visibility` is already private
            // by default in the ruma builder, so we don't need to set it.
            req.preset = Some(RoomPreset::PrivateChat);

            // Mark the room as a DM via the `m.direct` account-data event.
            // matrix-sdk exposes this through client.account().set_direct().
            // We set is_direct=true on the create request (above) and also
            // mark the account-data below after the room is created.

            // Set a friendly initial name based on the other user's MXID.
            let initial_name = format!("DM with {}", target_uid);
            req.name = Some(initial_name);

            let resp = c.send(req).await?;
            // ruma's create_room::v3::Response has `room_id` as a public
            // field (not a method), so we access it directly.
            let new_room_id = resp.room_id.clone();
            let new_room_id_str = new_room_id.to_string();

            // Mark this room as a DM in our own account_data so
            // room.is_dm() / direct_targets() return true for it on the
            // next refresh. Uses the built-in mark_as_dm() which
            // correctly handles fetching the existing m.direct event,
            // merging, and re-uploading.
            let _ = c.account().mark_as_dm(
                &new_room_id,
                &[target_uid.clone()],
            ).await;
            drop(c);

            opened_cb(new_room_id_str);
            AppResult::Ok(())
        });
    }

    /// Leave (and forget) a room.
    ///
    /// Calls `/_matrix/client/v3/rooms/{roomId}/leave`. On success emits
    /// `roomLeft(roomId)` and refreshes the room list so the room disappears
    /// from the sidebar.
    pub fn leaveRoom(&self, room_id: QString) {
        let rid_str = room_id.to_string();
        let qptr = QPointer::from(&*self);
        let left_cb = qmetaobject::queued_callback(move |rid: String| {
            if let Some(this) = qptr.as_pinned() {
                this.borrow().emit_room_left(QString::from(rid.as_str()));
                this.borrow().refreshRooms();
            }
        });
        self.spawn(async move {
            let client_arc = Self::require_client().await?;
            let c = client_arc.lock().await;
            let rid: ruma::OwnedRoomId = rid_str.parse()
                .map_err(|e: ruma::IdParseError| crate::errors::AppError::Other(e.to_string()))?;
            if let Some(room) = c.get_room(&rid) {
                room.leave().await?;
            } else {
                // Already gone — treat as success.
            }
            drop(c);
            left_cb(rid_str);
            AppResult::Ok(())
        });
    }
}

// Internal helpers (not exposed to QML).
impl MatrixClient {
    pub fn singleton_ptr() -> QPointer<MatrixClient> {
        Self::get()
    }

    pub fn get() -> QPointer<MatrixClient> {
        MATRIXCLIENT_SINGLETON.get_or_init(|| QPointer::default()).clone()
    }

    /// Get the client Arc from the singleton, for use in async contexts
    /// where we can't hold a reference to self across an await point.
    pub async fn require_client() -> AppResult<Arc<Mutex<matrix_sdk::Client>>> {
        let qptr = Self::singleton_ptr();
        let pinned = qptr.as_pinned().ok_or(crate::errors::AppError::NotLoggedIn)?;
        let result = pinned.borrow().inner.borrow().clone()
            .ok_or(crate::errors::AppError::NotLoggedIn);
        result
    }

    fn persist_session(&self) {
        if let Some(s) = self.session.borrow().as_ref() {
            let path = Self::session_file_path();
            if let Ok(json) = serde_json::to_string_pretty(s) {
                let _ = std::fs::write(path, json);
            }
        }
    }

    fn make_matrix_session(
        user_id: &str,
        device_id: &str,
        access_token: String,
        refresh_token: Option<String>,
    ) -> AppResult<matrix_sdk::authentication::matrix::MatrixSession> {
        use matrix_sdk::authentication::matrix::MatrixSession;
        use matrix_sdk::{SessionMeta, SessionTokens};

        Ok(MatrixSession {
            meta: SessionMeta {
                user_id: user_id
                    .parse()
                    .map_err(|e: ruma::IdParseError| crate::errors::AppError::Other(e.to_string()))?,
                device_id: device_id.into(),
            },
            tokens: SessionTokens {
                access_token,
                refresh_token,
            },
        })
    }

    /// Restore session with all fields known.
    async fn do_restore_session_with_full(
        homeserver: String,
        user_id: String,
        device_id: String,
        access_token: String,
        force_ipv6: bool,
    ) -> AppResult<()> {
        {
            let qptr = Self::singleton_ptr();
            if let Some(this) = qptr.as_pinned() {
                this.borrow_mut().set_busy(true);
            }
        }

        let client = crate::auth::build_client(&homeserver, force_ipv6).await?;

        let session = Self::make_matrix_session(
            &user_id,
            &device_id,
            access_token.clone(),
            None,
        )?;
        client.restore_session(session).await?;

        let s = SessionStore {
            homeserver,
            user_id,
            device_id,
            access_token: client.access_token().unwrap_or_default(),
            refresh_token: None,
            force_ipv6,
        };

        Self::finish_login(client, &s).await
    }

    async fn do_password_login(
        homeserver: String,
        username: String,
        password: String,
        force_ipv6: bool,
    ) -> AppResult<()> {
        {
            let qptr = Self::singleton_ptr();
            if let Some(this) = qptr.as_pinned() {
                this.borrow_mut().set_busy(true);
            }
        }

        let client = crate::auth::build_client(&homeserver, force_ipv6).await?;

        client
            .matrix_auth()
            .login_username(&username, &password)
            .initial_device_display_name("matrix-client (rust+qt)")
            .await?;

        let session_meta = client.session_meta()
            .ok_or(crate::errors::AppError::Other("no session after login".into()))?;
        let tokens = client.session_tokens()
            .ok_or(crate::errors::AppError::Other("no session tokens after login".into()))?;

        let s = SessionStore {
            homeserver,
            user_id: session_meta.user_id.to_string(),
            device_id: session_meta.device_id.to_string(),
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            force_ipv6,
        };

        Self::finish_login(client, &s).await
    }

    async fn finish_login(
        client: matrix_sdk::Client,
        sess: &SessionStore,
    ) -> AppResult<()> {
        ::log::info!("finish_login: user={} device={}", sess.user_id, sess.device_id);
        let arc = Arc::new(Mutex::new(client));

        // Handle the QPointer work on the Qt thread first (synchronously),
        // then DROP the qptr before we await anything — otherwise Rust thinks
        // the `QPointer` might still be live across the `.await` point and
        // marks the whole async block `!Send`, which breaks `self.spawn` /
        // `rt.spawn` everywhere that calls into `finish_login`.
        {
            let qptr = Self::singleton_ptr();
            if let Some(this) = qptr.as_pinned() {
                let mut mc = this.borrow_mut();
                *mc.inner.borrow_mut() = Some(arc.clone());
                *mc.session.borrow_mut() = Some(sess.clone());
                mc.persist_session();
                mc.set_user_id(sess.user_id.clone());
                mc.set_busy(false);
                mc.set_ready(true);
                mc.emit_logged_in(QString::from(sess.user_id.as_str()));

                // NOTE: Do NOT call refreshRooms() here. The SDK's
                // internal room state is empty before the first sync.
                // The sync loop's callback will call refreshRooms()
                // automatically after each successful sync cycle,
                // which is when rooms are actually available.
            }
        } // qptr dropped here

        // Kick off the sync loop in the background.
        //
        // IMPORTANT: We clone the `matrix_sdk::Client` out of the `Arc<Mutex<…>>`
        // before starting the loop. `matrix_sdk::Client` is internally `Arc`-backed
        // and `Send + Sync`, so the clone shares the same underlying state. Holding
        // our outer `Mutex` for the entire duration of `sync()` would block every
        // other code path that needs the client (refreshRooms, sendText, setAvatar,
        // profile lookups, …) forever, because `sync()` loops internally until
        // logout.
        //
        // We use `sync_once` in a manual loop instead of `sync` so that:
        //   1. The outer Mutex is never held during sync.
        //   2. We can call `refreshRooms()` on the Qt thread after every
        //      successful sync cycle, so newly-arrived state (e.g. `m.direct`
        //      account data that marks a room as a DM) is reflected in the UI
        //      without requiring the user to hit the refresh button.
        let client_clone = {
            let c = arc.lock().await;
            c.clone()
        };

        // Build queued_callbacks for posting data from the Tokio sync loop
        // back to the Qt thread. These are created BEFORE `rt.spawn` so the
        // QPointer captures stay Send-safe.
        //
        // IMPORTANT: We no longer use sync_cb to call refreshRooms().
        // The queued_callback mechanism was unreliable — callbacks posted from
        // Tokio were not delivered to the Qt event loop for 10+ seconds.
        // Instead, the sync loop directly calls RoomModel::fetch_rooms() from
        // Tokio and posts the results via these dedicated callbacks.

        // Callback to emit syncDone signal on Qt thread
        let sync_signal_qptr = Self::singleton_ptr();
        let sync_signal_cb = qmetaobject::queued_callback(move |_: ()| {
            if let Some(this) = sync_signal_qptr.as_pinned() {
                this.borrow().emit_sync_done(QString::from("{}"));
            }
        });

        // Callback to apply room entries on Qt thread
        let rooms_apply_ptr = RoomModel::get();
        let rooms_apply_cb = qmetaobject::queued_callback(move |entries: Vec<RoomEntry>| {
            ::log::info!("rooms_apply_cb: applying {} room entries on Qt thread", entries.len());
            if let Some(r) = rooms_apply_ptr.as_pinned() {
                r.borrow_mut().apply_entries(entries);
            } else {
                ::log::warn!("rooms_apply_cb: RoomModel QPointer is null!");
            }
        });

        // Callback to apply space entries on Qt thread
        let spaces_apply_ptr = SpaceModel::get();
        let spaces_apply_cb = qmetaobject::queued_callback(move |entries: Vec<SpaceEntry>| {
            if let Some(s) = spaces_apply_ptr.as_pinned() {
                s.borrow_mut().apply_entries(entries);
            }
        });

        // Callback to nudge ProfileManager on Qt thread
        let profile_qptr = crate::profile::ProfileManager::get();
        let profile_cb = qmetaobject::queued_callback(move |_: ()| {
            if let Some(pm_pinned) = profile_qptr.as_pinned() {
                pm_pinned.borrow().refresh();
            }
        });

        let rt = crate::get_runtime();
        rt.spawn(async move {
            let mut sync_token: Option<String> = None;
            let mut sync_cycle: u32 = 0;

            // ── Initial sync ──
            // Do a quick sync first so rooms appear immediately after login.
            ::log::info!("sync: performing initial sync with short timeout");
            let initial_settings = matrix_sdk::config::SyncSettings::default()
                .timeout(std::time::Duration::from_secs(10));
            match client_clone.sync_once(initial_settings).await {
                Ok(response) => {
                    sync_token = Some(response.next_batch);
                    ::log::info!("sync: initial sync OK, next_batch present={}", sync_token.is_some());
                    // Directly refresh rooms from Tokio — no queued_callback indirection.
                    match RoomModel::fetch_rooms(client_clone.clone()).await {
                        Ok(room_entries) => {
                            ::log::info!("sync: fetched {} rooms after initial sync", room_entries.len());
                            rooms_apply_cb(room_entries);
                        }
                        Err(e) => ::log::warn!("sync: fetch_rooms after initial sync error: {e}"),
                    }
                    match SpaceModel::fetch_spaces(client_clone.clone()).await {
                        Ok(space_entries) => spaces_apply_cb(space_entries),
                        Err(e) => ::log::warn!("sync: fetch_spaces after initial sync error: {e}"),
                    }
                    // Notify QML that sync is done (for message reload)
                    sync_signal_cb(());
                    profile_cb(());
                }
                Err(e) => {
                    ::log::warn!("sync: initial sync error: {e}");
                }
            }

            // ── Main sync loop ──
            loop {
                sync_cycle += 1;
                let mut sync_settings = matrix_sdk::config::SyncSettings::default()
                    .timeout(std::time::Duration::from_secs(15));
                if let Some(token) = sync_token.take() {
                    sync_settings = sync_settings.token(token);
                }
                ::log::debug!("sync_once: starting cycle #{}", sync_cycle);
                let start = std::time::Instant::now();
                let result = client_clone.sync_once(sync_settings).await;
                let elapsed = start.elapsed();
                match result {
                    Ok(response) => {
                        sync_token = Some(response.next_batch);
                        ::log::info!(
                            "sync_once: cycle #{} OK in {:.1}s, next_batch token present={}",
                            sync_cycle, elapsed.as_secs_f64(), sync_token.is_some()
                        );
                        // Directly refresh rooms from Tokio — bypasses
                        // sync_cb/queued_callback which was unreliable.
                        match RoomModel::fetch_rooms(client_clone.clone()).await {
                            Ok(room_entries) => {
                                ::log::info!("sync: fetched {} rooms after cycle #{}", room_entries.len(), sync_cycle);
                                rooms_apply_cb(room_entries);
                            }
                            Err(e) => ::log::warn!("sync: fetch_rooms error after cycle #{}: {e}", sync_cycle),
                        }
                        match SpaceModel::fetch_spaces(client_clone.clone()).await {
                            Ok(space_entries) => spaces_apply_cb(space_entries),
                            Err(e) => ::log::warn!("sync: fetch_spaces error after cycle #{}: {e}", sync_cycle),
                        }
                        // Notify QML that sync is done (for message reload)
                        sync_signal_cb(());
                        profile_cb(());
                    }
                    Err(e) => {
                        ::log::warn!("sync_once: cycle #{} error after {:.1}s: {e}", sync_cycle, elapsed.as_secs_f64());
                        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
                    }
                }
            }
        });

        Ok(())
    }
}

impl qmetaobject::QSingletonInit for MatrixClient {
    fn init(&mut self) {
        // Store the QPointer for global access from async contexts.
        MATRIXCLIENT_SINGLETON.set(QPointer::from(&*self));
    }
}
