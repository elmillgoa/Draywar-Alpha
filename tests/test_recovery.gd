extends GutTest

## Personal recovery path — Alpha A4.

const ENTITY_REACH: StringName = &"entity_reach_authority"
const PERSON_MENDI: StringName = &"person_ra_mendi"
const CHAIN_MENDI: StringName = &"recovery_reach_mendi"
const STEP_DENIABLE: StringName = &"step_deniable_package"
const TOLERANCE: float = 0.0001

## Deep negative Entity standing for sticky climb fixtures (Hostile band).
const DEEP_NEGATIVE: float = -70.0

var _recovery: RecoveryService = null
var _console: ConsoleService = null
var _output: PackedStringArray = []
var _completed: Array[StringName] = []
var _closed_people: Array[StringName] = []
var _offered: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	_output = []
	_completed = []
	_closed_people = []
	_offered = []

	_recovery = RecoveryService.new()
	add_child_autofree(_recovery)
	_recovery.reset()

	_console = ConsoleService.new()
	EventBus.on_console_output.connect(_on_console_output)
	EventBus.on_recovery_completed.connect(_on_recovery_completed)
	EventBus.on_person_closed.connect(_on_person_closed)
	EventBus.on_recovery_offered.connect(_on_recovery_offered)


func after_each() -> void:
	if EventBus.on_console_output.is_connected(_on_console_output):
		EventBus.on_console_output.disconnect(_on_console_output)
	if EventBus.on_recovery_completed.is_connected(_on_recovery_completed):
		EventBus.on_recovery_completed.disconnect(_on_recovery_completed)
	if EventBus.on_person_closed.is_connected(_on_person_closed):
		EventBus.on_person_closed.disconnect(_on_person_closed)
	if EventBus.on_recovery_offered.is_connected(_on_recovery_offered):
		EventBus.on_recovery_offered.disconnect(_on_recovery_offered)
	StandingService.reset_to_defaults()


func _on_console_output(line: String) -> void:
	_output.append(line)


func _on_recovery_completed(
	_chain_id: StringName,
	step_id: StringName,
	_person_id: StringName,
	_entity_id: StringName,
	_p_delta: float,
	_e_delta: float
) -> void:
	_completed.append(step_id)


func _on_person_closed(person_id: StringName, _reason: StringName) -> void:
	_closed_people.append(person_id)


func _on_recovery_offered(
	_chain_id: StringName, step_id: StringName, _person_id: StringName
) -> void:
	_offered.append(step_id)


func _ok(result: Dictionary) -> bool:
	return result[RecoveryService.REPORT_KEY_OK] == true


func _entity_delta(result: Dictionary) -> float:
	return result[RecoveryService.REPORT_KEY_ENTITY_DELTA]


func _person_delta(result: Dictionary) -> float:
	return result[RecoveryService.REPORT_KEY_PERSON_DELTA]


func _bootstrap_friendly_personal() -> void:
	# Non-zero path: set personal to Friendly band without inventing combat.
	StandingService.set_person_standing(PERSON_MENDI, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)


func test_recovery_chain_loaded_under_budget() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY)
	assert_eq(ids.size(), 4, "S4 ships four recovery chains")
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[BalanceStanding.RECOVERY_CONTENT_CATEGORY])
	assert_true(ContentLibrary.has_item(CHAIN_MENDI))
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))

	var item: ContentItem = ContentLibrary.item(CHAIN_MENDI)
	assert_true(item is RecoveryChain)
	var chain: RecoveryChain = item as RecoveryChain
	assert_eq(chain.person_id, PERSON_MENDI)
	assert_eq(chain.entity_id, ENTITY_REACH)
	assert_gte(chain.steps.size(), BalanceStanding.RECOVERY_CHAIN_MIN_STEPS)
	assert_lte(chain.steps.size(), BalanceStanding.RECOVERY_CHAIN_MAX_STEPS)
	assert_false(chain.steps[0].requires_prior_success, "deniable first step bootstrap")


func test_recovery_chain_shape_rejects_empty() -> void:
	var chain: RecoveryChain = RecoveryChain.new()
	chain.id = &"fixture_recovery"
	chain.display_name = "Fixture"
	var joined: String = "\n".join(chain.validation_errors())
	assert_string_contains(joined, "person_id")
	assert_string_contains(joined, "entity_id")
	assert_string_contains(joined, "steps")


func test_cannot_start_without_friendly_personal() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, DEEP_NEGATIVE)
	StandingService.set_person_standing(PERSON_MENDI, 0.0)
	assert_false(StandingService.can_offer_recovery(PERSON_MENDI))
	assert_false(_recovery.accept(PERSON_MENDI))
	assert_false(_recovery.has_active())


func test_deniable_complete_from_deep_negative_improves_entity() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, DEEP_NEGATIVE)
	_bootstrap_friendly_personal()
	assert_true(StandingService.can_offer_recovery(PERSON_MENDI))

	var before_entity: float = StandingService.get_entity_standing(ENTITY_REACH)
	var before_person: float = StandingService.get_person_standing(PERSON_MENDI)
	assert_true(_recovery.accept(PERSON_MENDI))
	assert_eq(_recovery.active_step_id(), STEP_DENIABLE)

	var result: Dictionary = _recovery.complete()
	assert_true(_ok(result))
	assert_gt(_entity_delta(result), 0.0, "entity standing must move up (visible if small)")
	assert_gt(_person_delta(result), 0.0)
	assert_gt(StandingService.get_entity_standing(ENTITY_REACH), before_entity)
	assert_gt(StandingService.get_person_standing(PERSON_MENDI), before_person)
	assert_eq(StandingService.personal_success_count(PERSON_MENDI), 1)
	assert_eq(_completed.size(), 1)
	assert_false(_recovery.has_active())

	# Stickiness at deep negative shrinks positives; still non-zero applied.
	var expected_raw: float = BalanceStanding.RECOVERY_DENIABLE_ENTITY_DELTA
	var expected_applied: float = StandingService.adjust_for_stickiness(DEEP_NEGATIVE, expected_raw)
	assert_almost_eq(_entity_delta(result), expected_applied, TOLERANCE)


func test_chain_progresses_all_steps_entity_climbs_slowly() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, DEEP_NEGATIVE)
	_bootstrap_friendly_personal()

	var chain_item: ContentItem = ContentLibrary.item(CHAIN_MENDI)
	var chain: RecoveryChain = chain_item as RecoveryChain
	var start_entity: float = StandingService.get_entity_standing(ENTITY_REACH)

	for index: int in chain.steps.size():
		var step: RecoveryStep = chain.steps[index]
		assert_true(_recovery.accept(PERSON_MENDI), "should accept step %d (%s)" % [index, step.id])
		assert_eq(_recovery.active_step_id(), step.id)
		var result: Dictionary = _recovery.complete()
		assert_true(_ok(result), "complete step %s" % step.id)
		assert_gt(_entity_delta(result), 0.0)

	assert_eq(_completed.size(), chain.steps.size())
	assert_gt(StandingService.get_entity_standing(ENTITY_REACH), start_entity)
	assert_eq(StandingService.personal_success_count(PERSON_MENDI), chain.steps.size())
	# Chain exhausted — no further offer.
	assert_false(_recovery.accept(PERSON_MENDI))


func test_betray_closes_recovery_route() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, DEEP_NEGATIVE)
	_bootstrap_friendly_personal()
	assert_true(_recovery.accept(PERSON_MENDI))

	var result: Dictionary = _recovery.betray()
	assert_true(_ok(result))
	assert_true(StandingService.is_person_closed(PERSON_MENDI))
	assert_eq(
		StandingService.person_close_reason(PERSON_MENDI),
		BalanceStanding.RECOVERY_CLOSE_REASON_BETRAYAL
	)
	assert_eq(_closed_people.size(), 1)
	assert_false(_recovery.has_active())
	assert_false(StandingService.can_offer_recovery(PERSON_MENDI))
	assert_false(_recovery.accept(PERSON_MENDI))
	assert_false(_ok(_recovery.complete()))


func test_betray_by_person_id_without_active() -> void:
	_bootstrap_friendly_personal()
	var result: Dictionary = _recovery.betray(PERSON_MENDI)
	assert_true(_ok(result))
	assert_true(StandingService.is_person_closed(PERSON_MENDI))
	assert_lt(StandingService.get_person_standing(PERSON_MENDI), BalanceStanding.TIER_FRIENDLY_MIN)


func test_rank_entity_deltas_are_low_rank_scale() -> void:
	# Alpha chain is low-rank (Mendi). Entity deltas must be tiny vs mid reference.
	var chain: RecoveryChain = ContentLibrary.item(CHAIN_MENDI) as RecoveryChain
	var first: RecoveryStep = chain.steps[0]
	assert_almost_eq(
		first.entity_standing_delta, BalanceStanding.RECOVERY_DENIABLE_ENTITY_DELTA, TOLERANCE
	)
	assert_lt(
		first.entity_standing_delta,
		BalanceStanding.RECOVERY_MID_DENIABLE_ENTITY_DELTA,
		"low-rank deniable Entity delta must be smaller than mid-rank reference"
	)
	assert_almost_eq(
		first.personal_standing_delta, BalanceStanding.RECOVERY_DENIABLE_PERSONAL_DELTA, TOLERANCE
	)


func test_favor_builds_personal_toward_friendly() -> void:
	StandingService.set_person_standing(PERSON_MENDI, 10.0)
	var before: float = StandingService.get_person_standing(PERSON_MENDI)
	var result: Dictionary = _recovery.favor(PERSON_MENDI)
	assert_true(_ok(result))
	assert_almost_eq(
		_person_delta(result), BalanceStanding.RECOVERY_FAVOR_PERSONAL_DELTA, TOLERANCE
	)
	assert_almost_eq(
		StandingService.get_person_standing(PERSON_MENDI),
		before + BalanceStanding.RECOVERY_FAVOR_PERSONAL_DELTA,
		TOLERANCE
	)


func test_favor_refused_when_closed() -> void:
	_bootstrap_friendly_personal()
	StandingService.close_person(PERSON_MENDI, BalanceStanding.RECOVERY_CLOSE_REASON_BETRAYAL)
	var result: Dictionary = _recovery.favor(PERSON_MENDI)
	assert_false(_ok(result))


func test_console_recovery_flow() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, DEEP_NEGATIVE)
	_bootstrap_friendly_personal()
	_console.start()
	_console.submit("recovery accept person_ra_mendi")
	assert_true(_recovery.has_active())
	_console.submit("recovery complete")
	assert_false(_recovery.has_active())
	assert_gt(StandingService.get_entity_standing(ENTITY_REACH), DEEP_NEGATIVE)
	assert_string_contains("\n".join(_output), "complete")


func test_console_favor() -> void:
	StandingService.set_person_standing(PERSON_MENDI, 8.0)
	_console.start()
	_console.submit("favor person_ra_mendi")
	assert_gt(StandingService.get_person_standing(PERSON_MENDI), 8.0)
	assert_string_contains("\n".join(_output), "Favor")


func test_standing_history_save_round_trip() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, DEEP_NEGATIVE)
	_bootstrap_friendly_personal()
	assert_true(_recovery.accept(PERSON_MENDI))
	assert_true(_ok(_recovery.complete()))
	assert_eq(StandingService.personal_success_count(PERSON_MENDI), 1)

	var section: Dictionary = StandingService.to_section()
	section[BalanceStanding.SAVE_KEY_RECOVERY_PROGRESS] = _recovery.progress_to_section()

	StandingService.reset_to_defaults()
	_recovery.reset()
	assert_eq(StandingService.personal_success_count(PERSON_MENDI), 0)

	StandingService.apply_section(section)
	_recovery.apply_progress_section(section[BalanceStanding.SAVE_KEY_RECOVERY_PROGRESS])

	assert_eq(StandingService.personal_success_count(PERSON_MENDI), 1)
	var sticky: float = StandingService.adjust_for_stickiness(
		DEEP_NEGATIVE, BalanceStanding.RECOVERY_DENIABLE_ENTITY_DELTA
	)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH), DEEP_NEGATIVE + sticky, TOLERANCE
	)
	# First step already done — next offer is step 2, not deniable.
	assert_true(_recovery.has_offer_for_person(PERSON_MENDI))
	assert_true(_recovery.accept(PERSON_MENDI))
	assert_ne(_recovery.active_step_id(), STEP_DENIABLE)


func test_closed_flag_save_round_trip() -> void:
	_bootstrap_friendly_personal()
	StandingService.close_person(PERSON_MENDI, BalanceStanding.RECOVERY_CLOSE_REASON_BETRAYAL)
	var section: Dictionary = StandingService.to_section()
	StandingService.reset_to_defaults()
	assert_false(StandingService.is_person_closed(PERSON_MENDI))
	StandingService.apply_section(section)
	assert_true(StandingService.is_person_closed(PERSON_MENDI))
	assert_false(StandingService.can_offer_recovery(PERSON_MENDI))


func test_fail_and_abandon_personal_hits() -> void:
	_bootstrap_friendly_personal()
	var start: float = StandingService.get_person_standing(PERSON_MENDI)
	assert_true(_recovery.accept(PERSON_MENDI))
	var fail_result: Dictionary = _recovery.fail()
	assert_true(_ok(fail_result))
	assert_almost_eq(
		_person_delta(fail_result), BalanceStanding.RECOVERY_FAIL_PERSONAL_DELTA, TOLERANCE
	)

	StandingService.set_person_standing(PERSON_MENDI, start)
	assert_true(_recovery.accept(PERSON_MENDI))
	var abandon_result: Dictionary = _recovery.abandon()
	assert_true(_ok(abandon_result))
	assert_lt(_person_delta(abandon_result), _person_delta(fail_result))


func test_nonzero_fixtures_throughout() -> void:
	# Guard against zero-only fixtures that hide clamp/stickiness bugs.
	StandingService.set_entity_standing(ENTITY_REACH, -63.5)
	StandingService.set_person_standing(PERSON_MENDI, 27.0)
	assert_true(_recovery.accept(PERSON_MENDI))
	var result: Dictionary = _recovery.complete()
	assert_true(_ok(result))
	assert_ne(_entity_delta(result), 0.0)
	assert_ne(_person_delta(result), 0.0)
