extends GutTest

## E6.1 encounter ecology — policing spawn slots, bounty ensure, safe bubbles.
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.1

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const TOLERANCE: float = 0.5


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_all_ecology_offsets_outside_station_safe() -> void:
	var i: int = 0
	while i < BalanceCombat.AMBIENT_SPAWN_OFFSET_SLOT_COUNT:
		var contested: Vector3 = BalanceCombat.ambient_spawn_offset_for_policing(&"contested", i)
		var lawless: Vector3 = BalanceCombat.ambient_spawn_offset_for_policing(&"lawless", i)
		assert_gt(
			contested.length(),
			BalanceCombat.STATION_SAFE_RADIUS,
			"contested slot %d outside safe" % i
		)
		assert_gt(
			lawless.length(), BalanceCombat.STATION_SAFE_RADIUS, "lawless slot %d outside safe" % i
		)
		i += 1
	assert_gt(BalanceCombat.BOUNTY_SPAWN_OFFSET.length(), BalanceCombat.STATION_SAFE_RADIUS)


func test_patrolled_zero_hostiles_in_safe_and_gate_approach() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 0, "patrolled: zero ambient hostiles")
	# Explicit: no hostiles inside safe or gate approach (vacuously true at 0).
	for node: Node in get_tree().get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if not world.is_ancestor_of(node):
			continue
		var body: Node3D = node as Node3D
		assert_false(_inside_any_station_safe(world, body.global_position))
		assert_false(_inside_any_gate_approach(world, body.global_position))


func test_contested_ambient_outside_safe_not_on_undock() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), BalanceCombat.AMBIENT_HOSTILE_COUNT_CONTESTED)
	var undock: Vector3 = BalanceFlight.STATION_POSITION + BalanceFlight.UNDOCK_OFFSET
	for h: HostileNpc in _all_hostiles(world):
		assert_false(
			_inside_any_station_safe(world, h.global_position),
			"contested ambient outside station safe"
		)
		assert_gt(
			h.global_position.distance_to(undock),
			BalanceCombat.STATION_SAFE_RADIUS * 0.5,
			"contested ambient not camping undock pad"
		)
		# Preferred mid/lane: contested offset table (not lawless near-gate).
		var slot0: Vector3 = BalanceCombat.ambient_spawn_offset_for_policing(&"contested", 0)
		assert_gt(
			h.global_position.distance_to(BalanceFlight.STATION_POSITION),
			slot0.length() * 0.4,
			"contested spawn uses mid-system scale"
		)


func test_lawless_nearer_gates_than_contested() -> void:
	var gate: Vector3 = BalanceFlight.GATE_POSITION
	var min_lawless: float = INF
	var min_contested: float = INF
	var i: int = 0
	while i < BalanceCombat.AMBIENT_SPAWN_OFFSET_SLOT_COUNT:
		var law_pos: Vector3 = (
			BalanceFlight.STATION_POSITION
			+ BalanceCombat.ambient_spawn_offset_for_policing(&"lawless", i)
		)
		var con_pos: Vector3 = (
			BalanceFlight.STATION_POSITION
			+ BalanceCombat.ambient_spawn_offset_for_policing(&"contested", i)
		)
		min_lawless = minf(min_lawless, law_pos.distance_to(gate))
		min_contested = minf(min_contested, con_pos.distance_to(gate))
		i += 1
	assert_lt(
		min_lawless,
		min_contested,
		"lawless ambient min dist to gate (%.1f) < contested (%.1f)" % [min_lawless, min_contested]
	)

	# Live gamma hostiles should also sit nearer the gate arc than beta's.
	var beta: SystemWorld = SystemWorld.new()
	beta.system_id = SYSTEM_BETA
	add_child_autofree(beta)
	beta.build()
	var gamma: SystemWorld = SystemWorld.new()
	gamma.system_id = SYSTEM_GAMMA
	add_child_autofree(gamma)
	gamma.build()
	await get_tree().process_frame

	var beta_min: float = _min_hostile_gate_distance(beta)
	var gamma_min: float = _min_hostile_gate_distance(gamma)
	assert_lt(gamma_min, beta_min, "live lawless hostiles closer to gate than contested")


func test_bounty_ensure_still_works() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	# Clear ambient so ensure has work to do under cap.
	for h: HostileNpc in _all_hostiles(world):
		h.queue_free()
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 0)

	var near: Vector3 = BalanceFlight.STATION_POSITION + Vector3(0.0, 0.0, 50.0)
	world.ensure_hostile_near(near)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 1, "bounty ensure places prey")
	var hostiles: Array[HostileNpc] = _all_hostiles(world)
	assert_eq(hostiles.size(), 1)
	assert_false(_inside_any_station_safe(world, hostiles[0].global_position))
	assert_lte(
		near.distance_to(hostiles[0].global_position),
		BalanceCombat.TARGET_LOCK_RANGE,
		"bounty prey within lock range of request point"
	)


func test_legacy_ambient_spawn_offset_aliases_contested() -> void:
	assert_eq(
		BalanceCombat.ambient_spawn_offset(0),
		BalanceCombat.ambient_spawn_offset_for_policing(&"contested", 0)
	)


func _all_hostiles(world: SystemWorld) -> Array[HostileNpc]:
	var out: Array[HostileNpc] = []
	for node: Node in get_tree().get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if not is_instance_valid(node) or not world.is_ancestor_of(node):
			continue
		if node is HostileNpc:
			out.append(node as HostileNpc)
	return out


func _inside_any_station_safe(world: SystemWorld, pos: Vector3) -> bool:
	var positions: Dictionary[StringName, Vector3] = world.station_positions()
	if positions.is_empty():
		return pos.distance_to(BalanceFlight.STATION_POSITION) <= BalanceCombat.STATION_SAFE_RADIUS
	for station_id: StringName in positions:
		if pos.distance_to(positions[station_id]) <= BalanceCombat.STATION_SAFE_RADIUS:
			return true
	return false


func _inside_any_gate_approach(world: SystemWorld, pos: Vector3) -> bool:
	var gates: Dictionary[StringName, Vector3] = world.gate_positions()
	for dest: StringName in gates:
		if pos.distance_to(gates[dest]) <= BalanceCombat.GATE_ENCOUNTER_APPROACH_RADIUS:
			return true
	return false


func _min_hostile_gate_distance(world: SystemWorld) -> float:
	var gates: Dictionary[StringName, Vector3] = world.gate_positions()
	var hostiles: Array[HostileNpc] = _all_hostiles(world)
	if hostiles.is_empty() or gates.is_empty():
		return INF
	var best: float = INF
	for h: HostileNpc in hostiles:
		for dest: StringName in gates:
			best = minf(best, h.global_position.distance_to(gates[dest]))
	return best
