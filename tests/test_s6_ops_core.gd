extends GutTest

## S6 Operations — hire/fire, standing gate, max N, upkeep, CareerSave round-trip.

const STATION_A: StringName = &"station_alpha_port"
const ENTITY_REACH: StringName = &"entity_reach_authority"


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()
	MarketService.reset()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()


func _make_ops_stack() -> Dictionary:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	var cargo: CargoService = CargoService.new()
	var ops: OperationService = OperationService.new()
	var docking: _FakeDock = _FakeDock.new()
	docking.station_id = STATION_A
	host.add_child(wallet)
	host.add_child(cargo)
	host.add_child(ops)
	host.add_child(docking)
	wallet.reset()
	cargo.reset()
	ops.reset()
	wallet.set_credits(5000)
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_FRIENDLY_MIN)
	return {&"host": host, &"wallet": wallet, &"cargo": cargo, &"ops": ops, &"docking": docking}


func test_hire_and_fire_updates_count_and_money() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var wallet: WalletService = stack[&"wallet"]
	var before: int = wallet.credits()
	assert_true(ops.can_hire(BalanceOps.TYPE_HAULER, STATION_A))
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_false(String(id).is_empty())
	assert_eq(ops.hired_count(), 1)
	assert_eq(wallet.credits(), before - BalanceOps.HIRE_COST)
	assert_true(ops.try_fire(id))
	assert_eq(ops.hired_count(), 0)


func test_fire_stops_upkeep() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var wallet: WalletService = stack[&"wallet"]
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_false(String(id).is_empty())
	assert_true(ops.try_fire(id))
	assert_eq(ops.hired_count(), 0)
	var after_fire: int = wallet.credits()
	WorldClock.advance_hours(2.0)
	assert_eq(wallet.credits(), after_fire, "fired ships must not keep charging upkeep")


func test_broke_wallet_refuses_hire() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var wallet: WalletService = stack[&"wallet"]
	wallet.set_credits(BalanceOps.HIRE_COST - 1)
	assert_false(ops.can_hire(BalanceOps.TYPE_HAULER, STATION_A))
	assert_eq(String(ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)), "")


func test_bus_hire_request_hires_while_docked() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	await get_tree().process_frame
	EventBus.on_ops_hire_requested.emit(BalanceOps.TYPE_HAULER)
	assert_eq(ops.hired_count(), 1, "hire_requested bus path must hire while docked")


func test_standing_below_friendly_refuses_hire() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_FRIENDLY_MIN - 1.0)
	assert_false(ops.can_hire(BalanceOps.TYPE_HAULER, STATION_A))
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_eq(String(id), "")
	assert_eq(ops.hired_count(), 0)


func test_max_hired_cap() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var wallet: WalletService = stack[&"wallet"]
	wallet.set_credits(10000)
	assert_false(String(ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)).is_empty())
	assert_false(String(ops.try_hire(BalanceOps.TYPE_FIGHTER, STATION_A)).is_empty())
	assert_eq(ops.hired_count(), BalanceOps.MAX_HIRED)
	assert_false(ops.can_hire(BalanceOps.TYPE_HAULER, STATION_A))
	var third: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_eq(String(third), "")


func test_upkeep_charges_while_docked() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var wallet: WalletService = stack[&"wallet"]
	ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	var before: int = wallet.credits()
	# 1 game hour → 5 credits per hired ship.
	WorldClock.advance_hours(1.0)
	var expected: int = BalanceOps.UPKEEP_CREDITS_PER_HOUR * ops.hired_count()
	assert_eq(wallet.credits(), before - expected)


func test_career_save_round_trip_and_missing_resets() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_false(String(id).is_empty())
	assert_true(
		ops.try_set_order(
			id, BalanceOps.ORDER_HAUL, STATION_A, &"station_alpha_yard", &"commodity_ore"
		)
	)

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceOps.SAVE_SECTION_KEY))
	var section: Dictionary = sections[BalanceOps.SAVE_SECTION_KEY]
	assert_true(section.has(BalanceOps.KEY_HIRED))
	var hired: Array = section[BalanceOps.KEY_HIRED]
	assert_eq(hired.size(), 1)

	ops.reset()
	assert_eq(ops.hired_count(), 0)
	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_eq(ops.hired_count(), 1)
	var restored: Dictionary = ops.get_ship(id)
	assert_eq(_as_name(restored[BalanceOps.SHIP_KEY_ORDER]), BalanceOps.ORDER_HAUL)
	assert_eq(_as_name(restored[BalanceOps.SHIP_KEY_ORIGIN]), STATION_A)
	assert_eq(_as_name(restored[BalanceOps.SHIP_KEY_DEST]), &"station_alpha_yard")
	assert_eq(_as_name(restored[BalanceOps.SHIP_KEY_COMMODITY]), &"commodity_ore")
	assert_eq(_as_name(restored[BalanceOps.SHIP_KEY_CHARTER]), ENTITY_REACH)

	# Missing section → empty ops.
	var without_ops: Dictionary = sections.duplicate(true)
	without_ops.erase(BalanceOps.SAVE_SECTION_KEY)
	CareerSave.apply_meta_sections(get_tree(), without_ops)
	assert_eq(ops.hired_count(), 0)


func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""


func test_charter_breach_hits_standing_and_fires() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var wallet: WalletService = stack[&"wallet"]
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_false(String(id).is_empty())
	var standing_before: float = StandingService.get_entity_standing(ENTITY_REACH)
	# Zero wallet so upkeep cannot be paid.
	wallet.set_credits(0)
	# Force miss cycles: each hour with unpaid whole credits increments miss.
	# Advance enough hours that floor(rate * hours) >= 1 each tick path.
	for _i: int in BalanceOps.UPKEEP_MISS_BREACH_COUNT:
		WorldClock.advance_hours(1.0)
	assert_eq(ops.hired_count(), 0, "breach must fire the ship")
	var standing_after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_lt(standing_after, standing_before, "breach must hit charter standing")
	assert_eq(StandingService.last_delta_reason, BalanceStanding.REASON_CHARTER_BREACH)


class _FakeDock:
	extends Node
	var station_id: StringName = &""

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station_id
