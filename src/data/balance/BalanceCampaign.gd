class_name BalanceCampaign
extends RefCounted

## Campaign spine flags, acts, and UI copy — Steam S7.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S7
##
## Spine contracts are ContractType rows with is_spine. Standing floors reuse
## BalanceStanding tiers — do not invent tiers here.

# --- Groups / save ----------------------------------------------------------

const SAVE_SECTION_KEY: StringName = &"campaign"
const GROUP_CAMPAIGN_SERVICE: StringName = &"campaign_service"

# --- Acts -------------------------------------------------------------------

const ACT_NONE: int = 0
const ACT_I: int = 1
const ACT_II: int = 2
## Reserved for S8 Holding / Act III.
const ACT_III: int = 3

const ACT_MIN: int = ACT_I
const ACT_MAX_S7: int = ACT_II

# --- Standing gate ----------------------------------------------------------

## min_entity_standing at or below this means "open to all" (no floor).
const STANDING_NO_FLOOR: float = -100.0

# --- Save keys --------------------------------------------------------------

const KEY_ACT: StringName = &"act"
const KEY_FLAGS: StringName = &"flags"
const KEY_COMPLETED_SPINE: StringName = &"completed_spine"
const KEY_HOLDING: StringName = &"holding"

# --- Journal line keys (dictionary entries for UI) --------------------------

const JOURNAL_KEY_ID: StringName = &"id"
const JOURNAL_KEY_TITLE: StringName = &"title"
const JOURNAL_KEY_BLURB: StringName = &"blurb"
const JOURNAL_KEY_STATUS: StringName = &"status"
const JOURNAL_KEY_ACT: StringName = &"act"
const JOURNAL_KEY_SORT: StringName = &"sort_index"

const JOURNAL_STATUS_OPEN: StringName = &"open"
const JOURNAL_STATUS_DONE: StringName = &"done"
const JOURNAL_STATUS_LOCKED: StringName = &"locked"

# --- Campaign flags (content sets_flags / requires_flags) -------------------

const FLAG_ACT1_STARTED: StringName = &"flag_act1_started"
const FLAG_WAKE_DONE: StringName = &"flag_wake_done"
const FLAG_JUMP_LESSON: StringName = &"flag_jump_lesson"
const FLAG_TRADE_LESSON: StringName = &"flag_trade_lesson"
const FLAG_DEBT_LESSON: StringName = &"flag_debt_lesson"
const FLAG_STANDING_LESSON: StringName = &"flag_standing_lesson"
const FLAG_ACT1_DONE: StringName = &"flag_act1_done"
const FLAG_LANE_TRADE: StringName = &"flag_lane_trade"
const FLAG_LANE_GUN: StringName = &"flag_lane_gun"
const FLAG_LANE_SHADOW: StringName = &"flag_lane_shadow"
const FLAG_OPS_INTRO: StringName = &"flag_ops_intro"
const FLAG_ACT2_DONE: StringName = &"flag_act2_done"

## Lane-choice flags: once any is set, other lane spines hide.
const LANE_FLAGS: Array[StringName] = [
	FLAG_LANE_TRADE,
	FLAG_LANE_GUN,
	FLAG_LANE_SHADOW,
]

# --- EventBus unbind arg counts ---------------------------------------------

const BUS_ARGS_FLAG_SET: int = 1
const BUS_ARGS_SPINE_COMPLETED: int = 1
const BUS_ARGS_ACT_CHANGED: int = 1
const BUS_ARGS_MISSION_ACCEPTED: int = 2
const BUS_ARGS_MISSION_CLOSED: int = 3

# --- UI canvas / layout -----------------------------------------------------

## Above captain sheet (36) / sector map (37); below debug console.
const JOURNAL_CANVAS_LAYER: int = 38
const JOURNAL_WIDTH: float = 460.0
const JOURNAL_HEIGHT: float = 420.0
const JOURNAL_HALF_WIDTH: float = 230.0
const JOURNAL_HALF_HEIGHT: float = 210.0
const JOURNAL_BUTTON_WIDTH: float = 200.0
const JOURNAL_BUTTON_HEIGHT: float = 40.0
const JOURNAL_SPACER: float = 8.0

# --- UI copy ----------------------------------------------------------------

const JOURNAL_TITLE: String = "JOURNAL"
const JOURNAL_CLOSE: String = "Close"
const JOURNAL_ACT_FORMAT: String = "Act %s"
const JOURNAL_ACT_NONE: String = "—"
const JOURNAL_SECTION_OPEN: String = "Open"
const JOURNAL_SECTION_DONE: String = "Done"
const JOURNAL_SECTION_LOCKED: String = "Locked"
const JOURNAL_LINE_FORMAT: String = "%s — %s"
const JOURNAL_EMPTY: String = "No story work yet."

const STATION_SECTION_STORY: String = "Story"
const STATION_STORY_ACCEPT_FORMAT: String = "Accept: %s"
const STATION_STORY_LOCKED_FORMAT: String = "Next locked: %s"
const STATION_STORY_NEED_STANDING: String = "Need better standing with the offerer"
const STATION_STORY_NEED_DEBT: String = "Need an open Free Haulers loan (Services)"
const STATION_STORY_NEED_FLAGS: String = "Complete earlier story work first"
const STATION_STORY_NEED_LANE: String = "Pick a lane first (trade, gun, or shadow)"
const STATION_STORY_BUSY: String = "Finish or abandon the active job first"
const STATION_STORY_NONE: String = "No story work at this dock"

const PAUSE_JOURNAL: String = "Journal"

const CAPTAIN_CAMPAIGN_FORMAT: String = "Campaign: Act %s — %s"
const CAPTAIN_CAMPAIGN_NEXT_NONE: String = "no open beat"

const NEW_GAME_TIP_STORY_LINE: String = (
	"Story work shows under Story at the station. " + "Journal is in the pause menu."
)

const ACT_DISPLAY_I: String = "I"
const ACT_DISPLAY_II: String = "II"
const ACT_DISPLAY_III: String = "III"


## Plain act label for UI (I / II / III / —).
static func act_display_name(act: int) -> String:
	if act == ACT_I:
		return ACT_DISPLAY_I
	if act == ACT_II:
		return ACT_DISPLAY_II
	if act == ACT_III:
		return ACT_DISPLAY_III
	return JOURNAL_ACT_NONE


## True when flag name is a lane-choice flag.
static func is_lane_flag(flag_name: StringName) -> bool:
	return LANE_FLAGS.has(flag_name)


## True when any string in `sets_flags` is a lane-choice flag.
static func sets_flags_include_lane(sets_flags: PackedStringArray) -> bool:
	for flag: String in sets_flags:
		if is_lane_flag(StringName(flag.strip_edges())):
			return true
	return false
