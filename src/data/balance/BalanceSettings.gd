class_name BalanceSettings
extends RefCounted

## Player options, a11y, and packaging constants — Steam S10.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10
##
## Settings live in user:// (not career save). Controller support is locked
## keyboard+mouse for 1.0 — freighter mouse-aim does not map cleanly to sticks.

# --- Packaging / product ---------------------------------------------------

## Window / export product name (not "Draywar Alpha").
const PRODUCT_NAME: String = "Draywar"
const PRODUCT_DESCRIPTION: String = "The empire fell. The contracts didn't."
const BOOT_BANNER: String = "Draywar — boot OK"

## 1.0 input decision: keyboard + mouse only. No gamepad bindings ship.
const CONTROLLER_SUPPORT_1_0: bool = false
const CONTROLLER_DECISION_NOTE: String = (
	"Keyboard and mouse only for Steam 1.0. " + "Gamepad deferred — freighter mouse-aim."
)

# --- Persist path ----------------------------------------------------------

const SETTINGS_PATH: String = "user://settings.cfg"
## Sibling of SETTINGS_PATH — temp write for atomic replace (REPAIR-23).
const SETTINGS_TMP_PATH: String = "user://settings.cfg.tmp"
## Previous good file after a successful replace (REPAIR-23).
const SETTINGS_BAK_PATH: String = "user://settings.cfg.bak"
const CFG_SECTION: String = "options"
const CFG_SECTION_BINDS: String = "binds"

const KEY_FOV: String = "fov"
const KEY_SENSITIVITY: String = "sensitivity"
const KEY_MASTER_VOLUME: String = "master_volume"
const KEY_FULLSCREEN: String = "fullscreen"
const KEY_UI_VOLUME: String = "ui_volume"
const KEY_SFX_VOLUME: String = "sfx_volume"

# --- Defaults / ranges -----------------------------------------------------

const DEFAULT_FOV: float = 65.0
const FOV_MIN: float = 50.0
const FOV_MAX: float = 90.0
const FOV_STEP: float = 1.0

## Multiplier on ship turn rate (mouse aim responsiveness). 1.0 = balance default.
const DEFAULT_SENSITIVITY: float = 1.0
const SENSITIVITY_MIN: float = 0.4
const SENSITIVITY_MAX: float = 2.0
const SENSITIVITY_STEP: float = 0.05

const DEFAULT_MASTER_VOLUME: float = 0.8
const DEFAULT_UI_VOLUME: float = 1.0
const DEFAULT_SFX_VOLUME: float = 1.0
const VOLUME_MIN: float = 0.0
const VOLUME_MAX: float = 1.0
const VOLUME_STEP: float = 0.05

const DEFAULT_FULLSCREEN: bool = false

# --- Audio buses (must match default_bus_layout.tres) ----------------------

const BUS_MASTER: StringName = &"Master"
const BUS_UI: StringName = &"UI"
const BUS_SFX: StringName = &"SFX"
## Bus layout resource (UI + SFX under Master). Loaded at boot (REPAIR-6).
const BUS_LAYOUT_PATH: String = "res://default_bus_layout.tres"

## Keys that must never be offered as rebinds (REPAIR-6). Escape = pause;
## backtick = debug console toggle (console itself is Brief 24).
const RESERVED_REBIND_KEYS: Array[Key] = [KEY_ESCAPE, KEY_QUOTELEFT]

# --- Rebindable actions (display label, action name) -----------------------
# Pause stays Escape-only for safety (not rebindable here).

const REBIND_ROWS: Array[Dictionary] = [
	{"action": &"throttle_up", "label": "Throttle up"},
	{"action": &"throttle_down", "label": "Throttle down"},
	{"action": &"strafe_left", "label": "Strafe left"},
	{"action": &"strafe_right", "label": "Strafe right"},
	{"action": &"afterburner", "label": "Afterburner"},
	{"action": &"dock", "label": "Dock"},
	{"action": &"fire_weapon", "label": "Fire"},
	{"action": &"target_lock", "label": "Target lock"},
	{"action": &"sector_map", "label": "Sector map"},
	{"action": &"incident_a", "label": "Incident choice 1"},
	{"action": &"incident_b", "label": "Incident choice 2"},
	{"action": &"call_tow", "label": "Call a tow"},
]

# --- Options UI copy -------------------------------------------------------

const OPTIONS_TITLE: String = "OPTIONS"
const OPTIONS_FOV: String = "Field of view"
const OPTIONS_SENSITIVITY: String = "Turn sensitivity"
const OPTIONS_MASTER_VOLUME: String = "Master volume"
const OPTIONS_UI_VOLUME: String = "UI volume"
const OPTIONS_SFX_VOLUME: String = "SFX volume"
const OPTIONS_FULLSCREEN: String = "Fullscreen"
const OPTIONS_FULLSCREEN_ON: String = "Fullscreen: On"
const OPTIONS_FULLSCREEN_OFF: String = "Fullscreen: Off"
const OPTIONS_REBINDS_HEADER: String = "Key bindings"
const OPTIONS_REBIND_HINT: String = "Click a row, then press a key."
const OPTIONS_LISTENING: String = "Press a key…"
const OPTIONS_RESET: String = "Reset defaults"
const OPTIONS_CLOSE: String = "Close"
const OPTIONS_CONTROLLER_NOTE: String = "Input: keyboard + mouse (no gamepad in 1.0)"
const OPTIONS_APPLY_FEEDBACK: String = "Settings saved."
## Shown when a rebind key collides with another rebindable action (REPAIR-6).
const OPTIONS_REBIND_CONFLICT: String = "That key is already bound to %s."
## Shown when the key is reserved (Escape, debug-console backtick) (REPAIR-6).
const OPTIONS_REBIND_RESERVED: String = "That key is reserved."

const MAIN_OPTIONS: String = "Options"
const PAUSE_OPTIONS: String = "Options"

## Options panel size (taller for rebinds).
const OPTIONS_WIDTH: float = 520.0
const OPTIONS_HEIGHT: float = 620.0
const OPTIONS_HALF_WIDTH: float = 260.0
const OPTIONS_HALF_HEIGHT: float = 310.0
const OPTIONS_SLIDER_WIDTH: float = 220.0
const OPTIONS_SCROLL_HEIGHT: float = 480.0
const OPTIONS_BIND_BUTTON_WIDTH: float = 140.0
const OPTIONS_BIND_BUTTON_HEIGHT: float = 32.0
const OPTIONS_VALUE_LABEL_WIDTH: float = 48.0
const OPTIONS_SLIDER_HEIGHT: float = 24.0
const OPTIONS_PERCENT_SCALE: float = 100.0
const OPTIONS_CANVAS_LAYER: int = 45

## Volume mute threshold / silent bus floor (dB).
const VOLUME_MUTE_EPSILON: float = 0.0001
const VOLUME_MUTE_DB: float = -80.0

## Procedural tone PCM (AudioService).
const TONE_SAMPLE_RATE: int = 22050
const TONE_BYTES_PER_SAMPLE: int = 2
const TONE_PCM_PEAK_INT: int = 32767
const TONE_PCM_MIN_INT: int = -32768

## UI click / confirm / weapon / dock tone presets (hz, seconds, peak linear).
const TONE_UI_CLICK_HZ: float = 880.0
const TONE_UI_CLICK_SEC: float = 0.04
const TONE_UI_CLICK_PEAK: float = 0.12
const TONE_UI_CONFIRM_HZ: float = 660.0
const TONE_UI_CONFIRM_SEC: float = 0.06
const TONE_UI_CONFIRM_PEAK: float = 0.15
const TONE_WEAPON_HZ: float = 220.0
const TONE_WEAPON_SEC: float = 0.05
const TONE_WEAPON_PEAK: float = 0.18
const TONE_DOCK_HZ: float = 440.0
const TONE_DOCK_SEC: float = 0.1
const TONE_DOCK_PEAK: float = 0.2
const TONE_UNDOCK_HZ: float = 330.0
const TONE_UNDOCK_SEC: float = 0.08
const TONE_UNDOCK_PEAK: float = 0.16

## Steam rich-presence keys (stub until GodotSteam wired).
const STEAM_PRESENCE_MENU: String = "In menu"
const STEAM_PRESENCE_FLIGHT: String = "In space"
const STEAM_PRESENCE_DOCKED: String = "Docked"
