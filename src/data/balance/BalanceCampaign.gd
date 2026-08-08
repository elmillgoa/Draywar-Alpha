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
## S7 ceiling kept as alias; live validation uses ACT_MAX (includes Act III / S8).
const ACT_MAX_S7: int = ACT_II
const ACT_MAX: int = ACT_III

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
## Job 6 phase 2: an ending that can never be reached again. "Locked" means
## "not yet" everywhere else in that list, so a dead ending needs its own word.
const JOURNAL_STATUS_CLOSED: StringName = &"closed"

# --- Ending reachability (Job 6 phase 2) ------------------------------------

## Decision: Draywar Review/DECISION_campaign-dead-end.md — Elliot, 2026-08-07.
## The campaign may dead-end; the game says so at the moment it happens and
## tells a recoverable grind apart from a genuinely finished career.
## At least one ignition route is offerable right now.
const ENDING_GRADE_OPEN: StringName = &"open"
## Both routes shut, but the standing they need can still be earned back.
const ENDING_GRADE_STALLED: StringName = &"stalled"
## Both routes shut and no live mechanism can raise the standing that shut them.
const ENDING_GRADE_CLOSED: StringName = &"closed"

const ENDING_SEVERITY_OPEN: int = 0
const ENDING_SEVERITY_STALLED: int = 1
const ENDING_SEVERITY_CLOSED: int = 2

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

## Act III Holding milestones (S8) — names only; money/UI in BalanceHolding.
const FLAG_HOLDING_CLAIM: StringName = &"flag_holding_claim"
const FLAG_HOLDING_POWER: StringName = &"flag_holding_power"
const FLAG_HOLDING_SUPPLY: StringName = &"flag_holding_supply"
const FLAG_HOLDING_PROTECT: StringName = &"flag_holding_protect"
const FLAG_HOLDING_PEOPLE: StringName = &"flag_holding_people"
## Set on Holding purchase (not on milestone work).
const FLAG_HOLDING_CLAIMED: StringName = &"flag_holding_claimed"
## Set when ignition spine completes (campaign complete).
const FLAG_CAMPAIGN_COMPLETE: StringName = &"flag_campaign_complete"

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
const BUS_ARGS_ENDING_BLOCKED: int = 2

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
const JOURNAL_SECTION_CLOSED: String = "Closed for good"
const JOURNAL_LINE_FORMAT: String = "%s — %s"
const JOURNAL_EMPTY: String = "No story work yet."

const STATION_SECTION_STORY: String = "Story"
const STATION_STORY_ACCEPT_FORMAT: String = "Accept: %s"
const STATION_STORY_LOCKED_FORMAT: String = "Next locked: %s"
const STATION_STORY_NEED_STANDING: String = "Need better standing with the offerer"
const STATION_STORY_NEED_DEBT: String = "Need an open Free Haulers loan (Services)"
const STATION_STORY_NEED_DEBT_CLEAR: String = "Clear all debt before this story work"
const STATION_STORY_NEED_FLAGS: String = "Complete earlier story work first"
const STATION_STORY_NEED_LANE: String = "Pick a lane first (trade, gun, or shadow)"
const STATION_STORY_NEED_HOLDING_MATCH: String = "Ignition only at your claimed Holding dock"
const STATION_STORY_NEED_STANDOFF: String = (
	"Standoff unresolved: Neutral+ with prior, " + "or Friendly Free Haulers/Reach"
)
const STATION_STORY_BUSY: String = "Finish or abandon the active job first"
const STATION_STORY_NONE: String = "No story work at this dock"

# --- Ending block copy (Job 6 phase 2) --------------------------------------

## Both ignition routes shut, standing still climbable. `%s` is the needs list.
const ENDING_STALLED_FORMAT: String = (
	"Both endings are shut: %s. "
	+ "That standing can still be earned back — this is a grind, not the end."
)
## Both routes shut and nothing left can raise the standing. `%s` is the list.
const ENDING_CLOSED_FORMAT: String = (
	"Both endings are closed for good: %s. "
	+ "No dock, ally or rival left in the sector can move that standing."
)
## One requirement: entity display name, tier needed, tier held now.
const ENDING_NEED_TIER_FORMAT: String = "%s must be %s or better (now %s)"
## The either-backer requirement: joined backer names, tier needed.
const ENDING_NEED_BACKING_FORMAT: String = "or %s must be %s"
const ENDING_NEED_JOIN: String = ", "
const ENDING_BACKING_JOIN: String = " / "

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


## How bad an ending grade is. Higher is worse; used to announce only on the
## edge where the verdict gets worse, never on every standing change.
static func ending_grade_severity(grade: StringName) -> int:
	if grade == ENDING_GRADE_CLOSED:
		return ENDING_SEVERITY_CLOSED
	if grade == ENDING_GRADE_STALLED:
		return ENDING_SEVERITY_STALLED
	return ENDING_SEVERITY_OPEN


## True when flag name is a lane-choice flag.
static func is_lane_flag(flag_name: StringName) -> bool:
	return LANE_FLAGS.has(flag_name)


## True when any string in `sets_flags` is a lane-choice flag.
static func sets_flags_include_lane(sets_flags: PackedStringArray) -> bool:
	for flag: String in sets_flags:
		if is_lane_flag(StringName(flag.strip_edges())):
			return true
	return false
