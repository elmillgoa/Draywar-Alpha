class_name BalanceStanding
extends RefCounted

## Standing scale, tiers, and status-moment copy — Alpha A2.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A2
## Source of truth for numbers: docs/reputation_and_standing.md
##
## Stickiness hooks are named for A3 combat/missions; A2 only clamps and tiers.

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

# --- Stickiness hooks (A3+) ------------------------------------------------

## Everyday positives lose most effect at or below this floor.
const STICKY_NEGATIVE_FLOOR: float = -40.0

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
