extends GutTest

## S5 — perf measurement hook for densest layout (instrument only).
##
## Does not assert 60fps (machine variance). Asserts ship count ≤ budget and
## that PerfProbe returns a finite fps sample ≥ 0.

const SYSTEM_BETA: StringName = &"system_beta"
const SAMPLE_FRAMES: int = 6


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_densest_layout_within_budget() -> void:
	assert_eq(BalanceEconomy.PERF_BUDGET_SHIPS, 20)
	var densest: int = BalanceEconomy.densest_ships_layout()
	assert_lte(densest, BalanceEconomy.PERF_BUDGET_SHIPS)
	assert_eq(BalanceEconomy.densest_layout_policing(), &"contested")


func test_perf_probe_snapshot_finite() -> void:
	var fps: float = PerfProbe.snapshot_fps()
	assert_true(is_finite(fps), "snapshot fps must be finite")
	assert_gte(fps, 0.0)


func test_perf_probe_samples_densest_scene() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	var traffic_roots: Array[Node] = get_tree().get_nodes_in_group(BalanceEconomy.GROUP_NPC_TRAFFIC)
	var traffic_count: int = 0
	for root: Node in traffic_roots:
		if world.is_ancestor_of(root) and root.has_method(&"live_ship_count"):
			var raw: Variant = root.call(&"live_ship_count")
			if typeof(raw) == TYPE_INT:
				traffic_count = raw
	var hostiles: Array[Node] = get_tree().get_nodes_in_group(BalanceCombat.GROUP_HOSTILE)
	var hostile_here: int = 0
	for h: Node in hostiles:
		if world.is_ancestor_of(h):
			hostile_here += 1

	var live: int = BalanceEconomy.PERF_BUDGET_PLAYER_COUNT + traffic_count + hostile_here
	assert_lte(live, BalanceEconomy.PERF_BUDGET_SHIPS, "live densest spawn ≤ 20")

	var avg: float = await PerfProbe.sample_average_fps(get_tree(), SAMPLE_FRAMES)
	assert_true(is_finite(avg), "average fps finite")
	assert_gte(avg, 0.0, "instrument returns non-negative average")
