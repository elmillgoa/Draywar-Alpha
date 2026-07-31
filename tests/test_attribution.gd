extends GutTest

## Kill attribution, stickiness, trade, kill console — Alpha A3.

const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_BETA: StringName = &"entity_beta_syndicate"
const ENTITY_GAMMA: StringName = &"entity_gamma_collective"
const ENTITY_HAULERS: StringName = &"entity_free_haulers"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const TOLERANCE: float = 0.0001

var _attribution: AttributionService = null
var _console: ConsoleService = null
var _output: PackedStringArray = []
var _kill_attributed: Array[StringName] = []
var _kill_unattributed: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	_output = []
	_kill_attributed = []
	_kill_unattributed = []

	_attribution = AttributionService.new()
	add_child_autofree(_attribution)

	_console = ConsoleService.new()
	EventBus.on_console_output.connect(_on_console_output)
	EventBus.on_kill_attributed.connect(_on_kill_attributed)
	EventBus.on_kill_unattributed.connect(_on_kill_unattributed)


func after_each() -> void:
	if EventBus.on_console_output.is_connected(_on_console_output):
		EventBus.on_console_output.disconnect(_on_console_output)
	if EventBus.on_kill_attributed.is_connected(_on_kill_attributed):
		EventBus.on_kill_attributed.disconnect(_on_kill_attributed)
	if EventBus.on_kill_unattributed.is_connected(_on_kill_unattributed):
		EventBus.on_kill_unattributed.disconnect(_on_kill_unattributed)
	StandingService.reset_to_defaults()


func _on_console_output(line: String) -> void:
	_output.append(line)


func _on_kill_attributed(
	system_id: StringName, _entity_id: StringName, _delta: float, _reason: StringName
) -> void:
	_kill_attributed.append(system_id)


func _on_kill_unattributed(system_id: StringName, _victim: StringName) -> void:
	_kill_unattributed.append(system_id)


func _attributed(result: Dictionary) -> bool:
	var value: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	return value


func _entity_from(result: Dictionary) -> StringName:
	var value: StringName = result[BalanceStanding.REPORT_KEY_ENTITY_ID]
	return value


func test_systems_have_distinct_policing() -> void:
	var alpha: StarSystem = ContentLibrary.item(SYSTEM_ALPHA) as StarSystem
	var beta: StarSystem = ContentLibrary.item(SYSTEM_BETA) as StarSystem
	var gamma: StarSystem = ContentLibrary.item(SYSTEM_GAMMA) as StarSystem
	assert_eq(alpha.policing, StarSystem.POLICED_BY_PATROLS)
	assert_eq(beta.policing, StarSystem.POLICED_BY_CONTESTED)
	assert_eq(gamma.policing, StarSystem.POLICED_BY_NOBODY)


func test_patrolled_kill_drops_controller_standing() -> void:
	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(before, BalanceStanding.DEFAULT_STANDING, TOLERANCE)
	var result: Dictionary = _attribution.report_kill(SYSTEM_ALPHA, &"", 0, false)
	assert_true(_attributed(result))
	assert_eq(_entity_from(result), ENTITY_REACH)
	var after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(after, before + BalanceStanding.COMBAT_KILL_DELTA, TOLERANCE)
	assert_lt(after, before)
	assert_eq(_kill_attributed.size(), 1)
	assert_eq(_kill_attributed[0], SYSTEM_ALPHA)


func test_lawless_kill_without_evidence_no_standing_change() -> void:
	var before_reach: float = StandingService.get_entity_standing(ENTITY_REACH)
	# Non-zero baseline so a silent no-op cannot hide behind defaults.
	StandingService.set_entity_standing(ENTITY_GAMMA, -7.0)
	var before_gamma: float = StandingService.get_entity_standing(ENTITY_GAMMA)

	var result: Dictionary = _attribution.report_kill(SYSTEM_GAMMA, ENTITY_REACH, 5, false)
	assert_false(_attributed(result))
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_GAMMA), before_gamma, TOLERANCE)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_REACH), before_reach, TOLERANCE)
	assert_eq(_kill_unattributed.size(), 1)
	assert_eq(_kill_unattributed[0], SYSTEM_GAMMA)


func test_lawless_kill_with_evidence_hits_controller() -> void:
	StandingService.set_entity_standing(ENTITY_GAMMA, 4.0)
	var before: float = StandingService.get_entity_standing(ENTITY_GAMMA)
	var result: Dictionary = _attribution.report_kill(SYSTEM_GAMMA, ENTITY_HAULERS, 0, true)
	assert_true(_attributed(result))
	assert_eq(_entity_from(result), ENTITY_GAMMA)
	var after: float = StandingService.get_entity_standing(ENTITY_GAMMA)
	assert_almost_eq(after, before + BalanceStanding.COMBAT_KILL_DELTA, TOLERANCE)


func test_contested_zero_witnesses_no_evidence_no_change() -> void:
	StandingService.set_entity_standing(ENTITY_BETA, 11.0)
	var before: float = StandingService.get_entity_standing(ENTITY_BETA)
	var result: Dictionary = _attribution.report_kill(SYSTEM_BETA, &"", 0, false)
	assert_false(_attributed(result))
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_BETA), before, TOLERANCE)


func test_contested_with_witness_attributes() -> void:
	StandingService.set_entity_standing(ENTITY_BETA, 11.0)
	var before: float = StandingService.get_entity_standing(ENTITY_BETA)
	var result: Dictionary = _attribution.report_kill(
		SYSTEM_BETA, &"", BalanceStanding.ATTRIBUTION_WITNESS_THRESHOLD, false
	)
	assert_true(_attributed(result))
	assert_eq(_entity_from(result), ENTITY_BETA)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_BETA),
		before + BalanceStanding.COMBAT_KILL_DELTA,
		TOLERANCE
	)


func test_contested_with_evidence_no_witness_attributes() -> void:
	StandingService.set_entity_standing(ENTITY_BETA, 6.0)
	var before: float = StandingService.get_entity_standing(ENTITY_BETA)
	var result: Dictionary = _attribution.report_kill(SYSTEM_BETA, &"", 0, true)
	assert_true(_attributed(result))
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_BETA),
		before + BalanceStanding.COMBAT_KILL_DELTA,
		TOLERANCE
	)


func test_combat_kill_ripples_to_rival() -> void:
	# Reach kill: rival Beta gets inverse (positive) echo of the negative hit.
	StandingService.set_entity_standing(ENTITY_REACH, 0.0)
	StandingService.set_entity_standing(ENTITY_BETA, 0.0)
	_attribution.report_kill(SYSTEM_ALPHA, &"", 0, false)
	var reach: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(reach, BalanceStanding.COMBAT_KILL_DELTA, TOLERANCE)
	var beta: float = StandingService.get_entity_standing(ENTITY_BETA)
	var expected_ripple: float = (
		-BalanceStanding.COMBAT_KILL_DELTA * BalanceStanding.RIPPLE_RIVAL_FRACTION
	)
	expected_ripple = clampf(
		expected_ripple, -BalanceStanding.RIPPLE_MAX_ABS, BalanceStanding.RIPPLE_MAX_ABS
	)
	assert_almost_eq(beta, expected_ripple, TOLERANCE)
	assert_gt(beta, 0.0)


func test_stickiness_reduces_positive_at_deep_negative() -> void:
	var raw: float = BalanceStanding.MISSION_COMPLETE_DELTA
	assert_gt(raw, 0.0)

	var at_zero: float = StandingService.adjust_for_stickiness(0.0, raw)
	assert_almost_eq(at_zero, raw, TOLERANCE)

	var deep: float = BalanceStanding.STICKY_NEGATIVE_FLOOR - 10.0
	assert_lte(deep, BalanceStanding.STICKY_NEGATIVE_FLOOR)
	var sticky: float = StandingService.adjust_for_stickiness(deep, raw)
	assert_almost_eq(sticky, raw * BalanceStanding.STICKY_POSITIVE_FACTOR, TOLERANCE)
	assert_lt(sticky, at_zero)

	StandingService.set_entity_standing(ENTITY_REACH, deep)
	var applied_deep: float = StandingService.apply_entity_delta(
		ENTITY_REACH, raw, BalanceStanding.REASON_MISSION_COMPLETE, false
	)
	assert_almost_eq(applied_deep, sticky, TOLERANCE)

	StandingService.set_entity_standing(ENTITY_REACH, 0.0)
	var applied_zero: float = StandingService.apply_entity_delta(
		ENTITY_REACH, raw, BalanceStanding.REASON_MISSION_COMPLETE, false
	)
	assert_almost_eq(applied_zero, raw, TOLERANCE)
	assert_lt(applied_deep, applied_zero)


func test_stickiness_does_not_reduce_negative_deltas() -> void:
	var raw: float = BalanceStanding.COMBAT_KILL_DELTA
	assert_lt(raw, 0.0)
	var deep: float = -50.0
	var adjusted: float = StandingService.adjust_for_stickiness(deep, raw)
	assert_almost_eq(adjusted, raw, TOLERANCE)


func test_legal_trade_small_positive_soft_capped() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, 10.0)
	var applied: float = StandingService.record_legal_trade(ENTITY_REACH)
	assert_almost_eq(applied, BalanceStanding.TRADE_LEGAL_DELTA, TOLERANCE)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		10.0 + BalanceStanding.TRADE_LEGAL_DELTA,
		TOLERANCE
	)

	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TRADE_STANDING_SOFT_CAP)
	var capped: float = StandingService.record_legal_trade(ENTITY_REACH)
	assert_almost_eq(capped, 0.0, TOLERANCE)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		BalanceStanding.TRADE_STANDING_SOFT_CAP,
		TOLERANCE
	)

	# Near cap: gain only up to soft cap.
	var near: float = BalanceStanding.TRADE_STANDING_SOFT_CAP - 0.3
	StandingService.set_entity_standing(ENTITY_REACH, near)
	var partial: float = StandingService.record_legal_trade(ENTITY_REACH)
	assert_gt(partial, 0.0)
	assert_lt(partial, BalanceStanding.TRADE_LEGAL_DELTA + TOLERANCE)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		BalanceStanding.TRADE_STANDING_SOFT_CAP,
		TOLERANCE
	)


func test_console_kill_patrolled_attributes() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, 0.0)
	_console.start()
	_console.submit("kill system_alpha")
	assert_lt(StandingService.get_entity_standing(ENTITY_REACH), 0.0)
	assert_gt(_output.size(), 0)
	assert_string_contains("\n".join(_output), "attributed")


func test_console_kill_lawless_clean_unattributed() -> void:
	StandingService.set_entity_standing(ENTITY_GAMMA, 3.0)
	var before: float = StandingService.get_entity_standing(ENTITY_GAMMA)
	_console.start()
	_console.submit("kill system_gamma")
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_GAMMA), before, TOLERANCE)
	assert_string_contains("\n".join(_output), "not attributed")


func test_console_trade_legal() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, 0.0)
	_console.start()
	_console.submit("trade legal entity_reach_authority")
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		BalanceStanding.TRADE_LEGAL_DELTA,
		TOLERANCE
	)
