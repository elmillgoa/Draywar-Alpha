extends GutTest

## E6.1 layout stretch — pad↔gate and multi-dock separations.
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.1

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_DELTA: StringName = &"system_delta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const TOLERANCE: float = 0.5


func test_layout_constants_exceed_pre_e6_scale() -> void:
	assert_gte(
		BalanceFlight.LAYOUT_MIN_STATION_GATE_SEPARATION,
		1000.0,
		"min pad→gate must be order-of-magnitude over pre-E6 ~272m"
	)
	assert_gte(BalanceFlight.LAYOUT_MIN_DOCK_SEPARATION, 400.0)
	assert_gte(
		BalanceFlight.GATE_POSITION.length(),
		BalanceFlight.LAYOUT_MIN_STATION_GATE_SEPARATION,
		"GATE_POSITION length must meet min station-gate separation"
	)
	assert_eq(BalanceEconomy.PERF_BUDGET_SHIPS, 20, "E6.4 ship budget is 20")


func test_alpha_station_to_nearest_gate_meets_min() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	var stations: Dictionary[StringName, Vector3] = world.station_positions()
	var gates: Dictionary[StringName, Vector3] = world.gate_positions()
	assert_false(stations.is_empty(), "alpha has stations")
	assert_false(gates.is_empty(), "alpha has gates")
	for station_id: StringName in stations:
		var station_pos: Vector3 = stations[station_id]
		var nearest: float = INF
		for dest: StringName in gates:
			var d: float = station_pos.distance_to(gates[dest])
			if d < nearest:
				nearest = d
		assert_gte(
			nearest,
			BalanceFlight.LAYOUT_MIN_STATION_GATE_SEPARATION - TOLERANCE,
			"%s → nearest gate %.1f" % [String(station_id), nearest]
		)


func test_multi_dock_secondary_separation() -> void:
	for system_id: StringName in [SYSTEM_ALPHA, SYSTEM_BETA, SYSTEM_DELTA, SYSTEM_GAMMA]:
		var world: SystemWorld = SystemWorld.new()
		world.system_id = system_id
		add_child_autofree(world)
		world.build()
		await get_tree().process_frame
		var positions: Dictionary[StringName, Vector3] = world.station_positions()
		if positions.size() < 2:
			continue
		var ids: Array = positions.keys()
		var i: int = 0
		while i < ids.size():
			var j: int = i + 1
			while j < ids.size():
				var a: StringName = ids[i]
				var b: StringName = ids[j]
				var dist: float = positions[a].distance_to(positions[b])
				assert_gte(
					dist,
					BalanceFlight.LAYOUT_MIN_DOCK_SEPARATION - TOLERANCE,
					"%s docks %s↔%s = %.1f" % [String(system_id), String(a), String(b), dist]
				)
				j += 1
			i += 1


func test_station_and_gate_colliders_exist() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	var station_col: Node = _find_named_descendant(world, "StationCollider")
	var gate_col: Node = _find_named_descendant(world, "GateCollider")
	assert_ne(station_col, null, "StationCollider present")
	assert_ne(gate_col, null, "GateCollider present")
	assert_true(station_col is StaticBody3D)
	assert_true(gate_col is StaticBody3D)
	var sbody: StaticBody3D = station_col as StaticBody3D
	var gbody: StaticBody3D = gate_col as StaticBody3D
	assert_eq(sbody.collision_layer, BalanceFlight.PHYSICS_LAYER_STATICS)
	assert_eq(gbody.collision_layer, BalanceFlight.PHYSICS_LAYER_STATICS)
	var station_class: StringName = StringName(str(sbody.get_meta(BalanceCombat.META_MASS_CLASS)))
	var gate_class: StringName = StringName(str(gbody.get_meta(BalanceCombat.META_MASS_CLASS)))
	assert_eq(station_class, BalanceCombat.MASS_CLASS_STATION)
	assert_eq(gate_class, BalanceCombat.MASS_CLASS_GATE)


func test_undock_offset_clear_of_station_disc() -> void:
	var undock_z: float = BalanceFlight.UNDOCK_OFFSET.z
	assert_gt(
		undock_z,
		BalanceFlight.STATION_DISC_RADIUS + BalanceCombat.PLAYER_HURTBOX_RADIUS,
		"undock pad must sit outside station collider radius"
	)


func _find_named_descendant(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_named_descendant(child, node_name)
		if found != null:
			return found
	return null
