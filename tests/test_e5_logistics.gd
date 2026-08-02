extends GutTest

## E5.4 Multi-station logistics.
##
## Implements: docs/BETA_E5_CONTENT_SCALE.md E5.4

const GRAIN: StringName = &"commodity_grain"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_ZETA: StringName = &"system_zeta"
const STATION_ZETA: StringName = &"station_zeta_spur"
const STATION_DELTA_YARD: StringName = &"station_delta_yard"
const CONTRACT_ZETA: StringName = &"contract_courier_reach_zeta"
const CONTRACT_DELTA_YARD: StringName = &"contract_courier_fringe_delta_yard"
const CONTRACT_SMUGGLE: StringName = &"contract_smuggle_beta_to_gamma"
const FIGHTER_ID: StringName = BalanceFlight.FIGHTER_HULL_ID
const HAULER_ID: StringName = BalanceFlight.PLAYER_HULL_ID


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_secondary_or_new_dock_as_destination() -> void:
	var secondary: Array[StringName] = [
		&"station_alpha_yard",
		&"station_beta_spit",
		&"station_gamma_rim",
		&"station_delta_yard",
		&"station_epsilon_belt",
		&"station_zeta_spur",
	]
	var found: int = 0
	for id: StringName in ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY):
		var contract: ContractType = ContentLibrary.item(id) as ContractType
		if contract == null:
			continue
		if secondary.has(contract.destination_station_id):
			found += 1
	assert_gte(found, 1, "≥1 job ends at a secondary/new non-hub dock")


func test_two_long_haul_routes_at_least_two_hops() -> void:
	var long_routes: int = 0
	for id: StringName in ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY):
		var contract: ContractType = ContentLibrary.item(id) as ContractType
		if contract == null or contract.kind != BalanceStanding.MISSION_KIND_DELIVERY:
			continue
		var origin_system: StringName = _any_system_for_entity(contract.offering_entity_id)
		var dest_system: StringName = SectorGraph.system_of_station(contract.destination_station_id)
		var hops: int = SectorGraph.hop_distance(origin_system, dest_system)
		if hops >= 2:
			long_routes += 1
	assert_gte(long_routes, 2, "≥2 courier templates need ≥2 gate hops")


func test_trade_contrast_core_vs_zeta_grain() -> void:
	var grain: Commodity = ContentLibrary.item(GRAIN) as Commodity
	assert_ne(grain, null)
	var buy_alpha: int = BalanceEconomy.buy_price_at(grain, SYSTEM_ALPHA)
	var sell_zeta: int = BalanceEconomy.sell_price_at(grain, SYSTEM_ZETA)
	assert_gt(sell_zeta, buy_alpha, "grain profitable Alpha buy → Zeta sell")


func test_long_haul_accept_and_turn_in() -> void:
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_true(ContentLibrary.has_item(CONTRACT_ZETA))
	assert_true(mission.accept(CONTRACT_ZETA), "accept long-haul Reach→Zeta")
	assert_true(mission.has_active())
	var result: Dictionary = mission.try_complete_at(STATION_ZETA)
	var attributed_raw: Variant = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	var attributed: bool = false
	if typeof(attributed_raw) == TYPE_BOOL:
		attributed = attributed_raw
	assert_true(attributed, "turn-in at Zeta spur")


func test_fringe_long_haul_to_delta_yard() -> void:
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_true(mission.accept(CONTRACT_DELTA_YARD))
	var result: Dictionary = mission.try_complete_at(STATION_DELTA_YARD)
	var attributed_raw: Variant = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	var attributed: bool = false
	if typeof(attributed_raw) == TYPE_BOOL:
		attributed = attributed_raw
	assert_true(attributed)


func test_fighter_still_blocked_from_oversize_smuggle() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	await get_tree().process_frame
	cargo.reset()
	ships.reset()
	mission.reset()
	ships.set_active_hull_id(FIGHTER_ID)
	assert_false(mission.accept(CONTRACT_SMUGGLE), "fighter cannot fit smuggle qty")
	ships.set_active_hull_id(HAULER_ID)
	assert_true(mission.accept(CONTRACT_SMUGGLE), "hauler can accept smuggle")


func _any_system_for_entity(entity_id: StringName) -> StringName:
	for station_id: StringName in ContentLibrary.ids_in(&"stations"):
		var station: Station = ContentLibrary.item(station_id) as Station
		if station != null and station.controller_entity_id == entity_id:
			return station.system_id
	return SYSTEM_ALPHA
