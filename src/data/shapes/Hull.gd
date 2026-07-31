class_name Hull
extends ContentItem

## A flyable ship profile as data — full-sized Alpha shape, one A1 courier.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Numbers live on the resource so content is data. Defaults mirror
## `BalanceFlight` courier tunables; the `.tres` is free to diverge later.

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

	return problems
