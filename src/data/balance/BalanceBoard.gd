class_name BalanceBoard
extends RefCounted

## Station job board + radiant generator tunables — Steam S3a.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3a
##
## Board restock steps derive from WorldClock the same way MarketService does:
## `floor(elapsed / BOARD_STEP_SECONDS)`. Offers for a station at step N are a
## pure function of content + market catch-up state + step + station_id. No RNG.

# --- Tick cadence ------------------------------------------------------------

## One board restock interval in game seconds (4 game hours).
## Jump away-time and live time share this step derivation with MarketService.
const BOARD_STEP_SECONDS: float = 14400.0

## BOARD_STEP_SECONDS in game hours (BalanceWorldClock.SECONDS_PER_HOUR = 3600).
const BOARD_STEP_HOURS: float = 4.0

# --- Board layout ------------------------------------------------------------

## Max offers shown on one station board after a restock.
const BOARD_SLOTS_PER_STATION: int = 5

## How many of those slots prefer hand (ContentLibrary) templates first.
const BOARD_HAND_SLOTS_MAX: int = 2

# --- Save (optional section, schema v1 — no envelope bump) -------------------

const SAVE_SECTION_KEY: StringName = &"boards"

const SAVE_KEY_STEPS: StringName = &"steps_done"

## station_id string → Array of claimed offer id strings for the current cycle.
const SAVE_KEY_CLAIMED: StringName = &"claimed"

# --- Offer dictionary keys ---------------------------------------------------

const OFFER_KEY_ID: StringName = &"instance_id"
## Station board that listed this offer (claim bookkeeping; not the mission dest).
const OFFER_KEY_BOARD_STATION: StringName = &"board_station_id"
const OFFER_KEY_KIND: StringName = &"kind"
const OFFER_KEY_OFFERING_ENTITY: StringName = &"offering_entity_id"
const OFFER_KEY_PAY: StringName = &"pay_credits"
const OFFER_KEY_STANDING_COMPLETE: StringName = &"standing_complete"
const OFFER_KEY_STANDING_FAIL: StringName = &"standing_fail"
const OFFER_KEY_STANDING_ABANDON: StringName = &"standing_abandon"
const OFFER_KEY_DESTINATION: StringName = &"destination_station_id"
const OFFER_KEY_TARGET_SYSTEM: StringName = &"target_system_id"
const OFFER_KEY_CARGO_COMMODITY: StringName = &"cargo_commodity_id"
const OFFER_KEY_CARGO_QUANTITY: StringName = &"cargo_quantity"
const OFFER_KEY_LABEL: StringName = &"label"
const OFFER_KEY_SOURCE: StringName = &"source"

const OFFER_SOURCE_HAND: StringName = &"hand"
const OFFER_SOURCE_RADIANT: StringName = &"radiant"

# --- Radiant kind weights (base; policing / market scale them) ---------------

const WEIGHT_DELIVERY_BASE: int = 40
const WEIGHT_BOUNTY_BASE: int = 20
const WEIGHT_ESCORT_BASE: int = 15
const WEIGHT_SMUGGLE_BASE: int = 10

## Added to bounty weight when local system is contested.
const WEIGHT_BOUNTY_CONTESTED_BONUS: int = 25

## Added to bounty weight when local system is lawless.
const WEIGHT_BOUNTY_LAWLESS_BONUS: int = 35

## Bounty weight multiplier numerator/denominator in hard-patrolled space
## (suppresses bounty on patrolled docks).
const WEIGHT_BOUNTY_PATROLLED_NUM: int = 1
const WEIGHT_BOUNTY_PATROLLED_DEN: int = 4

## Added to escort weight when origin/dest policing differ across a risk edge.
const WEIGHT_ESCORT_RISK_BONUS: int = 30

## Added to smuggle weight when munitions (or other Reach-contraband) shortage.
const WEIGHT_SMUGGLE_CONTRABAND_BONUS: int = 20

## Added to delivery weight when a destination shows a real shortage.
const WEIGHT_DELIVERY_SHORTAGE_BONUS: int = 35

# --- Market shortage / pay ---------------------------------------------------

## stock / target at or below this counts as a shortage for haul generation.
const SHORTAGE_RATIO: float = 0.55

## Minimum pay for any radiant job (credits).
const PAY_FLOOR: int = 80

## Base pay before hop and shortage multipliers.
const PAY_BASE: int = 100

## Extra credits per gate hop to the destination.
const PAY_PER_HOP: int = 40

## Extra credits when the job is shortage-driven (severity scale applied too).
const PAY_SHORTAGE_BASE: int = 50

## Max shortage severity multiplier applied to PAY_SHORTAGE_BASE (integer scale).
const PAY_SHORTAGE_SEVERITY_MAX: int = 3

## Escort premium on top of hop-scaled base.
const PAY_ESCORT_PREMIUM: int = 60

## Bounty premium on top of base.
const PAY_BOUNTY_PREMIUM: int = 80

## Smuggle premium on top of hop-scaled base.
const PAY_SMUGGLE_PREMIUM: int = 100

## Default smuggle crate count when radiant builds a munitions run.
const SMUGGLE_CARGO_QUANTITY: int = 4

## Prefer this commodity for radiant smuggle (existing contraband law).
const SMUGGLE_PREFERRED_COMMODITY: StringName = &"commodity_munitions"

# --- Deterministic mix (no RNG) ----------------------------------------------

## Mix constants for pure integer hashing of (station, step, slot, salt).
const HASH_A: int = 374761393
const HASH_B: int = 668265263
const HASH_C: int = 1274126177
const HASH_D: int = 1103515245
const HASH_E: int = 12345
const HASH_MASK: int = 0x7fffffff

## Deterministic salt tags for pick_index call sites (stable, not gameplay knobs).
const SALT_HAND_ROTATE: int = 7
const SALT_ESCORT_FALLBACK: int = 17
const SALT_SHORTAGE_ROUTE: int = 91
const SALT_RISK_DEST: int = 44
const SALT_BOUNTY_SYSTEM: int = 22
const SALT_BOUNTY_FALLBACK: int = 23
const SALT_SMUGGLE_ROUTE: int = 66
const SALT_OTHER_STATION: int = 11

## Shortage severity bands (ratio vs SHORTAGE_RATIO).
const SHORTAGE_SEVERITY_MID_FACTOR: float = 0.5
const SHORTAGE_SEVERITY_DEEP_FACTOR: float = 0.25
const SHORTAGE_SEVERITY_MID: int = 2
const SHORTAGE_SEVERITY_DEEP: int = 3

# --- Escort freighter (thin world prop) --------------------------------------

## Scene-tree group for the active mission escort freighter.
const GROUP_MISSION_ESCORT: StringName = &"mission_escort"

## Meta flag on the escort hull (string key for set_meta).
const META_MISSION_ESCORT: StringName = &"mission_escort"

## Hull hit points — soft target; hostiles can kill it if the player ignores it.
const ESCORT_HULL_HP: float = 40.0

## Spawn offset from the player (or station) when ensuring the freighter.
const ESCORT_SPAWN_OFFSET: Vector3 = Vector3(18.0, 2.0, -12.0)

## Display colour for the mission freighter (readable next to civilian traffic).
const ESCORT_COLOR: Color = Color(0.55, 0.78, 0.95, 1.0)

## Lock HUD / toast label for the escort freighter.
const ESCORT_LOCK_LABEL: String = "Escort freighter"

# --- UI labels (plain English) -----------------------------------------------

const LABEL_DELIVERY_FORMAT: String = "Haul to %s"
const LABEL_BOUNTY_FORMAT: String = "Bounty — clear %s"
const LABEL_ESCORT_FORMAT: String = "Escort freighter to %s"
const LABEL_SMUGGLE_FORMAT: String = "Smuggle to %s"
const LABEL_FALLBACK: String = "Available work"


## Deterministic non-negative mix of up to four salts (no RNG).
static func mix4(a: int, b: int, c: int, d: int) -> int:
	var x: int = a * HASH_A + b * HASH_B + c * HASH_C + d * HASH_D + HASH_E
	x = (x ^ (x >> 13)) * HASH_C
	x = x ^ (x >> 16)
	return x & HASH_MASK


## Pick index in [0, count) from a deterministic mix. count must be > 0.
static func pick_index(count: int, a: int, b: int, c: int, d: int) -> int:
	if count <= 1:
		return 0
	return mix4(a, b, c, d) % count
