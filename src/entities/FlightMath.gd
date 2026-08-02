class_name FlightMath
extends RefCounted

## Pure flight helpers — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## No nodes, no input, no side effects. Unit-tested directly.


## Clamps throttle into the legal 0..1 band.
static func clamp_throttle(throttle: float) -> float:
	return clampf(throttle, BalanceFlight.THROTTLE_MIN, BalanceFlight.THROTTLE_MAX)


## Max speed with afterburner applied when active.
static func max_speed_with_afterburner(
	base_max_speed: float, afterburner_multiplier: float, afterburning: bool
) -> float:
	if afterburning:
		return base_max_speed * afterburner_multiplier
	return base_max_speed


## New forward direction after turning at most `turn_rate * delta` toward target.
##
## Returns a unit vector. Empty inputs fall back to the current forward (or
## -Z if that is also empty) so callers never get NaN basis axes.
static func turn_toward(
	current_forward: Vector3, target_direction: Vector3, turn_rate: float, delta: float
) -> Vector3:
	var from: Vector3 = current_forward
	if from.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		from = Vector3(0.0, 0.0, -1.0)
	else:
		from = from.normalized()

	var to: Vector3 = target_direction
	if to.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		return from
	to = to.normalized()

	var angle: float = from.angle_to(to)
	if angle <= BalanceFlight.TURN_ANGLE_EPSILON:
		return to

	var max_step: float = turn_rate * delta
	if angle <= max_step:
		return to

	var weight: float = max_step / angle
	return from.slerp(to, weight).normalized()


## Desired velocity from throttle, facing, strafe, and afterburner.
static func desired_velocity(
	forward: Vector3,
	right: Vector3,
	throttle: float,
	strafe_axis: float,
	base_max_speed: float,
	strafe_speed: float,
	afterburner_multiplier: float,
	afterburning: bool
) -> Vector3:
	var capped_throttle: float = clamp_throttle(throttle)
	var max_speed: float = max_speed_with_afterburner(
		base_max_speed, afterburner_multiplier, afterburning
	)
	var along: Vector3 = forward.normalized() * (capped_throttle * max_speed)
	var lateral: Vector3 = right.normalized() * (strafe_axis * strafe_speed)
	return along + lateral


## Integrate velocity toward desired with accel and drag.
static func integrate_velocity(
	current: Vector3, desired: Vector3, acceleration: float, drag: float, delta: float
) -> Vector3:
	var to_desired: Vector3 = desired - current
	var step: float = acceleration * delta
	if to_desired.length() <= step:
		var arrived: Vector3 = desired
		if drag > 0.0 and desired.length_squared() < BalanceFlight.DIRECTION_EPSILON:
			var damp: float = exp(-drag * delta)
			return current * damp
		return arrived
	var moved: Vector3 = current + to_desired.normalized() * step
	if drag > 0.0 and desired.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		var bleed: float = exp(-drag * delta)
		return moved * bleed
	return moved


## Lead intercept so a bolt at `shot_speed` meets a moving target.
## Re-exports BalanceCombat.lead_point (data layer is the single solver body —
## ui/world may not call into entities).
static func lead_point(
	shooter_pos: Vector3, target_pos: Vector3, target_vel: Vector3, shot_speed: float
) -> Vector3:
	return BalanceCombat.lead_point(shooter_pos, target_pos, target_vel, shot_speed)


## Soft bump re-export (body lives on BalanceFlight so world may call it too).
static func apply_soft_bump(
	velocity: Vector3, normal: Vector3, restitution: float = -1.0
) -> Vector3:
	return BalanceFlight.apply_soft_bump(velocity, normal, restitution)
