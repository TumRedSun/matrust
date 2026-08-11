//! Profile management: display name, avatar, presence.

use qmetaobject::*;

#[derive(QObject, Default)]
#[allow(non_snake_case)]
pub struct ProfileManager {
    base: qt_base_class!(trait QObject),

    displayName: qt_property!(QString; NOTIFY displayNameChanged),
    avatarUrl: qt_property!(QString; NOTIFY avatarUrlChanged),
    userId: qt_property!(QString; NOTIFY userIdChanged),
    presence: qt_property!(QString; NOTIFY presenceChanged),
    statusMessage: qt_property!(QString; NOTIFY statusMessageChanged),

    displayNameChanged: qt_signal!(),
    avatarUrlChanged: qt_signal!(),
    userIdChanged: qt_signal!(),
    presenceChanged: qt_signal!(),
    statusMessageChanged: qt_signal!(),

    // QML-callable method declarations.
    refresh: qt_method!(fn(&self)),
    setPresence: qt_method!(fn(&self, presence: QString, status_msg: QString)),
}

impl ProfileManager {
    #[allow(dead_code)]
    pub fn display_name(&self) -> QString {
        self.displayName.clone()
    }
    #[allow(dead_code)]
    pub fn avatar_url(&self) -> QString {
        self.avatarUrl.clone()
    }
    #[allow(dead_code)]
    pub fn user_id(&self) -> QString {
        self.userId.clone()
    }
    #[allow(dead_code)]
    pub fn presence(&self) -> QString {
        self.presence.clone()
    }
    #[allow(dead_code)]
    pub fn status_message(&self) -> QString {
        self.statusMessage.clone()
    }

    /// Pull the latest profile from the server. Called when the user opens
    /// the profile page.
    pub fn refresh(&self) {
        let qptr = QPointer::from(&*self);
        let profile_cb = qmetaobject::queued_callback(
            move |data: (Option<String>, Option<String>, String)| {
                if let Some(this) = qptr.as_pinned() {
                    let mut pm = this.borrow_mut();
                    pm.displayName = QString::from(data.0.as_deref().unwrap_or(""));
                    pm.displayNameChanged();
                    pm.avatarUrl = QString::from(
                        data.1.as_deref().unwrap_or_default(),
                    );
                    pm.avatarUrlChanged();
                    pm.userId = QString::from(data.2.as_str());
                    pm.userIdChanged();
                }
            },
        );
        let rt = crate::get_runtime();
        rt.spawn(async move {
            let client_arc = crate::MatrixClient::require_client().await?;
            let c = client_arc.lock().await;
            let uid = c.user_id()
                .ok_or(crate::errors::AppError::NotLoggedIn)?
                .to_owned();

            // In matrix-sdk 0.18: get_profile() was renamed to fetch_user_profile().
            // The Response type uses dynamic field access via .get("field_name")
            // instead of direct struct fields.
            let profile = c.account().fetch_user_profile().await?;
            let displayname: Option<String> = profile
                .get("displayname")
                .and_then(|v| v.as_str().map(|s| s.to_owned()));
            let avatar_url_str: Option<String> = profile
                .get("avatar_url")
                .and_then(|v| v.as_str().map(|s| s.to_owned()));

            profile_cb((displayname, avatar_url_str, uid.to_string()));
            crate::errors::AppResult::Ok(())
        });
    }

    /// Set the user's presence manually.
    ///
    /// In matrix-sdk 0.18+, there is no `client.presence().set_presence()`.
    /// Instead, presence is set by sending a `PUT /_matrix/client/v3/presence/{userId}/status`
    /// request via the ruma API directly, or by passing `SyncSettings::set_presence()`
    /// when starting the sync loop.
    ///
    /// This implementation uses the direct ruma API call.
    pub fn setPresence(&self, presence: QString, status_msg: QString) {
        let p = presence.to_string();
        let s = status_msg.to_string();
        let qptr = QPointer::from(&*self);
        let presence_cb = qmetaobject::queued_callback(move |data: (String, String)| {
            if let Some(this) = qptr.as_pinned() {
                let mut pm = this.borrow_mut();
                pm.presence = QString::from(data.0.as_str());
                pm.presenceChanged();
                pm.statusMessage = QString::from(data.1.as_str());
                pm.statusMessageChanged();
            }
        });
        let rt = crate::get_runtime();
        rt.spawn(async move {
            let client_arc = crate::MatrixClient::require_client().await?;
            let c = client_arc.lock().await;
            let user_id = c.user_id().ok_or(crate::errors::AppError::NotLoggedIn)?.to_owned();

            let presence_enum = match p.as_str() {
                "online" => matrix_sdk::ruma::presence::PresenceState::Online,
                "unavailable" => matrix_sdk::ruma::presence::PresenceState::Unavailable,
                _ => matrix_sdk::ruma::presence::PresenceState::Offline,
            };

            // Send presence update via the ruma set_presence endpoint.
            use matrix_sdk::ruma::api::client::presence::set_presence::v3::Request as SetPresenceRequest;
            let mut request = SetPresenceRequest::new(user_id, presence_enum);
            request.status_msg = if s.is_empty() { None } else { Some(s.as_str().to_owned()) };
            c.send(request).await?;

            presence_cb((p, s));
            crate::errors::AppResult::Ok(())
        });
    }
}
