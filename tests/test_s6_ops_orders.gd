extends GutTest

## S6 Operations — orders, haul market + money, park persist.

const STATION_A: StringName = &"station_alpha_port"
const STATION_B: StringName = &"station_alpha_yard"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const ORE: StringName = &"commodity_ore"


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
	wallet.set_credits(20000)
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_FRIENDLY_MIN)
	return {&"wallet": wallet, &"ops": ops, &"docking": docking}


func test_set_park_and_escort_orders() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_true(ops.try_set_order(id, BalanceOps.ORDER_ESCORT, &"", &"", &""))
	var ship: Dictionary = ops.get_ship(id)
	assert_eq(_as_name(ship[BalanceOps.SHIP_KEY_ORDER]), BalanceOps.ORDER_ESCORT)
	assert_true(ops.try_set_order(id, BalanceOps.ORDER_PARK, &"", &"", &""))
	ship = ops.get_ship(id)
	assert_eq(_as_name(ship[BalanceOps.SHIP_KEY_ORDER]), BalanceOps.ORDER_PARK)


func test_invalid_haul_rejected() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	# Same origin/dest.
	assert_false(ops.try_set_order(id, BalanceOps.ORDER_HAUL, STATION_A, STATION_A, ORE))
	# Fighter cannot haul.
	var fighter: StringName = ops.try_hire(BalanceOps.TYPE_FIGHTER, STATION_A)
	assert_false(ops.try_set_order(fighter, BalanceOps.ORDER_HAUL, STATION_A, STATION_B, ORE))
	# Unknown order.
	assert_false(ops.try_set_order(id, &"fly_to_moon", STATION_A, STATION_B, ORE))


func test_haul_moves_market_stock_and_money() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var wallet: WalletService = stack[&"wallet"]
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_true(ops.try_set_order(id, BalanceOps.ORDER_HAUL, STATION_A, STATION_B, ORE))

	var stock_origin_before: int = MarketService.stock(STATION_A, ORE)
	var stock_dest_before: int = MarketService.stock(STATION_B, ORE)
	var credits_before: int = wallet.credits()
	var haul_pay_events: Array = []
	var on_money: Callable = func(
		reason: StringName, credits_delta: int, _after: int, _detail: Dictionary
	) -> void:
		if reason == BalanceTelemetry.REASON_OPS_HAUL_PAY and credits_delta != 0:
			haul_pay_events.append(credits_delta)
	EventBus.on_money_event.connect(on_money)

	# Drive haul via tick_ops (also charges upkeep). Full WorldClock advance also
	# runs market production, which can restock more units than one haul leg pulls.
	ops.tick_ops(BalanceOps.HAUL_LEG_HOURS * BalanceWorldClock.SECONDS_PER_HOUR)

	if EventBus.on_money_event.is_connected(on_money):
		EventBus.on_money_event.disconnect(on_money)

	var stock_origin_after: int = MarketService.stock(STATION_A, ORE)
	var stock_dest_after: int = MarketService.stock(STATION_B, ORE)
	assert_lt(stock_origin_after, stock_origin_before, "haul buy must reduce origin stock")
	assert_gt(stock_dest_after, stock_dest_before, "haul sell must increase dest stock")
	assert_true(haul_pay_events.size() >= 1, "haul must emit ops_haul_pay money events")
	# Adversary: upkeep alone would green a bare assert_ne(credits). Require
	# wallet to differ from "upkeep-only" so strip-haul-money fails.
	var expected_upkeep: int = (
		BalanceOps.UPKEEP_CREDITS_PER_HOUR * int(round(BalanceOps.HAUL_LEG_HOURS))
	)
	var credits_after_upkeep_only: int = credits_before - expected_upkeep
	assert_ne(
		wallet.credits(),
		credits_after_upkeep_only,
		"haul buy/sell must move credits beyond upkeep alone"
	)


func test_park_persists_across_time() -> void:
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_true(ops.try_set_order(id, BalanceOps.ORDER_PARK, &"", &"", &""))
	WorldClock.advance_hours(BalanceOps.HAUL_LEG_HOURS * 2.0)
	var ship: Dictionary = ops.get_ship(id)
	assert_eq(_as_name(ship[BalanceOps.SHIP_KEY_ORDER]), BalanceOps.ORDER_PARK)
	assert_eq(ops.hired_count(), 1)


func test_haul_does_not_use_mission_service() -> void:
	## Regression: fleet haul is MarketService + wallet only — MissionService
	## must stay idle (no accept/complete path for abstract legs).
	var stack: Dictionary = _make_ops_stack()
	var ops: OperationService = stack[&"ops"]
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	await get_tree().process_frame
	assert_false(mission.has_active(), "precondition: no personal mission")
	var id: StringName = ops.try_hire(BalanceOps.TYPE_HAULER, STATION_A)
	assert_true(ops.try_set_order(id, BalanceOps.ORDER_HAUL, STATION_A, STATION_B, ORE))
	ops.tick_ops(BalanceOps.HAUL_LEG_HOURS * BalanceWorldClock.SECONDS_PER_HOUR)
	assert_false(mission.has_active(), "haul must not create a personal mission")
	assert_false(
		ops.has_method(&"accept") or ops.has_method(&"try_complete_at"),
		"OperationService must not expose MissionService APIs"
	)
	# Source guard: ops file must not reference MissionService by name.
	var src: String = FileAccess.get_file_as_string("res://src/systems/ops/OperationService.gd")
	assert_false(src.contains("MissionService"), "ops must not call MissionService")


func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""


class _FakeDock:
	extends Node
	var station_id: StringName = &""

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station_id
