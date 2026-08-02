extends GutTest

## E2.2 — security-aware encounter rules (counts, denser lawless, concurrent cap).
##
## Implements: docs/BETA_E2_COMBAT_HULL.md E2.2

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const TOLERANCE: float = 0.0001


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_balance_encounter_caps_and_counts() -> void:
	assert_eq(BalanceCombat.MAX_CONCURRENT_HOSTILES, 3)
	assert_lte(BalanceCombat.MAX_CONCURRENT_HOSTILES, 3, "E2 hard cap is ≤3")
	assert_eq(BalanceCombat.AMBIENT_HOSTILE_COUNT_PATROLLED, 0)
	assert_gt(BalanceCombat.AMBIENT_HOSTILE_COUNT_CONTESTED, 0)
	assert_gt(
		BalanceCombat.AMBIENT_HOSTILE_COUNT_LAWLESS,
		BalanceCombat.AMBIENT_HOSTILE_COUNT_CONTESTED,
		"lawless ambient count denser than contested"
	)
	assert_lte(
		BalanceCombat.AMBIENT_HOSTILE_COUNT_LAWLESS,
		BalanceCombat.MAX_CONCURRENT_HOSTILES,
		"ambient lawless must leave room under concurrent cap"
	)


func test_all_ambient_spawn_offsets_outside_station_safe() -> void:
	var i: int = 0
	while i < BalanceCombat.AMBIENT_SPAWN_OFFSET_SLOT_COUNT:
		var offset: Vector3 = BalanceCombat.ambient_spawn_offset(i)
		assert_gt(
			offset.length(),
			BalanceCombat.STATION_SAFE_RADIUS,
			"ambient offset slot %d must sit outside safe radius" % i
		)
		i += 1
	assert_gt(
		BalanceCombat.BOUNTY_SPAWN_OFFSET.length(),
		BalanceCombat.STATION_SAFE_RADIUS,
		"bounty restock offset outside safe radius"
	)
	assert_gt(BalanceCombat.UNDOCK_GRACE_SECONDS, 0.0, "undock grace still configured")


func test_undock_grace_blocks_hostile_fire() -> void:
	# E2.2 AC4: hostiles must not fire during undock grace after undock.
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var wallet: WalletService = WalletService.new()
	space.add_child(wallet)
	await get_tree().process_frame
	wallet.reset()
	var start_condition: float = wallet.condition()

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	# Outside station safe radius so only undock grace protects the player.
	ship.global_position = Vector3(0.0, 0.0, BalanceCombat.STATION_SAFE_RADIUS + 80.0)

	var hostile: HostileNpc = HostileNpc.spawn_under(
		space, ship.global_position + Vector3(0.0, 0.0, -30.0)
	)
	hostile.look_at(ship.global_position, Vector3.UP)
	hostile._player_docked = false
	EventBus.on_undocked.emit(&"station_beta_hub")
	assert_gt(hostile._undock_grace, 0.0, "undock event must arm grace")
	assert_almost_eq(
		hostile._undock_grace, BalanceCombat.UNDOCK_GRACE_SECONDS, TOLERANCE, "grace seconds"
	)

	var bolts_before: int = _count_hostile_bolts(space)
	# Burn less than full grace — fire must stay off.
	var steps: int = 4
	var step_dt: float = BalanceCombat.UNDOCK_GRACE_SECONDS / float(steps + 1)
	for _i: int in steps:
		hostile._physics_process(step_dt)
		assert_gt(hostile._undock_grace, 0.0, "still inside grace window")
	assert_eq(
		_count_hostile_bolts(space),
		bolts_before,
		"hostiles must not spawn bolts during undock grace"
	)
	assert_almost_eq(wallet.condition(), start_condition, TOLERANCE, "no damage during grace")

	# After grace expires, a facing hostile may fire.
	hostile._undock_grace = 0.0
	hostile._fire_cooldown = 0.0
	hostile.look_at(ship.global_position, Vector3.UP)
	hostile._physics_process(0.05)
	assert_gt(
		_count_hostile_bolts(space),
		bolts_before,
		"after grace ends, hostile may fire when facing and out of safe zone"
	)


func _count_hostile_bolts(parent: Node) -> int:
	var n: int = 0
	for child: Node in parent.get_children():
		if child.get_script() == null:
			continue
		var path: String = str(child.get_script().resource_path)
		if path.ends_with("HostileProjectile.gd"):
			n += 1
	return n


func test_patrolled_alpha_zero_ambient_and_allows_false() -> void:
	assert_false(SystemWorld.system_allows_hostiles(SYSTEM_ALPHA))
	assert_eq(SystemWorld.ambient_hostile_count(SYSTEM_ALPHA), 0)
	assert_eq(
		SystemWorld.ambient_hostile_count(SYSTEM_ALPHA),
		BalanceCombat.AMBIENT_HOSTILE_COUNT_PATROLLED
	)
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 0, "patrolled Alpha: zero ambient combat hostiles")
	world.ensure_hostile_near(Vector3.ZERO)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 0, "patrolled Alpha: ensure stays a no-op")


func test_contested_beta_ambient_count_and_profile_from_balance() -> void:
	assert_true(SystemWorld.system_allows_hostiles(SYSTEM_BETA))
	assert_eq(
		SystemWorld.ambient_hostile_count(SYSTEM_BETA),
		BalanceCombat.AMBIENT_HOSTILE_COUNT_CONTESTED
	)
	assert_eq(
		SystemWorld.ambient_hostile_profile(SYSTEM_BETA), BalanceCombat.AMBIENT_PROFILE_CONTESTED
	)
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	assert_eq(
		world.live_hostile_count(),
		BalanceCombat.AMBIENT_HOSTILE_COUNT_CONTESTED,
		"contested ambient count must match balance (not a magic number in world)"
	)
	var hostiles: Array[HostileNpc] = _all_hostiles(world)
	assert_eq(hostiles.size(), BalanceCombat.AMBIENT_HOSTILE_COUNT_CONTESTED)
	for h: HostileNpc in hostiles:
		assert_eq(h.profile_id, BalanceCombat.AMBIENT_PROFILE_CONTESTED)
		assert_false(
			_hostile_inside_any_station_safe(world, h.global_position),
			"contested ambient must not camp station airspace"
		)


func test_lawless_gamma_denser_and_meaner_than_contested() -> void:
	assert_true(SystemWorld.system_allows_hostiles(SYSTEM_GAMMA))
	var lawless_count: int = SystemWorld.ambient_hostile_count(SYSTEM_GAMMA)
	var contested_count: int = SystemWorld.ambient_hostile_count(SYSTEM_BETA)
	assert_eq(lawless_count, BalanceCombat.AMBIENT_HOSTILE_COUNT_LAWLESS)
	assert_gt(lawless_count, contested_count, "lawless denser by ambient count")

	var lawless_profile: StringName = SystemWorld.ambient_hostile_profile(SYSTEM_GAMMA)
	var contested_profile: StringName = SystemWorld.ambient_hostile_profile(SYSTEM_BETA)
	assert_eq(lawless_profile, BalanceCombat.AMBIENT_PROFILE_LAWLESS)
	assert_ne(lawless_profile, contested_profile, "lawless uses meaner profile (gunboat)")
	var hp_lawless: float = BalanceCombat.profile_float(
		lawless_profile, BalanceCombat.PROFILE_KEY_HP, 0.0
	)
	var hp_contested: float = BalanceCombat.profile_float(
		contested_profile, BalanceCombat.PROFILE_KEY_HP, 0.0
	)
	assert_gt(hp_lawless, hp_contested, "lawless ambient profile harder by HP")

	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_GAMMA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	assert_eq(
		world.live_hostile_count(),
		BalanceCombat.AMBIENT_HOSTILE_COUNT_LAWLESS,
		"lawless ambient count from balance"
	)
	var hostiles: Array[HostileNpc] = _all_hostiles(world)
	assert_eq(hostiles.size(), BalanceCombat.AMBIENT_HOSTILE_COUNT_LAWLESS)
	for h: HostileNpc in hostiles:
		assert_eq(h.profile_id, BalanceCombat.AMBIENT_PROFILE_LAWLESS)
		assert_false(
			_hostile_inside_any_station_safe(world, h.global_position),
			"lawless ambient must not camp station airspace"
		)
	# Offsets must differ so denser spawn does not stack on one point.
	if hostiles.size() >= 2:
		var d: float = hostiles[0].global_position.distance_to(hostiles[1].global_position)
		assert_gt(d, 1.0, "lawless ambient hostiles must use distinct spawn offsets")


func test_bounty_ensure_places_one_in_lock_range_when_empty() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	_free_all_hostiles(world)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 0)

	var near: Vector3 = Vector3(-160.0, 0.0, 90.0)
	world.ensure_hostile_near(near)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 1, "ensure places prey when ambient died")
	var hostile: HostileNpc = _first_hostile(world)
	assert_ne(hostile, null)
	assert_eq(hostile.profile_id, BalanceCombat.BOUNTY_HOSTILE_PROFILE)
	assert_false(_hostile_inside_any_station_safe(world, hostile.global_position))
	assert_lte(
		near.distance_to(hostile.global_position),
		BalanceCombat.TARGET_LOCK_RANGE,
		"bounty ensure places prey within lock range"
	)


func test_bounty_ensure_when_ambient_far_still_places_in_range() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	assert_gt(world.live_hostile_count(), 0)

	# Ambient sits near station+SPAWN_OFFSET; request point far away outside lock range.
	var far: Vector3 = Vector3(2000.0, 0.0, 2000.0)
	assert_false(
		world.live_hostile_within_range(far, BalanceCombat.TARGET_LOCK_RANGE),
		"setup: ambient must be outside lock of far request"
	)
	var before: int = world.live_hostile_count()
	world.ensure_hostile_near(far)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), before + 1, "ensure adds prey when ambient is far")
	assert_true(
		world.live_hostile_within_range(far, BalanceCombat.TARGET_LOCK_RANGE),
		"after ensure, a live hostile sits in lock range of request"
	)


func test_bounty_ensure_skips_when_prey_already_in_lock_range() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	_free_all_hostiles(world)
	await get_tree().process_frame
	var near: Vector3 = Vector3(-160.0, 0.0, 90.0)
	world.ensure_hostile_near(near)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 1)
	world.ensure_hostile_near(near)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 1, "ensure must not stack when prey already in range")


func test_concurrent_cap_blocks_further_spawns() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	_free_all_hostiles(world)
	await get_tree().process_frame

	# Space requests farther than lock range so each ensure actually needs a new spawn.
	# Include bounty offset length so placed prey near request N is outside lock of N+1.
	var step: float = (
		BalanceCombat.TARGET_LOCK_RANGE + BalanceCombat.BOUNTY_SPAWN_OFFSET.length() + 200.0
	)
	var i: int = 0
	while i < BalanceCombat.MAX_CONCURRENT_HOSTILES:
		var request: Vector3 = Vector3(float(i) * step + 800.0, 0.0, 0.0)
		world.ensure_hostile_near(request)
		await get_tree().process_frame
		i += 1
	assert_eq(
		world.live_hostile_count(),
		BalanceCombat.MAX_CONCURRENT_HOSTILES,
		"ensure fills up to concurrent cap"
	)
	assert_false(world.can_spawn_hostile())
	var blocked: int = world.live_hostile_count()
	world.ensure_hostile_near(Vector3(9000.0, 0.0, 0.0))
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), blocked, "ensure refuses spawn at concurrent cap")
	# Ambient path must also refuse when full.
	world._spawn_hostile()
	await get_tree().process_frame
	assert_eq(
		world.live_hostile_count(),
		BalanceCombat.MAX_CONCURRENT_HOSTILES,
		"ambient path never exceeds concurrent cap"
	)


func test_cap_constant_is_source_of_truth_not_world_literal() -> void:
	## Guard: SystemWorld must not hardcode 3 — the balance constant does.
	assert_eq(BalanceCombat.MAX_CONCURRENT_HOSTILES, 3)
	assert_true(
		BalanceCombat.MAX_CONCURRENT_HOSTILES >= BalanceCombat.AMBIENT_HOSTILE_COUNT_LAWLESS
	)


func test_ambient_count_helpers_match_policing_strings() -> void:
	assert_eq(
		BalanceCombat.ambient_count_for_policing(&"patrolled"),
		BalanceCombat.AMBIENT_HOSTILE_COUNT_PATROLLED
	)
	assert_eq(
		BalanceCombat.ambient_count_for_policing(&"contested"),
		BalanceCombat.AMBIENT_HOSTILE_COUNT_CONTESTED
	)
	assert_eq(
		BalanceCombat.ambient_count_for_policing(&"lawless"),
		BalanceCombat.AMBIENT_HOSTILE_COUNT_LAWLESS
	)
	assert_eq(
		BalanceCombat.ambient_count_for_policing(&"unknown_tier"),
		BalanceCombat.AMBIENT_HOSTILE_COUNT_PATROLLED
	)


func _free_all_hostiles(world: SystemWorld) -> void:
	var tree: SceneTree = world.get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if is_instance_valid(node) and world.is_ancestor_of(node):
			node.free()


func _first_hostile(world: SystemWorld) -> HostileNpc:
	var all: Array[HostileNpc] = _all_hostiles(world)
	if all.is_empty():
		return null
	return all[0]


func _all_hostiles(world: SystemWorld) -> Array[HostileNpc]:
	var out: Array[HostileNpc] = []
	var tree: SceneTree = world.get_tree()
	if tree == null:
		return out
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if is_instance_valid(node) and world.is_ancestor_of(node) and node is HostileNpc:
			out.append(node as HostileNpc)
	return out


func _hostile_inside_any_station_safe(world: SystemWorld, pos: Vector3) -> bool:
	var positions: Dictionary[StringName, Vector3] = world.station_positions()
	if positions.is_empty():
		return pos.distance_to(BalanceFlight.STATION_POSITION) <= BalanceCombat.STATION_SAFE_RADIUS
	for station_id: StringName in positions:
		if pos.distance_to(positions[station_id]) <= BalanceCombat.STATION_SAFE_RADIUS:
			return true
	return false
