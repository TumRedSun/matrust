//! Pending-events queue — a reliable cross-thread bridge from Tokio to Qt.
//!
//! ## Why this exists
//!
//! `qmetaobject::queued_callback` captures the *current thread* at creation
//! time (via `QPointer<QThread>`). The callback is then posted to that
//! thread's Qt event loop. If the callback was created on a Tokio worker
//! thread — which is NOT a `QThread` — the captured `QPointer<QThread>`
//! is null, and `queued_callback` silently drops the invocation (see
//! `qmetaobject` source: `if (!current_thread) { return; }`).
//!
//! `MatrixClient::finish_login` is `async` and runs on a Tokio worker
//! thread, so every `queued_callback` it creates is broken. The sync
//! loop's `rooms_apply_cb`, `sync_signal_cb`, `offline_cb`,
//! `spaces_apply_cb`, and `profile_cb` therefore never fire, which is
//! why the loading screen never transitions to the main view even
//! though sync succeeds.
//!
//! Additionally, `finish_login` calls `set_busy`, `set_ready`,
//! `set_user_id`, and `emit_logged_in` directly from Tokio. While Qt's
//! `QMetaObject::activate` does in principle marshal cross-thread signal
//! emissions via `Qt::AutoConnection` → `Qt::QueuedConnection`, in
//! practice qmetaobject's signal emission from a non-Qt thread is
//! unreliable, and the QML side never observes the signals.
//!
//! ## How this module fixes it
//!
//! Instead of relying on `queued_callback`, Tokio code pushes
//! `PendingEvent`s into a global `Arc<Mutex<Vec<PendingEvent>>>`.
//! A QML-side `Timer` calls `MatrixClient.pollPending()` every 100 ms,
//! which drains the queue on the Qt main thread and applies each event
//! (sets properties, emits signals, mutates models). This works because:
//!
//! 1. The queue is plain `std::sync::Mutex`-protected data — no Qt
//!    threading semantics involved.
//! 2. `pollPending` is a `qt_method!`, so it runs on whatever thread
//!    QML calls it from — which is always the Qt main thread.
//! 3. All Qt property mutations and signal emissions inside
//!    `pollPending` happen on the Qt main thread, so they propagate
//!    correctly to QML.
//!
//! This is the same pattern as a `mpsc::channel`-based command queue,
//! just using a `Mutex<Vec<_>>` for simplicity.

use std::sync::{Arc, Mutex, OnceLock};

use crate::room_model::RoomEntry;
use crate::spaces::SpaceEntry;

/// A command that needs to be executed on the Qt main thread.
///
/// All variants must be `Send` because they cross the Tokio → Qt
/// thread boundary. `RoomEntry` and `SpaceEntry` are `Send` (they
/// consist of `QString`s, which qmetaobject permits to be `Send`).
pub enum PendingEvent {
    // ── MatrixClient state ──
    SetUserId(String),
    SetBusy(bool),
    SetReady(bool),
    SetOffline(bool),
    SetError(String),
    EmitLoggedIn(String),
    EmitSyncDone,
    EmitLoggedOut,

    // ── Sub-model updates ──
    ApplyRooms(Vec<RoomEntry>),
    ApplySpaces(Vec<SpaceEntry>),
    RefreshProfile,
}

/// Global pending-events queue.
fn queue() -> &'static Arc<Mutex<Vec<PendingEvent>>> {
    static Q: OnceLock<Arc<Mutex<Vec<PendingEvent>>>> = OnceLock::new();
    Q.get_or_init(|| Arc::new(Mutex::new(Vec::new())))
}

/// Push an event onto the queue (called from any thread, typically Tokio).
pub fn push(ev: PendingEvent) {
    if let Ok(mut q) = queue().lock() {
        q.push(ev);
    }
}

/// Drain all pending events (called only from the Qt main thread via
/// `MatrixClient::pollPending`).
pub fn drain() -> Vec<PendingEvent> {
    if let Ok(mut q) = queue().lock() {
        return std::mem::take(&mut *q);
    }
    Vec::new()
}

/// Returns the number of pending events. Used only for diagnostics.
#[allow(dead_code)]
pub fn len() -> usize {
    queue().lock().map(|q| q.len()).unwrap_or(0)
}
