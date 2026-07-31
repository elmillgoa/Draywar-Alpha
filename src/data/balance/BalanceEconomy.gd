class_name BalanceEconomy
extends RefCounted

## Money, fuel, fees, repairs, trade cargo, and NPC traffic tunables — A5 / B3.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5, Alpha/ALPHA_DECISION_PHASE_PLAN.md B3
##
## Wallet, fuel burn, docking fees, refuel/repair station services, mission pay
## defaults, jump fuel cost, cargo capacity / trade copy, and gray-box NPC
## traffic density live here.

# --- Wallet / fuel boot ----------------------------------------------------

## Starting credits for a new session (enough for fees + one refuel).
const STARTING_CREDITS: int = 500

## Fuel tank capacity (units). Full at boot.
const FUEL_MAX: float = 100.0

## Starting fuel (full tank).
const STARTING_FUEL: float = 100.0

## Fuel units burned per second at full throttle (scaled by throttle).
const FUEL_BURN_PER_SECOND_AT_FULL: float = 0.35

## Extra fuel burn multiplier while afterburner is held.
const FUEL_AFTERBURNER_MULTIPLIER: float = 1.8

## Near-zero fuel; ship motion treats this as empty.
const FUEL_EMPTY_EPSILON: float = 0.001

# --- Docking fees by system policing ---------------------------------------

## Docking fee (credits) in patrolled space.
## E1.4: mild bump so dock fees stay a real credit sink.
const DOCK_FEE_PATROLLED: int = 30

## Docking fee in contested space.
const DOCK_FEE_CONTESTED: int = 18

## Docking fee in lawless space (cheaper, riskier).
const DOCK_FEE_LAWLESS: int = 5

## Default fee when policing is unknown.
const DOCK_FEE_DEFAULT: int = 18

# --- E1.5 enforcement lite (standing surcharge / service friction) ---------
# Applied from station controller standing via StandingService.tier_for only.
# No new tiers or standing math — docs/reputation_and_standing.md is law.

## Dock fee multiplier when controller standing is Neutral or better.
const DOCK_FEE_STANDING_MULT_DEFAULT: float = 1.0

## Dock fee multiplier at Unfriendly (controller).
const DOCK_FEE_STANDING_MULT_UNFRIENDLY: float = 1.5

## Dock fee multiplier at Hostile (controller).
const DOCK_FEE_STANDING_MULT_HOSTILE: float = 2.0

## Dock fee multiplier at Hated (controller) — worse than Hostile.
const DOCK_FEE_STANDING_MULT_HATED: float = 2.5

## Refuel/repair cost multiplier when Neutral or better.
const SERVICE_COST_MULT_DEFAULT: float = 1.0

## Refuel/repair cost multiplier at Unfriendly (controller).
const SERVICE_COST_MULT_UNFRIENDLY: float = 1.35

## Refuel cost multiplier at Hostile (repair is refused at Hostile+).
const SERVICE_COST_MULT_HOSTILE: float = 2.0

## Refuel cost multiplier at Hated (repair refused; leave-path fuel only).
const SERVICE_COST_MULT_HATED: float = 2.5

# --- Station services ------------------------------------------------------

## Credits per fuel unit when refueling.
## E1.4: slight raise — fuel remains a real money pressure without trapping the player.
const REFUEL_CREDITS_PER_UNIT: float = 2.5

## Minimum fuel units purchased in one refuel action (or remaining capacity).
const REFUEL_CHUNK: float = 25.0

## Full repair cost when condition is empty.
## E1.4: mild bump; full repair still affordable after a few jobs.
const REPAIR_FULL_COST: int = 100

## Ship condition range.
const CONDITION_MAX: float = 100.0
const CONDITION_MIN: float = 0.0

## Starting ship condition.
const STARTING_CONDITION: float = 100.0

## Condition lost per second while afterburning.
const CONDITION_WEAR_PER_SECOND_AFTERBURN: float = 0.4

## Speed multiplier when condition is at minimum (still flyable).
const CONDITION_MIN_SPEED_FACTOR: float = 0.55

# --- Jump / gate -----------------------------------------------------------

## Fuel cost to jump through a gate.
const JUMP_FUEL_COST: float = 12.0

## Distance at which the HUD shows a jump prompt (metres).
const GATE_APPROACH_RADIUS: float = 90.0

## Distance at which the jump action is accepted (metres).
const GATE_INTERACT_RADIUS: float = 45.0

## Where the ship appears after a jump (relative to destination gate).
const JUMP_ARRIVAL_OFFSET: Vector3 = Vector3(0.0, 8.0, 70.0)

## Angular step (degrees) between multiple gate markers around GATE_POSITION.
const GATE_ARC_STEP_DEGREES: float = 40.0

## Radius of the gate placement arc (metres from GATE_POSITION).
const GATE_ARC_RADIUS: float = 30.0

# --- Mission pay defaults --------------------------------------------------

## Credits paid on mission complete when ContractType does not override.
const MISSION_PAY_DEFAULT: int = 120

## Credits paid on recovery step complete (personal work stipend).
const RECOVERY_STEP_PAY: int = 40

# --- Cargo / trade (B3) ----------------------------------------------------

## Content category directory for commodities.
const COMMODITY_CONTENT_CATEGORY: StringName = &"commodities"

## Hold capacity in volume units (sum of unit_volume * qty).
const CARGO_CAPACITY: int = 20

## Default trade button quantity.
const TRADE_QTY_UNIT: int = 1

## Trade sides for on_trade_completed.
const TRADE_SIDE_BUY: StringName = &"buy"
const TRADE_SIDE_SELL: StringName = &"sell"

## Global sell multiplier (1.0 = base sell price). Layered under system modifiers.
const STATION_SELL_BONUS: float = 1.0

## Default buy/sell multiplier when a system has no row for a commodity.
const TRADE_PRICE_MUL_DEFAULT: float = 1.0

## Floor for resolved unit prices after modifiers (credits).
const TRADE_PRICE_MIN: int = 1

## Per-system buy multipliers: system_id → { commodity_id → float mul on base_buy }.
## Static contrast only — not a dynamic economy (E1.4).
##
## Documented profitable player routes (buy_at_source < sell_at_dest):
##   1) Grain Alpha → Gamma   (staple out to the fringe)
##   2) Scrap Gamma → Alpha   (salvage / industrial reverse)
##   3) Ore Gamma → Alpha     (raw ore into industry)
##   4) Luxuries Alpha → Gamma (wealth goods outward)
##   5) Munitions Beta → Gamma (arms from contested docks to lawless)
##   6) Rations Alpha → Beta  (packaged food into contested space)
## Same-station round-trips still lose (sell < buy at one dock).
const TRADE_SYSTEM_BUY_MUL: Dictionary = {
	&"system_alpha":
	{
		&"commodity_grain": 0.8,
		&"commodity_rations": 0.8,
		&"commodity_luxuries": 0.85,
		&"commodity_scrap": 1.15,
		&"commodity_ore": 1.2,
		&"commodity_munitions": 1.1,
	},
	&"system_beta":
	{
		&"commodity_alloy": 0.85,
		&"commodity_munitions": 0.8,
		&"commodity_spare_parts": 0.9,
		&"commodity_fuel_cells": 0.9,
		&"commodity_medical": 1.15,
		&"commodity_grain": 1.05,
	},
	&"system_gamma":
	{
		&"commodity_scrap": 0.7,
		&"commodity_ore": 0.75,
		&"commodity_grain": 1.25,
		&"commodity_luxuries": 1.2,
		&"commodity_medical": 1.15,
		&"commodity_munitions": 1.15,
	},
}

## Per-system sell multipliers: system_id → { commodity_id → float mul on base_sell }.
## Mirrors the buy table so the six documented routes stay profitable.
const TRADE_SYSTEM_SELL_MUL: Dictionary = {
	&"system_alpha":
	{
		&"commodity_grain": 0.8,
		&"commodity_luxuries": 0.9,
		&"commodity_scrap": 1.7,
		&"commodity_ore": 1.55,
		&"commodity_munitions": 1.1,
	},
	&"system_beta":
	{
		&"commodity_grain": 1.2,
		&"commodity_fuel_cells": 1.25,
		&"commodity_spare_parts": 1.2,
		&"commodity_rations": 1.5,
		&"commodity_medical": 1.1,
		&"commodity_munitions": 0.95,
	},
	&"system_gamma":
	{
		&"commodity_grain": 2.0,
		&"commodity_medical": 1.5,
		&"commodity_luxuries": 1.55,
		&"commodity_munitions": 1.55,
		&"commodity_scrap": 0.85,
		&"commodity_ore": 0.85,
	},
}

# --- Save (optional sections, schema v1) -----------------------------------

const SAVE_SECTION_KEY: StringName = &"wallet"
const SAVE_KEY_CREDITS: StringName = &"credits"
const SAVE_KEY_FUEL: StringName = &"fuel"
const SAVE_KEY_CONDITION: StringName = &"condition"

## Optional cargo section key (inventory map is the section body).
const SAVE_SECTION_CARGO: StringName = &"cargo"

# --- NPC traffic -----------------------------------------------------------

## NPC ship count for patrolled systems.
const NPC_COUNT_PATROLLED: int = 6

## NPC ship count for contested systems.
const NPC_COUNT_CONTESTED: int = 4

## NPC ship count for lawless systems.
const NPC_COUNT_LAWLESS: int = 2

## Orbit radius range for NPC wander (metres from system origin).
const NPC_ORBIT_MIN: float = 80.0
const NPC_ORBIT_MAX: float = 280.0

## NPC wander speed (m/s).
const NPC_SPEED: float = 12.0

## NPC mesh size.
const NPC_MESH_SIZE: Vector3 = Vector3(2.0, 0.7, 3.8)

## NPC colour by policing (unshaded).
const NPC_COLOR_PATROLLED: Color = Color(0.35, 0.55, 0.85)
const NPC_COLOR_CONTESTED: Color = Color(0.75, 0.55, 0.25)
const NPC_COLOR_LAWLESS: Color = Color(0.55, 0.35, 0.35)
const NPC_COLOR_DEFAULT: Color = Color(0.5, 0.5, 0.55)

## Vertical spread for NPC orbits.
const NPC_HEIGHT_SPREAD: float = 20.0

## Angular speed base (radians per second) for orbiting NPCs.
const NPC_ORBIT_OMEGA: float = 0.08

## Extra omega spread factor across the NPC ring (t * this).
const NPC_ORBIT_OMEGA_SPREAD: float = 0.5

## Parity divisor for reversing every other NPC orbit.
const NPC_ORBIT_REVERSE_EVERY: int = 2

## Mid-index half factor for multi-gate arc centering.
const GATE_ARC_MID_HALF: float = 0.5

# --- HUD / station copy ----------------------------------------------------

const HUD_LINE_CREDITS: float = 4.0
const HUD_LINE_FUEL: float = 5.0
const HUD_LINE_MISSION: float = 6.0

const HUD_CREDITS_FORMAT: String = "CREDITS  %d"
const HUD_FUEL_FORMAT: String = "FUEL  %d%%"
const HUD_CONDITION_FORMAT: String = "HULL  %d%%"

## Jump prompt when in range and fuel is enough.
const JUMP_PROMPT_FORMAT: String = "PRESS F TO JUMP — %s"

## Jump prompt when fuel is too low.
const JUMP_PROMPT_NO_FUEL_FORMAT: String = "JUMP BLOCKED — need %s fuel for %s"

# --- Nav panel (B0 discoverable gates without console) ---------------------

## HUD line slots for nav block (right column; floats below title block).
const HUD_LINE_NAV_TITLE: float = 0.0
const HUD_LINE_NAV_HERE: float = 1.0
const HUD_LINE_NAV_GATES: float = 2.0

## Right-edge margin for the nav column.
const NAV_PANEL_RIGHT_MARGIN: float = 18.0

## Max gate lines listed on the HUD nav panel.
const NAV_MAX_GATE_LINES: int = 4

const NAV_TITLE_TEXT: String = "NAV"
const NAV_HERE_FORMAT: String = "HERE  %s"
const NAV_GATES_HEADER: String = "GATES"
const NAV_GATE_LINE_FORMAT: String = "→ %s"
const NAV_NO_GATES: String = "→ (none)"
const GATE_WORLD_LABEL_FORMAT: String = "GATE → %s"

## NPC capsule silhouette (distinct from station/gate/player).
const NPC_CAPSULE_RADIUS_FACTOR: float = 0.45
const NPC_MESH_PITCH_DEGREES: float = 90.0
const NPC_CAPSULE_RADIAL_SEGMENTS: int = 8

## Small dorsal fin / box so traffic ≠ hostile at a glance (E1.1).
const NPC_FIN_SIZE: Vector3 = Vector3(0.35, 1.1, 1.4)
const NPC_FIN_OFFSET: Vector3 = Vector3(0.0, 0.85, 0.15)
const NPC_FIN_LIGHTEN: float = 0.2

## Station service button labels.
const STATION_REFUEL_LABEL: String = "Refuel"
const STATION_REFUEL_MARKUP_LABEL: String = "Refuel (standing markup)"
const STATION_REPAIR_LABEL: String = "Repair ship"
## Repair button when Hostile/Hated with controller (still docked via recovery).
const STATION_REPAIR_DENIED_LABEL: String = "Repair refused — standing"
## Trade section banner when Hostile/Hated with controller.
const STATION_TRADE_DENIED_MESSAGE: String = "Trade closed — standing too low"
## Dock fee readout while docked (base rate for this system + standing mult).
const STATION_DOCK_FEE_FORMAT: String = "Dock fee here: %d credits"
const STATION_DOCK_FEE_SURCHARGE_FORMAT: String = "Dock fee here: %d credits (standing surcharge)"
const STATION_TURN_IN_JOB_LABEL: String = "Turn in job"
const STATION_ABANDON_JOB_LABEL: String = "Abandon job"
const STATION_COMPLETE_RECOVERY_LABEL: String = "Complete recovery work"
const STATION_ABANDON_RECOVERY_LABEL: String = "Abandon recovery work"
const STATION_ASK_FAVOR_FORMAT: String = "Ask favor of %s"
const STATION_BETRAY_FORMAT: String = "Betray %s"
const STATION_UNDOCK_LABEL: String = "Undock"

## Station menu job turn-in feedback (no silent no-ops).
const STATION_TURN_IN_OK_FORMAT: String = "Job complete. +%d credits."
const STATION_TURN_IN_WRONG_STATION_FORMAT: String = "Deliver to %s first."
const STATION_TURN_IN_NO_JOB: String = "No active job to turn in."
const STATION_TURN_IN_FAILED: String = "Could not turn in job here."

## Station menu section headers (B3 / B5 drama).
const STATION_SECTION_JOBS: String = "Jobs"
const STATION_SECTION_SERVICES: String = "Services"
const STATION_SECTION_TRADE: String = "Trade"
const STATION_SECTION_CONTACTS: String = "Contacts"
## Contacts row: display name + rank (E1.2 density — people used on board).
const STATION_CONTACT_LINE_FORMAT: String = "%s — %s"
## Shown instead of Contacts when local controller standing is sticky-deep.
const STATION_SECTION_RECOVERY_DRAMA: String = "Recovery foothold"
## Hint under recovery header — %s = person display name.
const STATION_RECOVERY_DRAMA_HINT_FORMAT: String = (
	"%s still deals under the table. " + "Ask a favor, then take their work."
)

## Trade row copy.
const STATION_TRADE_BUY_LABEL: String = "Buy 1"
const STATION_TRADE_SELL_LABEL: String = "Sell 1"
const STATION_TRADE_LINE_FORMAT: String = "%s  buy %d  sell %d  hold %d"

## Station menu size for A5 service buttons (kept for older references).
const STATION_MENU_HEIGHT_A5: float = 420.0
const STATION_MENU_HALF_HEIGHT_A5: float = 210.0

## Station menu size for B3 sections + trade list.
## Height uses viewport anchors so Undock stays on screen; body scrolls.
const STATION_MENU_WIDTH_B3: float = 440.0
const STATION_MENU_HALF_WIDTH_B3: float = 220.0
## Horizontal center anchor (0.5 = middle of viewport).
const STATION_MENU_ANCHOR_CENTER: float = 0.5
## Top / bottom anchors (fraction of viewport) for the station panel.
const STATION_MENU_ANCHOR_TOP: float = 0.05
const STATION_MENU_ANCHOR_BOTTOM: float = 0.95
## Minimum body scroll height so trade list is usable on small windows.
const STATION_MENU_SCROLL_MIN_HEIGHT: float = 220.0
## Both side content margins when sizing the undock footer button width.
const STATION_MENU_SIDE_MARGINS: float = 2.0
## Kept for older size references / tests that only need a panel present.
const STATION_MENU_HEIGHT_B3: float = 640.0
const STATION_MENU_HALF_HEIGHT_B3: float = 320.0
const STATION_MENU_SCROLL_HEIGHT: float = 460.0
const STATION_TRADE_BUTTON_WIDTH: float = 72.0
const STATION_SECTION_SPACER: float = 6.0
const STATION_UNDOCK_SPACER: float = 10.0

# --- Console ---------------------------------------------------------------

const CREDITS_COMMAND: StringName = &"credits"
const CONSOLE_CREDITS_SET_ARGS: int = 2
const CONSOLE_CREDITS_SHOW_ARGS: int = 1
const CONSOLE_CREDITS_VALUE_INDEX: int = 1
const CONSOLE_CREDITS_SHOW_FORMAT: String = "Credits: %d  Fuel: %s  Hull: %s"
const CONSOLE_CREDITS_SET_FORMAT: String = "Credits set to %d."

const CARGO_COMMAND: StringName = &"cargo"
const CONSOLE_CARGO_EMPTY: String = "Cargo empty (%d/%d free volume)."
const CONSOLE_CARGO_LINE_FORMAT: String = "  %s  x%d  (vol %d)"
const CONSOLE_CARGO_HEADER_FORMAT: String = "Cargo %d/%d:"

## Percent scale for fuel/hull console and HUD (0..1 → 0..100).
const PERCENT_SCALE: float = 100.0

## Refuel cost rounding ceiling uses this unit floor when credits are partial.
const REFUEL_MIN_UNITS: float = 0.01

# --- Trade price resolution (B5 system contrast) ---------------------------


## Dock fee standing multiplier for a display tier id (StandingService.tier_for).
static func dock_fee_mult_for_tier(tier: StringName) -> float:
	if tier == BalanceStanding.TIER_UNFRIENDLY:
		return DOCK_FEE_STANDING_MULT_UNFRIENDLY
	if tier == BalanceStanding.TIER_HOSTILE:
		return DOCK_FEE_STANDING_MULT_HOSTILE
	if tier == BalanceStanding.TIER_HATED:
		return DOCK_FEE_STANDING_MULT_HATED
	return DOCK_FEE_STANDING_MULT_DEFAULT


## Station service cost multiplier (refuel always; repair only when allowed).
static func service_cost_mult_for_tier(tier: StringName) -> float:
	if tier == BalanceStanding.TIER_UNFRIENDLY:
		return SERVICE_COST_MULT_UNFRIENDLY
	if tier == BalanceStanding.TIER_HOSTILE:
		return SERVICE_COST_MULT_HOSTILE
	if tier == BalanceStanding.TIER_HATED:
		return SERVICE_COST_MULT_HATED
	return SERVICE_COST_MULT_DEFAULT


## True when repair is refused at this controller standing tier.
static func service_repair_denied_for_tier(tier: StringName) -> bool:
	return tier == BalanceStanding.TIER_HOSTILE or tier == BalanceStanding.TIER_HATED


## True when buy/sell is refused at this controller standing tier.
static func trade_denied_for_tier(tier: StringName) -> bool:
	return service_repair_denied_for_tier(tier)


## Buy multiplier for a commodity in a system (1.0 when unlisted).
static func trade_buy_mul(system_id: StringName, commodity_id: StringName) -> float:
	return _trade_mul_from(TRADE_SYSTEM_BUY_MUL, system_id, commodity_id)


## Sell multiplier for a commodity in a system (1.0 when unlisted).
static func trade_sell_mul(system_id: StringName, commodity_id: StringName) -> float:
	return _trade_mul_from(TRADE_SYSTEM_SELL_MUL, system_id, commodity_id)


## Credits to buy one unit at this system (min TRADE_PRICE_MIN).
static func buy_price_at(commodity: Commodity, system_id: StringName) -> int:
	if commodity == null:
		return TRADE_PRICE_MIN
	var mul: float = trade_buy_mul(system_id, commodity.id)
	var base: float = float(commodity.base_buy_price)
	return maxi(TRADE_PRICE_MIN, int(roundf(base * mul)))


## Credits paid for selling one unit at this system (min TRADE_PRICE_MIN).
static func sell_price_at(commodity: Commodity, system_id: StringName) -> int:
	if commodity == null:
		return TRADE_PRICE_MIN
	var mul: float = trade_sell_mul(system_id, commodity.id) * STATION_SELL_BONUS
	var base: float = float(commodity.base_sell_price)
	return maxi(TRADE_PRICE_MIN, int(roundf(base * mul)))


static func _trade_mul_from(
	table: Dictionary, system_id: StringName, commodity_id: StringName
) -> float:
	if String(system_id).is_empty() or String(commodity_id).is_empty():
		return TRADE_PRICE_MUL_DEFAULT
	if not table.has(system_id):
		return TRADE_PRICE_MUL_DEFAULT
	var row_raw: Variant = table[system_id]
	if typeof(row_raw) != TYPE_DICTIONARY:
		return TRADE_PRICE_MUL_DEFAULT
	var row: Dictionary = row_raw
	if not row.has(commodity_id):
		return TRADE_PRICE_MUL_DEFAULT
	var mul_raw: Variant = row[commodity_id]
	if typeof(mul_raw) == TYPE_FLOAT:
		var as_float: float = mul_raw
		return as_float
	if typeof(mul_raw) == TYPE_INT:
		var as_int: int = mul_raw
		return float(as_int)
	return TRADE_PRICE_MUL_DEFAULT
