//! matrix-client — entry point.
//!
//! Boots the Tokio runtime, registers all QML singletons and types,
//! and starts the Qt UI event loop.

use qmetaobject::{qrc, QPointer, QObject, QmlEngine, qt_base_class};
use std::sync::Arc;
use tokio::runtime::Runtime;

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

// Embed the QML directory into the binary so the app is self-contained.
qrc! {
    pub qml_resources {
        "/qml" {
            "qml/main.qml",
            "qml/LoginPage.qml",
            "qml/ChatPage.qml",
            "qml/SpacesPage.qml",
            "qml/RoomsSidebar.qml",
            "qml/MessageBubble.qml",
            "qml/ProfilePage.qml",
            "qml/SettingsPage.qml",
            "qml/AppearancePage.qml",
        },
        "/assets" {
            "assets/logo.svg",
            "assets/default-avatar.svg",
        }
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
}

impl qmetaobject::Singleton for Backend {
    fn get() -> qmetaobject::QPointer<Backend> {
        use std::sync::Once;
        static INIT: Once = Once::new();
        static mut INSTANCE: Option<QPointer<Backend>> = None;
        INIT.call_once(|| {
            let rt = Arc::new(
                Runtime::new()
                    .expect("failed to build Tokio runtime"),
            );
            let mut b = Backend::default();
            b.runtime = Some(rt);
            unsafe { INSTANCE = Some(QPointer::from(b)); }
        });
        unsafe { INSTANCE.clone().unwrap() }
    }
}

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp_secs()
        .init();

    // Load embedded QML resources.
    qml_resources();

    let mut engine = QmlEngine::new();

    // Ensure the Backend (shared Tokio runtime) is initialized up-front.
    Backend::get();

    // Register singletons. qmetaobject 0.2 uses the free function
    // `register_singleton_type::<T>(&mut engine, uri, major, minor, name)`.
    qmetaobject::register_singleton_type::<Backend>(&mut engine, "MatrixClient", 1, 0, "Backend");
    qmetaobject::register_singleton_type::<Theme>(&mut engine, "MatrixClient", 1, 0, "Theme");
    qmetaobject::register_singleton_type::<MatrixClient>(&mut engine, "MatrixClient", 1, 0, "MatrixClient");

    // Register instantiable types.
    qmetaobject::register_type::<room_model::RoomModel>(&mut engine, "MatrixClient", 1, 0, "RoomModel");
    qmetaobject::register_type::<message_model::MessageModel>(&mut engine, "MatrixClient", 1, 0, "MessageModel");
    qmetaobject::register_type::<spaces::SpaceModel>(&mut engine, "MatrixClient", 1, 0, "SpaceModel");
    qmetaobject::register_type::<profile::ProfileManager>(&mut engine, "MatrixClient", 1, 0, "ProfileManager");

    engine.load_file("qrc:/qml/main.qml");
    engine.exec();
}
