//! `Theme` — fully customizable appearance.
//!
//! All visual knobs (colors, fonts, paddings, corner radii, message bubble
//! shapes, etc.) are exposed as QML properties AND persisted to disk so
//! they survive restarts. A built-in set of presets ("Material Dark",
//! "Solarized", "Tokyo Night", "Nordic", "Dracula", "Gruvbox", "Catppuccin",
//! "Sunset", "Matrix Green", "Custom") lets users switch instantly.

use qmetaobject::*;
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::path::PathBuf;

use paste::paste;

#[derive(QObject, Default)]
pub struct Theme {
    base: qt_base_class!(trait QObject),

    // --- Identification ---
    /// Active preset name. Setting this to a known preset overrides every
    /// field below. Setting to "Custom" keeps the current colors.
    preset: qt_property!(QString; NOTIFY preset_changed READ preset WRITE set_preset),

    // --- Window chrome ---
    window_bg: qt_property!(QString; NOTIFY window_bg_changed READ window_bg WRITE set_window_bg),
    window_fg: qt_property!(QString; NOTIFY window_fg_changed READ window_fg WRITE set_window_fg),
    sidebar_bg: qt_property!(QString; NOTIFY sidebar_bg_changed READ sidebar_bg WRITE set_sidebar_bg),
    sidebar_fg: qt_property!(QString; NOTIFY sidebar_fg_changed READ sidebar_fg WRITE set_sidebar_fg),
    accent: qt_property!(QString; NOTIFY accent_changed READ accent WRITE set_accent),
    accent_fg: qt_property!(QString; NOTIFY accent_fg_changed READ accent_fg WRITE set_accent_fg),
    danger: qt_property!(QString; NOTIFY danger_changed READ danger WRITE set_danger),
    success: qt_property!(QString; NOTIFY success_changed READ success WRITE set_success),
    warning: qt_property!(QString; NOTIFY warning_changed READ warning WRITE set_warning),
    muted: qt_property!(QString; NOTIFY muted_changed READ muted WRITE set_muted),
    border: qt_property!(QString; NOTIFY border_changed READ border WRITE set_border),

    // --- Typography ---
    font_family: qt_property!(QString; NOTIFY font_family_changed READ font_family WRITE set_font_family),
    font_family_mono: qt_property!(QString; NOTIFY font_family_mono_changed READ font_family_mono WRITE set_font_family_mono),
    font_size_xs: qt_property!(i32; NOTIFY font_size_xs_changed READ font_size_xs WRITE set_font_size_xs),
    font_size_sm: qt_property!(i32; NOTIFY font_size_sm_changed READ font_size_sm WRITE set_font_size_sm),
    font_size_md: qt_property!(i32; NOTIFY font_size_md_changed READ font_size_md WRITE set_font_size_md),
    font_size_lg: qt_property!(i32; NOTIFY font_size_lg_changed READ font_size_lg WRITE set_font_size_lg),
    font_size_xl: qt_property!(i32; NOTIFY font_size_xl_changed READ font_size_xl WRITE set_font_size_xl),

    // --- Geometry ---
    radius_sm: qt_property!(i32; NOTIFY radius_sm_changed READ radius_sm WRITE set_radius_sm),
    radius_md: qt_property!(i32; NOTIFY radius_md_changed READ radius_md WRITE set_radius_md),
    radius_lg: qt_property!(i32; NOTIFY radius_lg_changed READ radius_lg WRITE set_radius_lg),
    padding_xs: qt_property!(i32; NOTIFY padding_xs_changed READ padding_xs WRITE set_padding_xs),
    padding_sm: qt_property!(i32; NOTIFY padding_sm_changed READ padding_sm WRITE set_padding_sm),
    padding_md: qt_property!(i32; NOTIFY padding_md_changed READ padding_md WRITE set_padding_md),
    padding_lg: qt_property!(i32; NOTIFY padding_lg_changed READ padding_lg WRITE set_padding_lg),
    spacing_xs: qt_property!(i32; NOTIFY spacing_xs_changed READ spacing_xs WRITE set_spacing_xs),
    spacing_sm: qt_property!(i32; NOTIFY spacing_sm_changed READ spacing_sm WRITE set_spacing_sm),
    spacing_md: qt_property!(i32; NOTIFY spacing_md_changed READ spacing_md WRITE set_spacing_md),
    spacing_lg: qt_property!(i32; NOTIFY spacing_lg_changed READ spacing_lg WRITE set_spacing_lg),

    // --- Message bubbles ---
    bubble_bg_me: qt_property!(QString; NOTIFY bubble_bg_me_changed READ bubble_bg_me WRITE set_bubble_bg_me),
    bubble_bg_them: qt_property!(QString; NOTIFY bubble_bg_them_changed READ bubble_bg_them WRITE set_bubble_bg_them),
    bubble_fg_me: qt_property!(QString; NOTIFY bubble_fg_me_changed READ bubble_fg_me WRITE set_bubble_fg_me),
    bubble_fg_them: qt_property!(QString; NOTIFY bubble_fg_them_changed READ bubble_fg_them WRITE set_bubble_fg_them),
    bubble_radius: qt_property!(i32; NOTIFY bubble_radius_changed READ bubble_radius WRITE set_bubble_radius),
    bubble_padding_h: qt_property!(i32; NOTIFY bubble_padding_h_changed READ bubble_padding_h WRITE set_bubble_padding_h),
    bubble_padding_v: qt_property!(i32; NOTIFY bubble_padding_v_changed READ bubble_padding_v WRITE set_bubble_padding_v),
    bubble_tail: qt_property!(bool; NOTIFY bubble_tail_changed READ bubble_tail WRITE set_bubble_tail),
    bubble_max_width_pct: qt_property!(i32; NOTIFY bubble_max_width_pct_changed READ bubble_max_width_pct WRITE set_bubble_max_width_pct),

    // --- Avatars ---
    avatar_size_sm: qt_property!(i32; NOTIFY avatar_size_sm_changed READ avatar_size_sm WRITE set_avatar_size_sm),
    avatar_size_md: qt_property!(i32; NOTIFY avatar_size_md_changed READ avatar_size_md WRITE set_avatar_size_md),
    avatar_size_lg: qt_property!(i32; NOTIFY avatar_size_lg_changed READ avatar_size_lg WRITE set_avatar_size_lg),
    avatar_radius: qt_property!(i32; NOTIFY avatar_radius_changed READ avatar_radius WRITE set_avatar_radius),
    avatar_shape: qt_property!(QString; NOTIFY avatar_shape_changed READ avatar_shape WRITE set_avatar_shape), // "circle" | "rounded" | "square"

    // --- Scrollbars & misc ---
    scrollbar_size: qt_property!(i32; NOTIFY scrollbar_size_changed READ scrollbar_size WRITE set_scrollbar_size),
    scrollbar_radius: qt_property!(i32; NOTIFY scrollbar_radius_changed READ scrollbar_radius WRITE set_scrollbar_radius),
    compact_mode: qt_property!(bool; NOTIFY compact_mode_changed READ compact_mode WRITE set_compact_mode),
    show_timestamps: qt_property!(bool; NOTIFY show_timestamps_changed READ show_timestamps WRITE set_show_timestamps),
    show_avatars: qt_property!(bool; NOTIFY show_avatars_changed READ show_avatars WRITE set_show_avatars),
    animate_bubbles: qt_property!(bool; NOTIFY animate_bubbles_changed READ animate_bubbles WRITE set_animate_bubbles),
    animation_duration_ms: qt_property!(i32; NOTIFY animation_duration_ms_changed READ animation_duration_ms WRITE set_animation_duration_ms),

    // --- Signals ---
    preset_changed: qt_signal!(),
    window_bg_changed: qt_signal!(),
    window_fg_changed: qt_signal!(),
    sidebar_bg_changed: qt_signal!(),
    sidebar_fg_changed: qt_signal!(),
    accent_changed: qt_signal!(),
    accent_fg_changed: qt_signal!(),
    danger_changed: qt_signal!(),
    success_changed: qt_signal!(),
    warning_changed: qt_signal!(),
    muted_changed: qt_signal!(),
    border_changed: qt_signal!(),
    font_family_changed: qt_signal!(),
    font_family_mono_changed: qt_signal!(),
    font_size_xs_changed: qt_signal!(),
    font_size_sm_changed: qt_signal!(),
    font_size_md_changed: qt_signal!(),
    font_size_lg_changed: qt_signal!(),
    font_size_xl_changed: qt_signal!(),
    radius_sm_changed: qt_signal!(),
    radius_md_changed: qt_signal!(),
    radius_lg_changed: qt_signal!(),
    padding_xs_changed: qt_signal!(),
    padding_sm_changed: qt_signal!(),
    padding_md_changed: qt_signal!(),
    padding_lg_changed: qt_signal!(),
    spacing_xs_changed: qt_signal!(),
    spacing_sm_changed: qt_signal!(),
    spacing_md_changed: qt_signal!(),
    spacing_lg_changed: qt_signal!(),
    bubble_bg_me_changed: qt_signal!(),
    bubble_bg_them_changed: qt_signal!(),
    bubble_fg_me_changed: qt_signal!(),
    bubble_fg_them_changed: qt_signal!(),
    bubble_radius_changed: qt_signal!(),
    bubble_padding_h_changed: qt_signal!(),
    bubble_padding_v_changed: qt_signal!(),
    bubble_tail_changed: qt_signal!(),
    bubble_max_width_pct_changed: qt_signal!(),
    avatar_size_sm_changed: qt_signal!(),
    avatar_size_md_changed: qt_signal!(),
    avatar_size_lg_changed: qt_signal!(),
    avatar_radius_changed: qt_signal!(),
    avatar_shape_changed: qt_signal!(),
    scrollbar_size_changed: qt_signal!(),
    scrollbar_radius_changed: qt_signal!(),
    compact_mode_changed: qt_signal!(),
    show_timestamps_changed: qt_signal!(),
    show_avatars_changed: qt_signal!(),
    animate_bubbles_changed: qt_signal!(),
    animation_duration_ms_changed: qt_signal!(),

    /// Fired after `apply_preset` or `load_from_disk` finishes; QML uses it
    /// to rebind bound expressions.
    theme_changed: qt_signal!(),

    state: RefCell<ThemeState>,
}

#[derive(Default, Serialize, Deserialize, Clone)]
struct ThemeState {
    preset: String,
    window_bg: String,
    window_fg: String,
    sidebar_bg: String,
    sidebar_fg: String,
    accent: String,
    accent_fg: String,
    danger: String,
    success: String,
    warning: String,
    muted: String,
    border: String,
    font_family: String,
    font_family_mono: String,
    font_size_xs: i32,
    font_size_sm: i32,
    font_size_md: i32,
    font_size_lg: i32,
    font_size_xl: i32,
    radius_sm: i32,
    radius_md: i32,
    radius_lg: i32,
    padding_xs: i32,
    padding_sm: i32,
    padding_md: i32,
    padding_lg: i32,
    spacing_xs: i32,
    spacing_sm: i32,
    spacing_md: i32,
    spacing_lg: i32,
    bubble_bg_me: String,
    bubble_bg_them: String,
    bubble_fg_me: String,
    bubble_fg_them: String,
    bubble_radius: i32,
    bubble_padding_h: i32,
    bubble_padding_v: i32,
    bubble_tail: bool,
    bubble_max_width_pct: i32,
    avatar_size_sm: i32,
    avatar_size_md: i32,
    avatar_size_lg: i32,
    avatar_radius: i32,
    avatar_shape: String,
    scrollbar_size: i32,
    scrollbar_radius: i32,
    compact_mode: bool,
    show_timestamps: bool,
    show_avatars: bool,
    animate_bubbles: bool,
    animation_duration_ms: i32,
}

fn path() -> PathBuf {
    let base = directories::ProjectDirs::from("dev", "matrixclient", "matrix-client")
        .map(|d| d.config_dir().to_path_buf())
        .unwrap_or_else(|| std::env::temp_dir().join("matrix-client"));
    std::fs::create_dir_all(&base).ok();
    base.join("theme.json")
}

impl Theme {
    fn file_path() -> PathBuf { path() }

    pub fn load_from_disk(&self) {
        if let Ok(json) = std::fs::read_to_string(Self::file_path()) {
            if let Ok(s) = serde_json::from_str::<ThemeState>(&json) {
                *self.state.borrow_mut() = s;
            } else {
                self.apply_defaults();
            }
        } else {
            self.apply_defaults();
        }
        self.fire_all_signals();
    }

    pub fn save_to_disk(&self) {
        let s = self.state.borrow().clone();
        if let Ok(json) = serde_json::to_string_pretty(&s) {
            let _ = std::fs::write(Self::file_path(), json);
        }
    }

    fn apply_defaults(&self) {
        let defaults = preset("Material Dark");
        *self.state.borrow_mut() = defaults;
    }

    fn fire_all_signals(&self) {
        let _ = self.preset_changed();
        let _ = self.window_bg_changed();
        let _ = self.window_fg_changed();
        let _ = self.sidebar_bg_changed();
        let _ = self.sidebar_fg_changed();
        let _ = self.accent_changed();
        let _ = self.accent_fg_changed();
        let _ = self.danger_changed();
        let _ = self.success_changed();
        let _ = self.warning_changed();
        let _ = self.muted_changed();
        let _ = self.border_changed();
        let _ = self.font_family_changed();
        let _ = self.font_family_mono_changed();
        let _ = self.font_size_xs_changed();
        let _ = self.font_size_sm_changed();
        let _ = self.font_size_md_changed();
        let _ = self.font_size_lg_changed();
        let _ = self.font_size_xl_changed();
        let _ = self.radius_sm_changed();
        let _ = self.radius_md_changed();
        let _ = self.radius_lg_changed();
        let _ = self.padding_xs_changed();
        let _ = self.padding_sm_changed();
        let _ = self.padding_md_changed();
        let _ = self.padding_lg_changed();
        let _ = self.spacing_xs_changed();
        let _ = self.spacing_sm_changed();
        let _ = self.spacing_md_changed();
        let _ = self.spacing_lg_changed();
        let _ = self.bubble_bg_me_changed();
        let _ = self.bubble_bg_them_changed();
        let _ = self.bubble_fg_me_changed();
        let _ = self.bubble_fg_them_changed();
        let _ = self.bubble_radius_changed();
        let _ = self.bubble_padding_h_changed();
        let _ = self.bubble_padding_v_changed();
        let _ = self.bubble_tail_changed();
        let _ = self.bubble_max_width_pct_changed();
        let _ = self.avatar_size_sm_changed();
        let _ = self.avatar_size_md_changed();
        let _ = self.avatar_size_lg_changed();
        let _ = self.avatar_radius_changed();
        let _ = self.avatar_shape_changed();
        let _ = self.scrollbar_size_changed();
        let _ = self.scrollbar_radius_changed();
        let _ = self.compact_mode_changed();
        let _ = self.show_timestamps_changed();
        let _ = self.show_avatars_changed();
        let _ = self.animate_bubbles_changed();
        let _ = self.animation_duration_ms_changed();
        self.theme_changed();
    }

    #[qt_method]
    pub fn apply_preset(&self, name: QString) {
        let s = preset(&name.to_string());
        *self.state.borrow_mut() = s;
        self.fire_all_signals();
        self.save_to_disk();
    }

    #[qt_method]
    pub fn reset(&self) {
        self.apply_defaults();
        self.fire_all_signals();
        self.save_to_disk();
    }

    #[qt_method]
    pub fn export_json(&self) -> QString {
        let s = self.state.borrow().clone();
        QString::from(serde_json::to_string_pretty(&s).unwrap_or_default().as_str())
    }

    #[qt_method]
    pub fn import_json(&self, json: QString) -> bool {
        match serde_json::from_str::<ThemeState>(&json.to_string()) {
            Ok(s) => {
                *self.state.borrow_mut() = s;
                self.fire_all_signals();
                self.save_to_disk();
                true
            }
            Err(_) => false,
        }
    }

    // --- List of available presets, for QML dropdowns ---
    #[qt_method]
    pub fn available_presets(&self) -> QString {
        QString::from(
            r#"["Material Dark","Solarized Dark","Tokyo Night","Nordic","Dracula","Gruvbox","Catppuccin Mocha","Sunset","Matrix Green"]"#,
        )
    }

    // --- Getters / setters ---
    // All getters/setters are implemented manually below because the state
    // is held in a `RefCell` and qmetaobject's `qt_property!` macro expects
    // field-style access. Each setter writes through to the RefCell, emits
    // the corresponding `*_changed` signal, and persists the new state to
    // disk.
}

// String accessors
impl Theme {
    pub fn preset(&self) -> QString { QString::from(self.state.borrow().preset.as_str()) }
    pub fn set_preset(&self, v: QString) {
        let name = v.to_string();
        let s = preset(&name);
        *self.state.borrow_mut() = s;
        self.fire_all_signals();
        self.save_to_disk();
    }
    pub fn window_bg(&self) -> QString { QString::from(self.state.borrow().window_bg.as_str()) }
    pub fn set_window_bg(&self, v: QString) { self.state.borrow_mut().window_bg = v.to_string(); self.window_bg_changed(); self.save_to_disk(); }
    pub fn window_fg(&self) -> QString { QString::from(self.state.borrow().window_fg.as_str()) }
    pub fn set_window_fg(&self, v: QString) { self.state.borrow_mut().window_fg = v.to_string(); self.window_fg_changed(); self.save_to_disk(); }
    pub fn sidebar_bg(&self) -> QString { QString::from(self.state.borrow().sidebar_bg.as_str()) }
    pub fn set_sidebar_bg(&self, v: QString) { self.state.borrow_mut().sidebar_bg = v.to_string(); self.sidebar_bg_changed(); self.save_to_disk(); }
    pub fn sidebar_fg(&self) -> QString { QString::from(self.state.borrow().sidebar_fg.as_str()) }
    pub fn set_sidebar_fg(&self, v: QString) { self.state.borrow_mut().sidebar_fg = v.to_string(); self.sidebar_fg_changed(); self.save_to_disk(); }
    pub fn accent(&self) -> QString { QString::from(self.state.borrow().accent.as_str()) }
    pub fn set_accent(&self, v: QString) { self.state.borrow_mut().accent = v.to_string(); self.accent_changed(); self.save_to_disk(); }
    pub fn accent_fg(&self) -> QString { QString::from(self.state.borrow().accent_fg.as_str()) }
    pub fn set_accent_fg(&self, v: QString) { self.state.borrow_mut().accent_fg = v.to_string(); self.accent_fg_changed(); self.save_to_disk(); }
    pub fn danger(&self) -> QString { QString::from(self.state.borrow().danger.as_str()) }
    pub fn set_danger(&self, v: QString) { self.state.borrow_mut().danger = v.to_string(); self.danger_changed(); self.save_to_disk(); }
    pub fn success(&self) -> QString { QString::from(self.state.borrow().success.as_str()) }
    pub fn set_success(&self, v: QString) { self.state.borrow_mut().success = v.to_string(); self.success_changed(); self.save_to_disk(); }
    pub fn warning(&self) -> QString { QString::from(self.state.borrow().warning.as_str()) }
    pub fn set_warning(&self, v: QString) { self.state.borrow_mut().warning = v.to_string(); self.warning_changed(); self.save_to_disk(); }
    pub fn muted(&self) -> QString { QString::from(self.state.borrow().muted.as_str()) }
    pub fn set_muted(&self, v: QString) { self.state.borrow_mut().muted = v.to_string(); self.muted_changed(); self.save_to_disk(); }
    pub fn border(&self) -> QString { QString::from(self.state.borrow().border.as_str()) }
    pub fn set_border(&self, v: QString) { self.state.borrow_mut().border = v.to_string(); self.border_changed(); self.save_to_disk(); }
    pub fn font_family(&self) -> QString { QString::from(self.state.borrow().font_family.as_str()) }
    pub fn set_font_family(&self, v: QString) { self.state.borrow_mut().font_family = v.to_string(); self.font_family_changed(); self.save_to_disk(); }
    pub fn font_family_mono(&self) -> QString { QString::from(self.state.borrow().font_family_mono.as_str()) }
    pub fn set_font_family_mono(&self, v: QString) { self.state.borrow_mut().font_family_mono = v.to_string(); self.font_family_mono_changed(); self.save_to_disk(); }
    pub fn bubble_bg_me(&self) -> QString { QString::from(self.state.borrow().bubble_bg_me.as_str()) }
    pub fn set_bubble_bg_me(&self, v: QString) { self.state.borrow_mut().bubble_bg_me = v.to_string(); self.bubble_bg_me_changed(); self.save_to_disk(); }
    pub fn bubble_bg_them(&self) -> QString { QString::from(self.state.borrow().bubble_bg_them.as_str()) }
    pub fn set_bubble_bg_them(&self, v: QString) { self.state.borrow_mut().bubble_bg_them = v.to_string(); self.bubble_bg_them_changed(); self.save_to_disk(); }
    pub fn bubble_fg_me(&self) -> QString { QString::from(self.state.borrow().bubble_fg_me.as_str()) }
    pub fn set_bubble_fg_me(&self, v: QString) { self.state.borrow_mut().bubble_fg_me = v.to_string(); self.bubble_fg_me_changed(); self.save_to_disk(); }
    pub fn bubble_fg_them(&self) -> QString { QString::from(self.state.borrow().bubble_fg_them.as_str()) }
    pub fn set_bubble_fg_them(&self, v: QString) { self.state.borrow_mut().bubble_fg_them = v.to_string(); self.bubble_fg_them_changed(); self.save_to_disk(); }
    pub fn avatar_shape(&self) -> QString { QString::from(self.state.borrow().avatar_shape.as_str()) }
    pub fn set_avatar_shape(&self, v: QString) { self.state.borrow_mut().avatar_shape = v.to_string(); self.avatar_shape_changed(); self.save_to_disk(); }
}

// Integer accessors
macro_rules! int_accessors {
    ($($name:ident, $sig:ident);* $(;)?) => {
        paste! {
        $(
        impl Theme {
            pub fn $name(&self) -> i32 { self.state.borrow().$name }
            pub fn [<set_ $name>](&self, v: i32) {
                self.state.borrow_mut().$name = v;
                self.$sig;
                self.save_to_disk();
            }
        }
        )*
        }
    };
}

int_accessors! {
    font_size_xs, font_size_xs_changed;
    font_size_sm, font_size_sm_changed;
    font_size_md, font_size_md_changed;
    font_size_lg, font_size_lg_changed;
    font_size_xl, font_size_xl_changed;
    radius_sm, radius_sm_changed;
    radius_md, radius_md_changed;
    radius_lg, radius_lg_changed;
    padding_xs, padding_xs_changed;
    padding_sm, padding_sm_changed;
    padding_md, padding_md_changed;
    padding_lg, padding_lg_changed;
    spacing_xs, spacing_xs_changed;
    spacing_sm, spacing_sm_changed;
    spacing_md, spacing_md_changed;
    spacing_lg, spacing_lg_changed;
    bubble_radius, bubble_radius_changed;
    bubble_padding_h, bubble_padding_h_changed;
    bubble_padding_v, bubble_padding_v_changed;
    bubble_max_width_pct, bubble_max_width_pct_changed;
    avatar_size_sm, avatar_size_sm_changed;
    avatar_size_md, avatar_size_md_changed;
    avatar_size_lg, avatar_size_lg_changed;
    avatar_radius, avatar_radius_changed;
    scrollbar_size, scrollbar_size_changed;
    scrollbar_radius, scrollbar_radius_changed;
    animation_duration_ms, animation_duration_ms_changed;
}

// Bool accessors
macro_rules! bool_accessors {
    ($($name:ident, $sig:ident);* $(;)?) => {
        paste! {
        $(
        impl Theme {
            pub fn $name(&self) -> bool { self.state.borrow().$name }
            pub fn [<set_ $name>](&self, v: bool) {
                self.state.borrow_mut().$name = v;
                self.$sig;
                self.save_to_disk();
            }
        }
        )*
        }
    };
}

bool_accessors! {
    bubble_tail, bubble_tail_changed;
    compact_mode, compact_mode_changed;
    show_timestamps, show_timestamps_changed;
    show_avatars, show_avatars_changed;
    animate_bubbles, animate_bubbles_changed;
}

impl qmetaobject::Singleton for Theme {
    fn get() -> QPointer<Theme> {
        use std::sync::Once;
        static INIT: Once = Once::new();
        static mut INSTANCE: Option<QPointer<Theme>> = None;
        INIT.call_once(|| unsafe {
            let t = Theme::default();
            t.load_from_disk();
            INSTANCE = Some(QPointer::from(t));
        });
        unsafe { INSTANCE.clone().unwrap() }
    }
}

/// Built-in color presets. Each returns a fully-populated `ThemeState`.
fn preset(name: &str) -> ThemeState {
    let mut s = base_layout();
    match name {
        "Solarized Dark" => {
            s.preset = "Solarized Dark".into();
            s.window_bg = "#002b36".into();
            s.window_fg = "#93a1a1".into();
            s.sidebar_bg = "#073642".into();
            s.sidebar_fg = "#93a1a1".into();
            s.accent = "#268bd2".into();
            s.accent_fg = "#fdf6e3".into();
            s.bubble_bg_me = "#073642".into();
            s.bubble_bg_them = "#586e75".into();
            s.bubble_fg_me = "#93a1a1".into();
            s.bubble_fg_them = "#fdf6e3".into();
            s.border = "#586e75".into();
            s.muted = "#657b83".into();
        }
        "Tokyo Night" => {
            s.preset = "Tokyo Night".into();
            s.window_bg = "#1a1b26".into();
            s.window_fg = "#c0caf5".into();
            s.sidebar_bg = "#16161e".into();
            s.sidebar_fg = "#c0caf5".into();
            s.accent = "#7aa2f7".into();
            s.accent_fg = "#1a1b26".into();
            s.bubble_bg_me = "#283457".into();
            s.bubble_bg_them = "#24283b".into();
            s.bubble_fg_me = "#c0caf5".into();
            s.bubble_fg_them = "#c0caf5".into();
            s.border = "#414868".into();
            s.muted = "#565f89".into();
        }
        "Nordic" => {
            s.preset = "Nordic".into();
            s.window_bg = "#2e3440".into();
            s.window_fg = "#d8dee9".into();
            s.sidebar_bg = "#3b4252".into();
            s.sidebar_fg = "#e5e9f0".into();
            s.accent = "#88c0d0".into();
            s.accent_fg = "#2e3440".into();
            s.bubble_bg_me = "#434c5e".into();
            s.bubble_bg_them = "#4c566a".into();
            s.bubble_fg_me = "#eceff4".into();
            s.bubble_fg_them = "#eceff4".into();
            s.border = "#4c566a".into();
            s.muted = "#7b8497".into();
        }
        "Dracula" => {
            s.preset = "Dracula".into();
            s.window_bg = "#282a36".into();
            s.window_fg = "#f8f8f2".into();
            s.sidebar_bg = "#21222c".into();
            s.sidebar_fg = "#f8f8f2".into();
            s.accent = "#bd93f9".into();
            s.accent_fg = "#282a36".into();
            s.bubble_bg_me = "#44475a".into();
            s.bubble_bg_them = "#6272a4".into();
            s.bubble_fg_me = "#f8f8f2".into();
            s.bubble_fg_them = "#f8f8f2".into();
            s.border = "#6272a4".into();
            s.muted = "#6272a4".into();
        }
        "Gruvbox" => {
            s.preset = "Gruvbox".into();
            s.window_bg = "#282828".into();
            s.window_fg = "#ebdbb2".into();
            s.sidebar_bg = "#3c3836".into();
            s.sidebar_fg = "#ebdbb2".into();
            s.accent = "#fabd2f".into();
            s.accent_fg = "#282828".into();
            s.bubble_bg_me = "#504945".into();
            s.bubble_bg_them = "#665c54".into();
            s.bubble_fg_me = "#ebdbb2".into();
            s.bubble_fg_them = "#ebdbb2".into();
            s.border = "#7c6f64".into();
            s.muted = "#928374".into();
        }
        "Catppuccin Mocha" => {
            s.preset = "Catppuccin Mocha".into();
            s.window_bg = "#1e1e2e".into();
            s.window_fg = "#cdd6f4".into();
            s.sidebar_bg = "#181825".into();
            s.sidebar_fg = "#cdd6f4".into();
            s.accent = "#cba6f7".into();
            s.accent_fg = "#1e1e2e".into();
            s.bubble_bg_me = "#313244".into();
            s.bubble_bg_them = "#45475a".into();
            s.bubble_fg_me = "#cdd6f4".into();
            s.bubble_fg_them = "#cdd6f4".into();
            s.border = "#45475a".into();
            s.muted = "#6c7086".into();
        }
        "Sunset" => {
            s.preset = "Sunset".into();
            s.window_bg = "#2b1d2a".into();
            s.window_fg = "#f5d9c0".into();
            s.sidebar_bg = "#3a2530".into();
            s.sidebar_fg = "#f5d9c0".into();
            s.accent = "#ff7e6b".into();
            s.accent_fg = "#2b1d2a".into();
            s.bubble_bg_me = "#5a3447".into();
            s.bubble_bg_them = "#7a3a52".into();
            s.bubble_fg_me = "#f5d9c0".into();
            s.bubble_fg_them = "#ffe6cf".into();
            s.border = "#7a3a52".into();
            s.muted = "#a87889".into();
        }
        "Matrix Green" => {
            s.preset = "Matrix Green".into();
            s.window_bg = "#000000".into();
            s.window_fg = "#00ff41".into();
            s.sidebar_bg = "#0a0a0a".into();
            s.sidebar_fg = "#00ff41".into();
            s.accent = "#00ff41".into();
            s.accent_fg = "#000000".into();
            s.bubble_bg_me = "#003b00".into();
            s.bubble_bg_them = "#002200".into();
            s.bubble_fg_me = "#00ff41".into();
            s.bubble_fg_them = "#00ff41".into();
            s.border = "#006400".into();
            s.muted = "#008f11".into();
            s.font_family_mono = "Monospace".into();
        }
        _ => {
            // Material Dark (default)
            s.preset = "Material Dark".into();
            s.window_bg = "#1e1e1e".into();
            s.window_fg = "#e4e4e4".into();
            s.sidebar_bg = "#252525".into();
            s.sidebar_fg = "#e4e4e4".into();
            s.accent = "#7c4dff".into();
            s.accent_fg = "#ffffff".into();
            s.bubble_bg_me = "#7c4dff".into();
            s.bubble_bg_them = "#3a3a3a".into();
            s.bubble_fg_me = "#ffffff".into();
            s.bubble_fg_them = "#e4e4e4".into();
            s.border = "#3a3a3a".into();
            s.muted = "#888888".into();
        }
    }
    s.danger = "#ef4444".into();
    s.success = "#22c55e".into();
    s.warning = "#f59e0b".into();
    s
}

/// The layout / sizing skeleton shared by every preset. Only colors and
/// font family differ between presets; geometry stays consistent so the user
/// can fine-tune without breaking the layout.
fn base_layout() -> ThemeState {
    ThemeState {
        preset: "Material Dark".into(),
        window_bg: "#1e1e1e".into(),
        window_fg: "#e4e4e4".into(),
        sidebar_bg: "#252525".into(),
        sidebar_fg: "#e4e4e4".into(),
        accent: "#7c4dff".into(),
        accent_fg: "#ffffff".into(),
        danger: "#ef4444".into(),
        success: "#22c55e".into(),
        warning: "#f59e0b".into(),
        muted: "#888888".into(),
        border: "#3a3a3a".into(),
        font_family: "Sans Serif".into(),
        font_family_mono: "Monospace".into(),
        font_size_xs: 10,
        font_size_sm: 12,
        font_size_md: 14,
        font_size_lg: 16,
        font_size_xl: 22,
        radius_sm: 4,
        radius_md: 8,
        radius_lg: 16,
        padding_xs: 4,
        padding_sm: 8,
        padding_md: 12,
        padding_lg: 16,
        spacing_xs: 2,
        spacing_sm: 4,
        spacing_md: 8,
        spacing_lg: 16,
        bubble_bg_me: "#7c4dff".into(),
        bubble_bg_them: "#3a3a3a".into(),
        bubble_fg_me: "#ffffff".into(),
        bubble_fg_them: "#e4e4e4".into(),
        bubble_radius: 14,
        bubble_padding_h: 12,
        bubble_padding_v: 8,
        bubble_tail: true,
        bubble_max_width_pct: 75,
        avatar_size_sm: 28,
        avatar_size_md: 36,
        avatar_size_lg: 48,
        avatar_radius: 18,
        avatar_shape: "circle".into(),
        scrollbar_size: 8,
        scrollbar_radius: 4,
        compact_mode: false,
        show_timestamps: true,
        show_avatars: true,
        animate_bubbles: true,
        animation_duration_ms: 180,
    }
}
