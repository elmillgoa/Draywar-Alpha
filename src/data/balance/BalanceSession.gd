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
## Optional life-path career section (E4.6 / D10). Missing = old save, no path lines.
const SAVE_SECTION_CAREER: StringName = &"career"

## Career section keys (optional strings + bool; no envelope bump).
const CAREER_KEY_ORIGIN_ID: StringName = &"origin_id"
const CAREER_KEY_TRADE_ID: StringName = &"trade_id"
const CAREER_KEY_MARK_ID: StringName = &"mark_id"
const CAREER_KEY_OPENING_COMPLETE: StringName = &"opening_complete"

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
## Sector chart above pause so map can open from pause or flight (E5.5).
const SECTOR_MAP_CANVAS_LAYER: int = 37

# --- Menu layout -----------------------------------------------------------

const MENU_WIDTH: float = 380.0
## Room for optional tagline under title (E4.5).
const MENU_HEIGHT: float = 360.0
const MENU_HALF_WIDTH: float = 190.0
const MENU_HALF_HEIGHT: float = 180.0
const MENU_BUTTON_WIDTH: float = 240.0
const MENU_BUTTON_HEIGHT: float = 44.0
const MENU_DIM_ALPHA: float = 0.62
const MENU_SPACER_HEIGHT: float = 12.0

const SHEET_WIDTH: float = 420.0
## Taller for Origin/Trade/Mark lines (E4.5).
const SHEET_HEIGHT: float = 530.0
const SHEET_HALF_WIDTH: float = 210.0
const SHEET_HALF_HEIGHT: float = 265.0
const SHEET_BUTTON_WIDTH: float = 200.0
const SHEET_BUTTON_HEIGHT: float = 40.0
const SHEET_SPACER_HEIGHT: float = 8.0
const SHEET_MAX_STANDING_LINES: int = 6

# --- Copy ------------------------------------------------------------------

const MAIN_TITLE: String = "DRAYWAR"
## Optional main-menu tagline under title (E4.5). Empty string hides it.
const MAIN_TAGLINE: String = "The empire fell. The contracts didn't."
const MAIN_NEW_GAME: String = "New Game"
const MAIN_CONTINUE: String = "Continue"
const MAIN_QUIT: String = "Quit"

const PAUSE_TITLE: String = "PAUSED"
const PAUSE_RESUME: String = "Resume"
const PAUSE_CAPTAIN_SHEET: String = "Captain sheet"
const PAUSE_SECTOR_MAP: String = "Sector map"
const PAUSE_SAVE: String = "Save"
const PAUSE_LOAD: String = "Load"
const PAUSE_QUIT_TO_MENU: String = "Quit to menu"

## Sector chart (E5.5) — functional layout for 6 systems.
const SECTOR_MAP_TITLE: String = "SECTOR CHART"
const SECTOR_MAP_CLOSE: String = "Close"
const SECTOR_MAP_CURRENT_FORMAT: String = "Here  %s"
const SECTOR_MAP_CURRENT_UNKNOWN: String = "Here  —"
const SECTOR_MAP_WIDTH: float = 520.0
const SECTOR_MAP_HEIGHT: float = 420.0
const SECTOR_MAP_HALF_WIDTH: float = 260.0
const SECTOR_MAP_HALF_HEIGHT: float = 210.0
const SECTOR_MAP_CHART_WIDTH: float = 480.0
const SECTOR_MAP_CHART_HEIGHT: float = 280.0
const SECTOR_MAP_NODE_SIZE: float = 14.0
const SECTOR_MAP_NODE_SIZE_CURRENT: float = 20.0
const SECTOR_MAP_EDGE_WIDTH: float = 2.0
const SECTOR_MAP_EDGE_COLOR: Color = Color(0.55, 0.6, 0.7, 0.85)
const SECTOR_MAP_NODE_COLOR: Color = Color(0.45, 0.55, 0.75)
const SECTOR_MAP_NODE_COLOR_CURRENT: Color = Color(0.95, 0.82, 0.25)
const SECTOR_MAP_LABEL_OFFSET_X: float = 12.0
const SECTOR_MAP_LABEL_OFFSET_Y: float = -8.0
const SECTOR_MAP_NODE_HALF: float = 0.5
const SECTOR_MAP_FALLBACK_POS: Vector2 = Vector2(40.0, 40.0)
## Chart positions (local to chart control) for the branched E5 graph.
const SECTOR_MAP_NODE_POSITIONS: Dictionary = {
	&"system_alpha": Vector2(60.0, 140.0),
	&"system_beta": Vector2(180.0, 140.0),
	&"system_gamma": Vector2(300.0, 140.0),
	&"system_delta": Vector2(180.0, 40.0),
	&"system_epsilon": Vector2(380.0, 140.0),
	&"system_zeta": Vector2(440.0, 220.0),
}
## Undirected path graph: internal nodes have this degree; ends have 1.
const GRAPH_PATH_INTERNAL_DEGREE: int = 2
## Pause panel taller with sector map button.
const MENU_HEIGHT_WITH_MAP: float = 420.0
const MENU_HALF_HEIGHT_WITH_MAP: float = 210.0

const SHEET_TITLE: String = "CAPTAIN"
const SHEET_STANDING_HEADER: String = "Standing"
const SHEET_CLOSE: String = "Close"
## Captain sheet life-path lines (E4.5). Shown only when CareerStart.has_path().
const SHEET_ORIGIN_FORMAT: String = "Origin  %s"
const SHEET_TRADE_FORMAT: String = "Trade  %s"
const SHEET_MARK_FORMAT: String = "Mark  %s"
const SHEET_SHIP_FORMAT: String = "Ship  %s"
const SHEET_CREDITS_FORMAT: String = "Credits  %d"
## E3.2 debt line on captain sheet (only when debt_owed > 0).
const SHEET_DEBT_FORMAT: String = "Debt  %d owed (%s)"
const SHEET_DEBT_NONE: String = "Debt  — none —"
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
## Captain sheet smuggle lines (commodity / destination display names).
const SHEET_JOB_SMUGGLE_FORMAT: String = "Smuggle  %s → %s"
const SHEET_JOB_SMUGGLE_NO_DEST_FORMAT: String = "Smuggle  %s"
const SHEET_JOB_STATUS_SMUGGLE: String = "Status  Cargo must reach dest"
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

# --- Life path create (E4.2) -----------------------------------------------

## Above main menu (40); full-screen modal until confirm/cancel.
const LIFE_PATH_CREATE_CANVAS_LAYER: int = 42

const LIFE_PATH_CREATE_WIDTH: float = 720.0
const LIFE_PATH_CREATE_HEIGHT: float = 560.0
const LIFE_PATH_CREATE_HALF_WIDTH: float = 360.0
const LIFE_PATH_CREATE_HALF_HEIGHT: float = 280.0
## Keep panel inside the window; content columns scroll if they still overflow.
const LIFE_PATH_CREATE_VIEWPORT_MARGIN: float = 24.0
const LIFE_PATH_CREATE_SCROLL_MIN_HEIGHT: float = 160.0
## Center panel offsets from half-size (width * factor).
const LIFE_PATH_CREATE_CENTER_HALF: float = 0.5
const LIFE_PATH_CREATE_BUTTON_WIDTH: float = 200.0
const LIFE_PATH_CREATE_BUTTON_HEIGHT: float = 40.0
const LIFE_PATH_CREATE_OPTION_MIN_HEIGHT: float = 72.0
const LIFE_PATH_CREATE_SPACER: float = 8.0
const LIFE_PATH_CREATE_AXIS_GAP: float = 10.0
const LIFE_PATH_CREATE_ACTION_GAP: int = 16
const LIFE_PATH_CREATE_DIM_ALPHA: float = 0.72
const LIFE_PATH_CREATE_COLUMN_MIN_WIDTH: float = 210.0

const LIFE_PATH_CREATE_TITLE: String = "WHO WERE YOU"
const LIFE_PATH_CREATE_SUBTITLE: String = (
	"Three picks. Each one leaves standing teeth. " + "No free rides."
)
const LIFE_PATH_CREATE_AXIS_ORIGIN: String = "Origin"
const LIFE_PATH_CREATE_AXIS_TRADE: String = "Former trade"
const LIFE_PATH_CREATE_AXIS_MARK: String = "The mark"
const LIFE_PATH_CREATE_CONFIRM: String = "Confirm"
const LIFE_PATH_CREATE_CANCEL: String = "Cancel"
const LIFE_PATH_CREATE_NEED_ALL: String = "Pick one on each column to continue."
const LIFE_PATH_CREATE_TEETH_NONE: String = "No standing change"
const LIFE_PATH_CREATE_TEETH_DEBT: String = "Free Haulers loan — +%d credits, owe %d"
const LIFE_PATH_CREATE_TEETH_DELTA_FORMAT: String = "%s %+d"
const LIFE_PATH_CREATE_TEETH_JOIN: String = " · "
const LIFE_PATH_CREATE_BLURB_FALLBACK: String = "—"
## Option button: display name, blurb, teeth summary.
const LIFE_PATH_CREATE_OPTION_FORMAT: String = "%s\n%s\n%s"

# --- Opening annexation (E4.3) ---------------------------------------------

## Same band as create; shown after path apply, before fly tip.
const ANNEXATION_CANVAS_LAYER: int = 42

const ANNEXATION_WIDTH: float = 520.0
const ANNEXATION_HEIGHT: float = 320.0
const ANNEXATION_HALF_WIDTH: float = 260.0
const ANNEXATION_HALF_HEIGHT: float = 160.0
const ANNEXATION_VIEWPORT_MARGIN: float = 24.0
const ANNEXATION_CENTER_HALF: float = 0.5
const ANNEXATION_BUTTON_WIDTH: float = 200.0
const ANNEXATION_BUTTON_HEIGHT: float = 40.0
const ANNEXATION_SPACER: float = 12.0
const ANNEXATION_DIM_ALPHA: float = 0.72

const ANNEXATION_TITLE: String = "The corridor is claimed"
const ANNEXATION_BODY: String = (
	"Your last neutral berth is gone.\n"
	+ "Reach Authority runs the pad under your feet.\n"
	+ "Alpha Port is theirs now. So is the ledger that greets you."
)
## Args: tier display, controller display (status moment line pieces).
const ANNEXATION_BAGGAGE_FORMAT: String = "Your standing here: %s — %s"
const ANNEXATION_BAGGAGE_UNCONTROLLED: String = "Your standing here: uncontrolled space"
const ANNEXATION_CONTINUE: String = "Continue"

# --- Input -----------------------------------------------------------------

## Pause menu action (bound to Escape via FlightInput).
const ACTION_PAUSE: StringName = &"pause_menu"

# --- Groups / discovery ----------------------------------------------------

const GROUP_PLAYER_SHIP: StringName = &"player_ship"
const GROUP_SYSTEM_WORLD: StringName = &"system_world"
const ENTITY_CONTENT_CATEGORY: StringName = &"entities"
const HULL_CONTENT_CATEGORY: StringName = &"hulls"
