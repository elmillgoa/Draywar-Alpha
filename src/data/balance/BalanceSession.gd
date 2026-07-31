class_name BalanceSession
extends RefCounted

## Session shell tunables — Path C B2.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B2
##
## Main menu, pause, captain sheet, and optional world/mission save sections.

# --- Save (optional sections, schema v1 — no envelope bump) ----------------

## Default career save base name (user://saves/career.sav).
const DEFAULT_SAVE_NAME: String = "career"

## Optional section keys.
const SAVE_SECTION_WORLD: StringName = &"world"
const SAVE_SECTION_MISSION: StringName = &"mission"

## World section keys.
const WORLD_KEY_SYSTEM_ID: StringName = &"system_id"
const WORLD_KEY_POS_X: StringName = &"pos_x"
const WORLD_KEY_POS_Y: StringName = &"pos_y"
const WORLD_KEY_POS_Z: StringName = &"pos_z"
const WORLD_KEY_DOCKED_STATION_ID: StringName = &"docked_station_id"

## Mission section keys.
const MISSION_KEY_TEMPLATE_ID: StringName = &"template_id"
## Optional: bounty kill objective met (bool). Missing = false. No schema bump.
const MISSION_KEY_OBJECTIVE_MET: StringName = &"objective_met"

# --- Canvas layers (above station 20 / HUD 10; below debug console 100) -----

const MAIN_MENU_CANVAS_LAYER: int = 40
const PAUSE_MENU_CANVAS_LAYER: int = 35
const CAPTAIN_SHEET_CANVAS_LAYER: int = 36

# --- Menu layout -----------------------------------------------------------

const MENU_WIDTH: float = 380.0
const MENU_HEIGHT: float = 320.0
const MENU_HALF_WIDTH: float = 190.0
const MENU_HALF_HEIGHT: float = 160.0
const MENU_BUTTON_WIDTH: float = 240.0
const MENU_BUTTON_HEIGHT: float = 44.0
const MENU_DIM_ALPHA: float = 0.62
const MENU_SPACER_HEIGHT: float = 12.0

const SHEET_WIDTH: float = 420.0
const SHEET_HEIGHT: float = 470.0
const SHEET_HALF_WIDTH: float = 210.0
const SHEET_HALF_HEIGHT: float = 235.0
const SHEET_BUTTON_WIDTH: float = 200.0
const SHEET_BUTTON_HEIGHT: float = 40.0
const SHEET_SPACER_HEIGHT: float = 8.0
const SHEET_MAX_STANDING_LINES: int = 6

# --- Copy ------------------------------------------------------------------

const MAIN_TITLE: String = "DRAYWAR"
const MAIN_NEW_GAME: String = "New Game"
const MAIN_CONTINUE: String = "Continue"
const MAIN_QUIT: String = "Quit"

const PAUSE_TITLE: String = "PAUSED"
const PAUSE_RESUME: String = "Resume"
const PAUSE_CAPTAIN_SHEET: String = "Captain sheet"
const PAUSE_SAVE: String = "Save"
const PAUSE_LOAD: String = "Load"
const PAUSE_QUIT_TO_MENU: String = "Quit to menu"

const SHEET_TITLE: String = "CAPTAIN"
const SHEET_STANDING_HEADER: String = "Standing"
const SHEET_CLOSE: String = "Close"
const SHEET_SHIP_FORMAT: String = "Ship  %s"
const SHEET_CREDITS_FORMAT: String = "Credits  %d"
const SHEET_CARGO_FORMAT: String = "Cargo  %d/%d"
const SHEET_FUEL_FORMAT: String = "Fuel  %d%%"
const SHEET_HULL_FORMAT: String = "Hull  %d%%"
const SHEET_JOB_FORMAT: String = "Job  %s → %s"
const SHEET_JOB_NO_DEST_FORMAT: String = "Job  %s"
## Captain sheet bounty lines (system / station display names).
const SHEET_JOB_BOUNTY_FORMAT: String = "Bounty  clear hostiles in %s"
const SHEET_JOB_BOUNTY_READY_FORMAT: String = "Bounty  turn in at %s"
const SHEET_JOB_STATUS_BOUNTY_HUNT: String = "Status  Hunt active"
const SHEET_JOB_STATUS_BOUNTY_READY: String = "Status  Ready to turn in"
const SHEET_NO_JOB: String = "Job  — none —"
const SHEET_STATUS_FORMAT: String = "Local  %s"
const SHEET_STANDING_LINE_FORMAT: String = "%s  %s  (%s)"
const SHEET_JOB_STATUS_ACTIVE: String = "Status  Active"

const SAVE_OK_FORMAT: String = "Saved '%s'."
const SAVE_FAIL_FORMAT: String = "Save failed: %s"
const LOAD_OK_FORMAT: String = "Loaded '%s'."
const LOAD_FAIL_FORMAT: String = "Load failed: %s"
const LOAD_NONE: String = "No save to load."

# --- New game tip (B5) -----------------------------------------------------

## Canvas layer above HUD (10) / station (20), below pause (35).
const NEW_GAME_TIP_CANVAS_LAYER: int = 32

const NEW_GAME_TIP_WIDTH: float = 420.0
const NEW_GAME_TIP_HEIGHT: float = 220.0
const NEW_GAME_TIP_HALF_WIDTH: float = 210.0
const NEW_GAME_TIP_HALF_HEIGHT: float = 110.0
const NEW_GAME_TIP_BUTTON_WIDTH: float = 160.0
const NEW_GAME_TIP_BUTTON_HEIGHT: float = 40.0
const NEW_GAME_TIP_SPACER: float = 10.0
const NEW_GAME_TIP_DIM_ALPHA: float = 0.55

const NEW_GAME_TIP_TITLE: String = "How to fly"
const NEW_GAME_TIP_BODY: String = (
	"Mouse aim · WASD move · Shift afterburn\n"
	+ "F  dock at station / jump at gate\n"
	+ "Tab  lock · put reticle on red lead diamond\n"
	+ "Space or left mouse  fire (no auto-aim)\n"
	+ "Esc  pause · captain sheet · save\n"
	+ "Pirates sit near gates — not on the undock pad"
)
const NEW_GAME_TIP_DISMISS: String = "Got it"

# --- Input -----------------------------------------------------------------

## Pause menu action (bound to Escape via FlightInput).
const ACTION_PAUSE: StringName = &"pause_menu"

# --- Groups / discovery ----------------------------------------------------

const GROUP_PLAYER_SHIP: StringName = &"player_ship"
const GROUP_SYSTEM_WORLD: StringName = &"system_world"
const ENTITY_CONTENT_CATEGORY: StringName = &"entities"
const HULL_CONTENT_CATEGORY: StringName = &"hulls"
