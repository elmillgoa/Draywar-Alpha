extends GutTest

## A5 minimal playable slice — multi-system, money, NPC traffic, normal-play loop.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5

const ENTITY_REACH: StringName = &"entity_reach_authority"
const CONTRACT_ALPHA: StringName = &"contract_courier_alpha"
const STATION_ALPHA: StringName = &"station_alpha_port"
const STATION_BETA: StringName = &"station_beta_hub"
const PERSON_MENDI: StringName = &"person_ra_mendi"
const TOLERANCE: float = 0.001


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_three_systems_distinct_controllers_and_security() -> void:
	var systems: Array[StringName] = [&"system_alpha", &"system_beta", &"system_gamma"]
	var policings: Dictionary = {}
	var holders: Dictionary = {}
	for system_id: StringName in systems:
		assert_true(ContentLibrary.has_item(system_id))
		var system: StarSystem = ContentLibrary.item(system_id) as StarSystem
		assert_ne(system, null)
		assert_gt(system.station_ids.size(), 0, "%s needs a station" % system_id)
		assert_gt(system.gate_destination_ids.size(), 0, "%s needs a gate" % system_id)
		policings[system.policing] = true
		holders[system.held_by] = true
	assert_eq(policings.size(), 3, "need patrolled, contested, lawless")
	assert_eq(holders.size(), 3, "three distinct controllers")


func test_system_world_places_gates_and_npc_traffic() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_alpha"
	add_child_autofree(world)
	world.build()

	var gates: Dictionary[StringName, Vector3] = world.gate_positions()
	assert_true(gates.has(&"system_beta"), "alpha gate must target beta")
	assert_gt(world.get_child_count(), 2, "station, gate, env, npc traffic expected")

	var npc: NpcTraffic = null
	for child: Node in world.get_children():
		if child is NpcTraffic:
			npc = child as NpcTraffic
			break
	assert_ne(npc, null, "NpcTraffic must spawn under the world")
	assert_eq(npc.get_child_count(), BalanceEconomy.NPC_COUNT_PATROLLED)


func test_npc_count_follows_policing() -> void:
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(&"system_alpha")
	assert_eq(traffic.get_child_count(), BalanceEconomy.NPC_COUNT_PATROLLED)
	traffic.rebuild_for_system(&"system_beta")
	assert_eq(traffic.get_child_count(), BalanceEconomy.NPC_COUNT_CONTESTED)
	traffic.rebuild_for_system(&"system_gamma")
	assert_eq(traffic.get_child_count(), BalanceEconomy.NPC_COUNT_LAWLESS)


func test_wallet_mission_pay_and_dock_fee() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start: int = wallet.credits()
	assert_eq(start, BalanceEconomy.STARTING_CREDITS)

	var fee: int = wallet.charge_dock_fee(&"system_alpha")
	assert_eq(fee, BalanceEconomy.DOCK_FEE_PATROLLED)
	assert_eq(wallet.credits(), start - fee)

	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	assert_true(mission.accept(CONTRACT_ALPHA))
	var before_pay: int = wallet.credits()
	var result: Dictionary = mission.complete()
	var attributed: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	assert_true(attributed)
	assert_eq(wallet.credits(), before_pay + BalanceEconomy.MISSION_PAY_DEFAULT)


func test_wallet_fuel_burn_and_jump_cost() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var before: float = wallet.fuel()
	wallet.burn_fuel(1.0, 1.0, false)
	assert_lt(wallet.fuel(), before)
	assert_true(wallet.can_jump())
	assert_true(wallet.try_spend_jump_fuel())
	assert_almost_eq(
		wallet.fuel(),
		before - BalanceEconomy.FUEL_BURN_PER_SECOND_AT_FULL - BalanceEconomy.JUMP_FUEL_COST,
		TOLERANCE
	)


func test_mission_destination_gate_for_turn_in() -> void:
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	assert_true(mission.accept(CONTRACT_ALPHA))
	assert_false(mission.can_complete_at_station(STATION_ALPHA))
	assert_true(mission.can_complete_at_station(STATION_BETA))
	assert_eq(mission.active_destination_station_id(), STATION_BETA)


func test_refuel_and_repair_cost_credits() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	wallet.set_credits(1000)
	# Drain fuel and hull.
	while wallet.fuel() > 1.0:
		wallet.burn_fuel(1.0, 1.0, true)
	wallet.wear_condition(50.0, true)
	assert_lt(wallet.fuel(), BalanceEconomy.FUEL_MAX)
	assert_lt(wallet.condition(), BalanceEconomy.CONDITION_MAX)
	var credits_before: int = wallet.credits()
	var added: float = wallet.refuel_chunk()
	assert_gt(added, 0.0)
	assert_lt(wallet.credits(), credits_before)
	credits_before = wallet.credits()
	assert_true(wallet.repair_full())
	assert_lt(wallet.credits(), credits_before)
	assert_almost_eq(wallet.condition(), BalanceEconomy.CONDITION_MAX, TOLERANCE)


func test_recovery_favor_and_complete_via_event_bus() -> void:
	StandingService.reset_to_defaults()
	var recovery: RecoveryService = RecoveryService.new()
	add_child_autofree(recovery)
	recovery.reset()

	# Bootstrap to Friendly without console method call — EventBus path.
	while not StandingService.can_offer_recovery(PERSON_MENDI):
		EventBus.on_recovery_favor_requested.emit(PERSON_MENDI)

	assert_true(recovery.has_offer_for_person(PERSON_MENDI))
	EventBus.on_recovery_accept_requested.emit(PERSON_MENDI)
	assert_true(recovery.has_active())

	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var credits_before: int = wallet.credits()
	EventBus.on_recovery_complete_requested.emit()
	assert_false(recovery.has_active())
	assert_eq(wallet.credits(), credits_before + BalanceEconomy.RECOVERY_STEP_PAY)


func test_wallet_save_section_round_trip() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	wallet.set_credits(321)
	wallet.burn_fuel(2.0, 1.0, false)
	wallet.wear_condition(5.0, true)
	var section: Dictionary = wallet.to_section()
	var other: WalletService = WalletService.new()
	add_child_autofree(other)
	other.apply_section(section)
	assert_eq(other.credits(), 321)
	assert_almost_eq(other.fuel(), wallet.fuel(), TOLERANCE)
	assert_almost_eq(other.condition(), wallet.condition(), TOLERANCE)


func test_contract_templates_have_pay_and_destinations() -> void:
	for id: StringName in ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY):
		var item: ContentItem = ContentLibrary.item(id)
		assert_true(item is ContractType)
		var contract: ContractType = item as ContractType
		assert_gte(contract.pay_credits, 0)
		assert_false(String(contract.destination_station_id).is_empty())


func test_deep_negative_still_allows_dock_for_open_recovery_contact() -> void:
	## Law Example B: Hated by Entity, open personal recovery → still seek them out.
	StandingService.reset_to_defaults()
	StandingService.set_entity_standing(ENTITY_REACH, -70.0)
	assert_true(
		StandingService.has_open_recovery_contact_for_controller(ENTITY_REACH),
		"Mendi chain must keep Reach recovery open"
	)
	assert_true(
		StandingService.can_dock_at_station(STATION_ALPHA),
		"deep negative must not block dock while recovery contact is open"
	)
	StandingService.close_person(PERSON_MENDI, BalanceStanding.RECOVERY_CLOSE_REASON_BETRAYAL)
	assert_false(
		StandingService.can_dock_at_station(STATION_ALPHA),
		"after recovery closed, dock refusal applies again"
	)


func test_mission_complete_via_event_bus_requires_destination_dock() -> void:
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	assert_true(mission.accept(CONTRACT_ALPHA))
	# Wrong station (not docked) — EventBus complete must no-op.
	EventBus.on_mission_complete_requested.emit()
	assert_true(mission.has_active(), "complete without destination dock must fail")
