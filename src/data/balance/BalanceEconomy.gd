class_name BalanceEconomy
extends RefCounted

## Money, fuel, fees, repairs, and NPC traffic tunables — Alpha A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5
##
## Wallet, fuel burn, docking fees, refuel/repair station services, mission pay
## defaults, jump fuel cost, and gray-box NPC traffic density live here.

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
const DOCK_FEE_PATROLLED: int = 25

## Docking fee in contested space.
const DOCK_FEE_CONTESTED: int = 15

## Docking fee in lawless space (cheaper, riskier).
const DOCK_FEE_LAWLESS: int = 5

## Default fee when policing is unknown.
const DOCK_FEE_DEFAULT: int = 15

# --- Station services ------------------------------------------------------

## Credits per fuel unit when refueling.
const REFUEL_CREDITS_PER_UNIT: float = 2.0

## Minimum fuel units purchased in one refuel action (or remaining capacity).
const REFUEL_CHUNK: float = 25.0

## Full repair cost when condition is empty.
const REPAIR_FULL_COST: int = 80

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

# --- Save (optional section, schema v1) ------------------------------------

const SAVE_SECTION_KEY: StringName = &"wallet"
const SAVE_KEY_CREDITS: StringName = &"credits"
const SAVE_KEY_FUEL: StringName = &"fuel"
const SAVE_KEY_CONDITION: StringName = &"condition"

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

## Station service button labels.
const STATION_REFUEL_LABEL: String = "Refuel"
const STATION_REPAIR_LABEL: String = "Repair ship"
const STATION_TURN_IN_JOB_LABEL: String = "Turn in job"
const STATION_ABANDON_JOB_LABEL: String = "Abandon job"
const STATION_COMPLETE_RECOVERY_LABEL: String = "Complete recovery work"
const STATION_ABANDON_RECOVERY_LABEL: String = "Abandon recovery work"
const STATION_ASK_FAVOR_FORMAT: String = "Ask favor of %s"
const STATION_BETRAY_FORMAT: String = "Betray %s"

## Station menu height for A5 service buttons.
const STATION_MENU_HEIGHT_A5: float = 420.0
const STATION_MENU_HALF_HEIGHT_A5: float = 210.0

# --- Console ---------------------------------------------------------------

const CREDITS_COMMAND: StringName = &"credits"
const CONSOLE_CREDITS_SET_ARGS: int = 2
const CONSOLE_CREDITS_SHOW_ARGS: int = 1
const CONSOLE_CREDITS_VALUE_INDEX: int = 1
const CONSOLE_CREDITS_SHOW_FORMAT: String = "Credits: %d  Fuel: %s  Hull: %s"
const CONSOLE_CREDITS_SET_FORMAT: String = "Credits set to %d."

## Percent scale for fuel/hull console and HUD (0..1 → 0..100).
const PERCENT_SCALE: float = 100.0

## Refuel cost rounding ceiling uses this unit floor when credits are partial.
const REFUEL_MIN_UNITS: float = 0.01
