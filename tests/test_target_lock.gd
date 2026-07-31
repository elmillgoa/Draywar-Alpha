extends GutTest

## Tab target lock — closest first, then cycle by distance.
##
## Implements: Path C combat lock (BalanceCombat + PlayerShip).


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_first_tab_locks_nearest_hostile() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	var far: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -120.0))
	var near: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -40.0))
	await get_tree().process_frame

	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), near, "first Tab locks nearest")
	assert_ne(ship.locked_target(), far)


func test_tab_cycles_near_to_far_then_wraps() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	var a: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -30.0))
	var b: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -60.0))
	var c: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -90.0))
	await get_tree().process_frame

	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), a)
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), b)
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), c)
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), a, "wrap back to closest")


func test_fire_prefers_locked_target_in_range() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	# Behind the ship; pure nose hitscan would miss without lock.
	var hostile: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, 50.0))
	await get_tree().process_frame
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), hostile)
	var before: float = hostile.remaining_hp()
	assert_true(ship.try_fire())
	assert_lt(hostile.remaining_hp(), before, "lock should let fire hit off-nose targets")


func test_lock_clears_when_no_hostiles() -> void:
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	await get_tree().process_frame
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), null)
