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
use crate::room_model::RoomModel;
use crate::message_model::MessageModel;
use crate::spaces::SpaceModel;
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
    session_path: RefCell<Option<PathBuf>>,

    rooms: QPointer<RoomModel>,
    spaces: QPointer<SpaceModel>,
    messages: QPointer<MessageModel>,
    profile: QPointer<ProfileManager>,

    /// True when fully synced and ready.
    ready: qt_property!(bool; NOTIFY ready_changed READ ready),
    /// True while a network call is in flight.
    busy: qt_property!(bool; NOTIFY busy_changed READ busy),
    /// Current user MXID, "" if logged out.
    user_id: qt_property!(QString; NOTIFY user_id_changed READ user_id),
    /// Last error message surfaced to the UI.
    last_error: qt_property!(QString; NOTIFY last_error_changed READ last_error),

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

    // QML-callable method declarations (qt_method! is a function-like macro
    // in qmetaobject 0.2; the actual bodies live in the impl block below).
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

    fn set_busy(&self, on: bool) {
        self.busy = on;
        self.busy_changed();
    }

    fn set_error(&self, msg: impl Into<String>) {
        self.last_error = QString::from(msg.into().as_str());
        self.last_error_changed();
    }

    fn set_ready(&self, on: bool) {
        self.ready = on;
        self.ready_changed();
    }

    fn set_user_id(&self, id: impl Into<String>) {
        self.user_id = QString::from(id.into().as_str());
        self.user_id_changed();
    }

    fn spawn<F, T>(&self, fut: F)
    where
        F: std::future::Future<Output = AppResult<T>> + Send + 'static,
        T: Send + 'static,
    {
        let qptr = QPointer::from(self);
        let backend = crate::Backend::get();
        backend.runtime().spawn(async move {
            match fut.await {
                Ok(_) => {}
                Err(e) => {
                    // Use ::log to disambiguate from the `log` module
                    // re-exported by qmetaobject's glob import.
                    ::log::warn!("async error: {e}");
                    if let Some(this) = qptr.as_ref() {
                        this.set_error(e.to_string());
                    }
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
                        let this = MatrixClient::singleton_ptr();
                        this.restore_session(homeserver, token, ipv6).await
                    });
                }
                Err(e) => self.set_error(format!("session corrupt: {e}")),
            },
            Err(_) => {
                // No saved session — UI will show login page.
                self.set_ready(false);
            }
        }
    }

    /// Login with username + password. `force_ipv6` toggles the IPv6-only
    /// transport.
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
        self.set_busy(true);
        self.spawn(async move {
            let this = MatrixClient::singleton_ptr();
            this.do_password_login(homeserver, username, password, force_ipv6).await
        });
    }

    /// Login with a pre-existing access token (e.g. imported from another
    /// client, or stored on disk by `auto_login`).
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
        self.set_busy(true);
        self.spawn(async move {
            let this = MatrixClient::singleton_ptr();
            this.restore_session_with_full(homeserver, user_id, device_id, access_token, force_ipv6).await
        });
    }

    /// Logout and clear the on-disk session.
    pub fn logout(&self) {
        let path = Self::session_file_path();
        let _ = std::fs::remove_file(&path);
        self.spawn(async move {
            let this = MatrixClient::singleton_ptr();
            let guard = this.inner.borrow().clone();
            if let Some(c) = guard {
                // In matrix-sdk 0.18+, logout() is on Client directly.
                let _ = c.lock().await.logout().await;
            }
            *this.inner.borrow_mut() = None;
            *this.session.borrow_mut() = None;
            this.set_user_id(String::new());
            this.set_ready(false);
            this.logged_out();
            AppResult::Ok(())
        });
    }

    /// Send a text message (markdown supported).
    pub fn send_text(&self, room_id: QString, body: QString) {
        let room_id = room_id.to_string();
        let body = body.to_string();
        self.spawn(async move {
            let this = MatrixClient::singleton_ptr();
            let c = this.require_client().await?;
            let room = c
                .get_room(&room_id.parse().map_err(|e: ruma::IdParseError| crate::errors::AppError::Other(e.to_string()))?)
                .ok_or_else(|| crate::errors::AppError::RoomNotFound(room_id.clone()))?;
            room.send(matrix_sdk::ruma::events::room::message::RoomMessageEventContent::text_markdown(body))
                .await?;
            AppResult::Ok(())
        });
    }

    /// Upload a file and send it as a message attachment.
    /// `mime` is a MIME string, `kind` is one of "file" | "image" | "video" | "audio".
    pub fn send_file(&self, room_id: QString, local_path: QString, mime: QString, kind: QString) {
        let room_id = room_id.to_string();
        let path = local_path.to_string();
        let mime = mime.to_string();
        let kind = kind.to_string();
        self.spawn(async move {
            crate::file_transfer::send_attachment(room_id, path, mime, kind).await
        });
    }

    /// Download an `mxc://` URI to disk; returns the local path via the
    /// `fileDownloaded(roomId, mxc, localPath)` signal.
    pub fn download_media(&self, room_id: QString, mxc: QString, suggested_name: QString) {
        let room_id = room_id.to_string();
        let mxc = mxc.to_string();
        let name = suggested_name.to_string();
        self.spawn(async move {
            crate::file_transfer::download_media(room_id, mxc, name).await
        });
    }

    /// Set display name.
    pub fn set_display_name(&self, name: QString) {
        let name = name.to_string();
        self.spawn(async move {
            let this = MatrixClient::singleton_ptr();
            let c = this.require_client().await?;
            c.account().set_display_name(Some(&name)).await?;
            AppResult::Ok(())
        });
    }

    /// Upload and set avatar from a local file.
    pub fn set_avatar(&self, local_path: QString) {
        let path = local_path.to_string();
        self.spawn(async move {
            let this = MatrixClient::singleton_ptr();
            let c = this.require_client().await?;
            crate::file_transfer::set_avatar(c.clone(), path).await
        });
    }

    /// Toggle IPv6-only mode at runtime. Forces a client rebuild on next
    /// sync.
    pub fn set_force_ipv6(&self, on: bool) {
        if let Some(s) = self.session.borrow_mut().as_mut() {
            s.force_ipv6 = on;
            self.persist_session();
        }
    }

    pub fn room_model(&self) -> QPointer<RoomModel> {
        if self.rooms.is_null() {
            self.rooms = QPointer::from(RoomModel::default());
        }
        self.rooms.clone()
    }

    pub fn space_model(&self) -> QPointer<SpaceModel> {
        if self.spaces.is_null() {
            self.spaces = QPointer::from(SpaceModel::default());
        }
        self.spaces.clone()
    }

    pub fn message_model(&self) -> QPointer<MessageModel> {
        if self.messages.is_null() {
            self.messages = QPointer::from(MessageModel::default());
        }
        self.messages.clone()
    }

    pub fn profile_manager(&self) -> QPointer<ProfileManager> {
        if self.profile.is_null() {
            self.profile = QPointer::from(ProfileManager::default());
        }
        self.profile.clone()
    }

    /// Load messages for a room; the model will be populated asynchronously
    /// via signals.
    pub fn load_room_messages(&self, room_id: QString) {
        let room_id = room_id.to_string();
        self.spawn(async move {
            let this = MatrixClient::singleton_ptr();
            let c = this.require_client().await?;
            let model = this.messages.clone();
            if let Some(m) = model.as_ref() {
                m.load_for_room(c, room_id).await?;
            }
            AppResult::Ok(())
        });
    }

    /// Refresh the room list and spaces tree from cache + sync.
    pub fn refresh_rooms(&self) {
        self.spawn(async move {
            let this = MatrixClient::singleton_ptr();
            let c = this.require_client().await?;
            if let Some(r) = this.rooms.as_ref() {
                r.refresh(c.clone()).await?;
            }
            if let Some(s) = this.spaces.as_ref() {
                s.refresh(c.clone()).await?;
            }
            AppResult::Ok(())
        });
    }
}

// Internal helpers (not exposed to QML).
impl MatrixClient {
    /// Returns the global singleton pointer.
    pub fn singleton_ptr() -> QPointer<MatrixClient> {
        Self::get()
    }

    /// Global singleton accessor (replaces the removed qmetaobject::Singleton trait).
    pub fn get() -> QPointer<MatrixClient> {
        use std::sync::Once;
        static INIT: Once = Once::new();
        static mut INSTANCE: Option<QPointer<MatrixClient>> = None;
        INIT.call_once(|| unsafe {
            INSTANCE = Some(QPointer::from(MatrixClient::default()));
        });
        unsafe { INSTANCE.clone().unwrap() }
    }

    async fn require_client(&self) -> AppResult<Arc<Mutex<matrix_sdk::Client>>> {
        self.inner
            .borrow()
            .clone()
            .ok_or(crate::errors::AppError::NotLoggedIn)
    }

    fn persist_session(&self) {
        if let Some(s) = self.session.borrow().as_ref() {
            let path = Self::session_file_path();
            if let Ok(json) = serde_json::to_string_pretty(s) {
                let _ = std::fs::write(path, json);
            }
        }
    }

    /// Build a `MatrixSession` from the stored session fields.
    /// In matrix-sdk 0.18, `MatrixSession` lives in
    /// `matrix_sdk::authentication::matrix` and is composed of
    /// `SessionMeta` (user_id + device_id) and `SessionTokens`
    /// (access_token + refresh_token). Note: `MatrixSessionTokens`
    /// was renamed to `SessionTokens`.
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

    async fn restore_session(
        &self,
        homeserver: String,
        access_token: String,
        force_ipv6: bool,
    ) -> AppResult<()> {
        self.set_busy(true);
        let client = crate::auth::build_client(&homeserver, force_ipv6).await?;

        // For token-only restore we don't yet know the user_id/device_id.
        // Use a sentinel session first, then call whoami() to fill in the gaps.
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
        *self.session.borrow_mut() = Some(s.clone());
        self.persist_session();
        self.finish_login(client, &s).await
    }

    async fn restore_session_with_full(
        &self,
        homeserver: String,
        user_id: String,
        device_id: String,
        access_token: String,
        force_ipv6: bool,
    ) -> AppResult<()> {
        self.set_busy(true);
        let client = crate::auth::build_client(&homeserver, force_ipv6).await?;

        // In matrix-sdk 0.18+, restore_session() is on Client directly
        // and takes a MatrixSession.
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
        *self.session.borrow_mut() = Some(s.clone());
        self.persist_session();
        self.finish_login(client, &s).await
    }

    async fn do_password_login(
        &self,
        homeserver: String,
        username: String,
        password: String,
        force_ipv6: bool,
    ) -> AppResult<()> {
        self.set_busy(true);
        let client = crate::auth::build_client(&homeserver, force_ipv6).await?;

        // In matrix-sdk 0.18+, login_username() returns a builder that
        // you .await directly (no .send()).
        client
            .matrix_auth()
            .login_username(&username, &password)
            .initial_device_display_name("matrix-client (rust+qt)")
            .await?;

        // After login, retrieve session info from the client.
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
        *self.session.borrow_mut() = Some(s.clone());
        self.persist_session();
        self.finish_login(client, &s).await
    }

    async fn finish_login(
        &self,
        client: matrix_sdk::Client,
        sess: &SessionStore,
    ) -> AppResult<()> {
        let arc = Arc::new(Mutex::new(client));
        *self.inner.borrow_mut() = Some(arc.clone());

        self.set_user_id(sess.user_id.clone());
        self.set_busy(false);
        self.set_ready(true);
        self.logged_in(QString::from(sess.user_id.as_str()));

        // Kick off the sync loop in the background.
        let arc2 = arc.clone();
        let qptr = QPointer::from(self);
        crate::Backend::get().runtime().spawn(async move {
            // In matrix-sdk 0.18+, SyncSettings is in matrix_sdk::config.
            let c = arc2.lock().await;
            c.sync(matrix_sdk::config::SyncSettings::default()).await.ok();
            drop(c);
            if let Some(this) = qptr.as_ref() {
                this.sync_done(QString::from("{}"));
            }
        });

        // Refresh models immediately.
        self.refresh_rooms();
        AppResult::Ok(())
    }
}

impl qmetaobject::QSingletonInit for MatrixClient {
    fn init(&mut self) {}
}
