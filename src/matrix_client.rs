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
use crate::profile::ProfileManager;

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
pub struct MatrixClient {
    base: qt_base_class!(trait QObject),

    inner: RefCell<Option<Arc<Mutex<matrix_sdk::Client>>>>,
    session: RefCell<Option<SessionStore>>,
    #[allow(dead_code)]
    session_path: RefCell<Option<PathBuf>>,

    rooms: QPointer<RoomModel>,
    spaces: QPointer<SpaceModel>,
    messages: QPointer<MessageModel>,
    profile: QPointer<ProfileManager>,

    /// True when fully synced and ready.
    ready: qt_property!(bool; NOTIFY ready_changed),
    /// True while a network call is in flight.
    busy: qt_property!(bool; NOTIFY busy_changed),
    /// Current user MXID, "" if logged out.
    user_id: qt_property!(QString; NOTIFY user_id_changed),
    /// Last error message surfaced to the UI.
    last_error: qt_property!(QString; NOTIFY last_error_changed),

    ready_changed: qt_signal!(),
    busy_changed: qt_signal!(),
    user_id_changed: qt_signal!(),
    last_error_changed: qt_signal!(),

    /// Emitted with a JSON payload whenever a sync cycle completes.
    sync_done: qt_signal!(payload: QString),
    /// Emitted when login completes successfully.
    logged_in: qt_signal!(user_id: QString),
    /// Emitted on logout.
    logged_out: qt_signal!(),
    /// Emitted when a media download finishes. The third arg is the local
    /// filesystem path the file was saved to.
    file_downloaded: qt_signal!(room_id: QString, mxc: QString, local_path: QString),

    // QML-callable method declarations
    auto_login: qt_method!(fn(&self)),
    login_with_password: qt_method!(fn(&self, homeserver: QString, username: QString, password: QString, force_ipv6: bool)),
    login_with_token: qt_method!(fn(&self, homeserver: QString, user_id: QString, device_id: QString, access_token: QString, force_ipv6: bool)),
    logout: qt_method!(fn(&self)),
    send_text: qt_method!(fn(&self, room_id: QString, body: QString)),
    send_file: qt_method!(fn(&self, room_id: QString, local_path: QString, mime: QString, kind: QString)),
    download_media: qt_method!(fn(&self, room_id: QString, mxc: QString, suggested_name: QString)),
    set_display_name: qt_method!(fn(&self, name: QString)),
    set_avatar: qt_method!(fn(&self, local_path: QString)),
    set_force_ipv6: qt_method!(fn(&self, on: bool)),
    room_model: qt_method!(fn(&self) -> QPointer<RoomModel>),
    space_model: qt_method!(fn(&self) -> QPointer<SpaceModel>),
    message_model: qt_method!(fn(&self) -> QPointer<MessageModel>),
    profile_manager: qt_method!(fn(&self) -> QPointer<ProfileManager>),
    load_room_messages: qt_method!(fn(&self, room_id: QString)),
    refresh_rooms: qt_method!(fn(&self)),
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
        self.busy_changed();
    }

    fn set_error(&mut self, msg: impl Into<String>) {
        self.last_error = QString::from(msg.into().as_str());
        self.last_error_changed();
    }

    fn set_ready(&mut self, on: bool) {
        self.ready = on;
        self.ready_changed();
    }

    fn set_user_id(&mut self, id: impl Into<String>) {
        self.user_id = QString::from(id.into().as_str());
        self.user_id_changed();
    }

    /// Public wrapper to emit the `file_downloaded` signal from outside this module.
    pub fn emit_file_downloaded(&self, room_id: QString, mxc: QString, local_path: QString) {
        self.file_downloaded(room_id, mxc, local_path);
    }

    /// Public wrapper to emit the `sync_done` signal from outside this module.
    pub fn emit_sync_done(&self, payload: QString) {
        self.sync_done(payload);
    }

    /// Public wrapper to emit the `logged_in` signal from outside this module.
    pub fn emit_logged_in(&self, user_id: QString) {
        self.logged_in(user_id);
    }

    /// Public wrapper to emit the `logged_out` signal from outside this module.
    pub fn emit_logged_out(&self) {
        self.logged_out();
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
        let rt = crate::Backend::get().as_ref()
            .expect("Backend not initialized").runtime().clone();
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
    /// Try to resume a saved session (auto-login via stored access token).
    /// Called from QML on startup.
    pub fn auto_login(&self) {
        let path = Self::session_file_path();
        match std::fs::read_to_string(&path) {
            Ok(body) => match serde_json::from_str::<SessionStore>(&body) {
                Ok(sess) => {
                    let token = sess.access_token.clone();
                    let homeserver = sess.homeserver.clone();
                    let ipv6 = sess.force_ipv6;
                    self.spawn(async move {
                        Self::do_restore_session(homeserver, token, ipv6).await
                    });
                }
                Err(e) => {
                    if let Some(this) = QPointer::from(&*self).as_pinned() {
                        this.borrow_mut().set_error(format!("session corrupt: {e}"));
                    }
                }
            },
            Err(_) => {
                if let Some(this) = QPointer::from(&*self).as_pinned() {
                    this.borrow_mut().set_ready(false);
                }
            }
        }
    }

    pub fn login_with_password(
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

    pub fn login_with_token(
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
        let rt = crate::Backend::get().as_ref()
            .expect("Backend not initialized").runtime().clone();
        rt.spawn(async move {
            if let Some(c) = client_arc {
                let _ = c.lock().await.logout().await;
            }
            logout_cb(());
            let _: AppResult<()> = Ok(());
        });
    }

    pub fn send_text(&self, room_id: QString, body: QString) {
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

    pub fn send_file(&self, room_id: QString, local_path: QString, mime: QString, kind: QString) {
        let room_id = room_id.to_string();
        let path = local_path.to_string();
        let mime = mime.to_string();
        let kind = kind.to_string();
        self.spawn(async move {
            crate::file_transfer::send_attachment(room_id, path, mime, kind).await
        });
    }

    pub fn download_media(&self, room_id: QString, mxc: QString, suggested_name: QString) {
        let room_id = room_id.to_string();
        let mxc = mxc.to_string();
        let name = suggested_name.to_string();
        self.spawn(async move {
            crate::file_transfer::download_media(room_id, mxc, name).await
        });
    }

    pub fn set_display_name(&self, name: QString) {
        let name = name.to_string();
        self.spawn(async move {
            let client_arc = Self::require_client().await?;
            let c = client_arc.lock().await;
            c.account().set_display_name(Some(&name)).await?;
            AppResult::Ok(())
        });
    }

    pub fn set_avatar(&self, local_path: QString) {
        let path = local_path.to_string();
        self.spawn(async move {
            let client_arc = Self::require_client().await?;
            crate::file_transfer::set_avatar(client_arc, path).await
        });
    }

    pub fn set_force_ipv6(&self, on: bool) {
        if let Some(s) = self.session.borrow_mut().as_mut() {
            s.force_ipv6 = on;
            self.persist_session();
        }
    }

    pub fn room_model(&self) -> QPointer<RoomModel> {
        self.rooms.clone()
    }

    pub fn space_model(&self) -> QPointer<SpaceModel> {
        self.spaces.clone()
    }

    pub fn message_model(&self) -> QPointer<MessageModel> {
        self.messages.clone()
    }

    pub fn profile_manager(&self) -> QPointer<ProfileManager> {
        self.profile.clone()
    }

    pub fn load_room_messages(&self, room_id: QString) {
        let room_id_str = room_id.to_string();
        let model = self.messages.clone();
        let client_arc = match self.inner.borrow().clone() {
            Some(c) => c,
            None => return,
        };
        // Create the queued_callback BEFORE spawn so QPointer is wrapped
        // by qmetaobject (which makes the callback itself Send).
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

    pub fn refresh_rooms(&self) {
        let rooms_ptr = self.rooms.clone();
        let spaces_ptr = self.spaces.clone();
        let client_arc = match self.inner.borrow().clone() {
            Some(c) => c,
            None => return,
        };
        // Create queued_callbacks BEFORE spawn so QPointer is wrapped
        // by qmetaobject (which makes the callbacks themselves Send).
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
}

// Internal helpers (not exposed to QML).
impl MatrixClient {
    pub fn singleton_ptr() -> QPointer<MatrixClient> {
        Self::get()
    }

    pub fn get() -> QPointer<MatrixClient> {
        use std::sync::OnceLock;
        static INSTANCE: OnceLock<QPointer<MatrixClient>> = OnceLock::new();
        INSTANCE.get_or_init(|| {
            let mc = MatrixClient::default();
            QPointer::from(&mc)
        }).clone()
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

    /// Restore session with just an access token.
    async fn do_restore_session(
        homeserver: String,
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
            "@_restore_pending:localhost",
            "RESTORE",
            access_token.clone(),
            None,
        )?;
        client.restore_session(session).await?;
        let who = client.whoami().await?;

        let s = SessionStore {
            homeserver,
            user_id: who.user_id.to_string(),
            device_id: who.device_id.map(|d| d.to_string()).unwrap_or_default(),
            access_token: client.access_token().unwrap_or_default(),
            refresh_token: None,
            force_ipv6,
        };

        Self::finish_login(client, &s).await
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

            mc.refresh_rooms();
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
        let rt = crate::Backend::get().as_ref()
            .expect("Backend not initialized").runtime().clone();
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
    fn init(&mut self) {}
}
