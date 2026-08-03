class_name BalanceOps
extends RefCounted

## Operations fleet, warehouse, and charter tunables — Steam S6.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S6
##
## Hired ships are abstract (no world spawn). Standing floor for hire reuses
## BalanceStanding.TIER_FRIENDLY_MIN — do not invent tiers here.

# --- Groups / save ----------------------------------------------------------

const SAVE_SECTION_KEY: StringName = &"operation"
const GROUP_OPERATION_SERVICE: StringName = &"operation_service"

# --- Fleet ceiling ----------------------------------------------------------

const MAX_HIRED: int = 2
const HIRE_COST: int = 800
## Credits per game-hour per hired ship (always, docked or not).
const UPKEEP_CREDITS_PER_HOUR: int = 5

# --- Haul loop --------------------------------------------------------------

## Game hours between haul resolve ticks (buy origin + sell dest).
const HAUL_LEG_HOURS: float = 4.0
const HAUL_UNITS: int = 5
const DEFAULT_HAUL_COMMODITY: StringName = &"commodity_ore"

# --- Warehouse --------------------------------------------------------------

## Total cargo volume units of warehouse capacity per station.
const WAREHOUSE_CAPACITY: int = 40

# --- Standing / charter -----------------------------------------------------

## Standing hit on charter breach (missed upkeep threshold). StandingService only.
const CHARTER_BREACH_STANDING_DELTA: float = -15.0
## Consecutive missed upkeep cycles (can't fully pay) before breach + fire.
const UPKEEP_MISS_BREACH_COUNT: int = 3

# --- Orders -----------------------------------------------------------------

const ORDER_PARK: StringName = &"park"
const ORDER_HAUL: StringName = &"haul_route"
const ORDER_ESCORT: StringName = &"escort_player"

const KNOWN_ORDERS: Array[StringName] = [
	ORDER_PARK,
	ORDER_HAUL,
	ORDER_ESCORT,
]

# --- Hireable types (data tables, not ContentLibrary rows) ------------------

const TYPE_HAULER: StringName = &"ops_hauler"
const TYPE_FIGHTER: StringName = &"ops_fighter"

const HAULER_DISPLAY_NAME: String = "Ops Hauler"
const FIGHTER_DISPLAY_NAME: String = "Ops Escort"

const HAULER_CARGO_CAP: int = 20
const FIGHTER_CARGO_CAP: int = 0

const KNOWN_TYPES: Array[StringName] = [
	TYPE_HAULER,
	TYPE_FIGHTER,
]

# --- Save keys --------------------------------------------------------------

const KEY_HIRED: StringName = &"hired"
const KEY_WAREHOUSE: StringName = &"warehouse"

const SHIP_KEY_ID: StringName = &"id"
const SHIP_KEY_TYPE: StringName = &"type"
const SHIP_KEY_ORDER: StringName = &"order"
const SHIP_KEY_ORIGIN: StringName = &"origin_station"
const SHIP_KEY_DEST: StringName = &"dest_station"
const SHIP_KEY_COMMODITY: StringName = &"commodity_id"
const SHIP_KEY_CHARTER: StringName = &"charter_entity"
const SHIP_KEY_UPKEEP_MISSES: StringName = &"upkeep_misses"
const SHIP_KEY_HAUL_PROGRESS: StringName = &"haul_progress_hours"
const SHIP_KEY_HOME: StringName = &"home_station"

# --- Money reasons (also listed on BalanceTelemetry for telemetry parity) ---

const REASON_OPS_HIRE: StringName = &"ops_hire"
const REASON_OPS_FIRE: StringName = &"ops_fire"
const REASON_OPS_UPKEEP: StringName = &"ops_upkeep"
const REASON_OPS_HAUL_PAY: StringName = &"ops_haul_pay"

# --- Id prefix for hired abstract ships ------------------------------------

const SHIP_ID_PREFIX: String = "ops_ship_"

# --- EventBus unbind arg counts (StationOpsUi connect_refresh) --------------

const BUS_ARGS_SHIP_HIRED: int = 3
const BUS_ARGS_SHIP_FIRED: int = 1
const BUS_ARGS_ORDER_CHANGED: int = 2
const BUS_ARGS_WAREHOUSE_CHANGED: int = 1
const BUS_ARGS_UPKEEP_PAID: int = 1

# --- Station UI copy --------------------------------------------------------

const STATION_SECTION_OPS: String = "Operations"
const STATION_OPS_DASHBOARD_FORMAT: String = "Fleet: %d ships · upkeep %d cr/h"
const STATION_OPS_HIRE_HAULER_FORMAT: String = "Hire hauler — %d cr"
const STATION_OPS_HIRE_FIGHTER_FORMAT: String = "Hire escort — %d cr"
const STATION_OPS_FIRE_FORMAT: String = "Fire %s"
const STATION_OPS_ORDER_PARK: String = "Order: park"
const STATION_OPS_ORDER_HAUL_FORMAT: String = "Order: haul %s → %s"
const STATION_OPS_ORDER_ESCORT: String = "Order: escort player"
const STATION_OPS_SHIP_LINE_FORMAT: String = "%s · %s · %s"
const STATION_OPS_WAREHOUSE_HEADER: String = "Warehouse"
const STATION_OPS_WAREHOUSE_CAP_FORMAT: String = "Used %d / %d vol"
const STATION_OPS_DEPOSIT_FORMAT: String = "Deposit %s x%d"
const STATION_OPS_WITHDRAW_FORMAT: String = "Withdraw %s x%d"
const STATION_OPS_NEED_FRIENDLY: String = "Need Friendly standing with dock controller to hire"
const STATION_OPS_FULL: String = "Fleet full (max 2)"
const STATION_OPS_BROKE: String = "Not enough credits to hire"
const STATION_OPS_NOT_DOCKED: String = "Dock to manage operations"


## Display name for a hireable ops type.
static func type_display_name(ship_type: StringName) -> String:
	if ship_type == TYPE_HAULER:
		return HAULER_DISPLAY_NAME
	if ship_type == TYPE_FIGHTER:
		return FIGHTER_DISPLAY_NAME
	return String(ship_type)


## Abstract cargo capacity for a hireable type (haul only cares about hauler).
static func type_cargo_cap(ship_type: StringName) -> int:
	if ship_type == TYPE_HAULER:
		return HAULER_CARGO_CAP
	if ship_type == TYPE_FIGHTER:
		return FIGHTER_CARGO_CAP
	return 0


## True when ship_type is a known hireable ops type.
static func is_known_type(ship_type: StringName) -> bool:
	return KNOWN_TYPES.has(ship_type)


## True when order is park / haul_route / escort_player.
static func is_known_order(order: StringName) -> bool:
	return KNOWN_ORDERS.has(order)
