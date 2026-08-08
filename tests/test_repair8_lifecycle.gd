extends GutTest

## REPAIR-8: escort despawn on mission close + combat-lock release on multi-death.
##
## External audit baseline ee17eab5:
## - Stale escort freighter after complete/fail/abandon blocks the next escort.
## - Two hostiles dying the same frame never release the combat time lock.

const ENTITY_REACH: StringName = &"entity_reach_authority"
const DEST_BETA: StringName = &"station_beta_hub"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const LETHAL: float = 10000.0

var _mission: MissionService = null


func before_each() -> void:
	StandingService.reset_to_defaults()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	_mission = MissionService.new()
	add_child_autofree(_mission)
	_mission.reset()


func after_each() -> void:
	StandingService.reset_to_defaults()
	BoardService.reset()
	MarketService.reset()
	WorldClockHelpers.reset_clock()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	_free_kill_flashes(self)


func _free_kill_flashes(node: Node) -> void:
	var to_free: Array[Node] = []
	for child: Node in node.get_children():
		if child.name == "KillFlash":
			to_free.append(child)
		else:
			_free_kill_flashes(child)
	for flash: Node in to_free:
		if is_instance_valid(flash):
			flash.free()


func _make_escort_offer(offer_id: StringName = &"rad_repair8_escort") -> Dictionary:
	return {
		BalanceBoard.OFFER_KEY_ID: offer_id,
		BalanceBoard.OFFER_KEY_BOARD_STATION: &"station_alpha_port",
		BalanceBoard.OFFER_KEY_KIND: BalanceStanding.MISSION_KIND_ESCORT,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: ENTITY_REACH,
		BalanceBoard.OFFER_KEY_PAY: 220,
		BalanceBoard.OFFER_KEY_STANDING_COMPLETE: BalanceStanding.MISSION_COMPLETE_DELTA,
		BalanceBoard.OFFER_KEY_STANDING_FAIL: BalanceStanding.MISSION_FAIL_DELTA,
		BalanceBoard.OFFER_KEY_STANDING_ABANDON: BalanceStanding.MISSION_ABANDON_DELTA,
		BalanceBoard.OFFER_KEY_DESTINATION: DEST_BETA,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: &"system_beta",
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: &"",
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: 0,
		BalanceBoard.OFFER_KEY_LABEL: "Escort freighter to Beta Hub",
		BalanceBoard.OFFER_KEY_SOURCE: BalanceBoard.OFFER_SOURCE_RADIANT,
	}


func _live_escort_count() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(BalanceBoard.GROUP_MISSION_ESCORT):
		if not is_instance_valid(node):
			continue
		if node.has_method(&"is_alive") and node.call(&"is_alive") != true:
			continue
		count += 1
	return count


func _first_escort() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(BalanceBoard.GROUP_MISSION_ESCORT):
		if is_instance_valid(node):
			if node.has_method(&"is_alive") and node.call(&"is_alive") != true:
				continue
			return node
	return null


func test_escort_despawns_on_mission_complete_and_next_spawns_fresh() -> void:
	## Complete leaves the freighter alive in the world; without a mission-close
	## despawn, _live_escort_count stays > 0 and the next ensure is a no-op.
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	assert_true(_mission._accept_runtime(_make_escort_offer(&"rad_r8_escort_a"), true))
	world.ensure_escort_freighter()
	await get_tree().process_frame
	assert_eq(_live_escort_count(), 1, "first escort must spawn")
	var first: Node = _first_escort()
	assert_ne(first, null)
	var first_id: int = first.get_instance_id()

	var result: Dictionary = _mission.try_complete_at(DEST_BETA)
	var attributed: bool = result.get(BalanceStanding.REPORT_KEY_ATTRIBUTED, false) == true
	assert_true(attributed, "complete at destination must credit the job")
	assert_false(_mission.has_active())
	await get_tree().process_frame
	assert_eq(_live_escort_count(), 0, "REPAIR-8: completing an escort must free the freighter")

	assert_true(_mission._accept_runtime(_make_escort_offer(&"rad_r8_escort_b"), true))
	world.ensure_escort_freighter()
	await get_tree().process_frame
	assert_eq(_live_escort_count(), 1, "next escort must spawn fresh after despawn")
	var second: Node = _first_escort()
	assert_ne(second, null)
	assert_ne(second.get_instance_id(), first_id, "second freighter is a new node")


func test_escort_despawns_on_mission_abandon() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	assert_true(_mission._accept_runtime(_make_escort_offer(&"rad_r8_escort_ab"), true))
	world.ensure_escort_freighter()
	await get_tree().process_frame
	assert_eq(_live_escort_count(), 1)

	_mission.abandon()
	assert_false(_mission.has_active())
	await get_tree().process_frame
	assert_eq(_live_escort_count(), 0, "REPAIR-8: abandoning an escort must free the freighter")


func test_two_hostiles_die_same_frame_releases_combat_lock() -> void:
	## Both call _die in the same frame while the other is still valid but
	## already dead. Without is_alive() in _release_combat_lock_if_last the
	## lock sticks at 1x forever.
	var host: Node3D = Node3D.new()
	add_child_autofree(host)

	var a: HostileNpc = HostileNpc.spawn_under(host, Vector3(10.0, 0.0, 0.0))
	var b: HostileNpc = HostileNpc.spawn_under(host, Vector3(-10.0, 0.0, 0.0))
	await get_tree().process_frame
	assert_true(TimeScale.is_combat_locked(), "live hostiles hold the combat lock")

	a.take_damage(LETHAL)
	b.take_damage(LETHAL)
	assert_false(a.is_alive())
	assert_false(b.is_alive())
	assert_false(
		TimeScale.is_combat_locked(),
		"REPAIR-8: last hostile death must release combat lock even if another dead node is still valid"
	)
