extends GutTest

## E1.2 content density - second stations, multi-job boards, used contacts.
##
## Implements: docs/BETA_E1_LEGIBLE_SECTOR.md E1.2

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const STATION_ALPHA_PORT: StringName = &"station_alpha_port"
const STATION_ALPHA_YARD: StringName = &"station_alpha_yard"
const STATION_BETA_HUB: StringName = &"station_beta_hub"
const STATION_BETA_SPIT: StringName = &"station_beta_spit"
const STATION_GAMMA_OUTPOST: StringName = &"station_gamma_outpost"
const STATION_GAMMA_RIM: StringName = &"station_gamma_rim"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_BETA: StringName = &"entity_beta_syndicate"
const ENTITY_GAMMA: StringName = &"entity_gamma_collective"
const PERSON_KELL: StringName = &"person_ra_kell"
const PERSON_NIX: StringName = &"person_bs_nix"
const PERSON_SELA: StringName = &"person_gc_sela"
const CONTRACT_ALPHA_YARD: StringName = &"contract_courier_alpha_yard"


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_stations_load_under_budget_and_span_systems() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(&"stations")
	assert_gte(ids.size(), 4, "cold play needs at least 4 dock places")
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[&"stations"])
	assert_true(ContentLibrary.has_item(STATION_ALPHA_PORT))
	assert_true(ContentLibrary.has_item(STATION_ALPHA_YARD))
	assert_true(ContentLibrary.has_item(STATION_BETA_SPIT))
	assert_true(ContentLibrary.has_item(STATION_GAMMA_RIM))
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))


func test_each_system_has_at_least_two_station_ids() -> void:
	for system_id: StringName in [SYSTEM_ALPHA, SYSTEM_BETA, SYSTEM_GAMMA]:
		var system: StarSystem = ContentLibrary.item(system_id) as StarSystem
		assert_ne(system, null, "%s loads" % system_id)
		assert_gte(system.station_ids.size(), 2, "%s needs at least 2 docks" % system_id)


func test_secondary_stations_have_distinct_offsets() -> void:
	var port: Station = ContentLibrary.item(STATION_ALPHA_PORT) as Station
	var yard: Station = ContentLibrary.item(STATION_ALPHA_YARD) as Station
	assert_ne(port, null)
	assert_ne(yard, null)
	assert_ne(port.position_offset, yard.position_offset, "yard offset from port")
	assert_eq(yard.controller_entity_id, ENTITY_REACH)
	assert_eq(yard.system_id, SYSTEM_ALPHA)
	assert_false(yard.flavor_line.is_empty())


func test_system_world_places_two_stations_at_different_positions() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	var positions: Dictionary[StringName, Vector3] = world.station_positions()
	assert_true(positions.has(STATION_ALPHA_PORT))
	assert_true(positions.has(STATION_ALPHA_YARD))
	assert_ne(positions[STATION_ALPHA_PORT], positions[STATION_ALPHA_YARD])
	var port_node: Node = world.get_node_or_null("Station_station_alpha_port")
	var yard_node: Node = world.get_node_or_null("Station_station_alpha_yard")
	assert_ne(port_node, null, "port mesh node present")
	assert_ne(yard_node, null, "yard mesh node present")


func test_new_people_exist_and_validate() -> void:
	assert_true(ContentLibrary.has_item(PERSON_KELL))
	assert_true(ContentLibrary.has_item(PERSON_NIX))
	assert_true(ContentLibrary.has_item(PERSON_SELA))
	var people: Array[StringName] = ContentLibrary.ids_in(&"people")
	assert_gte(people.size(), 15)
	assert_lte(people.size(), Balance.CONTENT_BUDGET[&"people"])
	var kell: Person = ContentLibrary.item(PERSON_KELL) as Person
	assert_eq(kell.primary_entity_id, ENTITY_REACH)
	assert_eq(kell.rank, Person.RANK_MID)
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0)


func test_each_controller_offers_at_least_two_contracts() -> void:
	var reach_count: int = 0
	var beta_count: int = 0
	var gamma_count: int = 0
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY)
	for id: StringName in ids:
		var contract: ContractType = ContentLibrary.item(id) as ContractType
		assert_ne(contract, null)
		assert_eq(contract.kind, BalanceStanding.MISSION_KIND_DELIVERY)
		assert_true(ContentLibrary.has_item(contract.destination_station_id))
		if contract.offering_entity_id == ENTITY_REACH:
			reach_count += 1
		elif contract.offering_entity_id == ENTITY_BETA:
			beta_count += 1
		elif contract.offering_entity_id == ENTITY_GAMMA:
			gamma_count += 1
	assert_gte(reach_count, 2, "Reach at least 2 jobs")
	assert_gte(beta_count, 2, "Syndicate at least 2 jobs")
	assert_gte(gamma_count, 2, "Collective at least 2 jobs")
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[BalanceStanding.MISSION_CONTENT_CATEGORY])


func test_station_menu_shows_two_jobs_and_new_contact() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var menu: StationMenu = StationMenu.new()
	host.add_child(menu)
	await get_tree().process_frame
	EventBus.on_docked.emit(STATION_ALPHA_PORT)
	await get_tree().process_frame
	var accept_buttons: Array[Button] = _find_accept_job_buttons(menu)
	assert_gte(accept_buttons.size(), 2, "Alpha Port board stocks at least 2 jobs")
	var kell_label: Label = _find_label_containing(menu, "Kell")
	assert_ne(kell_label, null, "Yard Clerk Kell listed under Contacts")
	EventBus.on_undocked.emit(STATION_ALPHA_PORT)


func test_turn_in_at_secondary_destination() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	wallet.reset()
	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	mission.reset()
	await get_tree().process_frame
	assert_true(mission.accept(CONTRACT_ALPHA_YARD))
	assert_true(mission.can_complete_at_station(STATION_BETA_SPIT))
	assert_false(mission.can_complete_at_station(STATION_ALPHA_PORT))
	var result: Dictionary = mission.try_complete_at(STATION_BETA_SPIT)
	var attributed: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	assert_true(attributed)
	assert_false(mission.has_active())


func test_status_moment_still_local_controller_only() -> void:
	var yard_status: Dictionary = StandingService.status_for_station(STATION_ALPHA_YARD)
	var yard_entity: StringName = yard_status[StandingService.STATUS_KEY_ENTITY_ID]
	assert_eq(yard_entity, ENTITY_REACH)
	var spit_status: Dictionary = StandingService.status_for_station(STATION_BETA_SPIT)
	var spit_entity: StringName = spit_status[StandingService.STATUS_KEY_ENTITY_ID]
	assert_eq(spit_entity, ENTITY_BETA)


func _find_accept_job_buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	_collect_accept_job_buttons(node, found)
	return found


func _collect_accept_job_buttons(node: Node, found: Array[Button]) -> void:
	if node is Button:
		var btn: Button = node as Button
		if btn.visible and btn.text.begins_with("Accept job"):
			found.append(btn)
	for child: Node in node.get_children():
		_collect_accept_job_buttons(child, found)


func _find_label_containing(node: Node, fragment: String) -> Label:
	if node is Label:
		var label: Label = node as Label
		if label.text.contains(fragment):
			return label
	for child: Node in node.get_children():
		var found: Label = _find_label_containing(child, fragment)
		if found != null:
			return found
	return null
