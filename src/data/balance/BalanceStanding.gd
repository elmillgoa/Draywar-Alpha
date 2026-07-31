class_name BalanceStanding
extends RefCounted

## Standing scale, tiers, attribution, mission, and trade tunables — Alpha A3.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A2–A3
## Source of truth for numbers: docs/reputation_and_standing.md
##
## Stickiness, combat attribution, mission outcomes, light trade, and one-hop
## ripples all live here. Logic reads these; nothing under src/ invents magnitudes.

# --- Scale -----------------------------------------------------------------

const STANDING_MIN: float = -100.0
const STANDING_MAX: float = 100.0
const DEFAULT_STANDING: float = 0.0

## Standing at or below this refuses docking when the entity uses the default.
## Hostile and below refuse; the open gap in the reputation doc lives in data.
const DEFAULT_DOCK_REFUSAL_THRESHOLD: float = -50.0

# --- Display tiers (inclusive ranges) --------------------------------------

const TIER_REVERED: StringName = &"revered"
const TIER_ALLIED: StringName = &"allied"
const TIER_FRIENDLY: StringName = &"friendly"
const TIER_NEUTRAL: StringName = &"neutral"
const TIER_UNFRIENDLY: StringName = &"unfriendly"
const TIER_HOSTILE: StringName = &"hostile"
const TIER_HATED: StringName = &"hated"

const TIER_REVERED_MIN: float = 80.0
const TIER_ALLIED_MIN: float = 50.0
const TIER_FRIENDLY_MIN: float = 20.0
const TIER_NEUTRAL_MIN: float = -19.0
const TIER_UNFRIENDLY_MIN: float = -20.0
const TIER_HOSTILE_MIN: float = -50.0
const TIER_HATED_MIN: float = -80.0

## Upper bounds (inclusive) for each tier.
const TIER_REVERED_MAX: float = 100.0
const TIER_ALLIED_MAX: float = 79.0
const TIER_FRIENDLY_MAX: float = 49.0
const TIER_NEUTRAL_MAX: float = 19.0
const TIER_UNFRIENDLY_MAX: float = -49.0
const TIER_HOSTILE_MAX: float = -79.0
const TIER_HATED_MAX: float = -100.0

const KNOWN_TIERS: Array[StringName] = [
	TIER_REVERED,
	TIER_ALLIED,
	TIER_FRIENDLY,
	TIER_NEUTRAL,
	TIER_UNFRIENDLY,
	TIER_HOSTILE,
	TIER_HATED,
]

const TIER_DISPLAY_REVERED: String = "Revered"
const TIER_DISPLAY_ALLIED: String = "Allied"
const TIER_DISPLAY_FRIENDLY: String = "Friendly"
const TIER_DISPLAY_NEUTRAL: String = "Neutral"
const TIER_DISPLAY_UNFRIENDLY: String = "Unfriendly"
const TIER_DISPLAY_HOSTILE: String = "Hostile"
const TIER_DISPLAY_HATED: String = "Hated"

# --- Stickiness (A3) -------------------------------------------------------

## Everyday positives lose most effect at or below this floor.
const STICKY_NEGATIVE_FLOOR: float = -40.0

## Multiply positive deltas by this when standing is at or below the floor.
## Negative deltas always apply at full force.
const STICKY_POSITIVE_FACTOR: float = 0.25

# --- Combat attribution (A3) -----------------------------------------------

## Standing hit for an attributed kill (local system controller).
const COMBAT_KILL_DELTA: float = -12.0

## Contested space: attribute when witness_count is at least this (or evidence).
const ATTRIBUTION_WITNESS_THRESHOLD: int = 1

## Default witness count when the console omits it.
const ATTRIBUTION_DEFAULT_WITNESSES: int = 0

## report_kill / EventBus result dictionary keys.
const REPORT_KEY_ATTRIBUTED: StringName = &"attributed"
const REPORT_KEY_ENTITY_ID: StringName = &"entity_id"
const REPORT_KEY_DELTA: StringName = &"delta"
const REPORT_KEY_REASON: StringName = &"reason"
const REPORT_KEY_SYSTEM_ID: StringName = &"system_id"
const REPORT_KEY_VICTIM_ENTITY_ID: StringName = &"victim_entity_id"

# --- Mission outcomes (A3) -------------------------------------------------

## Default standing deltas when a ContractType does not override.
const MISSION_COMPLETE_DELTA: float = 8.0
const MISSION_FAIL_DELTA: float = -3.0
const MISSION_ABANDON_DELTA: float = -8.0

## ContractType.kind value for Alpha courier work.
const MISSION_KIND_DELIVERY: StringName = &"delivery"

## Content category directory for mission templates.
const MISSION_CONTENT_CATEGORY: StringName = &"contract_types"

# --- Legal trade (A3, light) -----------------------------------------------

## Small standing gain from one legal trade action.
const TRADE_LEGAL_DELTA: float = 1.0

## Soft cap: trade alone cannot push standing above this (Neutral band top).
const TRADE_STANDING_SOFT_CAP: float = 19.0

# --- One-hop ripple (A3) ---------------------------------------------------

## Allied / subsidiary / member_of: fraction of source applied delta (same sign).
const RIPPLE_ALLY_FRACTION: float = 0.25

## Rival / enemy: fraction of source applied delta, inverted.
const RIPPLE_RIVAL_FRACTION: float = 0.15

## Absolute cap on any single ripple delta (cannot alone cross a major tier).
const RIPPLE_MAX_ABS: float = 5.0

# --- Mutation reasons (StringName tags for apply_* / logs) -----------------

const REASON_COMBAT_KILL: StringName = &"combat_kill"
const REASON_MISSION_COMPLETE: StringName = &"mission_complete"
const REASON_MISSION_FAIL: StringName = &"mission_fail"
const REASON_MISSION_ABANDON: StringName = &"mission_abandon"
const REASON_TRADE_LEGAL: StringName = &"trade_legal"
const REASON_RIPPLE: StringName = &"ripple"

# --- Status moment / HUD copy ----------------------------------------------

## HUD standing line: tier display name, then controller display name.
const STATUS_LINE_FORMAT: String = "STANDING  %s — %s"

## When system/station has no controller entity.
const STATUS_UNCONTROLLED_LABEL: String = "Uncontrolled"

## Dock prompt when standing blocks: tier display, entity display.
const DOCK_REFUSED_PROMPT_FORMAT: String = "DOCKING REFUSED — %s (%s)"

## Docked status with standing: station name, tier, entity.
const DOCKED_STATUS_FORMAT: String = "DOCKED — %s · %s — %s"

## Status moment kinds carried on EventBus.on_status_moment.
const STATUS_KIND_SYSTEM: StringName = &"system"
const STATUS_KIND_STATION: StringName = &"station"

# --- Save section keys -----------------------------------------------------

const SAVE_SECTION_KEY: StringName = &"standing"
const SAVE_KEY_ENTITIES: StringName = &"entities"
const SAVE_KEY_PEOPLE: StringName = &"people"

# --- Console ---------------------------------------------------------------

## `standing show <kind> <id>` and `standing entity|person <id> <value>` each
## take this many tokens after the verb.
const CONSOLE_PAIR_ARG_COUNT: int = 2

## `kill <system_id>` minimum args after the verb.
const CONSOLE_KILL_MIN_ARGS: int = 1

## Optional kill args: witnesses, evidence, victim → max tokens after verb.
const CONSOLE_KILL_MAX_ARGS: int = 4

## Arg counts (size of args array) when optional kill tokens are present.
const CONSOLE_KILL_SIZE_WITH_WITNESSES: int = 2
const CONSOLE_KILL_SIZE_WITH_EVIDENCE: int = 3
const CONSOLE_KILL_SIZE_WITH_VICTIM: int = 4

## Indices into kill args (0 = system_id).
const CONSOLE_KILL_INDEX_SYSTEM: int = 0
const CONSOLE_KILL_INDEX_WITNESSES: int = 1
const CONSOLE_KILL_INDEX_EVIDENCE: int = 2
const CONSOLE_KILL_INDEX_VICTIM: int = 3

## `trade legal <entity_id>` tokens after the verb.
const CONSOLE_TRADE_LEGAL_ARGS: int = 2

## Index of the entity id in `trade legal <entity_id>`.
const CONSOLE_TRADE_ENTITY_INDEX: int = 1

## `mission accept <id>` tokens after the verb (action + id).
const CONSOLE_MISSION_ACCEPT_ARGS: int = 2

## Index of the template id in `mission accept <id>` args.
const CONSOLE_MISSION_ID_INDEX: int = 1

## Evidence console token truthy values parse as true when equal to these.
const CONSOLE_EVIDENCE_TRUE: String = "1"
const CONSOLE_EVIDENCE_ON: String = "on"
const CONSOLE_EVIDENCE_YES: String = "yes"
const CONSOLE_EVIDENCE_TRUE_WORD: String = "true"

## Station menu: accept job button label.
const STATION_ACCEPT_JOB_LABEL: String = "Accept courier job"

## Console feedback formats.
const CONSOLE_KILL_ATTRIBUTED_FORMAT: String = "Kill attributed in %s → %s standing %s (delta %s)."
const CONSOLE_KILL_UNATTRIBUTED_FORMAT: String = "Kill in %s not attributed."
const CONSOLE_MISSION_ACCEPTED_FORMAT: String = "Accepted mission %s (%s)."
const CONSOLE_MISSION_OUTCOME_FORMAT: String = "Mission %s %s → %s standing %s (delta %s)."
const CONSOLE_TRADE_FORMAT: String = "Legal trade with %s → standing %s (delta %s)."
const CONSOLE_TRADE_CAPPED_FORMAT: String = "Legal trade with %s → no gain (at/above soft cap %s)."
