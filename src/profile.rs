//! Profile management: display name, avatar, presence.

use qmetaobject::*;

#[derive(QObject, Default)]
pub struct ProfileManager {
    base: qt_base_class!(trait QObject),

    display_name: qt_property!(QString; NOTIFY display_name_changed READ display_name),
    avatar_url: qt_property!(QString; NOTIFY avatar_url_changed READ avatar_url),
    user_id: qt_property!(QString; NOTIFY user_id_changed READ user_id),
    presence: qt_property!(QString; NOTIFY presence_changed READ presence),
    status_message: qt_property!(QString; NOTIFY status_message_changed READ status_message),

    display_name_changed: qt_signal!(),
    avatar_url_changed: qt_signal!(),
    user_id_changed: qt_signal!(),
    presence_changed: qt_signal!(),
    status_message_changed: qt_signal!(),

    // QML-callable method declarations.
    refresh: qt_method!(fn(&self)),
    set_presence: qt_method!(fn(&self, presence: QString, status_msg: QString)),
}

impl ProfileManager {
    pub fn display_name(&self) -> QString {
        self.display_name.clone()
    }
    pub fn avatar_url(&self) -> QString {
        self.avatar_url.clone()
    }
    pub fn user_id(&self) -> QString {
        self.user_id.clone()
    }
    pub fn presence(&self) -> QString {
        self.presence.clone()
    }
    pub fn status_message(&self) -> QString {
        self.status_message.clone()
    }

    /// Pull the latest profile from the server. Called when the user opens
    /// the profile page.
    pub fn refresh(&self) {
        let qptr = QPointer::from(self);
        crate::Backend::get().runtime().spawn(async move {
            let mc = crate::MatrixClient::singleton_ptr();
            let client = mc.require_client().await?;
            let uid = client.user_id().ok_or(crate::errors::AppError::NotLoggedIn)?.to_owned();

            // In matrix-sdk 0.18: get_profile() was renamed to fetch_user_profile().
            let profile = client.account().fetch_user_profile().await?;

            if let Some(this) = qptr.as_ref() {
                this.display_name = QString::from(profile.displayname.as_deref().unwrap_or("").to_string().as_str());
                this.display_name_changed();

                this.avatar_url = QString::from(
                    profile
                        .avatar_url
                        .map(|u| u.to_string())
                        .unwrap_or_default()
                        .as_str(),
                );
                this.avatar_url_changed();

                this.user_id = QString::from(uid.as_str());
                this.user_id_changed();
            }
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
    pub fn set_presence(&self, presence: QString, status_msg: QString) {
        let p = presence.to_string();
        let s = status_msg.to_string();
        let qptr = QPointer::from(self);
        crate::Backend::get().runtime().spawn(async move {
            let mc = crate::MatrixClient::singleton_ptr();
            let client = mc.require_client().await?;
            let user_id = client.user_id().ok_or(crate::errors::AppError::NotLoggedIn)?.to_owned();

            let presence_enum = match p.as_str() {
                "online" => matrix_sdk::ruma::presence::PresenceState::Online,
                "unavailable" => matrix_sdk::ruma::presence::PresenceState::Unavailable,
                _ => matrix_sdk::ruma::presence::PresenceState::Offline,
            };

            // Send presence update via the ruma set_presence endpoint.
            use matrix_sdk::ruma::api::client::presence::set_presence::v3::Request as SetPresenceRequest;
            // In ruma 0.16, SetPresenceRequest::new takes OwnedUserId (not &OwnedUserId)
            let mut request = SetPresenceRequest::new(user_id, presence_enum);
            request.status_msg = if s.is_empty() { None } else { Some(s.as_str().to_owned()) };
            // In matrix-sdk 0.18+, client.send() takes only the request
            // (no timeout parameter). Returns a builder that implements IntoFuture.
            client.send(request).await?;

            if let Some(this) = qptr.as_ref() {
                this.presence = QString::from(p.as_str());
                this.presence_changed();
                this.status_message = QString::from(s.as_str());
                this.status_message_changed();
            }
            crate::errors::AppResult::Ok(())
        });
    }
}
