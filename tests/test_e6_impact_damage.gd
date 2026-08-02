extends GutTest

## E6.1 impact damage — mass class × speed, threshold bump-only.
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.1

const TOLERANCE: float = 0.0001
const CLOSING_FAST: float = 28.0
const CLOSING_SLOW: float = 4.0


func test_mass_factor_station_exceeds_traffic_light() -> void:
	assert_gt(
		BalanceCombat.mass_factor(BalanceCombat.MASS_CLASS_STATION),
		BalanceCombat.mass_factor(BalanceCombat.MASS_CLASS_TRAFFIC_LIGHT)
	)


func test_same_speed_station_damages_more_than_traffic_light() -> void:
	var vs_station: float = BalanceCombat.impact_damage(
		BalanceCombat.MASS_CLASS_STATION, CLOSING_FAST
	)
	var vs_traffic: float = BalanceCombat.impact_damage(
		BalanceCombat.MASS_CLASS_TRAFFIC_LIGHT, CLOSING_FAST
	)
	assert_gt(vs_station, 0.0, "station impact above threshold deals damage")
	assert_gt(vs_traffic, 0.0, "traffic impact above threshold deals damage")
	assert_gt(vs_station, vs_traffic, "same closing speed: station > traffic_light damage")


func test_below_threshold_is_bump_only() -> void:
	assert_eq(BalanceCombat.speed_factor(CLOSING_SLOW), 0.0)
	assert_eq(
		BalanceCombat.impact_damage(BalanceCombat.MASS_CLASS_STATION, CLOSING_SLOW),
		0.0,
		"below IMPACT_SPEED_THRESHOLD → no hull damage"
	)
	assert_eq(BalanceCombat.impact_damage(BalanceCombat.MASS_CLASS_HOSTILE, CLOSING_SLOW), 0.0)


func test_above_threshold_scales_with_speed() -> void:
	var slowish: float = BalanceCombat.IMPACT_SPEED_THRESHOLD + 2.0
	var faster: float = BalanceCombat.IMPACT_SPEED_THRESHOLD + 12.0
	var d_slow: float = BalanceCombat.impact_damage(BalanceCombat.MASS_CLASS_GATE, slowish)
	var d_fast: float = BalanceCombat.impact_damage(BalanceCombat.MASS_CLASS_GATE, faster)
	assert_gt(d_slow, 0.0)
	assert_gt(d_fast, d_slow)


func test_impact_formula_matches_balance_parts() -> void:
	var closing: float = 28.0
	var expected: float = (
		BalanceCombat.IMPACT_BASE
		* BalanceCombat.mass_factor(BalanceCombat.MASS_CLASS_STATION)
		* BalanceCombat.speed_factor(closing)
	)
	assert_almost_eq(
		BalanceCombat.impact_damage(BalanceCombat.MASS_CLASS_STATION, closing), expected, TOLERANCE
	)


func test_wallet_apply_via_impact_helper() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	await get_tree().process_frame
	wallet.reset()
	var before: float = wallet.condition()
	var dmg: float = BalanceCombat.impact_damage(BalanceCombat.MASS_CLASS_STATION, CLOSING_FAST)
	assert_gt(dmg, 0.0)
	wallet.apply_damage(dmg)
	assert_lt(wallet.condition(), before)
	assert_almost_eq(wallet.condition(), before - dmg, TOLERANCE)


func test_live_player_impact_damages_hull_via_ship_path() -> void:
	# Exercises PlayerShip._resolve_soft_bumps_and_impact with pre-slide velocity
	# so post-slide zeroing cannot hide a dead impact path.
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	await get_tree().process_frame
	wallet.reset()
	var before: float = wallet.condition()

	var station: StaticBody3D = StaticBody3D.new()
	station.collision_layer = BalanceFlight.PHYSICS_LAYER_STATICS
	station.collision_mask = 0
	station.set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_STATION)
	station.position = Vector3.ZERO
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 20.0, 4.0)
	shape_node.shape = box
	station.add_child(shape_node)
	space.add_child(station)

	var ship: PlayerShip = PlayerShip.new()
	ship.set_flight_enabled(false)
	space.add_child(ship)
	ship.global_position = Vector3(0.0, 0.0, 6.0)
	# Fast enough that closing >> IMPACT_SPEED_THRESHOLD after contact.
	ship.velocity = Vector3(0.0, 0.0, -60.0)
	await get_tree().physics_frame

	var hit: bool = false
	var i: int = 0
	while i < 12:
		var pre: Vector3 = ship.velocity
		ship.move_and_slide()
		if ship.get_slide_collision_count() > 0:
			hit = true
		ship.call(&"_resolve_soft_bumps_and_impact", 0.016, pre)
		await get_tree().physics_frame
		i += 1

	assert_true(hit, "expected collision with station wall")
	assert_lt(
		wallet.condition(),
		before,
		(
			"live impact path must apply hull damage (pre-slide closing); condition was %.2f now %.2f"
			% [before, wallet.condition()]
		)
	)


func test_live_slow_bump_does_not_damage_hull() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	await get_tree().process_frame
	wallet.reset()
	var before: float = wallet.condition()

	var station: StaticBody3D = StaticBody3D.new()
	station.collision_layer = BalanceFlight.PHYSICS_LAYER_STATICS
	station.collision_mask = 0
	station.set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_STATION)
	station.position = Vector3.ZERO
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 20.0, 4.0)
	shape_node.shape = box
	station.add_child(shape_node)
	space.add_child(station)

	var ship: PlayerShip = PlayerShip.new()
	ship.set_flight_enabled(false)
	space.add_child(ship)
	ship.global_position = Vector3(0.0, 0.0, 4.0)
	# Below IMPACT_SPEED_THRESHOLD (8 m/s).
	ship.velocity = Vector3(0.0, 0.0, -4.0)
	await get_tree().physics_frame

	var i: int = 0
	while i < 10:
		var pre: Vector3 = ship.velocity
		ship.move_and_slide()
		ship.call(&"_resolve_soft_bumps_and_impact", 0.016, pre)
		# Keep slow approach so we don't accelerate via other systems.
		if ship.velocity.length() > BalanceCombat.IMPACT_SPEED_THRESHOLD:
			ship.velocity = ship.velocity.normalized() * 4.0
		await get_tree().physics_frame
		i += 1

	assert_almost_eq(wallet.condition(), before, 0.01, "below threshold = bump only")


func test_soft_bump_keeps_lateral_motion() -> void:
	# Head-on into +Z wall normal (0,0,1) with velocity that has lateral X.
	var velocity: Vector3 = Vector3(12.0, 0.0, -30.0)
	var normal: Vector3 = Vector3(0.0, 0.0, 1.0)
	var after: Vector3 = BalanceFlight.apply_soft_bump(velocity, normal, 0.0)
	assert_almost_eq(after.x, 12.0, TOLERANCE, "lateral X retained")
	assert_gte(after.z, -TOLERANCE, "into-normal cancelled (no hard push deeper)")
	assert_gt(after.length(), TOLERANCE, "must not hard-stop to zero")
	# Pure into-normal should leave ~zero when restitution is 0.
	var head_on: Vector3 = BalanceFlight.apply_soft_bump(Vector3(0.0, 0.0, -20.0), normal, 0.0)
	assert_almost_eq(head_on.z, 0.0, TOLERANCE)
	assert_almost_eq(head_on.length(), 0.0, TOLERANCE)
