extends GutTest

## E6.1 solid space — soft bump, blocked penetration, gate interact range.
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.1

const TOLERANCE: float = 0.15
const PHYSICS_FRAMES: int = 8


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_player_layers_collide_with_ships_and_statics() -> void:
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	await get_tree().process_frame
	assert_eq(ship.collision_layer, BalanceFlight.PHYSICS_LAYER_SHIPS)
	assert_eq(ship.collision_mask, BalanceFlight.PHYSICS_MASK_SHIPS_AND_STATICS)
	assert_eq(ship.motion_mode, CharacterBody3D.MOTION_MODE_FLOATING)


func test_player_blocked_by_station_collider() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var station: StaticBody3D = StaticBody3D.new()
	station.name = "StationCollider"
	station.collision_layer = BalanceFlight.PHYSICS_LAYER_STATICS
	station.collision_mask = 0
	station.set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_STATION)
	station.position = Vector3.ZERO
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = 10.0
	cyl.height = 20.0
	shape_node.shape = cyl
	station.add_child(shape_node)
	space.add_child(station)

	var ship: PlayerShip = PlayerShip.new()
	ship.set_flight_enabled(false)
	space.add_child(ship)
	# Start outside, drive into station centre.
	ship.global_position = Vector3(0.0, 0.0, 25.0)
	ship.velocity = Vector3(0.0, 0.0, -80.0)
	await get_tree().physics_frame

	var i: int = 0
	while i < PHYSICS_FRAMES:
		# Live PlayerShip path: pre-slide velocity → move_and_slide → resolve.
		var pre: Vector3 = ship.velocity
		ship.move_and_slide()
		ship.call(&"_resolve_soft_bumps_and_impact", 0.016, pre)
		await get_tree().physics_frame
		i += 1

	# Must not reach the station centre (ghost through).
	assert_gt(
		ship.global_position.z,
		cyl.radius * 0.25,
		"player must not fully penetrate station collider (z=%.2f)" % ship.global_position.z
	)
	assert_lt(
		ship.global_position.distance_to(Vector3.ZERO),
		30.0,
		"ship should have approached the station"
	)


func test_soft_bump_retains_lateral_after_head_on_static() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = BalanceFlight.PHYSICS_LAYER_STATICS
	wall.collision_mask = 0
	wall.set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_GATE)
	wall.position = Vector3(0.0, 0.0, -5.0)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 20.0, 4.0)
	shape_node.shape = box
	wall.add_child(shape_node)
	space.add_child(wall)

	var ship: PlayerShip = PlayerShip.new()
	ship.set_flight_enabled(false)
	space.add_child(ship)
	# Close enough that a few physics frames guarantee contact.
	ship.global_position = Vector3(0.0, 0.0, 4.0)
	# Head-on -Z plus lateral +X.
	ship.velocity = Vector3(25.0, 0.0, -120.0)
	await get_tree().physics_frame

	var had_collision: bool = false
	var lateral_after: float = 0.0
	var i: int = 0
	while i < PHYSICS_FRAMES * 2:
		var pre: Vector3 = ship.velocity
		ship.move_and_slide()
		if ship.get_slide_collision_count() > 0:
			had_collision = true
		ship.call(&"_resolve_soft_bumps_and_impact", 0.016, pre)
		if had_collision:
			lateral_after = absf(ship.velocity.x)
		await get_tree().physics_frame
		i += 1

	assert_true(had_collision, "expected contact with wall")
	assert_gt(lateral_after, 1.0, "lateral motion retained after soft bump")
	assert_gt(ship.velocity.length(), 0.5, "must not hard-stop full velocity to zero")


func test_player_blocked_by_hostile_hull() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var hostile: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -8.0))
	hostile.set_physics_process(false)
	hostile.velocity = Vector3.ZERO

	var ship: PlayerShip = PlayerShip.new()
	ship.set_flight_enabled(false)
	space.add_child(ship)
	ship.global_position = Vector3(0.0, 0.0, 8.0)
	ship.velocity = Vector3(0.0, 0.0, -90.0)
	await get_tree().physics_frame

	var start_z: float = ship.global_position.z
	var i: int = 0
	while i < PHYSICS_FRAMES:
		var pre: Vector3 = ship.velocity
		ship.move_and_slide()
		ship.call(&"_resolve_soft_bumps_and_impact", 0.016, pre)
		await get_tree().physics_frame
		i += 1

	# Without collision the ship would travel far past the hostile in these frames.
	assert_gt(ship.global_position.z, hostile.global_position.z - 2.0)
	assert_lt(ship.global_position.z, start_z)


func test_player_blocked_by_traffic_hull() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var traffic: AnimatableBody3D = AnimatableBody3D.new()
	traffic.collision_layer = BalanceFlight.PHYSICS_LAYER_SHIPS
	traffic.collision_mask = 0
	traffic.set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_TRAFFIC_LIGHT)
	traffic.position = Vector3(0.0, 0.0, -6.0)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 2.0
	cap.height = 5.0
	shape_node.shape = cap
	traffic.add_child(shape_node)
	space.add_child(traffic)

	var ship: PlayerShip = PlayerShip.new()
	ship.set_flight_enabled(false)
	space.add_child(ship)
	ship.global_position = Vector3(0.0, 0.0, 10.0)
	ship.velocity = Vector3(0.0, 0.0, -80.0)
	await get_tree().physics_frame

	var i: int = 0
	while i < PHYSICS_FRAMES:
		var pre: Vector3 = ship.velocity
		ship.move_and_slide()
		ship.call(&"_resolve_soft_bumps_and_impact", 0.016, pre)
		await get_tree().physics_frame
		i += 1

	assert_gt(
		ship.global_position.z, traffic.global_position.z - 1.0, "must not ghost through traffic"
	)


func test_gate_interact_prompt_fires_outside_gate_collider() -> void:
	# Real GateTravelService: stand outside gate mesh but inside interact radius
	# with a built world collider present — F-path uses centre distance, not mesh.
	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_alpha"
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	var gates: Dictionary[StringName, Vector3] = world.gate_positions()
	assert_false(gates.is_empty(), "alpha must place at least one gate")
	var dest_id: StringName = gates.keys()[0]
	var gate_pos: Vector3 = gates[dest_id]

	var ship: PlayerShip = PlayerShip.new()
	ship.set_flight_enabled(false)
	add_child_autofree(ship)
	# Outside ring outer, inside interact radius.
	ship.global_position = gate_pos + Vector3(0.0, 0.0, BalanceFlight.GATE_RING_OUTER + 8.0)
	ship.force_update_transform()
	await get_tree().process_frame

	var dist: float = ship.global_position.distance_to(gate_pos)
	assert_lt(dist, BalanceEconomy.GATE_INTERACT_RADIUS)
	assert_gt(dist, BalanceFlight.GATE_RING_OUTER)

	# Array spy — GDScript lambdas can fail to write outer StringName locals.
	var prompts: Array = []
	var on_prompt: Callable = func(d: StringName, can: bool) -> void:
		prompts.append({"dest": d, "can": can})
	EventBus.on_gate_prompt_changed.connect(on_prompt)

	var gate_svc: GateTravelService = GateTravelService.new()
	add_child_autofree(gate_svc)
	var docking: DockingService = DockingService.new()
	add_child_autofree(docking)
	# Wire after tree enter so first process has ship + gates.
	gate_svc.setup(ship, gates, docking)
	gate_svc._physics_process(0.016)

	if EventBus.on_gate_prompt_changed.is_connected(on_prompt):
		EventBus.on_gate_prompt_changed.disconnect(on_prompt)

	assert_false(prompts.is_empty(), "gate prompt must fire at least once")
	var last: Dictionary = prompts[prompts.size() - 1]
	var got_dest: StringName = StringName(str(last.get("dest", &"")))
	assert_eq(got_dest, dest_id, "gate prompt must name nearest dest")
	# can_jump may be false without fuel/wallet; dest is the interact signal.
