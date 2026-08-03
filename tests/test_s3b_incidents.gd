extends GutTest

## Opportunistic incidents — Steam S3b.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3b

const ALPHA: StringName = &"system_alpha"
const BETA: StringName = &"system_beta"
const GAMMA: StringName = &"system_gamma"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const MUNITIONS: StringName = &"commodity_munitions"

var _mission: MissionService = null
var _wallet: WalletService = null
var _cargo: CargoService = null
var _offered: Array[StringName] = []
var _resolved: Array[StringName] = []


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	IncidentService.reset()
	StandingService.reset_to_defaults()
	_offered = []
	_resolved = []
	_mission = MissionService.new()
	add_child_autofree(_mission)
	_mission.reset()
	_wallet = WalletService.new()
	add_child_autofree(_wallet)
	_wallet.reset()
	_cargo = CargoService.new()
	add_child_autofree(_cargo)
	_cargo.reset()
	EventBus.on_incident_offered.connect(_on_offered)
	EventBus.on_incident_resolved.connect(_on_resolved)


func after_each() -> void:
	if EventBus.on_incident_offered.is_connected(_on_offered):
		EventBus.on_incident_offered.disconnect(_on_offered)
	if EventBus.on_incident_resolved.is_connected(_on_resolved):
		EventBus.on_incident_resolved.disconnect(_on_resolved)
	IncidentService.reset()
	BoardService.reset()
	MarketService.reset()
	StandingService.reset_to_defaults()
	WorldClockHelpers.reset_clock()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()


func _on_offered(
	incident_id: StringName, _kind: StringName, _system_id: StringName, _prompt: String
) -> void:
	_offered.append(incident_id)


func _on_resolved(
	incident_id: StringName,
	_kind: StringName,
	_system_id: StringName,
	_outcome: StringName,
	_promoted: bool
) -> void:
	_resolved.append(incident_id)


func test_incidents_offer_while_mission_active_no_clobber() -> void:
	assert_true(_mission.accept(&"contract_courier_alpha"))
	assert_true(_mission.has_active())
	var active_before: StringName = _mission.active_template_id()
	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_DISTRESS, ALPHA)
	assert_false(String(id).is_empty(), "distress still offers with mission active")
	assert_eq(_mission.active_template_id(), active_before, "mission not clobbered")
	assert_true(_mission.has_active())
	assert_eq(IncidentService.offered_count(), 1)


func test_promote_when_no_mission_activates_mission_service() -> void:
	assert_false(_mission.has_active())
	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_DISTRESS, ALPHA)
	assert_false(String(id).is_empty())
	var result: Dictionary = IncidentService.respond(id, BalanceIncident.CHOICE_HELP)
	assert_true(_flag(result, &"ok"), "respond ok")
	assert_true(_flag(result, &"promoted"), "promoted")
	assert_true(_mission.has_active(), "promoted into MissionService")
	assert_eq(_mission.active_kind(), BalanceStanding.MISSION_KIND_DELIVERY)
	assert_true(_mission.is_runtime_mission())
	assert_eq(IncidentService.offered_count(), 0)


func test_help_with_mission_active_pays_without_promote() -> void:
	assert_true(_mission.accept(&"contract_courier_alpha"))
	var credits_before: int = _wallet.credits()
	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_DISTRESS, ALPHA)
	assert_false(String(id).is_empty())
	var result: Dictionary = IncidentService.respond(id, BalanceIncident.CHOICE_HELP)
	assert_true(_flag(result, &"ok"), "respond ok")
	assert_false(_flag(result, &"promoted"), "not promoted")
	assert_true(_mission.has_active(), "original mission kept")
	assert_eq(_mission.active_template_id(), &"contract_courier_alpha")
	var pay: int = _dict_int(result, &"pay_credits")
	assert_eq(pay, BalanceIncident.DISTRESS_HELP_PAY_ACTIVE_MISSION)
	assert_eq(_wallet.credits(), credits_before + pay)


func test_distress_intercept_customs_each_fire() -> void:
	IncidentService.set_ship_count_override(1)
	# Distress + intercept: no cargo needed.
	var d: StringName = IncidentService.force_offer(BalanceIncident.KIND_DISTRESS, BETA)
	assert_false(String(d).is_empty(), "distress fires")
	IncidentService.respond(d, BalanceIncident.CHOICE_IGNORE)

	var inter: StringName = IncidentService.force_offer(BalanceIncident.KIND_INTERCEPT, GAMMA)
	assert_false(String(inter).is_empty(), "intercept fires")
	IncidentService.respond(inter, BalanceIncident.CHOICE_RESIST)

	# Customs needs patrolled + restricted cargo.
	assert_true(_cargo.add(MUNITIONS, 2))
	var c: StringName = IncidentService.force_offer(BalanceIncident.KIND_CUSTOMS, ALPHA)
	assert_false(String(c).is_empty(), "customs fires in patrolled with munitions")
	var kinds_seen: Dictionary = {
		String(BalanceIncident.KIND_DISTRESS): true,
		String(BalanceIncident.KIND_INTERCEPT): true,
		String(BalanceIncident.KIND_CUSTOMS): true,
	}
	assert_eq(kinds_seen.size(), 3)


func test_ship_budget_refuse_when_full() -> void:
	IncidentService.set_ship_count_override(BalanceEconomy.PERF_BUDGET_SHIPS)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_DISTRESS, ALPHA)
	assert_true(String(id).is_empty(), "distress needs a ship slot — refuse at budget")
	# Customs needs zero ships — still allowed at budget.
	assert_true(_cargo.add(MUNITIONS, 1))
	var c: StringName = IncidentService.force_offer(BalanceIncident.KIND_CUSTOMS, ALPHA)
	assert_false(String(c).is_empty(), "customs has zero ship slots")


func test_customs_cooperate_sets_same_trip_skip() -> void:
	assert_true(_cargo.add(MUNITIONS, 3))
	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_CUSTOMS, ALPHA)
	assert_false(String(id).is_empty())
	var before_qty: int = _cargo.quantity(MUNITIONS)
	var result: Dictionary = IncidentService.respond(id, BalanceIncident.CHOICE_COOPERATE)
	assert_true(_flag(result, &"ok"), "customs cooperate ok")
	assert_true(IncidentService.should_skip_dock_inspect())
	# Seize should have cleared munitions when flag is on.
	if BalanceEconomy.CONTRABAND_SEIZE_ALL:
		assert_eq(_cargo.quantity(MUNITIONS), 0)
	else:
		assert_eq(_cargo.quantity(MUNITIONS), before_qty)
	# Dock inspect path consumes skip and does not double-punish.
	assert_true(IncidentService.consume_dock_inspect_skip())
	assert_false(IncidentService.should_skip_dock_inspect())


func test_deterministic_kind_fire_stable() -> void:
	var a: bool = BalanceIncident.kind_fires(BalanceIncident.KIND_DISTRESS, ALPHA, 5)
	var b: bool = BalanceIncident.kind_fires(BalanceIncident.KIND_DISTRESS, ALPHA, 5)
	assert_eq(a, b)
	var offer_a: Dictionary = IncidentService.build_offer_for_kind(
		BalanceIncident.KIND_INTERCEPT, BETA, 7
	)
	var offer_b: Dictionary = IncidentService.build_offer_for_kind(
		BalanceIncident.KIND_INTERCEPT, BETA, 7
	)
	assert_eq(
		str(offer_a.get(BalanceIncident.KEY_ID, "")), str(offer_b.get(BalanceIncident.KEY_ID, ""))
	)


func test_incidents_expire_on_load() -> void:
	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_DISTRESS, ALPHA)
	assert_false(String(id).is_empty())
	assert_eq(IncidentService.offered_count(), 1)
	var section: Dictionary = IncidentService.to_section()
	IncidentService.apply_section(section)
	assert_eq(IncidentService.offered_count(), 0, "offered incidents expire on load")


func _flag(data: Dictionary, key: StringName) -> bool:
	return data.get(key, false) == true


func _dict_int(data: Dictionary, key: StringName) -> int:
	if not data.has(key):
		return 0
	var raw: Variant = data[key]
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return int(as_float)
	return 0
