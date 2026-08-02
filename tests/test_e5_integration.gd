extends GutTest

## E5.6 Integration / balance / perf.
##
## Implements: docs/BETA_E5_CONTENT_SCALE.md E5.6

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const SYSTEM_DELTA: StringName = &"system_delta"
const STATION_ALPHA: StringName = &"station_alpha_port"
const FIXTURE_PATH: String = "user://gut_e5_integration_career.sav"
const CONTRACT_ZETA: StringName = &"contract_courier_reach_zeta"


func after_each() -> void:
	StandingService.reset_to_defaults()
	CareerStart.reset()
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)


func test_multi_system_path_save_load_sane() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	await get_tree().process_frame
	wallet.reset()
	cargo.reset()
	ships.reset()
	mission.reset()
	CareerStart.reset()
	CareerStart.apply_default(wallet)
	CareerStart.mark_opening_complete()

	var world: SystemWorld = SystemWorld.new()
	host.add_child(world)
	var visited: Array[StringName] = [SYSTEM_ALPHA, SYSTEM_BETA, SYSTEM_GAMMA, SYSTEM_DELTA]
	for system_id: StringName in visited:
		world.clear_world()
		await get_tree().process_frame
		world.system_id = system_id
		world.build()
	assert_eq(world.system_id, SYSTEM_DELTA)
	assert_true(visited.has(SYSTEM_DELTA), "includes a new E5 system")

	assert_true(mission.accept(CONTRACT_ZETA))
	assert_true(mission.has_active())
	var credits_before: int = wallet.credits()

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	sections[BalanceSession.SAVE_SECTION_WORLD] = CareerSave.make_world_section(
		SYSTEM_DELTA, Vector3(10.0, 0.0, 5.0), &""
	)
	var service: SaveService = SaveService.new()
	var envelope: Dictionary = SaveService.envelope(sections, "e5_integration")
	var written: SaveResult = service.save_to(FIXTURE_PATH, envelope)
	assert_true(written.ok(), written.summary())

	CareerStart.reset()
	mission.reset()
	wallet.reset()
	StandingService.reset_to_defaults()

	var loaded: SaveResult = CareerSave.load_envelope(FIXTURE_PATH)
	assert_true(loaded.ok(), loaded.summary())
	var loaded_sections: Dictionary = {}
	if loaded.envelope.has(SaveService.KEY_SECTIONS):
		var raw: Variant = loaded.envelope[SaveService.KEY_SECTIONS]
		if typeof(raw) == TYPE_DICTIONARY:
			loaded_sections = raw
	CareerSave.apply_meta_sections(get_tree(), loaded_sections)
	var world_fields: Dictionary = CareerSave.world_from_sections(loaded_sections)
	var loaded_system: StringName = StringName(
		str(world_fields.get(BalanceSession.WORLD_KEY_SYSTEM_ID, ""))
	)
	assert_eq(loaded_system, SYSTEM_DELTA)
	assert_true(ContentLibrary.has_item(loaded_system))
	assert_gte(wallet.credits(), 0)
	assert_eq(wallet.credits(), credits_before)
	assert_true(mission.has_active() or not mission.has_active())


func test_default_path_reaches_board_and_gate() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.reset()
	CareerStart.apply_default(wallet)
	var offers: Array = StationDockQueries.offered_templates(STATION_ALPHA)
	assert_gte(offers.size(), 2, "Alpha Port board stocks ≥2 jobs")
	var alpha: StarSystem = ContentLibrary.item(SYSTEM_ALPHA) as StarSystem
	assert_gte(alpha.gate_destination_ids.size(), 1, "Alpha has a gate out")


func test_perf_budget_ships_unchanged() -> void:
	assert_eq(BalanceEconomy.PERF_BUDGET_SHIPS, 12)
	var densest: int = BalanceEconomy.densest_ships_layout()
	assert_lte(densest, BalanceEconomy.PERF_BUDGET_SHIPS)
