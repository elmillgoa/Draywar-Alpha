extends GutTest

## E5.3 Branch gate graph + world.
##
## Implements: docs/BETA_E5_CONTENT_SCALE.md E5.3

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_DELTA: StringName = &"system_delta"


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_graph_connected_from_alpha() -> void:
	assert_true(SectorGraph.is_connected_from(SYSTEM_ALPHA))


func test_at_least_one_branch_hub() -> void:
	assert_gte(SectorGraph.max_gate_degree(), 2)


func test_graph_is_not_a_pure_path() -> void:
	assert_false(SectorGraph.is_pure_path(), "E5 graph must branch")


func test_gates_bidirectional_for_every_edge() -> void:
	for id: StringName in ContentLibrary.ids_in(&"star_systems"):
		for dest: StringName in SectorGraph.neighbors(id):
			assert_true(
				SectorGraph.neighbors(dest).has(id), "%s → %s needs reverse edge" % [id, dest]
			)


func test_jump_into_delta_fires_status_moment() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()

	var moments: Array = []
	var on_status := func(
		_kind: StringName,
		_place_id: StringName,
		entity_id: StringName,
		_standing: float,
		_tier: StringName
	) -> void:
		moments.append(entity_id)
	EventBus.on_status_moment.connect(on_status)

	world.clear_world()
	await get_tree().process_frame
	world.system_id = SYSTEM_DELTA
	world.build()

	assert_gt(moments.size(), 0, "status moment on enter Delta")
	var delta: StarSystem = ContentLibrary.item(SYSTEM_DELTA) as StarSystem
	var last_raw: Variant = moments[moments.size() - 1]
	var last_entity: StringName = &""
	if typeof(last_raw) == TYPE_STRING_NAME:
		last_entity = last_raw
	assert_eq(last_entity, delta.held_by)
	EventBus.on_status_moment.disconnect(on_status)


func test_hud_lists_gate_display_names_for_beta() -> void:
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	EventBus.on_system_entered.emit(&"system_beta")
	await get_tree().process_frame
	var gates_text: String = hud.nav_gates_text()
	assert_true(gates_text.contains("Alpha") or gates_text.contains("Reach"), gates_text)
	assert_true(gates_text.contains("Gamma") or gates_text.contains("Fringe"), gates_text)
	assert_true(gates_text.contains("Delta") or gates_text.contains("Corridor"), gates_text)


func test_new_system_places_stations_and_gates() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_DELTA
	add_child_autofree(world)
	world.build()
	var positions: Dictionary = world.station_positions()
	assert_true(positions.has(&"station_delta_port"))
	assert_true(positions.has(&"station_delta_yard"))
	var gates: Dictionary = world.gate_positions()
	assert_true(gates.has(&"system_beta"))
