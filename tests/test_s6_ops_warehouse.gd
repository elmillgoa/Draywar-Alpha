extends GutTest

## S6 Operations — warehouse deposit/withdraw, capacity, save.

const STATION_A: StringName = &"station_alpha_port"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const ORE: StringName = &"commodity_ore"


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()


func _make_stack() -> Dictionary:
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
	return {&"wallet": wallet, &"cargo": cargo, &"ops": ops, &"docking": docking}


func test_deposit_and_withdraw() -> void:
	var stack: Dictionary = _make_stack()
	var ops: OperationService = stack[&"ops"]
	var cargo: CargoService = stack[&"cargo"]
	assert_true(cargo.add(ORE, 5))
	assert_eq(cargo.quantity(ORE), 5)
	assert_true(ops.try_deposit(STATION_A, ORE, 3))
	assert_eq(cargo.quantity(ORE), 2)
	assert_eq(ops.warehouse_qty(STATION_A, ORE), 3)
	assert_true(ops.try_withdraw(STATION_A, ORE, 2))
	assert_eq(cargo.quantity(ORE), 4)
	assert_eq(ops.warehouse_qty(STATION_A, ORE), 1)


func test_capacity_blocks_overfill() -> void:
	var stack: Dictionary = _make_stack()
	var ops: OperationService = stack[&"ops"]
	var cargo: CargoService = stack[&"cargo"]
	# Ore unit_volume is 1 in content; fill warehouse to capacity.
	var fill: int = BalanceOps.WAREHOUSE_CAPACITY
	# Cargo capacity may be lower than warehouse — deposit in chunks.
	var remaining: int = fill
	while remaining > 0:
		var chunk: int = mini(remaining, maxi(1, cargo.capacity() - cargo.used_volume()))
		if chunk <= 0:
			# Empty hold path: still need inventory for deposit; reset hold free.
			cargo.reset()
			chunk = mini(remaining, cargo.capacity())
		assert_true(cargo.add(ORE, chunk), "seed cargo for deposit")
		assert_true(ops.try_deposit(STATION_A, ORE, chunk))
		remaining -= chunk
	assert_eq(ops.warehouse_used_volume(STATION_A), BalanceOps.WAREHOUSE_CAPACITY)
	cargo.reset()
	assert_true(cargo.add(ORE, 1))
	assert_false(ops.try_deposit(STATION_A, ORE, 1), "over capacity must refuse")


func test_undocked_refuses_warehouse() -> void:
	var stack: Dictionary = _make_stack()
	var ops: OperationService = stack[&"ops"]
	var cargo: CargoService = stack[&"cargo"]
	var docking: _FakeDock = stack[&"docking"]
	assert_true(cargo.add(ORE, 2))
	docking.station_id = &""
	assert_false(ops.try_deposit(STATION_A, ORE, 1))
	docking.station_id = STATION_A
	assert_true(ops.try_deposit(STATION_A, ORE, 1))
	docking.station_id = &""
	assert_false(ops.try_withdraw(STATION_A, ORE, 1))


func test_warehouse_save_round_trip() -> void:
	var stack: Dictionary = _make_stack()
	var ops: OperationService = stack[&"ops"]
	var cargo: CargoService = stack[&"cargo"]
	assert_true(cargo.add(ORE, 4))
	assert_true(ops.try_deposit(STATION_A, ORE, 4))
	assert_eq(ops.warehouse_qty(STATION_A, ORE), 4)

	var section: Dictionary = ops.to_section()
	ops.reset()
	assert_eq(ops.warehouse_qty(STATION_A, ORE), 0)
	ops.apply_section(section)
	assert_eq(ops.warehouse_qty(STATION_A, ORE), 4)

	# CareerSave path.
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceOps.SAVE_SECTION_KEY))
	ops.reset()
	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_eq(ops.warehouse_qty(STATION_A, ORE), 4)


class _FakeDock:
	extends Node
	var station_id: StringName = &""

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station_id
