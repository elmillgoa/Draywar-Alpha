extends GutTest

## E2.3 — kill attribution HUD feedback + live witness count from traffic.
##
## Implements: docs/BETA_E2_COMBAT_HULL.md E2.3
## Law: docs/reputation_and_standing.md §7 (no new standing rules).

const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_BETA: StringName = &"entity_beta_syndicate"
const ENTITY_GAMMA: StringName = &"entity_gamma_collective"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const TOLERANCE: float = 0.0001


class FakeSystemWorld:
	extends Node3D
	var system_id: StringName = SYSTEM_ALPHA

	func _enter_tree() -> void:
		add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)


var _reported_witnesses: Array[int] = []
var _attributed_entities: Array[StringName] = []
var _unattributed_systems: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	_reported_witnesses = []
	_attributed_entities = []
	_unattributed_systems = []
	TimeScale.set_combat_lock(false)


func after_each() -> void:
	_disconnect_kill_bus()
	StandingService.reset_to_defaults()
	TimeScale.set_combat_lock(false)


func _disconnect_kill_bus() -> void:
	if EventBus.on_kill_reported.is_connected(_on_kill_reported):
		EventBus.on_kill_reported.disconnect(_on_kill_reported)
	if EventBus.on_kill_attributed.is_connected(_on_kill_attributed):
		EventBus.on_kill_attributed.disconnect(_on_kill_attributed)
	if EventBus.on_kill_unattributed.is_connected(_on_kill_unattributed):
		EventBus.on_kill_unattributed.disconnect(_on_kill_unattributed)


func _connect_kill_bus() -> void:
	EventBus.on_kill_reported.connect(_on_kill_reported)
	EventBus.on_kill_attributed.connect(_on_kill_attributed)
	EventBus.on_kill_unattributed.connect(_on_kill_unattributed)


func _on_kill_reported(
	_system_id: StringName, _victim: StringName, witness_count: int, _evidence: bool
) -> void:
	_reported_witnesses.append(witness_count)


func _on_kill_attributed(
	_system_id: StringName, entity_id: StringName, _delta: float, _reason: StringName
) -> void:
	_attributed_entities.append(entity_id)


func _on_kill_unattributed(system_id: StringName, _victim: StringName) -> void:
	_unattributed_systems.append(system_id)


func _spawn_traffic_for(system_id: StringName) -> NpcTraffic:
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(system_id)
	return traffic


func _kill_hostile_in(system_id: StringName) -> void:
	var host: FakeSystemWorld = FakeSystemWorld.new()
	host.system_id = system_id
	add_child_autofree(host)
	var hostile: HostileNpc = HostileNpc.spawn_under(host, Vector3(20.0, 0.0, 20.0))
	hostile.take_damage(hostile.hull_max())


# --- Pure formatters -------------------------------------------------------


func test_format_kill_attributed_names_entity_and_standing_fell() -> void:
	var line: String = BalanceStanding.format_kill_attributed("Reach Authority")
	assert_eq(line, "Kill recorded — Reach Authority standing fell.")
	assert_true(line.contains("Reach Authority"))
	assert_true(line.to_lower().contains("standing fell") or line.contains("standing fell"))
	assert_false(line.contains("Drift Syndicate"), "must not dump other factions")
	assert_false(line.contains("Fringe Collective"), "must not dump other factions")


func test_format_kill_unattributed_plain_no_standing_change() -> void:
	var line: String = BalanceStanding.format_kill_unattributed()
	assert_eq(line, BalanceStanding.HUD_KILL_UNATTRIBUTED)
	assert_true(line.to_lower().contains("not recorded") or line.contains("not recorded"))
	assert_true(line.to_lower().contains("standing") or line.contains("standing"))


func test_format_kill_attributed_empty_name_uses_uncontrolled() -> void:
	var line: String = BalanceStanding.format_kill_attributed("  ")
	assert_true(line.contains(BalanceStanding.STATUS_UNCONTROLLED_LABEL))


# --- HUD toast from bus signals --------------------------------------------


func test_hud_shows_attributed_toast_from_bus() -> void:
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	assert_eq(hud.kill_toast_text(), "")

	EventBus.on_kill_attributed.emit(
		SYSTEM_ALPHA,
		ENTITY_REACH,
		BalanceStanding.COMBAT_KILL_DELTA,
		BalanceStanding.REASON_COMBAT_KILL
	)
	var toast: String = hud.kill_toast_text()
	assert_eq(toast, BalanceStanding.format_kill_attributed("Reach Authority"))
	assert_true(toast.contains("Reach Authority"))
	assert_true(toast.contains("standing fell"))


func test_hud_shows_unattributed_toast_from_bus() -> void:
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame

	EventBus.on_kill_unattributed.emit(SYSTEM_GAMMA, ENTITY_REACH)
	assert_eq(hud.kill_toast_text(), BalanceStanding.format_kill_unattributed())


func test_hud_status_moment_still_local_controller_only() -> void:
	## Status line is local controller — kill toast does not replace or broaden it.
	StandingService.set_entity_standing(ENTITY_REACH, -55.0)
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	EventBus.on_system_entered.emit(SYSTEM_ALPHA)
	await get_tree().process_frame
	# Shape used by HUD for the protected status moment.
	var status: Dictionary = StandingService.status_for_system(SYSTEM_ALPHA)
	var line: String = status[StandingService.STATUS_KEY_LINE]
	assert_true(line.to_upper().contains("REACH AUTHORITY") or line.contains("Reach"))
	assert_false(line.contains("Drift Syndicate"))
	assert_false(line.contains("Fringe Collective"))
	# Kill toast is a separate line naming the same local controller only.
	EventBus.on_kill_attributed.emit(
		SYSTEM_ALPHA,
		ENTITY_REACH,
		BalanceStanding.COMBAT_KILL_DELTA,
		BalanceStanding.REASON_COMBAT_KILL
	)
	var toast: String = hud.kill_toast_text()
	assert_ne(toast, line, "toast is not the status moment line")
	assert_true(toast.contains("Reach Authority"))
	assert_false(toast.contains("Drift Syndicate"))
	assert_false(toast.contains("Fringe Collective"))


# --- Live witness count from NpcTraffic ------------------------------------


func test_npc_traffic_live_ship_count_matches_policing() -> void:
	var traffic: NpcTraffic = _spawn_traffic_for(SYSTEM_BETA)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_CONTESTED)
	traffic.rebuild_for_system(SYSTEM_ALPHA)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_PATROLLED)
	traffic.rebuild_for_system(SYSTEM_GAMMA)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_LAWLESS)


func test_patrolled_kill_attributes_even_with_zero_traffic() -> void:
	## Patrolled attributes regardless of witnesses (standing law §7).
	_connect_kill_bus()
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	await get_tree().process_frame

	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	_kill_hostile_in(SYSTEM_ALPHA)
	await get_tree().process_frame

	assert_eq(_reported_witnesses.size(), 1, "kill must report")
	assert_eq(_reported_witnesses[0], 0, "no traffic → zero witnesses")
	assert_eq(_attributed_entities.size(), 1, "patrolled still attributes")
	assert_eq(_attributed_entities[0], ENTITY_REACH)
	assert_eq(_unattributed_systems.size(), 0)
	var after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(after, before + BalanceStanding.COMBAT_KILL_DELTA, TOLERANCE)
	assert_lt(after, before)


func test_contested_with_traffic_witnesses_attributes() -> void:
	_connect_kill_bus()
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	var traffic: NpcTraffic = _spawn_traffic_for(SYSTEM_BETA)
	await get_tree().process_frame

	var expected_witnesses: int = traffic.live_ship_count()
	assert_gte(expected_witnesses, BalanceStanding.ATTRIBUTION_WITNESS_THRESHOLD)

	var before: float = StandingService.get_entity_standing(ENTITY_BETA)
	_kill_hostile_in(SYSTEM_BETA)
	await get_tree().process_frame

	assert_eq(_reported_witnesses.size(), 1)
	assert_eq(
		_reported_witnesses[0],
		expected_witnesses,
		"witness_count must be live ambient traffic, not a fixed 1"
	)
	assert_eq(_attributed_entities.size(), 1, "contested + witnesses attributes")
	assert_eq(_attributed_entities[0], ENTITY_BETA)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_BETA),
		before + BalanceStanding.COMBAT_KILL_DELTA,
		TOLERANCE
	)


func test_contested_zero_traffic_no_evidence_unattributed() -> void:
	_connect_kill_bus()
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	await get_tree().process_frame
	# No NpcTraffic in tree → witnesses = 0.

	StandingService.set_entity_standing(ENTITY_BETA, 11.0)
	var before: float = StandingService.get_entity_standing(ENTITY_BETA)
	_kill_hostile_in(SYSTEM_BETA)
	await get_tree().process_frame

	assert_eq(_reported_witnesses.size(), 1)
	assert_eq(_reported_witnesses[0], 0)
	assert_eq(_unattributed_systems.size(), 1, "contested without witnesses/evidence")
	assert_eq(_attributed_entities.size(), 0)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_BETA), before, TOLERANCE)


func test_lawless_with_traffic_no_evidence_unattributed() -> void:
	## Lawless needs evidence; ambient traffic alone does not attribute (Dest law).
	_connect_kill_bus()
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	var traffic: NpcTraffic = _spawn_traffic_for(SYSTEM_GAMMA)
	await get_tree().process_frame
	assert_gt(traffic.live_ship_count(), 0)

	StandingService.set_entity_standing(ENTITY_GAMMA, 4.0)
	var before: float = StandingService.get_entity_standing(ENTITY_GAMMA)
	_kill_hostile_in(SYSTEM_GAMMA)
	await get_tree().process_frame

	assert_eq(_reported_witnesses.size(), 1)
	assert_eq(_reported_witnesses[0], traffic.live_ship_count())
	assert_eq(_unattributed_systems.size(), 1)
	assert_eq(_attributed_entities.size(), 0)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_GAMMA), before, TOLERANCE)


func test_standing_mutations_only_via_standing_service_after_attribution() -> void:
	## Attributed kill applies COMBAT_KILL_DELTA through StandingService; bus carries result.
	_connect_kill_bus()
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	await get_tree().process_frame

	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	_kill_hostile_in(SYSTEM_ALPHA)
	await get_tree().process_frame

	assert_eq(_attributed_entities.size(), 1)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		before + BalanceStanding.COMBAT_KILL_DELTA,
		TOLERANCE
	)


func test_kill_toast_duration_constant_positive() -> void:
	assert_gt(BalanceStanding.HUD_KILL_TOAST_SECONDS, 0.0)
