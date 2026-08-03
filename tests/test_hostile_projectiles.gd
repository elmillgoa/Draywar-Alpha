extends GutTest

## Hostile travel bolts — Combat Fairness C2.
##
## Damage only on contact; fire spawns a bolt (no instant melt).

const HostileProjectileScript = preload("res://src/world/HostileProjectile.gd")


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func _is_hostile_bolt(node: Node) -> bool:
	if node == null or node.get_script() == null:
		return false
	var path: String = str(node.get_script().resource_path)
	return path.ends_with("HostileProjectile.gd")


func test_hostile_projectile_damages_player_once_on_contact() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var hull: HullConditionService = HullConditionService.new()
	space.add_child(hull)
	await get_tree().process_frame
	hull.reset()
	var start: float = hull.condition()

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	var bolt: Node = HostileProjectileScript.new()
	space.add_child(bolt)
	await get_tree().process_frame
	assert_true(bolt.has_method(&"try_hit"))
	bolt.call(&"try_hit", ship)
	assert_almost_eq(hull.condition(), start - BalanceCombat.HOSTILE_DAMAGE, 0.001)
	# Second call after spent must not stack.
	bolt.call(&"try_hit", ship)
	assert_almost_eq(hull.condition(), start - BalanceCombat.HOSTILE_DAMAGE, 0.001)


func test_hostile_projectile_miss_does_not_damage() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var hull: HullConditionService = HullConditionService.new()
	space.add_child(hull)
	await get_tree().process_frame
	hull.reset()
	var start: float = hull.condition()

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	var bolt: Node = HostileProjectileScript.new()
	space.add_child(bolt)
	if bolt is Node3D:
		var bolt_3d: Node3D = bolt as Node3D
		bolt_3d.global_position = Vector3(0.0, 0.0, -200.0)
	if bolt.has_method(&"launch"):
		bolt.call(&"launch", Vector3(0.0, 0.0, -1.0))
	await get_tree().process_frame
	# Fly past without contact.
	for _i: int in 30:
		if not is_instance_valid(bolt):
			break
		if bolt.has_method(&"_physics_process"):
			bolt.call(&"_physics_process", 0.05)
	assert_almost_eq(hull.condition(), start, 0.001, "far miss must not damage")


func test_hostile_fire_spawns_projectile_without_instant_damage() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var hull: HullConditionService = HullConditionService.new()
	space.add_child(hull)
	await get_tree().process_frame
	hull.reset()
	var start: float = hull.condition()

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	# Far enough that bolt will not hit in the same frame as spawn.
	ship.global_position = Vector3(0.0, 0.0, BalanceCombat.STATION_SAFE_RADIUS + 80.0)

	var hostile: HostileNpc = HostileNpc.spawn_under(
		space, ship.global_position + Vector3(0.0, 0.0, -30.0)
	)
	# Face the player and clear grace so fire is allowed.
	hostile.look_at(ship.global_position, Vector3.UP)
	hostile._undock_grace = 0.0
	hostile._player_docked = false
	await get_tree().process_frame

	var before_children: int = space.get_child_count()
	hostile._fire_at_player(ship)
	assert_almost_eq(hull.condition(), start, 0.001, "fire must not instantly reduce condition")
	assert_gt(space.get_child_count(), before_children, "hostile bolt should spawn")

	var found_bolt: bool = false
	for child: Node in space.get_children():
		if _is_hostile_bolt(child):
			found_bolt = true
			break
	assert_true(found_bolt, "HostileProjectile spawned on fire")

	# Simulated hit path still works for condition tests.
	var hit_bolt: Node = HostileProjectileScript.new()
	space.add_child(hit_bolt)
	await get_tree().process_frame
	hit_bolt.call(&"try_hit", ship)
	assert_almost_eq(hull.condition(), start - BalanceCombat.HOSTILE_DAMAGE, 0.001)


func test_hostile_lead_point_matches_stationary_target() -> void:
	var shooter: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3(0.0, 0.0, -80.0)
	var lead: Vector3 = HostileProjectileScript.lead_point(shooter, target, Vector3.ZERO, 200.0)
	assert_almost_eq(lead.x, target.x, 0.001)
	assert_almost_eq(lead.y, target.y, 0.001)
	assert_almost_eq(lead.z, target.z, 0.001)


func test_hostile_bolt_physics_overlap_damages_player() -> void:
	## Damage via Area3D contact only — test never calls try_hit.
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var hull: HullConditionService = HullConditionService.new()
	space.add_child(hull)
	await get_tree().process_frame
	hull.reset()
	var start: float = hull.condition()

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	ship.force_update_transform()
	await get_tree().physics_frame

	# Spawn bolt outside the ship so first physics step is a clean enter.
	var clear_gap: float = (
		BalanceCombat.PLAYER_HURTBOX_RADIUS
		+ (
			BalanceCombat.HOSTILE_PROJECTILE_RADIUS
			* BalanceCombat.HOSTILE_PROJECTILE_HIT_RADIUS_SCALE
		)
		+ 1.5
	)
	var bolt: HostileProjectile = HostileProjectileScript.new() as HostileProjectile
	space.add_child(bolt)
	bolt.global_position = Vector3(0.0, 0.0, -clear_gap)
	bolt.launch(Vector3(0.0, 0.0, 1.0))
	bolt.force_update_transform()
	await get_tree().physics_frame

	# Small steps from outside into the hurtbox (no try_hit from the test).
	var step_dt: float = 0.01
	for _i: int in 120:
		if not is_instance_valid(bolt):
			break
		if hull.condition() < start - 0.001:
			break
		bolt._physics_process(step_dt)
		await get_tree().physics_frame

	assert_almost_eq(
		hull.condition(),
		start - BalanceCombat.HOSTILE_DAMAGE,
		0.001,
		"physics overlap damages by HOSTILE_DAMAGE without test try_hit"
	)


func test_strafe_avoids_bolt_aimed_at_still_position() -> void:
	## Identical bolt aim at Vector3.ZERO rest position.
	## Case still: ship at origin is hit. Case strafe: ship teleported aside is not.
	var spawn_z: float = -(
		BalanceCombat.PLAYER_HURTBOX_RADIUS
		+ (
			BalanceCombat.HOSTILE_PROJECTILE_RADIUS
			* BalanceCombat.HOSTILE_PROJECTILE_HIT_RADIUS_SCALE
		)
		+ 2.0
	)
	var contact_radius: float = (
		BalanceCombat.PLAYER_HURTBOX_RADIUS
		+ (
			BalanceCombat.HOSTILE_PROJECTILE_RADIUS
			* BalanceCombat.HOSTILE_PROJECTILE_HIT_RADIUS_SCALE
		)
	)

	# --- Case still ---
	var space_a: Node3D = Node3D.new()
	add_child_autofree(space_a)
	var hull_a: HullConditionService = HullConditionService.new()
	space_a.add_child(hull_a)
	await get_tree().process_frame
	hull_a.reset()
	var start_still: float = hull_a.condition()

	var ship_a: PlayerShip = PlayerShip.new()
	ship_a.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space_a.add_child(ship_a)
	ship_a.global_position = Vector3.ZERO
	ship_a.force_update_transform()
	await get_tree().physics_frame

	var bolt_a: HostileProjectile = HostileProjectileScript.new() as HostileProjectile
	space_a.add_child(bolt_a)
	bolt_a.global_position = Vector3(0.0, 0.0, spawn_z)
	bolt_a.launch(Vector3(0.0, 0.0, 1.0))
	bolt_a.force_update_transform()
	await get_tree().physics_frame

	for _i: int in 120:
		if not is_instance_valid(bolt_a):
			break
		if hull_a.condition() < start_still - 0.001:
			break
		bolt_a._physics_process(0.01)
		await get_tree().physics_frame

	assert_almost_eq(
		hull_a.condition(),
		start_still - BalanceCombat.HOSTILE_DAMAGE,
		0.001,
		"still ship should take bolt damage"
	)

	# Hard teardown so physics space is clean for the miss case.
	ship_a.remove_from_group(BalanceSession.GROUP_PLAYER_SHIP)
	if is_instance_valid(bolt_a):
		bolt_a.queue_free()
	ship_a.queue_free()
	hull_a.queue_free()
	space_a.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	# --- Case strafe: ship never sits on the aim line ---
	var space_b: Node3D = Node3D.new()
	add_child_autofree(space_b)
	var hull_b: HullConditionService = HullConditionService.new()
	space_b.add_child(hull_b)
	await get_tree().process_frame
	hull_b.reset()
	var start_strafe: float = hull_b.condition()

	var ship_b: PlayerShip = PlayerShip.new()
	# Position before enter tree so the physics body is born off the aim line.
	ship_b.position = Vector3(50.0, 0.0, 0.0)
	ship_b.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space_b.add_child(ship_b)
	ship_b.force_update_transform()
	await get_tree().physics_frame
	assert_gt(ship_b.global_position.x, 40.0, "strafe ship must be far on +X")

	var bolt_b: HostileProjectile = HostileProjectileScript.new() as HostileProjectile
	space_b.add_child(bolt_b)
	bolt_b.global_position = Vector3(0.0, 0.0, spawn_z)
	bolt_b.launch(Vector3(0.0, 0.0, 1.0))
	bolt_b.force_update_transform()
	await get_tree().physics_frame

	var closest: float = ship_b.global_position.distance_to(bolt_b.global_position)
	for _i: int in 120:
		if not is_instance_valid(bolt_b):
			break
		bolt_b._physics_process(0.01)
		await get_tree().physics_frame
		if is_instance_valid(bolt_b):
			closest = minf(closest, ship_b.global_position.distance_to(bolt_b.global_position))

	assert_gt(closest, contact_radius + 1.0, "bolt path stays outside strafed hurtbox")
	assert_almost_eq(
		hull_b.condition(),
		start_strafe,
		0.001,
		"strafed ship far from aim line must not take damage"
	)


func test_hostile_jinks_in_hold_band() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	# Place hostile mid hold-band along -Z so dir is pure +Z toward player.
	var mid: float = (
		(BalanceCombat.HOSTILE_HOLD_DISTANCE_MIN + BalanceCombat.HOSTILE_HOLD_DISTANCE_MAX) * 0.5
	)
	var hostile: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -mid))
	await get_tree().process_frame

	# sin(_jink_time * freq) ~ 1 when _jink_time = PI/2 and freq = 2 → sin(PI) = 0.
	# Want sin ≈ 1: set _jink_time so _jink_time * HOSTILE_JINK_FREQ = PI/2.
	hostile._jink_time = (PI * 0.5) / BalanceCombat.HOSTILE_JINK_FREQ
	var to_player: Vector3 = ship.global_position - hostile.global_position
	var distance: float = to_player.length()
	assert_true(
		(
			distance >= BalanceCombat.HOSTILE_HOLD_DISTANCE_MIN
			and distance <= BalanceCombat.HOSTILE_HOLD_DISTANCE_MAX
		),
		"fixture distance must sit in hold band"
	)
	hostile._close_distance(to_player, distance, 0.1)

	var lat: float = absf(hostile.velocity.x) + absf(hostile.velocity.y)
	var close_in: float = absf(hostile.velocity.z)
	assert_gt(lat, 1.0, "hold-band jink must have significant lateral velocity")
	assert_lt(close_in, lat, "jink should not be pure close-in along to-player")
	assert_false(hostile.velocity.is_zero_approx(), "jink velocity must not be pure zero")
