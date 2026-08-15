//! Qt singleton storage for `QPointer<T>` values.
//!
//! `QPointer<T>` is `!Send + !Sync` because it wraps a raw C++ pointer.
//! This prevents using `OnceLock` or `Mutex` in `static` variables.
//!
//! `QtSingleton` works around this by using `UnsafeCell` and unsafely
//! implementing `Send + Sync`. This is sound because Qt singletons are
//! only ever created and accessed from the Qt main thread. All cross-thread
//! access goes through `queued_callback`, which posts work back to the
//! Qt event loop.

use std::cell::UnsafeCell;

/// A container for a Qt singleton value that is only accessed from the Qt main thread.
pub struct QtSingleton<T>(UnsafeCell<Option<T>>);

// SAFETY: Qt singletons are only created and read on the Qt main thread.
// Cross-thread access uses `queued_callback` which marshals execution
// back to the Qt event loop, so no data race can occur.
unsafe impl<T> Send for QtSingleton<T> {}
unsafe impl<T> Sync for QtSingleton<T> {}

impl<T> QtSingleton<T> {
    /// Create an empty singleton container.
    pub const fn new() -> Self {
        QtSingleton(UnsafeCell::new(None))
    }

    /// Get a reference to the stored value, initializing it with `f` on first call.
    ///
    /// # Safety
    /// Must only be called from the Qt main thread.
    pub fn get_or_init<F>(&self, f: F) -> &T
    where
        F: FnOnce() -> T,
    {
        unsafe {
            let ptr = self.0.get();
            if (*ptr).is_none() {
                *ptr = Some(f());
            }
            (*ptr).as_ref().unwrap()
        }
    }

    /// Store a value, replacing any existing one.
    ///
    /// # Safety
    /// Must only be called from the Qt main thread.
    pub fn set(&self, value: T) {
        unsafe {
            *self.0.get() = Some(value);
        }
    }
}
