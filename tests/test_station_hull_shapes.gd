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
	# S2: a station also declares an economic identity and trades something.
	station.economy_role = BalanceMarket.ROLE_TRADE_HUB
	station.stock_targets = {&"commodity_grain": 100.0}
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
	hull.cargo_capacity = BalanceEconomy.CARGO_CAPACITY
	hull.weapon_damage = BalanceCombat.PLAYER_WEAPON_DAMAGE
	hull.weapon_cooldown = BalanceCombat.PLAYER_FIRE_COOLDOWN
	hull.projectile_speed = BalanceCombat.PROJECTILE_SPEED
	hull.role = Hull.ROLE_HAULER
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
	hull.cargo_capacity = BalanceEconomy.CARGO_CAPACITY
	hull.weapon_damage = BalanceCombat.PLAYER_WEAPON_DAMAGE
	hull.weapon_cooldown = BalanceCombat.PLAYER_FIRE_COOLDOWN
	hull.projectile_speed = BalanceCombat.PROJECTILE_SPEED
	hull.role = Hull.ROLE_HAULER
	var joined: String = "\n".join(hull.validation_errors())
	assert_string_contains(joined, "afterburner_multiplier")


func test_hull_fighter_role_may_have_zero_cargo() -> void:
	var hull: Hull = Hull.new()
	hull.id = &"fixture_fighter_shape"
	hull.display_name = "Fixture Fighter"
	hull.max_speed = BalanceFlight.SHIP_MAX_SPEED
	hull.acceleration = BalanceFlight.SHIP_ACCELERATION
	hull.turn_rate = BalanceFlight.SHIP_TURN_RATE
	hull.strafe_speed = BalanceFlight.SHIP_STRAFE_SPEED
	hull.afterburner_multiplier = BalanceFlight.SHIP_AFTERBURNER_MULTIPLIER
	hull.drag = BalanceFlight.SHIP_DRAG
	hull.cargo_capacity = 0
	hull.weapon_damage = BalanceCombat.FIGHTER_BASELINE_WEAPON_DAMAGE
	hull.weapon_cooldown = BalanceCombat.FIGHTER_BASELINE_WEAPON_COOLDOWN
	hull.projectile_speed = BalanceCombat.FIGHTER_BASELINE_PROJECTILE_SPEED
	hull.role = Hull.ROLE_FIGHTER
	assert_eq(hull.validation_errors().size(), 0)
