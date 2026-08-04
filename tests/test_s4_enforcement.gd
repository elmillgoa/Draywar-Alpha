extends GutTest

## Per-Entity heat, patrol pressure, customs flee, recovery lift — Steam S4.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S4
## Law: heat is not standing; standing only via StandingService.

const ALPHA: StringName = &"system_alpha"
const GAMMA: StringName = &"system_gamma"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_GAMMA: StringName = &"entity_gamma_collective"
const PERSON_WREN: StringName = &"person_fh_wren"
const PERSON_DACE: StringName = &"person_fh_dace"
const CHAIN_WREN: StringName = &"recovery_haulers_wren"
const CHAIN_KADE: StringName = &"recovery_fringe_kade"
const STEP_SIDE_BAY: StringName = &"step_side_bay"
const MUNITIONS: StringName = &"commodity_munitions"
const TOLERANCE: float = 0.0001

var _attribution: AttributionService = null
var _recovery: RecoveryService = null
var _wallet: WalletService = null
var _cargo: CargoService = null
var _heat_events: Array[Dictionary] = []


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	IncidentService.reset()
	EnforcementService.reset()
	StandingService.reset_to_defaults()
	_heat_events = []
	_attribution = AttributionService.new()
	add_child_autofree(_attribution)
	_recovery = RecoveryService.new()
	add_child_autofree(_recovery)
	_recovery.reset()
	_wallet = WalletService.new()
	add_child_autofree(_wallet)
	_wallet.reset()
	_cargo = CargoService.new()
	add_child_autofree(_cargo)
	_cargo.reset()
	EventBus.on_heat_changed.connect(_on_heat_changed)


func after_each() -> void:
	if EventBus.on_heat_changed.is_connected(_on_heat_changed):
		EventBus.on_heat_changed.disconnect(_on_heat_changed)
	IncidentService.reset()
	EnforcementService.reset()
	BoardService.reset()
	MarketService.reset()
	StandingService.reset_to_defaults()
	WorldClockHelpers.reset_clock()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()


func _on_heat_changed(entity_id: StringName, heat: float, reason: StringName) -> void:
	_heat_events.append({&"entity": entity_id, &"heat": heat, &"reason": reason})


func _flag(data: Dictionary, key: StringName) -> bool:
	return data.get(key, false) == true


func test_kill_patrolled_raises_reach_heat_lawless_does_not() -> void:
	assert_eq(EnforcementService.get_heat(ENTITY_REACH), 0.0)
	var alpha_kill: Dictionary = _attribution.report_kill(ALPHA, ENTITY_GAMMA, 0, false)
	assert_true(_flag(alpha_kill, BalanceStanding.REPORT_KEY_ATTRIBUTED), "Alpha kill attributed")
	assert_almost_eq(
		EnforcementService.get_heat(ENTITY_REACH),
		BalanceEnforcement.HEAT_KILL_PATROLLED,
		TOLERANCE,
		"patrolled kill raises Reach heat"
	)

	var gamma_before: float = EnforcementService.get_heat(ENTITY_GAMMA)
	var reach_before: float = EnforcementService.get_heat(ENTITY_REACH)
	# Lawless without evidence: unattributed → no heat signal.
	var gamma_kill: Dictionary = _attribution.report_kill(GAMMA, ENTITY_REACH, 0, false)
	assert_false(_flag(gamma_kill, BalanceStanding.REPORT_KEY_ATTRIBUTED))
	assert_almost_eq(EnforcementService.get_heat(ENTITY_GAMMA), gamma_before, TOLERANCE)

	# Lawless with evidence may attribute standing, but heat magnitude is 0.
	assert_eq(BalanceEnforcement.kill_heat_for_policing(StarSystem.POLICED_BY_NOBODY), 0.0)
	var gamma_evidenced: Dictionary = _attribution.report_kill(GAMMA, ENTITY_REACH, 0, true)
	if _flag(gamma_evidenced, BalanceStanding.REPORT_KEY_ATTRIBUTED):
		var target: StringName = gamma_evidenced[BalanceStanding.REPORT_KEY_ENTITY_ID]
		# Heat on that Entity must not have risen from the lawless kill.
		if target == ENTITY_GAMMA:
			assert_almost_eq(EnforcementService.get_heat(ENTITY_GAMMA), gamma_before, TOLERANCE)
		elif target == ENTITY_REACH:
			assert_almost_eq(EnforcementService.get_heat(ENTITY_REACH), reach_before, TOLERANCE)


func test_customs_flee_raises_heat_cooperate_does_not_from_flee_path() -> void:
	assert_true(_cargo.add(MUNITIONS, 2))
	IncidentService.set_ship_count_override(1)
	var flee_id: StringName = IncidentService.force_offer(BalanceIncident.KIND_CUSTOMS, ALPHA)
	assert_false(String(flee_id).is_empty(), "customs offered")
	var heat_before: float = EnforcementService.get_heat(ENTITY_REACH)
	var flee_result: Dictionary = IncidentService.respond(flee_id, BalanceIncident.CHOICE_FLEE)
	assert_true(_flag(flee_result, &"ok"))
	assert_almost_eq(
		EnforcementService.get_heat(ENTITY_REACH),
		heat_before + BalanceEnforcement.HEAT_CUSTOMS_FLEE,
		TOLERANCE,
		"flee raises heat"
	)

	# Cooperate does not emit the flee heat reason (contraband seize heat is separate).
	_heat_events.clear()
	EnforcementService.reset()
	IncidentService.reset()
	_cargo.reset()
	assert_true(_cargo.add(MUNITIONS, 2))
	IncidentService.set_ship_count_override(1)
	var coop_id: StringName = IncidentService.force_offer(BalanceIncident.KIND_CUSTOMS, ALPHA)
	assert_false(String(coop_id).is_empty())
	var coop_result: Dictionary = IncidentService.respond(coop_id, BalanceIncident.CHOICE_COOPERATE)
	assert_true(_flag(coop_result, &"ok"))
	for ev: Dictionary in _heat_events:
		var reason: StringName = StringName(str(ev.get(&"reason", &"")))
		assert_ne(
			reason,
			BalanceEnforcement.REASON_HEAT_CUSTOMS_FLEE,
			"cooperate must not emit flee heat reason"
		)


func test_pressure_only_in_patrolled_not_lawless() -> void:
	EnforcementService.set_heat(ENTITY_REACH, BalanceEnforcement.HEAT_THRESHOLD_PRESSURE)
	EnforcementService.set_heat(ENTITY_GAMMA, BalanceEnforcement.HEAT_THRESHOLD_PRESSURE)
	assert_true(EnforcementService.is_pressure(ALPHA), "Alpha patrolled + heat → pressure")
	assert_false(
		EnforcementService.is_pressure(GAMMA), "same heat number in Gamma lawless → no pressure"
	)
	assert_false(EnforcementService.is_hunt(GAMMA), "lawless never hunt")


func test_save_load_round_trips_heat() -> void:
	EnforcementService.add_heat(ENTITY_REACH, 40.0, BalanceEnforcement.REASON_HEAT_KILL)
	assert_almost_eq(EnforcementService.get_heat(ENTITY_REACH), 40.0, TOLERANCE)
	var section: Dictionary = EnforcementService.to_section()
	assert_true(section.has(BalanceEnforcement.SAVE_KEY_HEAT))
	EnforcementService.reset()
	assert_eq(EnforcementService.get_heat(ENTITY_REACH), 0.0)
	EnforcementService.apply_section(section)
	assert_almost_eq(EnforcementService.get_heat(ENTITY_REACH), 40.0, TOLERANCE)

	# CareerSave gather includes enforcement when services are live autoloads.
	var gathered: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(gathered.has(BalanceEnforcement.SAVE_SECTION_KEY), "CareerSave has enforcement")
	var enf: Variant = gathered[BalanceEnforcement.SAVE_SECTION_KEY]
	assert_eq(typeof(enf), TYPE_DICTIONARY)
	var enf_dict: Dictionary = enf
	assert_true(enf_dict.has(BalanceEnforcement.SAVE_KEY_HEAT))


func test_hunt_threshold_forces_patrol_response_in_patrolled() -> void:
	EnforcementService.set_heat(ENTITY_REACH, BalanceEnforcement.HEAT_THRESHOLD_HUNT)
	assert_true(EnforcementService.is_hunt(ALPHA))
	IncidentService.set_ship_count_override(1)
	IncidentService.evaluate_system(ALPHA)
	var found_patrol: bool = false
	for id: StringName in IncidentService.offered_ids():
		var offer: Dictionary = IncidentService.get_offer(id)
		var is_patrol: bool = offer.get(BalanceEnforcement.KEY_PATROL_RESPONSE, false) == true
		if is_patrol:
			found_patrol = true
			assert_eq(
				StringName(str(offer.get(BalanceIncident.KEY_KIND, &""))),
				BalanceIncident.KIND_INTERCEPT
			)
			var label: String = str(offer.get(BalanceIncident.KEY_LABEL, ""))
			assert_eq(label, BalanceEnforcement.LABEL_PATROL_RESPONSE)
			break
	assert_true(found_patrol, "hunt forces patrol-response intercept in Alpha")


func test_recovery_four_chains_and_wren_step() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY)
	assert_eq(ids.size(), 8, "S9 live recovery chains")
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[&"recovery_chains"])
	assert_true(ContentLibrary.has_item(CHAIN_WREN))
	assert_true(ContentLibrary.has_item(CHAIN_KADE))

	StandingService.set_person_standing(PERSON_WREN, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)
	assert_true(_recovery.accept(PERSON_WREN), "accept Wren")
	assert_eq(_recovery.active_step_id(), STEP_SIDE_BAY)
	var completed: Dictionary = _recovery.complete()
	assert_true(_flag(completed, RecoveryService.REPORT_KEY_OK), "complete Wren step")


func test_network_betrayal_hits_contact_not_closed() -> void:
	StandingService.set_person_standing(PERSON_WREN, 30.0)
	StandingService.set_person_standing(PERSON_DACE, 20.0)
	var dace_before: float = StandingService.get_person_standing(PERSON_DACE)
	var result: Dictionary = _recovery.betray(PERSON_WREN)
	assert_true(_flag(result, RecoveryService.REPORT_KEY_OK))
	assert_true(StandingService.is_person_closed(PERSON_WREN))
	assert_false(StandingService.is_person_closed(PERSON_DACE), "network not closed")
	assert_almost_eq(
		StandingService.get_person_standing(PERSON_DACE),
		dace_before + BalanceStanding.RECOVERY_NETWORK_BETRAYAL_PERSONAL_DELTA,
		TOLERANCE,
		"network personal hit"
	)


func test_choice_mapping_helper() -> void:
	assert_eq(
		BalanceEnforcement.primary_choice_for_kind(BalanceIncident.KIND_CUSTOMS),
		BalanceIncident.CHOICE_COOPERATE
	)
	assert_eq(
		BalanceEnforcement.secondary_choice_for_kind(BalanceIncident.KIND_CUSTOMS),
		BalanceIncident.CHOICE_FLEE
	)
	assert_eq(
		FlightHUD.choice_for_incident_action(BalanceIncident.KIND_DISTRESS, true),
		BalanceIncident.CHOICE_HELP
	)
	assert_eq(
		FlightHUD.choice_for_incident_action(BalanceIncident.KIND_INTERCEPT, false),
		BalanceIncident.CHOICE_SUBMIT
	)
	var with_hint: String = BalanceEnforcement.prompt_with_controls(
		BalanceIncident.KIND_CUSTOMS, BalanceIncident.PROMPT_CUSTOMS
	)
	assert_string_contains(with_hint, "[1]")
	assert_string_contains(with_hint, "[2]")


func test_heat_decay_on_security_steps() -> void:
	EnforcementService.set_heat(ENTITY_REACH, 30.0)
	WorldClockHelpers.advance_seconds(BalanceIncident.INCIDENT_STEP_SECONDS)
	EnforcementService.catch_up()
	assert_almost_eq(
		EnforcementService.get_heat(ENTITY_REACH),
		30.0 - BalanceEnforcement.HEAT_DECAY_PER_SECURITY_STEP,
		TOLERANCE
	)
