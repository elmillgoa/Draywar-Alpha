class_name Hull
extends ContentItem

## A flyable ship profile as data — full-sized shape, thin content count.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1, docs/BETA_E2_COMBAT_HULL.md E2.4
##
## Numbers live on the resource so content is data. Defaults mirror
## `BalanceFlight` / `BalanceCombat` courier (Hauler) tunables; the `.tres`
## is free to diverge. Role tags separate cargo/endurance hulls from fighters.

## Role tags (Destination §6 interlock: Hauler vs Fighter).
const ROLE_HAULER: StringName = &"hauler"
const ROLE_FIGHTER: StringName = &"fighter"

## Maximum forward speed at full throttle without afterburner (m/s).
@export var max_speed: float = 0.0

## How fast the ship closes on its desired velocity (m/s^2).
@export var acceleration: float = 0.0

## Maximum turn rate while aiming (radians per second).
@export var turn_rate: float = 0.0

## Lateral strafe speed at full strafe input (m/s).
@export var strafe_speed: float = 0.0

## Multiplier applied to max speed while afterburner is held.
@export var afterburner_multiplier: float = 0.0

## Exponential velocity bleed factor (1/s).
@export var drag: float = 0.0

## Hold capacity in volume units (sum of commodity unit_volume * qty).
@export var cargo_capacity: int = 0

## Damage applied by one player bolt from this hull.
@export var weapon_damage: float = 0.0

## Seconds between player shots on this hull.
@export var weapon_cooldown: float = 0.0

## Player bolt travel speed (m/s) for this hull.
@export var projectile_speed: float = 0.0

## Play role: `hauler` (cargo/endurance) or `fighter` (combat).
@export var role: StringName = &""


## Everything wrong with this hull. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if max_speed <= 0.0:
		problems.append("`max_speed` must be greater than zero.")
	if acceleration <= 0.0:
		problems.append("`acceleration` must be greater than zero.")
	if turn_rate <= 0.0:
		problems.append("`turn_rate` must be greater than zero.")
	if strafe_speed < 0.0:
		problems.append("`strafe_speed` must not be negative.")
	if afterburner_multiplier < 1.0:
		problems.append(
			(
				"`afterburner_multiplier` must be at least 1.0 "
				+ "(1.0 means afterburner does not boost)."
			)
		)
	if drag < 0.0:
		problems.append("`drag` must not be negative.")

	if cargo_capacity < 0:
		problems.append("`cargo_capacity` must not be negative.")
	if weapon_damage <= 0.0:
		problems.append("`weapon_damage` must be greater than zero.")
	if weapon_cooldown <= 0.0:
		problems.append("`weapon_cooldown` must be greater than zero.")
	if projectile_speed <= 0.0:
		problems.append("`projectile_speed` must be greater than zero.")

	if role != ROLE_HAULER and role != ROLE_FIGHTER:
		problems.append(
			(
				"`role` must be '%s' or '%s' (got '%s')."
				% [String(ROLE_HAULER), String(ROLE_FIGHTER), String(role)]
			)
		)
	elif role == ROLE_HAULER and cargo_capacity <= 0:
		problems.append("`cargo_capacity` must be greater than zero for hauler role.")

	return problems
