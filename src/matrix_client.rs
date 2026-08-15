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
    setForceIpv6: qt_method!(fn(&self, on: bool)),
    loadRoomMessages: qt_method!(fn(&self, room_id: QString)),
    loadRoomMembers: qt_method!(fn(&self, room_id: QString)),
    refreshRooms: qt_method!(fn(&self)),
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
        match std::fs::read_to_string(&path) {
            Ok(body) => match serde_json::from_str::<SessionStore>(&body) {
                Ok(sess) => {
                    let homeserver = sess.homeserver.clone();
                    let user_id = sess.user_id.clone();
                    let device_id = sess.device_id.clone();
                    let access_token = sess.access_token.clone();
                    let ipv6 = sess.force_ipv6;
                    self.spawn(async move {
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

    pub fn setForceIpv6(&self, on: bool) {
        if let Some(s) = self.session.borrow_mut().as_mut() {
            s.force_ipv6 = on;
            self.persist_session();
        }
    }

    pub fn loadRoomMessages(&self, room_id: QString) {
        let room_id_str = room_id.to_string();
        let model = MessageModel::get();
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
        let rooms_ptr = RoomModel::get();
        let spaces_ptr = SpaceModel::get();
        let client_arc = match self.inner.borrow().clone() {
            Some(c) => c,
            None => return,
        };
        let rooms_cb = qmetaobject::queued_callback(move |entries: Vec<RoomEntry>| {
            if let Some(r) = rooms_ptr.as_pinned() {
                r.borrow_mut().apply_entries(entries);
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

        // Skip sqlite store on restore to avoid crypto device-ID mismatch.
        // The client will use an in-memory store; restore_session() sets up
        // the identity without conflicting with a pre-existing crypto account.
        let client = crate::auth::build_client(&homeserver, force_ipv6, false).await?;

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

        let client = crate::auth::build_client(&homeserver, force_ipv6, true).await?;

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
        let arc = Arc::new(Mutex::new(client));

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

            mc.refreshRooms();
        }

        // Kick off the sync loop in the background.
        // Use queued_callback so QPointer is never sent across threads.
        let arc2 = arc.clone();
        let qptr2 = qptr.clone();
        let sync_done_cb = qmetaobject::queued_callback(move |_: ()| {
            if let Some(this) = qptr2.as_pinned() {
                this.borrow().emit_sync_done(QString::from("{}"));
            }
        });
        let rt = crate::get_runtime();
        rt.spawn(async move {
            let c = arc2.lock().await;
            c.sync(matrix_sdk::config::SyncSettings::default()).await.ok();
            drop(c);
            sync_done_cb(());
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
