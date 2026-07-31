extends GutTest

## Station and Hull content shapes — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1


func test_station_requires_system_and_controller() -> void:
	var station: Station = Station.new()
	station.id = &"fixture_station"
	station.display_name = "Fixture"
	var problems: PackedStringArray = station.validation_errors()
	assert_gt(problems.size(), 0)
	assert_string_contains("\n".join(problems), "system_id")

	station.system_id = &"system_alpha"
	station.controller_entity_id = Station.CONTROLLER_NOBODY
	assert_eq(station.validation_errors().size(), 0)


func test_hull_rejects_non_positive_profile() -> void:
	var hull: Hull = Hull.new()
	hull.id = &"fixture_hull"
	hull.display_name = "Fixture"
	var problems: PackedStringArray = hull.validation_errors()
	assert_gt(problems.size(), 0)

	hull.max_speed = BalanceFlight.SHIP_MAX_SPEED
	hull.acceleration = BalanceFlight.SHIP_ACCELERATION
	hull.turn_rate = BalanceFlight.SHIP_TURN_RATE
	hull.strafe_speed = BalanceFlight.SHIP_STRAFE_SPEED
	hull.afterburner_multiplier = BalanceFlight.SHIP_AFTERBURNER_MULTIPLIER
	hull.drag = BalanceFlight.SHIP_DRAG
	assert_eq(hull.validation_errors().size(), 0)


func test_hull_rejects_afterburner_below_one() -> void:
	var hull: Hull = Hull.new()
	hull.id = &"fixture_hull_ab"
	hull.display_name = "Fixture"
	hull.max_speed = 10.0
	hull.acceleration = 10.0
	hull.turn_rate = 1.0
	hull.strafe_speed = 5.0
	hull.afterburner_multiplier = 0.5
	hull.drag = 1.0
	var joined: String = "\n".join(hull.validation_errors())
	assert_string_contains(joined, "afterburner_multiplier")
