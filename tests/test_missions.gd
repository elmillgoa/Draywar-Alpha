extends GutTest

## Mission templates, outcomes, console — Alpha A3.

const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_BETA: StringName = &"entity_beta_syndicate"
const CONTRACT_ALPHA: StringName = &"contract_courier_alpha"
const CONTRACT_BETA: StringName = &"contract_courier_beta"
const TOLERANCE: float = 0.0001

var _mission: MissionService = null
var _console: ConsoleService = null
var _output: PackedStringArray = []
var _mission_completed: Array[StringName] = []
var _mission_failed: Array[StringName] = []
var _mission_abandoned: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	_output = []
	_mission_completed = []
	_mission_failed = []
	_mission_abandoned = []

	_mission = MissionService.new()
	add_child_autofree(_mission)
	_mission.reset()

	_console = ConsoleService.new()
	EventBus.on_console_output.connect(_on_console_output)
	EventBus.on_mission_completed.connect(_on_mission_completed)
	EventBus.on_mission_failed.connect(_on_mission_failed)
	EventBus.on_mission_abandoned.connect(_on_mission_abandoned)


func after_each() -> void:
	if EventBus.on_console_output.is_connected(_on_console_output):
		EventBus.on_console_output.disconnect(_on_console_output)
	if EventBus.on_mission_completed.is_connected(_on_mission_completed):
		EventBus.on_mission_completed.disconnect(_on_mission_completed)
	if EventBus.on_mission_failed.is_connected(_on_mission_failed):
		EventBus.on_mission_failed.disconnect(_on_mission_failed)
	if EventBus.on_mission_abandoned.is_connected(_on_mission_abandoned):
		EventBus.on_mission_abandoned.disconnect(_on_mission_abandoned)
	StandingService.reset_to_defaults()


func _on_console_output(line: String) -> void:
	_output.append(line)


func _on_mission_completed(template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_mission_completed.append(template_id)


func _on_mission_failed(template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_mission_failed.append(template_id)


func _on_mission_abandoned(template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_mission_abandoned.append(template_id)


func _attributed(result: Dictionary) -> bool:
	var value: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	return value


func _delta_from(result: Dictionary) -> float:
	var value: float = result[BalanceStanding.REPORT_KEY_DELTA]
	return value


func test_contract_types_loaded_under_budget() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY)
	assert_gte(ids.size(), 1, "at least one mission template")
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[BalanceStanding.MISSION_CONTENT_CATEGORY])
	assert_true(ContentLibrary.has_item(CONTRACT_ALPHA))
	assert_true(ContentLibrary.has_item(CONTRACT_BETA))
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))


func test_contract_type_requires_offering_entity() -> void:
	var contract: ContractType = ContractType.new()
	contract.id = &"fixture_contract"
	contract.display_name = "Fixture"
	var joined: String = "\n".join(contract.validation_errors())
	assert_string_contains(joined, "offering_entity_id")
	contract.offering_entity_id = ENTITY_REACH
	contract.kind = BalanceStanding.MISSION_KIND_DELIVERY
	assert_eq(contract.validation_errors().size(), 0)


func test_mission_complete_positive_delta() -> void:
	# Pay path needs a wallet in-tree (A5); standing still applies without one.
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	StandingService.set_entity_standing(ENTITY_REACH, 5.0)
	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_true(_mission.accept(CONTRACT_ALPHA))
	var result: Dictionary = _mission.complete()
	assert_true(_attributed(result))
	var delta: float = _delta_from(result)
	assert_gt(delta, 0.0)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_REACH), before + delta, TOLERANCE)
	assert_eq(_mission_completed.size(), 1)
	assert_false(_mission.has_active())


func test_mission_fail_milder_negative_than_abandon() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, 20.0)
	assert_true(_mission.accept(CONTRACT_ALPHA))
	var fail_result: Dictionary = _mission.fail()
	var fail_delta: float = _delta_from(fail_result)
	assert_lt(fail_delta, 0.0)
	assert_eq(_mission_failed.size(), 1)

	StandingService.set_entity_standing(ENTITY_REACH, 20.0)
	assert_true(_mission.accept(CONTRACT_ALPHA))
	var abandon_result: Dictionary = _mission.abandon()
	var abandon_delta: float = _delta_from(abandon_result)
	assert_lt(abandon_delta, 0.0)
	assert_eq(_mission_abandoned.size(), 1)

	assert_lt(abandon_delta, fail_delta, "abandon must be stronger negative than fail")
	assert_almost_eq(fail_delta, BalanceStanding.MISSION_FAIL_DELTA, TOLERANCE)
	assert_almost_eq(abandon_delta, BalanceStanding.MISSION_ABANDON_DELTA, TOLERANCE)


func test_mission_one_active_max() -> void:
	assert_true(_mission.accept(CONTRACT_ALPHA))
	assert_false(_mission.accept(CONTRACT_BETA))
	assert_eq(_mission.active_template_id(), CONTRACT_ALPHA)


func test_mission_complete_magnitude_matches_balance_default() -> void:
	StandingService.set_entity_standing(ENTITY_BETA, -2.0)
	assert_true(_mission.accept(CONTRACT_BETA))
	var result: Dictionary = _mission.complete()
	assert_almost_eq(_delta_from(result), BalanceStanding.MISSION_COMPLETE_DELTA, TOLERANCE)


func test_console_mission_complete() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, 1.0)
	_console.start()
	_console.submit("mission accept contract_courier_alpha")
	assert_true(_mission.has_active())
	_console.submit("mission complete")
	assert_false(_mission.has_active())
	assert_gt(StandingService.get_entity_standing(ENTITY_REACH), 1.0)
	assert_string_contains("\n".join(_output), "complete")
