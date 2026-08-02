extends GutTest

## E6.4 Package D — density under 20-ship budget; secondary-dock traffic.
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.4 acceptance 1–5

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const SMOKE_FRAMES: int = 8
const DOCK_SEP_TOLERANCE: float = 0.5


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_perf_budget_is_20_and_densest_fits() -> void:
	## AC1: PERF_BUDGET_SHIPS is 20; densest system spawn math ≤ cap.
	assert_eq(BalanceEconomy.PERF_BUDGET_SHIPS, 20)
	assert_gt(
		BalanceEconomy.PERF_BUDGET_SHIPS,
		BalanceEconomy.PERF_BUDGET_SHIPS_E5_BASELINE,
		"E6 density must raise the E5 12-ship baseline"
	)
	assert_eq(BalanceCombat.MAX_CONCURRENT_HOSTILES, 3, "hostile combat cap stays 3")

	var densest: int = BalanceEconomy.densest_ships_layout()
	assert_lte(densest, BalanceEconomy.PERF_BUDGET_SHIPS, "densest layout ≤ 20")
	assert_eq(BalanceEconomy.densest_layout_policing(), &"contested")
	assert_eq(
		densest,
		(
			BalanceEconomy.PERF_BUDGET_PLAYER_COUNT
			+ BalanceEconomy.NPC_COUNT_CONTESTED
			+ BalanceCombat.MAX_CONCURRENT_HOSTILES
		),
		"densest = 1 player + contested traffic + max hostiles"
	)


func test_patrolled_density_exceeds_pre_e6_floor() -> void:
	## AC2: densest patrolled non-player count > pre-E6 typical; floor in balance.
	assert_gte(
		BalanceEconomy.DENSITY_FLOOR_PATROLLED_NON_PLAYER,
		8,
		"floor must exceed pre-E6 typical (~8)"
	)
	assert_gte(
		BalanceEconomy.NPC_COUNT_PATROLLED, BalanceEconomy.DENSITY_FLOOR_PATROLLED_NON_PLAYER
	)
	assert_gt(
		BalanceEconomy.NPC_COUNT_PATROLLED,
		BalanceEconomy.PERF_BUDGET_SHIPS_E5_BASELINE - BalanceEconomy.PERF_BUDGET_PLAYER_COUNT,
		"patrolled traffic alone exceeds E5 non-player room under 12"
	)

	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(SYSTEM_ALPHA)
	await get_tree().process_frame

	var non_player: int = traffic.live_ship_count()
	assert_eq(non_player, BalanceEconomy.NPC_COUNT_PATROLLED)
	assert_gte(
		non_player,
		BalanceEconomy.DENSITY_FLOOR_PATROLLED_NON_PLAYER,
		"Alpha live non-player ships meet density floor"
	)
	assert_eq(BalanceEconomy.max_hostiles_for_policing(&"patrolled"), 0)
	assert_lte(
		BalanceEconomy.PERF_BUDGET_PLAYER_COUNT + non_player, BalanceEconomy.PERF_BUDGET_SHIPS
	)


func test_lawless_respects_hostile_cap_and_budget() -> void:
	## AC3: lawless densest combat pressure ≤ hostile cap; traffic + hostiles ≤ 20.
	assert_lt(
		BalanceEconomy.NPC_COUNT_LAWLESS,
		BalanceEconomy.NPC_COUNT_PATROLLED,
		"lawless freighter traffic thinner than patrolled"
	)
	var lawless_total: int = BalanceEconomy.densest_ships_for_policing(&"lawless")
	assert_lte(lawless_total, BalanceEconomy.PERF_BUDGET_SHIPS)
	assert_eq(
		BalanceEconomy.max_hostiles_for_policing(&"lawless"), BalanceCombat.MAX_CONCURRENT_HOSTILES
	)

	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_GAMMA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	var traffic: NpcTraffic = _find_traffic(world)
	assert_not_null(traffic)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_LAWLESS)

	_free_all_hostiles(world)
	await get_tree().process_frame
	var step: float = (
		BalanceCombat.TARGET_LOCK_RANGE + BalanceCombat.BOUNTY_SPAWN_OFFSET.length() + 200.0
	)
	var i: int = 0
	while i < BalanceCombat.MAX_CONCURRENT_HOSTILES:
		world.ensure_hostile_near(Vector3(float(i) * step + 900.0, 0.0, -700.0))
		await get_tree().process_frame
		i += 1

	assert_eq(world.live_hostile_count(), BalanceCombat.MAX_CONCURRENT_HOSTILES)
	assert_lte(world.live_hostile_count(), BalanceCombat.MAX_CONCURRENT_HOSTILES)
	var total: int = (
		BalanceEconomy.PERF_BUDGET_PLAYER_COUNT
		+ traffic.live_ship_count()
		+ world.live_hostile_count()
	)
	assert_eq(total, lawless_total)
	assert_lte(total, BalanceEconomy.PERF_BUDGET_SHIPS, "lawless traffic + hostiles ≤ 20")


func test_dual_dock_secondary_has_local_traffic() -> void:
	## AC4: secondary dock not co-located; traffic nearby (or clear approach).
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	var positions: Dictionary[StringName, Vector3] = world.station_positions()
	assert_gte(positions.size(), 2, "Alpha is dual-dock")
	var primary_id: StringName = &"station_alpha_port"
	var secondary_id: StringName = &"station_alpha_yard"
	assert_true(positions.has(primary_id))
	assert_true(positions.has(secondary_id))
	var primary: Vector3 = positions[primary_id]
	var secondary: Vector3 = positions[secondary_id]
	var dock_sep: float = primary.distance_to(secondary)
	assert_gte(
		dock_sep,
		BalanceFlight.LAYOUT_MIN_DOCK_SEPARATION - DOCK_SEP_TOLERANCE,
		"secondary not co-located with primary"
	)

	var traffic: NpcTraffic = _find_traffic(world)
	assert_not_null(traffic)
	var expected_secondary_slots: int = BalanceEconomy.secondary_dock_traffic_slots(
		BalanceEconomy.NPC_COUNT_PATROLLED
	)
	assert_gte(expected_secondary_slots, 1, "multi-dock systems reserve secondary traffic")

	var near_secondary: int = 0
	for child: Node in traffic.get_children():
		if child is Node3D:
			var ship: Node3D = child as Node3D
			if (
				ship.global_position.distance_to(secondary)
				<= BalanceEconomy.NPC_SECONDARY_NEAR_RADIUS
			):
				near_secondary += 1
	assert_gte(near_secondary, 1, "at least one traffic ship near secondary dock (not empty clone)")
	# Approach clear of primary pad: secondary-local ships stay off primary bubble.
	for child: Node in traffic.get_children():
		if child is Node3D:
			var ship2: Node3D = child as Node3D
			if (
				ship2.global_position.distance_to(secondary)
				<= BalanceEconomy.NPC_SECONDARY_NEAR_RADIUS
			):
				assert_gt(
					ship2.global_position.distance_to(primary),
					BalanceCombat.STATION_SAFE_RADIUS * 0.5,
					"secondary traffic must not sit on primary pad"
				)


func test_densest_system_smoke_no_hard_error() -> void:
	## AC5: headless densest-system smoke — no crash; ships stay at budget.
	assert_eq(BalanceEconomy.densest_layout_policing(), &"contested")

	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	var traffic: NpcTraffic = _find_traffic(world)
	assert_not_null(traffic)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_CONTESTED)

	_free_all_hostiles(world)
	await get_tree().process_frame
	var step: float = (
		BalanceCombat.TARGET_LOCK_RANGE + BalanceCombat.BOUNTY_SPAWN_OFFSET.length() + 200.0
	)
	var i: int = 0
	while i < BalanceCombat.MAX_CONCURRENT_HOSTILES:
		world.ensure_hostile_near(Vector3(float(i) * step + 800.0, 0.0, 0.0))
		await get_tree().process_frame
		i += 1

	var total: int = (
		BalanceEconomy.PERF_BUDGET_PLAYER_COUNT
		+ traffic.live_ship_count()
		+ world.live_hostile_count()
	)
	assert_eq(total, BalanceEconomy.densest_ships_for_policing(&"contested"))
	assert_lte(total, BalanceEconomy.PERF_BUDGET_SHIPS)

	var f: int = 0
	while f < SMOKE_FRAMES:
		await get_tree().process_frame
		f += 1

	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_CONTESTED)
	assert_eq(world.live_hostile_count(), BalanceCombat.MAX_CONCURRENT_HOSTILES)
	assert_true(is_instance_valid(world), "world still valid after densest smoke")


func test_secondary_dock_slot_helper() -> void:
	assert_eq(BalanceEconomy.secondary_dock_traffic_slots(0), 0)
	assert_eq(BalanceEconomy.secondary_dock_traffic_slots(1), 0)
	var for_patrolled: int = BalanceEconomy.secondary_dock_traffic_slots(
		BalanceEconomy.NPC_COUNT_PATROLLED
	)
	assert_gte(for_patrolled, 1)
	assert_lt(for_patrolled, BalanceEconomy.NPC_COUNT_PATROLLED)


func _find_traffic(world: SystemWorld) -> NpcTraffic:
	for child: Node in world.get_children():
		if child is NpcTraffic:
			return child as NpcTraffic
	return null


func _free_all_hostiles(world: SystemWorld) -> void:
	var tree: SceneTree = world.get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if is_instance_valid(node) and world.is_ancestor_of(node):
			node.free()
