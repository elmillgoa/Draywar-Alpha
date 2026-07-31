extends GutTest

## E1.3 second job kind — thin bounty (kill then turn in).
##
## Implements: docs/BETA_E1_LEGIBLE_SECTOR.md E1.3

const ENTITY_BETA: StringName = &"entity_beta_syndicate"
const ENTITY_GAMMA: StringName = &"entity_gamma_collective"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const CONTRACT_BOUNTY_BETA: StringName = &"contract_bounty_beta_spit"
const CONTRACT_BOUNTY_GAMMA: StringName = &"contract_bounty_gamma_rim"
const CONTRACT_DELIVERY: StringName = &"contract_courier_alpha"
const STATION_BETA_SPIT: StringName = &"station_beta_spit"
const STATION_BETA_HUB: StringName = &"station_beta_hub"
const STATION_GAMMA_RIM: StringName = &"station_gamma_rim"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const TOLERANCE: float = 0.0001
const PAY_BETA: int = 180

var _mission: MissionService = null
var _wallet: WalletService = null
var _completed: Array[StringName] = []
var _abandoned: Array[StringName] = []
var _failed: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	_completed = []
	_abandoned = []
	_failed = []
	_mission = MissionService.new()
	add_child_autofree(_mission)
	_wallet = WalletService.new()
	add_child_autofree(_wallet)
	_mission.reset()
	_wallet.reset()
	EventBus.on_mission_completed.connect(_on_completed)
	EventBus.on_mission_abandoned.connect(_on_abandoned)
	EventBus.on_mission_failed.connect(_on_failed)


func after_each() -> void:
	if EventBus.on_mission_completed.is_connected(_on_completed):
		EventBus.on_mission_completed.disconnect(_on_completed)
	if EventBus.on_mission_abandoned.is_connected(_on_abandoned):
		EventBus.on_mission_abandoned.disconnect(_on_abandoned)
	if EventBus.on_mission_failed.is_connected(_on_failed):
		EventBus.on_mission_failed.disconnect(_on_failed)
	StandingService.reset_to_defaults()


func _on_completed(template_id: StringName, _entity_id: StringName, _standing_delta: float) -> void:
	_completed.append(template_id)


func _on_abandoned(template_id: StringName, _entity_id: StringName, _standing_delta: float) -> void:
	_abandoned.append(template_id)


func _on_failed(template_id: StringName, _entity_id: StringName, _standing_delta: float) -> void:
	_failed.append(template_id)


func _attributed(result: Dictionary) -> bool:
	return result[BalanceStanding.REPORT_KEY_ATTRIBUTED] == true


func _delta_from(result: Dictionary) -> float:
	var value: float = result[BalanceStanding.REPORT_KEY_DELTA]
	return value


func test_bounty_templates_load_under_budget() -> void:
	assert_true(ContentLibrary.has_item(CONTRACT_BOUNTY_BETA))
	assert_true(ContentLibrary.has_item(CONTRACT_BOUNTY_GAMMA))
	var beta: ContractType = ContentLibrary.item(CONTRACT_BOUNTY_BETA) as ContractType
	var gamma: ContractType = ContentLibrary.item(CONTRACT_BOUNTY_GAMMA) as ContractType
	assert_eq(beta.kind, BalanceStanding.MISSION_KIND_BOUNTY)
	assert_eq(gamma.kind, BalanceStanding.MISSION_KIND_BOUNTY)
	assert_eq(beta.target_system_id, SYSTEM_BETA)
	assert_eq(gamma.target_system_id, SYSTEM_GAMMA)
	assert_eq(beta.destination_station_id, STATION_BETA_SPIT)
	assert_eq(gamma.destination_station_id, STATION_GAMMA_RIM)
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY)
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[BalanceStanding.MISSION_CONTENT_CATEGORY])
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))


func test_bounty_accept_kill_in_target_system_unlocks_turn_in() -> void:
	assert_true(_mission.accept(CONTRACT_BOUNTY_BETA))
	assert_eq(_mission.active_kind(), BalanceStanding.MISSION_KIND_BOUNTY)
	assert_false(_mission.is_objective_ready())
	assert_false(_mission.can_complete_at_station(STATION_BETA_SPIT))
	# Wrong system kill does nothing.
	EventBus.on_hostile_killed.emit(SYSTEM_ALPHA, &"entity_nobody")
	assert_false(_mission.is_objective_ready())
	# Kill in target system unlocks objective (not auto-pay).
	EventBus.on_hostile_killed.emit(SYSTEM_BETA, &"entity_nobody")
	assert_true(_mission.is_objective_ready())
	assert_true(_mission.has_active(), "still active until turn-in")
	assert_true(_mission.can_complete_at_station(STATION_BETA_SPIT))
	assert_false(_mission.can_complete_at_station(STATION_BETA_HUB))


func test_bounty_complete_pays_credits_and_standing() -> void:
	StandingService.set_entity_standing(ENTITY_BETA, 0.0)
	assert_true(_mission.accept(CONTRACT_BOUNTY_BETA))
	EventBus.on_hostile_killed.emit(SYSTEM_BETA, &"entity_nobody")
	var credits_before: int = _wallet.credits()
	var standing_before: float = StandingService.get_entity_standing(ENTITY_BETA)
	var blocked: Dictionary = _mission.try_complete_at(STATION_BETA_HUB)
	assert_false(_attributed(blocked), "wrong station")
	assert_true(_mission.has_active())
	var result: Dictionary = _mission.try_complete_at(STATION_BETA_SPIT)
	assert_true(_attributed(result))
	assert_false(_mission.has_active())
	assert_eq(_completed.size(), 1)
	assert_eq(_wallet.credits(), credits_before + PAY_BETA)
	assert_gt(StandingService.get_entity_standing(ENTITY_BETA), standing_before)
	assert_almost_eq(_delta_from(result), BalanceStanding.MISSION_COMPLETE_DELTA, TOLERANCE)


func test_bounty_cannot_complete_before_kill() -> void:
	assert_true(_mission.accept(CONTRACT_BOUNTY_BETA))
	var result: Dictionary = _mission.complete()
	assert_false(_attributed(result))
	assert_true(_mission.has_active())
	assert_eq(_wallet.credits(), BalanceEconomy.STARTING_CREDITS)
	assert_eq(_completed.size(), 0)


func test_bounty_abandon_applies_negative_delta() -> void:
	StandingService.set_entity_standing(ENTITY_BETA, 20.0)
	assert_true(_mission.accept(CONTRACT_BOUNTY_BETA))
	var before: float = StandingService.get_entity_standing(ENTITY_BETA)
	var result: Dictionary = _mission.abandon()
	assert_true(_attributed(result))
	assert_lt(_delta_from(result), 0.0)
	assert_almost_eq(_delta_from(result), BalanceStanding.MISSION_ABANDON_DELTA, TOLERANCE)
	assert_lt(StandingService.get_entity_standing(ENTITY_BETA), before)
	assert_eq(_abandoned.size(), 1)
	assert_false(_mission.has_active())


func test_bounty_fail_applies_milder_negative_than_abandon() -> void:
	StandingService.set_entity_standing(ENTITY_GAMMA, 20.0)
	assert_true(_mission.accept(CONTRACT_BOUNTY_GAMMA))
	var fail_result: Dictionary = _mission.fail()
	var fail_delta: float = _delta_from(fail_result)
	assert_lt(fail_delta, 0.0)
	assert_eq(_failed.size(), 1)

	StandingService.set_entity_standing(ENTITY_GAMMA, 20.0)
	assert_true(_mission.accept(CONTRACT_BOUNTY_GAMMA))
	var abandon_result: Dictionary = _mission.abandon()
	var abandon_delta: float = _delta_from(abandon_result)
	assert_lt(abandon_delta, fail_delta)


func test_delivery_still_works_without_kill() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, 1.0)
	assert_true(_mission.accept(CONTRACT_DELIVERY))
	assert_eq(_mission.active_kind(), BalanceStanding.MISSION_KIND_DELIVERY)
	assert_true(_mission.is_objective_ready())
	assert_true(_mission.can_complete_at_station(STATION_BETA_HUB))
	var result: Dictionary = _mission.try_complete_at(STATION_BETA_HUB)
	assert_true(_attributed(result))
	assert_false(_mission.has_active())
	assert_eq(_completed.size(), 1)


func test_bounty_objective_round_trips_in_mission_section() -> void:
	assert_true(_mission.accept(CONTRACT_BOUNTY_BETA))
	EventBus.on_hostile_killed.emit(SYSTEM_BETA, &"entity_nobody")
	assert_true(_mission.is_objective_ready())
	var section: Dictionary = _mission.to_section()
	assert_true(section.has(BalanceSession.MISSION_KEY_OBJECTIVE_MET))
	var met_flag: bool = section[BalanceSession.MISSION_KEY_OBJECTIVE_MET] == true
	assert_true(met_flag)
	_mission.reset()
	assert_false(_mission.has_active())
	_mission.apply_section(section)
	assert_true(_mission.has_active())
	assert_eq(_mission.active_template_id(), CONTRACT_BOUNTY_BETA)
	assert_true(_mission.is_objective_ready())
	assert_true(_mission.can_complete_at_station(STATION_BETA_SPIT))


func test_station_menu_bounty_label_and_turn_in_after_kill() -> void:
	# Use before_each mission/wallet only — a second MissionService in the group
	# steals StationMenu's group lookup.
	assert_true(_mission.accept(CONTRACT_BOUNTY_BETA))
	var menu: StationMenu = StationMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	EventBus.on_docked.emit(STATION_BETA_SPIT)
	assert_true(menu.visible)
	# Before kill: no turn-in.
	assert_false(_mission.can_complete_at_station(STATION_BETA_SPIT))
	EventBus.on_hostile_killed.emit(SYSTEM_BETA, &"entity_nobody")
	EventBus.on_docked.emit(STATION_BETA_SPIT)
	await get_tree().process_frame
	assert_true(_mission.can_complete_at_station(STATION_BETA_SPIT))
	var credits_before: int = _wallet.credits()
	menu._on_turn_in_job_pressed()
	await get_tree().process_frame
	assert_false(_mission.has_active())
	assert_eq(_wallet.credits(), credits_before + PAY_BETA)

	# Board labels distinguish bounty when idle.
	EventBus.on_docked.emit(STATION_BETA_SPIT)
	await get_tree().process_frame
	var labels: PackedStringArray = _accept_button_labels(menu)
	var found_bounty: bool = false
	for label: String in labels:
		if label.findn("bounty") >= 0 or label.findn("clear") >= 0:
			found_bounty = true
			break
	assert_true(
		found_bounty, "board should show a bounty-style accept label: %s" % " | ".join(labels)
	)


func test_contract_type_bounty_requires_target_system() -> void:
	var contract: ContractType = ContractType.new()
	contract.id = &"fixture_bounty"
	contract.display_name = "Fixture bounty"
	contract.offering_entity_id = ENTITY_BETA
	contract.kind = BalanceStanding.MISSION_KIND_BOUNTY
	contract.destination_station_id = STATION_BETA_SPIT
	var joined: String = "\n".join(contract.validation_errors())
	assert_string_contains(joined, "target_system_id")
	contract.target_system_id = SYSTEM_BETA
	assert_eq(contract.validation_errors().size(), 0)


func _accept_button_labels(menu: StationMenu) -> PackedStringArray:
	var out: PackedStringArray = []
	_collect_accept_labels(menu, out)
	return out


func _collect_accept_labels(node: Node, out: PackedStringArray) -> void:
	if node is Button:
		var btn: Button = node as Button
		var text: String = btn.text
		if text.findn("Accept") >= 0:
			out.append(text)
	for child: Node in node.get_children():
		_collect_accept_labels(child, out)
