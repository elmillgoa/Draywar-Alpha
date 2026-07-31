extends GutTest

## E4.4 second recovery foothold — Drift / Cut Jax.
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.4 (D8/D9)
## Law: same Friendly personal + deniable bootstrap as Mendi; StandingService only.

const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_DRIFT: StringName = &"entity_beta_syndicate"
const PERSON_MENDI: StringName = &"person_ra_mendi"
const PERSON_JAX: StringName = &"person_bs_jax"
const CHAIN_MENDI: StringName = &"recovery_reach_mendi"
const CHAIN_JAX: StringName = &"recovery_drift_jax"
const STEP_SIDE_CRATE: StringName = &"step_side_crate"
const STATION_ALPHA: StringName = &"station_alpha_port"
const STATION_BETA_HUB: StringName = &"station_beta_hub"
const STATION_BETA_SPIT: StringName = &"station_beta_spit"
const DEEP_NEGATIVE: float = -70.0
const TOLERANCE: float = 0.0001

var _recovery: RecoveryService = null
var _completed: Array[StringName] = []
var _offered_people: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	_completed = []
	_offered_people = []

	_recovery = RecoveryService.new()
	add_child_autofree(_recovery)
	_recovery.reset()

	EventBus.on_recovery_completed.connect(_on_recovery_completed)
	EventBus.on_recovery_offered.connect(_on_recovery_offered)


func after_each() -> void:
	if EventBus.on_recovery_completed.is_connected(_on_recovery_completed):
		EventBus.on_recovery_completed.disconnect(_on_recovery_completed)
	if EventBus.on_recovery_offered.is_connected(_on_recovery_offered):
		EventBus.on_recovery_offered.disconnect(_on_recovery_offered)
	StandingService.reset_to_defaults()


func _on_recovery_completed(
	_chain_id: StringName,
	step_id: StringName,
	_person_id: StringName,
	_entity_id: StringName,
	_p_delta: float,
	_e_delta: float
) -> void:
	_completed.append(step_id)


func _on_recovery_offered(
	_chain_id: StringName, _step_id: StringName, person_id: StringName
) -> void:
	_offered_people.append(person_id)


func _ok(result: Dictionary) -> bool:
	return result[RecoveryService.REPORT_KEY_OK] == true


func _entity_delta(result: Dictionary) -> float:
	var raw: Variant = result[RecoveryService.REPORT_KEY_ENTITY_DELTA]
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return as_float
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return float(as_int)
	return 0.0


func _person_delta(result: Dictionary) -> float:
	var raw: Variant = result[RecoveryService.REPORT_KEY_PERSON_DELTA]
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return as_float
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return float(as_int)
	return 0.0


func _bootstrap_friendly_jax() -> void:
	StandingService.set_person_standing(PERSON_JAX, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)


func _bootstrap_friendly_mendi() -> void:
	StandingService.set_person_standing(PERSON_MENDI, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)


func test_exactly_two_chains_under_budget() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY)
	assert_eq(ids.size(), 2, "E4.4 ships exactly two recovery chains")
	assert_eq(ids.size(), Balance.CONTENT_BUDGET[BalanceStanding.RECOVERY_CONTENT_CATEGORY])
	assert_true(ContentLibrary.has_item(CHAIN_MENDI))
	assert_true(ContentLibrary.has_item(CHAIN_JAX))
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))


func test_jax_chain_shape_and_low_rank_deltas() -> void:
	var item: ContentItem = ContentLibrary.item(CHAIN_JAX)
	assert_true(item is RecoveryChain)
	var chain: RecoveryChain = item as RecoveryChain
	assert_eq(chain.person_id, PERSON_JAX)
	assert_eq(chain.entity_id, ENTITY_DRIFT)
	assert_eq(chain.steps.size(), 4)
	assert_gte(chain.steps.size(), BalanceStanding.RECOVERY_CHAIN_MIN_STEPS)
	assert_lte(chain.steps.size(), BalanceStanding.RECOVERY_CHAIN_MAX_STEPS)
	assert_false(chain.steps[0].requires_prior_success, "deniable first step")
	assert_eq(chain.steps[0].id, STEP_SIDE_CRATE)
	assert_true(chain.steps[1].requires_prior_success)
	assert_true(chain.steps[2].requires_prior_success)
	assert_true(chain.steps[3].requires_prior_success)

	# Step ids must not collide with Mendi's.
	var mendi: RecoveryChain = ContentLibrary.item(CHAIN_MENDI) as RecoveryChain
	var mendi_ids: Dictionary = {}
	for step: RecoveryStep in mendi.steps:
		mendi_ids[step.id] = true
	for step: RecoveryStep in chain.steps:
		assert_false(mendi_ids.has(step.id), "Jax step id must differ from Mendi: %s" % step.id)

	var first: RecoveryStep = chain.steps[0]
	assert_almost_eq(
		first.entity_standing_delta, BalanceStanding.RECOVERY_DENIABLE_ENTITY_DELTA, TOLERANCE
	)
	assert_almost_eq(
		first.personal_standing_delta, BalanceStanding.RECOVERY_DENIABLE_PERSONAL_DELTA, TOLERANCE
	)
	assert_lt(
		first.entity_standing_delta,
		BalanceStanding.RECOVERY_MID_DENIABLE_ENTITY_DELTA,
		"low-rank deniable Entity delta must be smaller than mid-rank reference"
	)


func test_cannot_start_jax_without_friendly_personal() -> void:
	StandingService.set_entity_standing(ENTITY_DRIFT, DEEP_NEGATIVE)
	StandingService.set_person_standing(PERSON_JAX, 0.0)
	assert_false(StandingService.can_offer_recovery(PERSON_JAX))
	assert_false(_recovery.accept(PERSON_JAX))
	assert_false(_recovery.has_active())


func test_deniable_complete_improves_drift_entity() -> void:
	StandingService.set_entity_standing(ENTITY_DRIFT, DEEP_NEGATIVE)
	_bootstrap_friendly_jax()
	assert_true(StandingService.can_offer_recovery(PERSON_JAX))

	var before_entity: float = StandingService.get_entity_standing(ENTITY_DRIFT)
	var before_person: float = StandingService.get_person_standing(PERSON_JAX)
	assert_true(_recovery.accept(PERSON_JAX))
	assert_eq(_recovery.active_chain_id(), CHAIN_JAX)
	assert_eq(_recovery.active_step_id(), STEP_SIDE_CRATE)

	var result: Dictionary = _recovery.complete()
	assert_true(_ok(result))
	assert_gt(_entity_delta(result), 0.0)
	assert_gt(_person_delta(result), 0.0)
	assert_gt(StandingService.get_entity_standing(ENTITY_DRIFT), before_entity)
	assert_gt(StandingService.get_person_standing(PERSON_JAX), before_person)
	assert_eq(StandingService.personal_success_count(PERSON_JAX), 1)
	assert_eq(_completed.size(), 1)
	assert_false(_recovery.has_active())


func test_follow_on_requires_prior_success() -> void:
	StandingService.set_entity_standing(ENTITY_DRIFT, DEEP_NEGATIVE)
	_bootstrap_friendly_jax()
	assert_true(_recovery.accept(PERSON_JAX))
	assert_true(_ok(_recovery.complete()))

	# Second step needs the success history from step 1.
	assert_true(_recovery.has_offer_for_person(PERSON_JAX))
	assert_true(_recovery.accept(PERSON_JAX))
	assert_ne(_recovery.active_step_id(), STEP_SIDE_CRATE)
	assert_true(_ok(_recovery.complete()))


func test_dock_offer_jax_at_drift_not_at_reach() -> void:
	StandingService.set_entity_standing(ENTITY_DRIFT, DEEP_NEGATIVE)
	_bootstrap_friendly_jax()
	_bootstrap_friendly_mendi()

	_offered_people.clear()
	EventBus.on_docked.emit(STATION_BETA_HUB)
	assert_true(_offered_people.has(PERSON_JAX), "Drift hub must offer Jax")
	assert_false(_offered_people.has(PERSON_MENDI), "Drift hub must not offer Mendi")

	_offered_people.clear()
	EventBus.on_docked.emit(STATION_BETA_SPIT)
	assert_true(_offered_people.has(PERSON_JAX), "Drift spit must offer Jax")
	assert_false(_offered_people.has(PERSON_MENDI), "Drift spit must not offer Mendi")

	_offered_people.clear()
	EventBus.on_docked.emit(STATION_ALPHA)
	assert_true(_offered_people.has(PERSON_MENDI), "Reach dock still offers Mendi")
	assert_false(_offered_people.has(PERSON_JAX), "Reach dock must not offer Jax")


func test_station_queries_scope_favor_and_offer_by_controller() -> void:
	_bootstrap_friendly_jax()
	_bootstrap_friendly_mendi()

	assert_eq(StationDockQueries.favor_person(STATION_BETA_HUB), PERSON_JAX)
	assert_eq(StationDockQueries.favor_person(STATION_BETA_SPIT), PERSON_JAX)
	assert_eq(StationDockQueries.favor_person(STATION_ALPHA), PERSON_MENDI)

	assert_eq(StationDockQueries.offered_recovery_person(STATION_BETA_HUB, _recovery), PERSON_JAX)
	assert_eq(StationDockQueries.offered_recovery_person(STATION_ALPHA, _recovery), PERSON_MENDI)
	assert_eq(StationDockQueries.offered_recovery_person(STATION_BETA_SPIT, _recovery), PERSON_JAX)


func test_station_ui_recovery_section_names_jax_without_console() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var recovery: RecoveryService = RecoveryService.new()
	host.add_child(recovery)
	await get_tree().process_frame
	recovery.reset()
	_bootstrap_friendly_jax()

	var menu: StationMenu = StationMenu.new()
	host.add_child(menu)
	await get_tree().process_frame

	EventBus.on_docked.emit(STATION_BETA_HUB)
	await get_tree().process_frame

	var favor_btn: Button = _find_button_containing(menu, "Jax")
	assert_ne(favor_btn, null, "favor button names Jax at Drift hub")
	assert_true(favor_btn.visible)

	# Talk button also names Jax when offer is open (Friendly).
	var talk_btn: Button = _find_button_containing(menu, "Jax")
	assert_ne(talk_btn, null)

	# Deep-negative drama header + hint for Drift.
	StandingService.apply_entity_delta(
		ENTITY_DRIFT, DEEP_NEGATIVE, BalanceStanding.REASON_MISSION_ABANDON, false
	)
	EventBus.on_undocked.emit(STATION_BETA_HUB)
	EventBus.on_docked.emit(STATION_BETA_HUB)
	await get_tree().process_frame

	var drama_header: Label = _find_label_with_text(
		menu, BalanceEconomy.STATION_SECTION_RECOVERY_DRAMA
	)
	assert_ne(drama_header, null, "deep-negative shows Recovery foothold header")
	var hint: Label = _find_label_containing(menu, "Jax")
	assert_ne(hint, null, "drama hint names Jax")
	EventBus.on_undocked.emit(STATION_BETA_HUB)


func test_deep_negative_dock_open_via_jax_contact() -> void:
	StandingService.set_entity_standing(ENTITY_DRIFT, DEEP_NEGATIVE)
	assert_true(
		StandingService.has_open_recovery_contact_for_controller(ENTITY_DRIFT),
		"Jax chain keeps Drift recovery open"
	)
	assert_true(
		StandingService.can_dock_at_station(STATION_BETA_HUB),
		"deep negative must not block Drift dock while Jax is open"
	)

	StandingService.close_person(PERSON_JAX, BalanceStanding.RECOVERY_CLOSE_REASON_BETRAYAL)
	assert_false(StandingService.has_open_recovery_contact_for_controller(ENTITY_DRIFT))
	assert_false(
		StandingService.can_dock_at_station(STATION_BETA_HUB),
		"after Jax closed, dock refusal applies again"
	)


func test_betray_closes_jax_only() -> void:
	_bootstrap_friendly_jax()
	_bootstrap_friendly_mendi()
	assert_true(_recovery.accept(PERSON_JAX))
	var result: Dictionary = _recovery.betray()
	assert_true(_ok(result))
	assert_true(StandingService.is_person_closed(PERSON_JAX))
	assert_false(StandingService.is_person_closed(PERSON_MENDI))
	assert_false(StandingService.can_offer_recovery(PERSON_JAX))
	assert_true(StandingService.can_offer_recovery(PERSON_MENDI))


func test_abandon_jax_personal_hit() -> void:
	_bootstrap_friendly_jax()
	var start: float = StandingService.get_person_standing(PERSON_JAX)
	assert_true(_recovery.accept(PERSON_JAX))
	var abandon_result: Dictionary = _recovery.abandon()
	assert_true(_ok(abandon_result))
	assert_almost_eq(
		_person_delta(abandon_result), BalanceStanding.RECOVERY_ABANDON_PERSONAL_DELTA, TOLERANCE
	)
	assert_lt(StandingService.get_person_standing(PERSON_JAX), start)
	assert_false(_recovery.has_active())


func test_beta_station_flavor_mentions_jax() -> void:
	var hub: Station = ContentLibrary.item(STATION_BETA_HUB) as Station
	var spit: Station = ContentLibrary.item(STATION_BETA_SPIT) as Station
	assert_ne(hub, null)
	assert_ne(spit, null)
	assert_true(hub.flavor_line.contains("Jax"), "hub flavor names Jax")
	assert_true(spit.flavor_line.contains("Jax"), "spit flavor names Jax")


func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label:
		var label: Label = node as Label
		if label.text == text:
			return label
	for child: Node in node.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null


func _find_label_containing(node: Node, fragment: String) -> Label:
	if node is Label:
		var label: Label = node as Label
		if label.text.contains(fragment):
			return label
	for child: Node in node.get_children():
		var found: Label = _find_label_containing(child, fragment)
		if found != null:
			return found
	return null


func _find_button_containing(node: Node, fragment: String) -> Button:
	if node is Button:
		var btn: Button = node as Button
		if btn.visible and btn.text.contains(fragment):
			return btn
	for child: Node in node.get_children():
		var found: Button = _find_button_containing(child, fragment)
		if found != null:
			return found
	return null
