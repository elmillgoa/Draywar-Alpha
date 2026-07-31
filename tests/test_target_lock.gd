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


func test_lock_clears_when_no_hostiles() -> void:
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	await get_tree().process_frame
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), null)


func test_target_lock_format_includes_hull_percent() -> void:
	var line: String = BalanceCombat.format_target_lock_line("Hostile", 42.0, 75)
	assert_true(line.contains("Hostile"), "name in lock line")
	assert_true(line.contains("42"), "range in lock line")
	assert_true(line.contains("75"), "hull percent in lock line")
	assert_true(line.contains("HULL"), "HULL token present")


func test_hostile_hull_percent_from_remaining_hp() -> void:
	assert_eq(BalanceCombat.hostile_hull_percent(BalanceCombat.HOSTILE_HP), 100)
	assert_eq(BalanceCombat.hostile_hull_percent(BalanceCombat.HOSTILE_HP * 0.5), 50)
	assert_eq(BalanceCombat.hostile_hull_percent(0.0), 0)


func test_flight_hud_target_line_updates_hull_on_damage() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	var hostile: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -40.0))
	var hud: FlightHUD = FlightHUD.new()
	space.add_child(hud)
	await get_tree().process_frame

	ship.cycle_target_lock()
	await get_tree().process_frame
	assert_true(hud._target_label.text.contains("100") or hud._target_label.text.contains("HULL"))

	hostile.take_damage(BalanceCombat.PLAYER_WEAPON_DAMAGE)
	await get_tree().process_frame
	var expected_pct: int = BalanceCombat.hostile_hull_percent(hostile.remaining_hp())
	# Soft assert: line must show HULL and the live percent (e.g. 60 after 40 dmg from 100).
	assert_true(hud._target_label.text.contains("HULL"), "HUD lock line should include HULL")
	assert_true(
		hud._target_label.text.contains(str(expected_pct)),
		"HUD lock line should show reduced hull after damage"
	)
