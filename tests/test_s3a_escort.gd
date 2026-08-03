extends GutTest

## Escort job kind end-to-end — Steam S3a.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3a

const ENTITY_REACH: StringName = &"entity_reach_authority"
const DEST_BETA: StringName = &"station_beta_hub"
const TOLERANCE: float = 0.0001

var _mission: MissionService = null
var _completed: Array[StringName] = []
var _failed: Array[StringName] = []
var _abandoned: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	_completed = []
	_failed = []
	_abandoned = []
	_mission = MissionService.new()
	add_child_autofree(_mission)
	_mission.reset()
	EventBus.on_mission_completed.connect(_on_completed)
	EventBus.on_mission_failed.connect(_on_failed)
	EventBus.on_mission_abandoned.connect(_on_abandoned)


func after_each() -> void:
	if EventBus.on_mission_completed.is_connected(_on_completed):
		EventBus.on_mission_completed.disconnect(_on_completed)
	if EventBus.on_mission_failed.is_connected(_on_failed):
		EventBus.on_mission_failed.disconnect(_on_failed)
	if EventBus.on_mission_abandoned.is_connected(_on_abandoned):
		EventBus.on_mission_abandoned.disconnect(_on_abandoned)
	StandingService.reset_to_defaults()
	BoardService.reset()
	MarketService.reset()
	WorldClockHelpers.reset_clock()


func _on_completed(template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_completed.append(template_id)


func _on_failed(template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_failed.append(template_id)


func _on_abandoned(template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_abandoned.append(template_id)


func _attributed(result: Dictionary) -> bool:
	return result.get(BalanceStanding.REPORT_KEY_ATTRIBUTED, false) == true


func _pay_credits(result: Dictionary) -> int:
	var raw: Variant = result.get(&"pay_credits", 0)
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	return 0


func _flag(data: Dictionary, key: StringName) -> bool:
	return data.get(key, false) == true


func _make_escort_offer(offer_id: StringName = &"rad_test_escort_0") -> Dictionary:
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


func test_contract_type_escort_requires_destination() -> void:
	var ct: ContractType = ContractType.new()
	ct.id = &"test_escort_bad"
	ct.display_name = "Bad escort"
	ct.kind = BalanceStanding.MISSION_KIND_ESCORT
	ct.offering_entity_id = ENTITY_REACH
	ct.pay_credits = 100
	var problems: PackedStringArray = ct.validation_errors()
	var joined: String = "\n".join(problems)
	assert_true(joined.contains("destination_station_id"), "escort needs dest")
	ct.destination_station_id = DEST_BETA
	problems = ct.validation_errors()
	joined = "\n".join(problems)
	assert_false(joined.contains("destination_station_id"))


func test_accept_escort_objective_ready_while_alive_complete_at_dest() -> void:
	# Pay path needs a wallet in-tree (A5); standing still applies without one.
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	var offer: Dictionary = _make_escort_offer()
	assert_true(_mission._accept_runtime(offer, true))
	assert_true(_mission.has_active())
	assert_eq(_mission.active_kind(), BalanceStanding.MISSION_KIND_ESCORT)
	assert_true(_mission.is_objective_ready(), "alive freighter → objective ready")
	assert_true(_mission.is_escort_alive())
	assert_true(_mission.can_complete_at_station(DEST_BETA))
	assert_false(_mission.can_complete_at_station(&"station_alpha_port"))
	var result: Dictionary = _mission.try_complete_at(DEST_BETA)
	assert_true(_attributed(result))
	assert_eq(_pay_credits(result), 220)
	assert_false(_mission.has_active())
	assert_eq(_completed.size(), 1)
	var after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(after - before, BalanceStanding.MISSION_COMPLETE_DELTA, TOLERANCE)


func test_kill_freighter_fails_mission() -> void:
	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_true(_mission._accept_runtime(_make_escort_offer(&"rad_test_escort_fail"), true))
	_mission.notify_escort_destroyed()
	assert_false(_mission.has_active())
	assert_eq(_failed.size(), 1)
	var after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(after - before, BalanceStanding.MISSION_FAIL_DELTA, TOLERANCE)


func test_abandon_escort_uses_abandon_delta() -> void:
	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_true(_mission._accept_runtime(_make_escort_offer(&"rad_test_escort_ab"), true))
	var result: Dictionary = _mission.abandon()
	assert_true(_attributed(result))
	assert_eq(_abandoned.size(), 1)
	var after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(after - before, BalanceStanding.MISSION_ABANDON_DELTA, TOLERANCE)


func test_save_load_active_escort_runtime() -> void:
	assert_true(_mission._accept_runtime(_make_escort_offer(&"rad_test_escort_save"), true))
	var section: Dictionary = _mission.to_section()
	assert_true(_flag(section, BalanceSession.MISSION_KEY_RUNTIME))
	assert_eq(str(section.get(BalanceSession.MISSION_KEY_KIND, "")), "escort")
	assert_eq(
		str(section.get(BalanceSession.MISSION_KEY_DESTINATION_STATION_ID, "")), String(DEST_BETA)
	)
	assert_true(_flag(section, BalanceSession.MISSION_KEY_ESCORT_ALIVE))

	_mission.reset()
	assert_false(_mission.has_active())
	_mission.apply_section(section)
	assert_true(_mission.has_active())
	assert_eq(_mission.active_kind(), BalanceStanding.MISSION_KIND_ESCORT)
	assert_true(_mission.is_escort_alive())
	assert_eq(_mission.active_destination_station_id(), DEST_BETA)
	assert_true(_mission.is_runtime_mission())


func test_one_active_mission_blocks_second_accept() -> void:
	assert_true(_mission._accept_runtime(_make_escort_offer(&"rad_test_escort_one"), true))
	assert_false(_mission._accept_runtime(_make_escort_offer(&"rad_test_escort_two"), true))
	assert_eq(_mission.active_template_id(), &"rad_test_escort_one")


func test_legacy_courier_still_accepts_from_content() -> void:
	var courier: StringName = &"contract_courier_alpha"
	assert_true(ContentLibrary.has_item(courier))
	assert_true(_mission.accept(courier))
	assert_eq(_mission.active_kind(), BalanceStanding.MISSION_KIND_DELIVERY)
	assert_false(_mission.is_runtime_mission())


func test_ensure_escort_freighter_spawns_and_death_fails_mission() -> void:
	## Same ensure path SystemWorld uses after accept / undock / system enter.
	## Thin freighter: complete-at-dest still only needs escort_alive flag (no
	## world freighter required at the destination pad) — death is the fail path.
	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_alpha"
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame
	assert_eq(_live_escort_count(), 0, "no freighter before escort accept")

	assert_true(_mission._accept_runtime(_make_escort_offer(&"rad_test_escort_world"), true))
	assert_true(_mission.has_active())
	assert_eq(_mission.active_kind(), BalanceStanding.MISSION_KIND_ESCORT)
	# Explicit ensure (mirrors event-driven path; also covers accept-before-world).
	world.ensure_escort_freighter()
	await get_tree().process_frame
	assert_eq(_live_escort_count(), 1, "ensure must spawn MissionEscortShip")
	var freighter: Node = _first_escort()
	assert_ne(freighter, null)
	assert_true(freighter is MissionEscortShip)
	assert_true(freighter.has_meta(BalanceBoard.META_MISSION_ESCORT))

	# Killing the hull must fail the job (standing fail delta already covered elsewhere).
	if freighter.has_method(&"take_damage"):
		freighter.call(&"take_damage", BalanceBoard.ESCORT_HULL_HP + 10.0)
	await get_tree().process_frame
	assert_false(_mission.has_active(), "freighter death fails escort mission")
	assert_eq(_failed.size(), 1, "notify_escort_destroyed path must emit mission failed")


func test_career_save_restores_boards_and_active_escort() -> void:
	## CareerSave gather + apply restores board steps/claims AND runtime escort.
	WorldClock.advance_seconds(BalanceBoard.BOARD_STEP_SECONDS * 2.0)
	var board_ids: Array[StringName] = BoardService.offer_ids_for_station(&"station_alpha_port")
	assert_gt(board_ids.size(), 0)
	var claimed_id: StringName = board_ids[0]
	assert_true(BoardService.claim_offer(claimed_id))
	var steps_before: int = BoardService.steps_done()
	assert_eq(steps_before, 2)

	assert_true(_mission._accept_runtime(_make_escort_offer(&"rad_test_escort_career"), true))
	assert_true(_mission.has_active())
	assert_true(_mission.is_runtime_mission())
	assert_true(_mission.is_escort_alive())

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceBoard.SAVE_SECTION_KEY), "boards always gathered")
	assert_true(sections.has(BalanceSession.SAVE_SECTION_MISSION), "active escort gathered")

	_mission.reset()
	BoardService.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	assert_false(_mission.has_active())
	assert_eq(BoardService.steps_done(), 0)

	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_eq(BoardService.steps_done(), steps_before, "board steps survive CareerSave")
	assert_false(BoardService.is_offer_available(claimed_id), "mid-cycle claim survives CareerSave")
	assert_true(_mission.has_active(), "escort mission restored")
	assert_eq(_mission.active_kind(), BalanceStanding.MISSION_KIND_ESCORT)
	assert_true(_mission.is_runtime_mission())
	assert_true(_mission.is_escort_alive())
	assert_eq(_mission.active_destination_station_id(), DEST_BETA)
	assert_eq(_mission.active_template_id(), &"rad_test_escort_career")


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
			return node
	return null
