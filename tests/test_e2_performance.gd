extends GutTest

## E2.6 — performance densify: traffic raised within 12-ship budget.
##
## Implements: docs/BETA_E2_COMBAT_HULL.md E2.6

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
## Brief process frames for spawn smoke (headless, no real fps sample required).
const SMOKE_FRAMES: int = 8


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_perf_budget_constant_and_densest_math() -> void:
	assert_eq(BalanceEconomy.PERF_BUDGET_SHIPS, 12, "performance bar is 12 ships")
	assert_eq(BalanceEconomy.PERF_BUDGET_PLAYER_COUNT, 1)
	assert_eq(BalanceCombat.MAX_CONCURRENT_HOSTILES, 3)

	# Raised vs pre-E2.6 (6/4/2) so patrolled + contested feel multi-ship.
	assert_gte(BalanceEconomy.NPC_COUNT_PATROLLED, 6)
	assert_gte(BalanceEconomy.NPC_COUNT_CONTESTED, 6)
	assert_gte(BalanceEconomy.NPC_COUNT_LAWLESS, 4)

	# Security gradient: freighter traffic thinnest in lawless.
	assert_lt(
		BalanceEconomy.NPC_COUNT_LAWLESS,
		BalanceEconomy.NPC_COUNT_PATROLLED,
		"lawless freighter traffic thinner than patrolled"
	)

	var patrolled: int = BalanceEconomy.densest_ships_for_policing(&"patrolled")
	var contested: int = BalanceEconomy.densest_ships_for_policing(&"contested")
	var lawless: int = BalanceEconomy.densest_ships_for_policing(&"lawless")

	assert_eq(
		patrolled, BalanceEconomy.PERF_BUDGET_PLAYER_COUNT + BalanceEconomy.NPC_COUNT_PATROLLED + 0
	)
	assert_eq(
		contested,
		(
			BalanceEconomy.PERF_BUDGET_PLAYER_COUNT
			+ BalanceEconomy.NPC_COUNT_CONTESTED
			+ BalanceCombat.MAX_CONCURRENT_HOSTILES
		)
	)
	assert_eq(
		lawless,
		(
			BalanceEconomy.PERF_BUDGET_PLAYER_COUNT
			+ BalanceEconomy.NPC_COUNT_LAWLESS
			+ BalanceCombat.MAX_CONCURRENT_HOSTILES
		)
	)

	assert_lte(patrolled, BalanceEconomy.PERF_BUDGET_SHIPS)
	assert_lte(contested, BalanceEconomy.PERF_BUDGET_SHIPS)
	assert_lte(lawless, BalanceEconomy.PERF_BUDGET_SHIPS)

	var densest: int = BalanceEconomy.densest_ships_layout()
	assert_eq(densest, maxi(patrolled, maxi(contested, lawless)))
	assert_lte(densest, BalanceEconomy.PERF_BUDGET_SHIPS, "densest legal layout ≤ budget")
	# Contested at max concurrent hostiles is the densest layout (documented).
	assert_eq(BalanceEconomy.densest_layout_policing(), &"contested")
	assert_eq(densest, contested, "densest is contested: 1 + traffic + max hostiles")


func test_npc_count_helper_matches_constants() -> void:
	assert_eq(
		BalanceEconomy.npc_count_for_policing(&"patrolled"), BalanceEconomy.NPC_COUNT_PATROLLED
	)
	assert_eq(
		BalanceEconomy.npc_count_for_policing(&"contested"), BalanceEconomy.NPC_COUNT_CONTESTED
	)
	assert_eq(BalanceEconomy.npc_count_for_policing(&"lawless"), BalanceEconomy.NPC_COUNT_LAWLESS)
	assert_eq(BalanceEconomy.npc_count_for_policing(&"unknown"), BalanceEconomy.NPC_COUNT_CONTESTED)


func test_traffic_spawn_counts_match_raised_balance() -> void:
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)

	traffic.rebuild_for_system(SYSTEM_ALPHA)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_PATROLLED)
	assert_eq(traffic.get_child_count(), BalanceEconomy.NPC_COUNT_PATROLLED)

	traffic.rebuild_for_system(SYSTEM_BETA)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_CONTESTED)

	traffic.rebuild_for_system(SYSTEM_GAMMA)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_LAWLESS)


func test_orbit_traffic_non_combat_hostiles_combat_only() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	var traffic_roots: Array[Node] = get_tree().get_nodes_in_group(BalanceEconomy.GROUP_NPC_TRAFFIC)
	assert_gt(traffic_roots.size(), 0, "NpcTraffic in group")
	for root: Node in traffic_roots:
		if not world.is_ancestor_of(root):
			continue
		# Traffic root is display-only; ships are children without combat group.
		assert_false(
			root.is_in_group(BalanceCombat.GROUP_HOSTILE), "traffic root must not be combat hostile"
		)
		for child: Node in root.get_children():
			assert_false(
				child.is_in_group(BalanceCombat.GROUP_HOSTILE), "orbit traffic ships are non-combat"
			)

	var hostiles: Array[Node] = get_tree().get_nodes_in_group(BalanceCombat.GROUP_HOSTILE)
	assert_gt(hostiles.size(), 0, "contested places ambient hostiles")
	for h: Node in hostiles:
		if not world.is_ancestor_of(h):
			continue
		assert_true(h.is_in_group(BalanceCombat.GROUP_HOSTILE))
		assert_false(
			h.is_in_group(BalanceEconomy.GROUP_NPC_TRAFFIC),
			"hostiles are combat-only, not orbit traffic"
		)


func test_densest_system_spawn_smoke() -> void:
	## Contested Beta: densest layout = 1 player + contested traffic + max hostiles.
	assert_eq(BalanceEconomy.densest_layout_policing(), &"contested")

	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	var traffic: NpcTraffic = _find_traffic(world)
	assert_not_null(traffic, "NpcTraffic spawned")
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_CONTESTED)

	# Ambient may be under the concurrent cap; fill to max (bounty-style ensure).
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

	assert_eq(world.live_hostile_count(), BalanceCombat.MAX_CONCURRENT_HOSTILES)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_CONTESTED)

	var total: int = (
		BalanceEconomy.PERF_BUDGET_PLAYER_COUNT
		+ traffic.live_ship_count()
		+ world.live_hostile_count()
	)
	assert_eq(total, BalanceEconomy.densest_ships_for_policing(&"contested"))
	assert_lte(total, BalanceEconomy.PERF_BUDGET_SHIPS, "spawned densest layout ≤ budget")

	# Brief run — no hard error / crash under densest load.
	var f: int = 0
	while f < SMOKE_FRAMES:
		await get_tree().process_frame
		f += 1

	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_CONTESTED)
	assert_eq(world.live_hostile_count(), BalanceCombat.MAX_CONCURRENT_HOSTILES)


func test_attribution_witnesses_sane_with_denser_traffic() -> void:
	## Contested needs traffic ≥ threshold; denser counts still attribute correctly.
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(SYSTEM_BETA)
	await get_tree().process_frame

	var witnesses: int = traffic.live_ship_count()
	assert_eq(witnesses, BalanceEconomy.NPC_COUNT_CONTESTED)
	assert_gte(
		witnesses,
		BalanceStanding.ATTRIBUTION_WITNESS_THRESHOLD,
		"contested denser traffic still clears witness threshold"
	)
	assert_gt(witnesses, 0, "contested attributes when traffic > 0")

	# Lawless still has traffic (witness count reported) but law needs evidence.
	traffic.rebuild_for_system(SYSTEM_GAMMA)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_LAWLESS)
	assert_gt(traffic.live_ship_count(), 0)

	# Patrolled freighter density is highest; zero hostiles in budget math.
	traffic.rebuild_for_system(SYSTEM_ALPHA)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_PATROLLED)
	assert_eq(BalanceEconomy.max_hostiles_for_policing(&"patrolled"), 0)


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
