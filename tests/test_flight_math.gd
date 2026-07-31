extends GutTest

## Pure flight math — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1

const TOLERANCE: float = 0.0001


func test_clamp_throttle_holds_the_legal_band() -> void:
	assert_eq(FlightMath.clamp_throttle(-1.0), BalanceFlight.THROTTLE_MIN)
	assert_eq(FlightMath.clamp_throttle(0.0), 0.0)
	assert_eq(FlightMath.clamp_throttle(0.5), 0.5)
	assert_eq(FlightMath.clamp_throttle(1.0), 1.0)
	assert_eq(FlightMath.clamp_throttle(2.0), BalanceFlight.THROTTLE_MAX)


func test_afterburner_multiplies_the_speed_cap() -> void:
	var base: float = 80.0
	var mult: float = 1.75
	assert_almost_eq(FlightMath.max_speed_with_afterburner(base, mult, false), base, TOLERANCE)
	assert_almost_eq(
		FlightMath.max_speed_with_afterburner(base, mult, true), base * mult, TOLERANCE
	)


func test_turn_toward_snaps_when_within_step() -> void:
	var current: Vector3 = Vector3(0.0, 0.0, -1.0)
	var target: Vector3 = Vector3(0.0, 0.0, -1.0)
	var result: Vector3 = FlightMath.turn_toward(current, target, 2.0, 1.0)
	assert_almost_eq(result.x, 0.0, TOLERANCE)
	assert_almost_eq(result.z, -1.0, TOLERANCE)


func test_turn_toward_moves_partway_when_angle_exceeds_step() -> void:
	var current: Vector3 = Vector3(0.0, 0.0, -1.0)
	var target: Vector3 = Vector3(1.0, 0.0, 0.0)
	var slow: Vector3 = FlightMath.turn_toward(current, target, 0.1, 0.1)
	# Slow turn should not reach the full rightward facing in one tiny step.
	assert_lt(slow.x, 0.5)
	assert_gt(slow.x, 0.0)
	var fast: Vector3 = FlightMath.turn_toward(current, target, 10.0, 1.0)
	assert_almost_eq(fast.x, 1.0, 0.01)
	assert_almost_eq(fast.z, 0.0, 0.01)


func test_desired_velocity_uses_throttle_strafe_and_afterburner() -> void:
	var forward: Vector3 = Vector3(0.0, 0.0, -1.0)
	var right: Vector3 = Vector3(1.0, 0.0, 0.0)
	var without: Vector3 = FlightMath.desired_velocity(
		forward, right, 1.0, 0.0, 80.0, 28.0, 1.75, false
	)
	assert_almost_eq(without.z, -80.0, TOLERANCE)
	var with_ab: Vector3 = FlightMath.desired_velocity(
		forward, right, 1.0, 0.0, 80.0, 28.0, 1.75, true
	)
	assert_almost_eq(with_ab.z, -80.0 * 1.75, TOLERANCE)
	var strafe: Vector3 = FlightMath.desired_velocity(
		forward, right, 0.0, 1.0, 80.0, 28.0, 1.75, false
	)
	assert_almost_eq(strafe.x, 28.0, TOLERANCE)


func test_integrate_velocity_approaches_desired() -> void:
	var current: Vector3 = Vector3.ZERO
	var desired: Vector3 = Vector3(0.0, 0.0, -40.0)
	var next: Vector3 = FlightMath.integrate_velocity(current, desired, 45.0, 1.8, 0.5)
	assert_lt(next.z, 0.0)
	assert_gt(next.z, desired.z)
