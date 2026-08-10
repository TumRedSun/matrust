# matrix-client

A **Matrix client for Linux** built with **Rust + Qt 6 / QML**, focused on
maximum visual customization and the everyday chat feature set.

## Features

### Protocol & connectivity
- **Token-based auto-login**: the last session's access token is stored on
  disk under `~/.local/share/matrix-client/session.json` and reused on the
  next launch — no password is ever stored.
- **Manual login** with username + password (against the homeserver's
  `/login` endpoint).
- **Manual token entry** for users who already have a working access token
  from another client (Element, FluffyChat, Cinny, etc.).
- **IPv6-only transport** toggle: when enabled, the underlying reqwest
  client is rebuilt with a custom resolver that issues only AAAA queries
  and refuses to dial IPv4 endpoints. Useful on IPv6-only / CGNAT-bypass
  networks and for testing dual-stack homeservers.
- **End-to-end encryption** via `matrix-sdk-crypto` (Olm/Megolm). Keys are
  persisted in a SQLite store under
  `~/.local/share/matrix-client/sqlite/`.

### Chat
- Send and receive **text messages** (Markdown supported via the SDK).
- Receive **formatted messages** (HTML).
- Send and receive **images** — inline thumbnails in the bubble.
- Send and receive **videos** — filename + size + download button.
- Send and receive **audio** and **arbitrary files**.
- **Download any attachment** with a single click — files land in
  `~/Downloads/matrix-client/` with collision-safe naming.
- Live unread badges & highlight counts on the room list.
- Per-room last-event preview.

### Spaces & rooms
- Hierarchical **Spaces → Rooms** view on the left sidebar (indented
  children, space/room iconography, unread counts).
- Flat **Rooms list** view for direct messages and standalone rooms.
- Each entry shows avatar, name, last event, and unread counter.

### Profile
- View & edit display name.
- Upload & set avatar (any image format supported by Qt).
- Set presence (online / unavailable / offline) with a status message.

### Maximum appearance customization
The dedicated **Appearance** page exposes ~60 knobs, all saved to
`~/.config/matrix-client/theme.json` and restored on the next launch:

| Group | Knobs |
|-------|-------|
| **Presets** | Material Dark, Solarized Dark, Tokyo Night, Nordic, Dracula, Gruvbox, Catppuccin Mocha, Sunset, Matrix Green |
| **Colors** | window bg/fg, sidebar bg/fg, accent, accent-fg, danger, success, warning, muted, border, bubble bg/fg (own + other) |
| **Typography** | font family, monospace family, 5 sizes (XS/SM/MD/LG/XL) |
| **Geometry** | 3 radii, 4 paddings, 4 spacings |
| **Bubbles** | radius, padding H/V, max-width %, tail on/off |
| **Avatars** | 3 sizes, corner radius, shape (circle / rounded / square) |
| **Scrollbars** | width, radius |
| **Behavior** | compact mode, show timestamps, show avatars, animate bubbles, animation duration (ms) |
| **Import / Export** | full JSON export and import for theme sharing |

A `ColorDialog` is wired to every color picker, and a `Slider` plus +/−
buttons to every integer field — change anything and the entire UI
updates live, no restart required.

---

## Project layout

```
matrix-client/
├── Cargo.toml            # dependencies & build profile
├── build.rs              # Qt discovery helper
├── src/
│   ├── main.rs           # entry point, registers QML types & singletons
│   ├── matrix_client.rs  # central QML-facing MatrixClient singleton
│   ├── auth.rs           # client construction + IPv6-only transport
│   ├── room_model.rs     # QAbstractListModel for joined rooms
│   ├── message_model.rs  # QAbstractListModel for a room's timeline
│   ├── spaces.rs         # SpaceModel: spaces → rooms tree
│   ├── profile.rs        # ProfileManager: display name / avatar / presence
│   ├── file_transfer.rs  # upload & download of files/images/videos/audio
│   ├── theme.rs          # Theme singleton with all visual knobs
│   ├── avatar_cache.rs   # on-disk caches and downloads dir helpers
│   └── errors.rs         # shared error type
├── qml/
│   ├── main.qml          # root window + MainView (3-pane layout)
│   ├── LoginPage.qml     # password + token login forms
│   ├── SpacesPage.qml    # spaces → rooms tree
│   ├── RoomsSidebar.qml  # flat room list (alternative)
│   ├── ChatPage.qml      # header + message list + composer
│   ├── MessageBubble.qml # themed bubble for every event kind
│   ├── ProfilePage.qml   # display name / avatar / presence editor
│   ├── SettingsPage.qml  # network, IPv6, logout, diagnostics
│   ├── AppearancePage.qml# full theme editor with live preview
│   ├── Theme.qml         # color helper (mix / lighten / darken / alpha)
│   ├── Components.qml    # shared widget stubs
│   └── icons.qml         # Canvas-drawn vector icons
├── assets/
│   ├── logo.svg
│   └── default-avatar.svg
└── scripts/
    ├── build.sh          # release build helper
    └── run.sh            # debug run helper
```

---

## Build prerequisites

### Debian / Ubuntu

```bash
sudo apt-get install -y \
  build-essential pkg-config \
  rustc cargo \
  qt6-base-dev qt6-declarative-dev qt6-svg-dev \
  libssl-dev libsqlite3-dev \
  qmake6
```

### Fedora

```bash
sudo dnf install -y \
  rust cargo \
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtsvg-devel \
  openssl-devel sqlite-devel \
  qt6-qtbase-devel-gui
```

### Arch

```bash
sudo pacman -S --needed \
  rust \
  qt6-base qt6-declarative qt6-svg \
  openssl sqlite
```

### NixOS (ephemeral shell)

```bash
nix-shell -p rustc cargo qt6.full pkg-config openssl sqlite
```

---

## Building

```bash
# From the project root:
cargo run                          # debug build + run
cargo build --release              # optimized binary at target/release/matrix-client
```

If `qmake` is not on `PATH`, point the build at it explicitly:

```bash
QMAKE=/usr/bin/qmake6 cargo build --release
```

The `scripts/build.sh` and `scripts/run.sh` helpers wrap these for convenience.

---

## First run

1. Launch the binary.
2. The login window appears. Either:
   - enter homeserver + username + password, **or**
   - switch to the **Token** tab and paste your access token (and user ID).
3. Optionally tick **Force IPv6** to restrict all Matrix traffic to IPv6
   endpoints only.
4. Click **Sign in**.
5. The session is stored on disk; subsequent launches auto-login.

## Where things live

| Path | Contents |
|------|----------|
| `~/.local/share/matrix-client/session.json` | Homeserver URL, user ID, device ID, access token |
| `~/.local/share/matrix-client/sqlite/` | Matrix SDK state (E2E keys, room state) |
| `~/.local/share/matrix-client/avatars/` | Downloaded avatar thumbnails |
| `~/.local/share/matrix-client/theme.json` | Custom appearance settings |
| `~/Downloads/matrix-client/` | All downloads from chats |

## Removing the saved session / logout

Either click **Logout** in the Settings page, or simply delete
`~/.local/share/matrix-client/session.json`. The SQLite store remains, so
E2E keys survive a re-login.

---

## Architecture notes

### Rust ↔ QML bridge

[qmetaobject](https://docs.rs/qmetaobject) provides pure-Rust Qt bindings
(no C++ glue). All `#[derive(QObject)]` structs are exposed to QML via
`register_type` (instantiable) or `register_singleton_type`
(globally-available).

### Async

A single Tokio runtime is owned by the `Backend` singleton. Every QML-callable
method on `MatrixClient` spawns a future onto it; results are returned via
Qt signals (`logged_in`, `sync_done`, `file_downloaded`, `last_error_changed`,
…). The UI thread never blocks.

### IPv6 transport

When **Force IPv6** is on, `build_client()` constructs a reqwest client with
a custom resolver callback that:

1. Issues only `ipv6_lookup` (AAAA) queries via `hickory-resolver`.
2. Returns `Err` if no AAAA records exist (forcing the request to fail
   rather than silently falling back to IPv4).
3. Sorts results to prefer ULA / global addresses over link-local.

This is the only change vs. the default transport — TLS, HTTP/2, etc.
behave identically.

### Theming

The `Theme` singleton is a `#[derive(QObject)]` Rust struct whose state is
mirrored to a `ThemeState` (serde). Every setter writes through to
`~/.config/matrix-client/theme.json`. QML reads properties via the
standard property binding, so changes propagate instantly.

---

## Known limitations / TODO

- Sliding Sync is not wired up; we use plain `/sync`. For large accounts,
  switching to `matrix_sdk_ui::sync_service` is recommended.
- Image rendering of `mxc://` URIs uses an `image://matrix/` QML image
  provider that is not yet implemented — currently image messages fall back
  to a download button. A future commit will add the provider.
- No voice / video calls (MSC3401).
- No reply / edit / reactions UI (events are rendered as-is; SDK supports
  them, the QML side just needs the controls).

## License

GPL-3.0-or-later.
