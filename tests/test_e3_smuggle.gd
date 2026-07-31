extends GutTest

## E3.4 smuggle job kind — accept loads cargo, complete needs hold + dest.
##
## Implements: docs/BETA_E3_ECONOMY.md E3.4 / locked D4

const StationBoardUiScript = preload("res://src/ui/station/StationBoardUi.gd")

const ENTITY_BETA: StringName = &"entity_beta_syndicate"
const ENTITY_GAMMA: StringName = &"entity_gamma_collective"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const CONTRACT_B2G: StringName = &"contract_smuggle_beta_to_gamma"
const CONTRACT_G2B: StringName = &"contract_smuggle_gamma_to_beta"
const CONTRACT_DELIVERY: StringName = &"contract_courier_alpha"
const CONTRACT_BOUNTY: StringName = &"contract_bounty_beta_spit"
const STATION_GAMMA: StringName = &"station_gamma_outpost"
const STATION_BETA: StringName = &"station_beta_hub"
const STATION_ALPHA: StringName = &"station_alpha_port"
const MUNITIONS: StringName = &"commodity_munitions"
const GRAIN: StringName = &"commodity_grain"
const HAULER_ID: StringName = BalanceFlight.PLAYER_HULL_ID
const FIGHTER_ID: StringName = BalanceFlight.FIGHTER_HULL_ID
const TOLERANCE: float = 0.0001
const PAY_B2G: int = 240
const PAY_G2B: int = 260
const SMUGGLE_QTY: int = 5


class FakeDock:
	extends Node
	var station: StringName = STATION_ALPHA

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station


func after_each() -> void:
	StandingService.reset_to_defaults()


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _attributed(result: Dictionary) -> bool:
	return result[BalanceStanding.REPORT_KEY_ATTRIBUTED] == true


func _pay_from(result: Dictionary) -> int:
	return _variant_to_int(result.get(&"pay_credits", 0))


func _setup() -> Dictionary:
	var host: Node = Node.new()
	add_child_autofree(host)
	var dock: FakeDock = FakeDock.new()
	dock.station = STATION_BETA
	host.add_child(dock)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	wallet.reset()
	cargo.reset()
	ships.reset()
	mission.reset()
	return {
		&"host": host,
		&"dock": dock,
		&"wallet": wallet,
		&"cargo": cargo,
		&"ships": ships,
		&"mission": mission,
	}


func test_exactly_three_mission_kinds_in_content() -> void:
	var kinds: Dictionary = {}
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY)
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[BalanceStanding.MISSION_CONTENT_CATEGORY])
	for id: StringName in ids:
		var contract: ContractType = ContentLibrary.item(id) as ContractType
		assert_ne(contract, null)
		kinds[contract.kind] = true
	assert_eq(kinds.size(), 3, "exactly three mission kinds in content")
	assert_true(kinds.has(BalanceStanding.MISSION_KIND_DELIVERY))
	assert_true(kinds.has(BalanceStanding.MISSION_KIND_BOUNTY))
	assert_true(kinds.has(BalanceStanding.MISSION_KIND_SMUGGLE))
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))


func test_smuggle_templates_load_and_validate() -> void:
	assert_true(ContentLibrary.has_item(CONTRACT_B2G))
	assert_true(ContentLibrary.has_item(CONTRACT_G2B))
	var b2g: ContractType = ContentLibrary.item(CONTRACT_B2G) as ContractType
	var g2b: ContractType = ContentLibrary.item(CONTRACT_G2B) as ContractType
	assert_eq(b2g.kind, BalanceStanding.MISSION_KIND_SMUGGLE)
	assert_eq(g2b.kind, BalanceStanding.MISSION_KIND_SMUGGLE)
	assert_eq(b2g.cargo_commodity_id, MUNITIONS)
	assert_eq(g2b.cargo_commodity_id, MUNITIONS)
	assert_eq(b2g.cargo_quantity, SMUGGLE_QTY)
	assert_eq(g2b.cargo_quantity, SMUGGLE_QTY)
	assert_eq(b2g.destination_station_id, STATION_GAMMA)
	assert_eq(g2b.destination_station_id, STATION_BETA)
	assert_eq(b2g.offering_entity_id, ENTITY_BETA)
	assert_eq(g2b.offering_entity_id, ENTITY_GAMMA)
	assert_eq(b2g.pay_credits, PAY_B2G)
	assert_eq(g2b.pay_credits, PAY_G2B)
	assert_gte(b2g.pay_credits, 200)
	assert_lte(b2g.pay_credits, 280)
	assert_gte(g2b.pay_credits, 200)
	assert_lte(g2b.pay_credits, 280)
	assert_eq(b2g.validation_errors().size(), 0)
	assert_eq(g2b.validation_errors().size(), 0)
	# Dest is gray station, not a Reach market turn-in.
	var dest_b2g: Station = ContentLibrary.item(STATION_GAMMA) as Station
	var dest_g2b: Station = ContentLibrary.item(STATION_BETA) as Station
	assert_ne(dest_b2g.controller_entity_id, ENTITY_REACH)
	assert_ne(dest_g2b.controller_entity_id, ENTITY_REACH)


func test_contract_type_smuggle_requires_cargo_fields() -> void:
	var contract: ContractType = ContractType.new()
	contract.id = &"fixture_smuggle"
	contract.display_name = "Fixture smuggle"
	contract.offering_entity_id = ENTITY_BETA
	contract.kind = BalanceStanding.MISSION_KIND_SMUGGLE
	var problems: PackedStringArray = contract.validation_errors()
	var joined: String = " ".join(problems)
	assert_string_contains(joined, "destination_station_id")
	assert_string_contains(joined, "cargo_commodity_id")
	assert_string_contains(joined, "cargo_quantity")
	contract.destination_station_id = STATION_GAMMA
	contract.cargo_commodity_id = MUNITIONS
	contract.cargo_quantity = SMUGGLE_QTY
	assert_eq(contract.validation_errors().size(), 0)


func test_accept_loads_cargo_complete_pays_and_removes() -> void:
	var env: Dictionary = _setup()
	var mission: MissionService = env[&"mission"]
	var cargo: CargoService = env[&"cargo"]
	var wallet: WalletService = env[&"wallet"]
	var ships: ShipService = env[&"ships"]
	ships.set_active_hull_id(HAULER_ID)

	assert_eq(cargo.quantity(MUNITIONS), 0)
	assert_true(mission.accept(CONTRACT_B2G))
	assert_eq(mission.active_kind(), BalanceStanding.MISSION_KIND_SMUGGLE)
	assert_eq(cargo.quantity(MUNITIONS), SMUGGLE_QTY)
	assert_true(mission.is_objective_ready())
	assert_true(mission.can_complete_at_station(STATION_GAMMA))
	assert_false(mission.can_complete_at_station(STATION_ALPHA))

	var before: int = wallet.credits()
	var before_standing: float = StandingService.get_entity_standing(ENTITY_BETA)
	var result: Dictionary = mission.try_complete_at(STATION_GAMMA)
	assert_true(_attributed(result))
	assert_eq(_pay_from(result), PAY_B2G)
	assert_eq(wallet.credits(), before + PAY_B2G)
	assert_eq(cargo.quantity(MUNITIONS), 0, "cargo removed on complete")
	assert_false(mission.has_active())
	var after_standing: float = StandingService.get_entity_standing(ENTITY_BETA)
	assert_gt(after_standing, before_standing)


func test_complete_refuses_without_cargo() -> void:
	var env: Dictionary = _setup()
	var mission: MissionService = env[&"mission"]
	var cargo: CargoService = env[&"cargo"]
	var ships: ShipService = env[&"ships"]
	ships.set_active_hull_id(HAULER_ID)

	assert_true(mission.accept(CONTRACT_B2G))
	assert_true(cargo.remove(MUNITIONS, SMUGGLE_QTY))
	assert_false(mission.is_objective_ready())
	assert_false(mission.can_complete_at_station(STATION_GAMMA))
	var result: Dictionary = mission.try_complete_at(STATION_GAMMA)
	assert_false(_attributed(result))
	assert_true(mission.has_active())


func test_abandon_leaves_cargo() -> void:
	var env: Dictionary = _setup()
	var mission: MissionService = env[&"mission"]
	var cargo: CargoService = env[&"cargo"]
	var ships: ShipService = env[&"ships"]
	ships.set_active_hull_id(HAULER_ID)

	assert_true(mission.accept(CONTRACT_B2G))
	assert_eq(cargo.quantity(MUNITIONS), SMUGGLE_QTY)
	var before_standing: float = StandingService.get_entity_standing(ENTITY_BETA)
	var result: Dictionary = mission.abandon()
	assert_true(_attributed(result))
	assert_eq(cargo.quantity(MUNITIONS), SMUGGLE_QTY, "abandon leaves cargo")
	assert_false(mission.has_active())
	var after_standing: float = StandingService.get_entity_standing(ENTITY_BETA)
	assert_lt(after_standing, before_standing)


func test_fighter_refuses_oversized_smuggle_hauler_accepts() -> void:
	var env: Dictionary = _setup()
	var mission: MissionService = env[&"mission"]
	var cargo: CargoService = env[&"cargo"]
	var ships: ShipService = env[&"ships"]

	ships.set_active_hull_id(FIGHTER_ID)
	assert_eq(cargo.capacity(), 1)
	assert_false(mission.accept(CONTRACT_B2G), "fighter cannot fit smuggle qty")
	assert_false(mission.has_active())
	assert_eq(cargo.quantity(MUNITIONS), 0)

	ships.set_active_hull_id(HAULER_ID)
	assert_gte(cargo.capacity(), SMUGGLE_QTY)
	assert_true(mission.accept(CONTRACT_B2G), "hauler accepts smuggle")
	assert_eq(cargo.quantity(MUNITIONS), SMUGGLE_QTY)


func test_full_hold_refuses_smuggle_accept() -> void:
	var env: Dictionary = _setup()
	var mission: MissionService = env[&"mission"]
	var cargo: CargoService = env[&"cargo"]
	var ships: ShipService = env[&"ships"]
	ships.set_active_hull_id(HAULER_ID)

	var free: int = cargo.free_volume()
	assert_true(cargo.add(GRAIN, free))
	assert_eq(cargo.free_volume(), 0)
	assert_false(mission.accept(CONTRACT_B2G))
	assert_false(mission.has_active())
	assert_eq(cargo.quantity(MUNITIONS), 0)


func test_reach_inspection_still_applies_to_smuggle_cargo() -> void:
	## Carrying munitions into Reach still triggers E3.3 fine + seize.
	var env: Dictionary = _setup()
	var mission: MissionService = env[&"mission"]
	var cargo: CargoService = env[&"cargo"]
	var wallet: WalletService = env[&"wallet"]
	var dock: FakeDock = env[&"dock"]
	var ships: ShipService = env[&"ships"]
	ships.set_active_hull_id(HAULER_ID)
	wallet.set_credits(500)

	assert_true(mission.accept(CONTRACT_B2G))
	assert_eq(cargo.quantity(MUNITIONS), SMUGGLE_QTY)

	dock.station = STATION_ALPHA
	var before_credits: int = wallet.credits()
	var before_standing: float = StandingService.get_entity_standing(ENTITY_REACH)
	var inspection: Dictionary = cargo.inspect_on_dock()
	var found: bool = inspection.get(&"found", false) == true
	assert_true(found)
	assert_eq(cargo.quantity(MUNITIONS), 0, "Reach seizes munitions")
	assert_eq(_variant_to_int(inspection.get(&"fine_paid", 0)), BalanceEconomy.CONTRABAND_FINE_BASE)
	assert_eq(wallet.credits(), before_credits - BalanceEconomy.CONTRABAND_FINE_BASE)
	var after_standing: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(
		after_standing, before_standing + BalanceStanding.CONTRABAND_STANDING_DELTA, TOLERANCE
	)
	# Job still active but turn-in blocked without cargo.
	assert_true(mission.has_active())
	assert_false(mission.is_objective_ready())


func test_mission_save_round_trips_without_double_cargo() -> void:
	var env: Dictionary = _setup()
	var mission: MissionService = env[&"mission"]
	var cargo: CargoService = env[&"cargo"]
	var ships: ShipService = env[&"ships"]
	ships.set_active_hull_id(HAULER_ID)

	assert_true(mission.accept(CONTRACT_G2B))
	assert_eq(cargo.quantity(MUNITIONS), SMUGGLE_QTY)
	var mission_section: Dictionary = mission.to_section()
	var cargo_section: Dictionary = cargo.to_section()
	assert_false(mission_section.is_empty())
	var saved_id: String = str(mission_section[BalanceSession.MISSION_KEY_TEMPLATE_ID])
	assert_eq(saved_id, String(CONTRACT_G2B))

	mission.reset()
	cargo.reset()
	assert_false(mission.has_active())
	assert_eq(cargo.quantity(MUNITIONS), 0)

	# Career order: cargo section first, then mission (no re-load).
	cargo.apply_section(cargo_section)
	mission.apply_section(mission_section)
	assert_true(mission.has_active())
	assert_eq(mission.active_template_id(), CONTRACT_G2B)
	assert_eq(cargo.quantity(MUNITIONS), SMUGGLE_QTY, "no double load on restore")
	assert_true(mission.can_complete_at_station(STATION_BETA))


func test_board_and_sheet_smuggle_labels_readable() -> void:
	var board_label: String = StationBoardUiScript.accept_job_label(CONTRACT_B2G)
	assert_true(board_label.findn("smuggle") >= 0, "board should say smuggle: %s" % board_label)
	assert_true(
		board_label.findn("Gamma") >= 0 or board_label.findn("Outpost") >= 0,
		"board should name dest: %s" % board_label
	)
	assert_true(BalanceSession.SHEET_JOB_SMUGGLE_FORMAT.find("Smuggle") >= 0)
	assert_true(BalanceStanding.HUD_MISSION_SMUGGLE_FORMAT.find("SMUGGLE") >= 0)
	assert_true(BalanceStanding.STATION_ACCEPT_SMUGGLE_FORMAT.find("smuggle") >= 0)

	var host: Node = Node.new()
	add_child_autofree(host)
	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	ships.reset()
	ships.set_active_hull_id(HAULER_ID)
	cargo.reset()
	mission.reset()
	assert_true(mission.accept(CONTRACT_B2G))

	var sheet: CaptainSheet = CaptainSheet.new()
	host.add_child(sheet)
	await get_tree().process_frame
	if sheet.has_method(&"_refresh_job"):
		sheet.call(&"_refresh_job")
	await get_tree().process_frame

	var job_text: String = ""
	var job_label_raw: Variant = sheet.get("_job_label")
	if job_label_raw is Label:
		var job_label: Label = job_label_raw
		job_text = job_label.text
	if not job_text.is_empty():
		assert_true(
			job_text.findn("smuggle") >= 0 or job_text.findn("Munitions") >= 0,
			"sheet job line readable: %s" % job_text
		)


func test_delivery_and_bounty_still_load() -> void:
	assert_true(ContentLibrary.has_item(CONTRACT_DELIVERY))
	assert_true(ContentLibrary.has_item(CONTRACT_BOUNTY))
	var delivery: ContractType = ContentLibrary.item(CONTRACT_DELIVERY) as ContractType
	var bounty: ContractType = ContentLibrary.item(CONTRACT_BOUNTY) as ContractType
	assert_eq(delivery.kind, BalanceStanding.MISSION_KIND_DELIVERY)
	assert_eq(bounty.kind, BalanceStanding.MISSION_KIND_BOUNTY)
	assert_eq(delivery.cargo_quantity, 0)
	assert_eq(String(delivery.cargo_commodity_id), "")
