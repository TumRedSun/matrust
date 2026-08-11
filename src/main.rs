#![recursion_limit = "256"]

//! matrix-client — entry point.
//!
//! Boots the Tokio runtime, registers all QML singletons and types,
//! and starts the Qt UI event loop.

use cstr::cstr;
use qmetaobject::{qrc, QPointer, QObject, QmlEngine, qt_base_class};
use std::sync::Arc;
use tokio::runtime::Runtime;

mod singleton;
mod matrix_client;
mod auth;
mod room_model;
mod message_model;
mod file_transfer;
mod spaces;
mod profile;
mod theme;
mod avatar_cache;
mod errors;

use crate::matrix_client::MatrixClient;
use crate::theme::Theme;

/// Module-level singleton storage for Backend.
static BACKEND_SINGLETON: singleton::QtSingleton<QPointer<Backend>> = singleton::QtSingleton::new();

// Embed the QML directory into the binary so the app is self-contained.
qrc! {
    pub qml_resources,
    "qml" as "/qml" {
        "main.qml",
        "LoginPage.qml",
        "ChatPage.qml",
        "SpacesPage.qml",
        "RoomsSidebar.qml",
        "MessageBubble.qml",
        "ProfilePage.qml",
        "SettingsPage.qml",
        "AppearancePage.qml",
    },
    "assets" as "/assets" {
        "logo.svg",
        "default-avatar.svg",
    }
}

/// Backend singleton exposed to QML as `Backend`.
///
/// Holds the shared Tokio runtime and the live MatrixClient handle.
#[derive(QObject, Default)]
pub struct Backend {
    base: qt_base_class!(trait QObject),
    runtime: Option<Arc<Runtime>>,
}

impl Backend {
    pub fn runtime(&self) -> &Arc<Runtime> {
        self.runtime.as_ref().expect("runtime initialized")
    }

    /// Global singleton accessor.
    /// Returns the QPointer stored when the QML engine created the singleton.
    pub fn get() -> QPointer<Backend> {
        BACKEND_SINGLETON.get_or_init(|| QPointer::default()).clone()
    }
}

impl qmetaobject::QSingletonInit for Backend {
    fn init(&mut self) {
        // Set up the Tokio runtime on the engine-created singleton.
        if self.runtime.is_none() {
            self.runtime = Some(Arc::new(
                Runtime::new().expect("failed to build Tokio runtime"),
            ));
        }
        // Store the QPointer for global access.
        BACKEND_SINGLETON.set(QPointer::from(&*self));
    }
}

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp_secs()
        .init();

    // Load embedded QML resources.
    qml_resources();

    let mut engine = QmlEngine::new();

    // Register singletons. qmetaobject 0.2 uses qml_register_singleton_type
    // with cstr!() and no &mut engine parameter.
    // The QML engine will create each singleton on first access and
    // call QSingletonInit::init(), which stores the QPointer and
    // performs any setup (e.g. starting the Tokio runtime for Backend).
    qmetaobject::qml_register_singleton_type::<Backend>(cstr!("MatrixClient"), 1, 0, cstr!("Backend"));
    qmetaobject::qml_register_singleton_type::<Theme>(cstr!("MatrixClient"), 1, 0, cstr!("Theme"));
    qmetaobject::qml_register_singleton_type::<MatrixClient>(cstr!("MatrixClient"), 1, 0, cstr!("MatrixClient"));

    // Register instantiable types.
    qmetaobject::qml_register_type::<room_model::RoomModel>(cstr!("MatrixClient"), 1, 0, cstr!("RoomModel"));
    qmetaobject::qml_register_type::<message_model::MessageModel>(cstr!("MatrixClient"), 1, 0, cstr!("MessageModel"));
    qmetaobject::qml_register_type::<spaces::SpaceModel>(cstr!("MatrixClient"), 1, 0, cstr!("SpaceModel"));
    qmetaobject::qml_register_type::<profile::ProfileManager>(cstr!("MatrixClient"), 1, 0, cstr!("ProfileManager"));

    engine.load_file("qrc:/qml/main.qml".into());
    engine.exec();
}
