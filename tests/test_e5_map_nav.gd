extends GutTest

## E5.5 Map / NAV upgrade.
##
## Implements: docs/BETA_E5_CONTENT_SCALE.md E5.5


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_sector_map_opens_without_console() -> void:
	var map: SectorMapPanel = SectorMapPanel.new()
	add_child_autofree(map)
	await get_tree().process_frame
	assert_false(map.visible)
	EventBus.on_sector_map_open_requested.emit()
	await get_tree().process_frame
	assert_true(map.visible)
	EventBus.on_sector_map_close_requested.emit()
	await get_tree().process_frame
	assert_false(map.visible)


func test_map_lists_all_loaded_systems() -> void:
	var map: SectorMapPanel = SectorMapPanel.new()
	add_child_autofree(map)
	EventBus.on_system_entered.emit(&"system_alpha")
	EventBus.on_sector_map_open_requested.emit()
	await get_tree().process_frame
	var listed: Array[StringName] = map.listed_system_ids()
	var live: Array[StringName] = ContentLibrary.ids_in(&"star_systems")
	assert_eq(listed.size(), live.size())
	for id: StringName in live:
		assert_true(listed.has(id), "map shows %s" % id)


func test_map_edges_match_gate_destination_ids() -> void:
	var map: SectorMapPanel = SectorMapPanel.new()
	add_child_autofree(map)
	EventBus.on_sector_map_open_requested.emit()
	await get_tree().process_frame
	var expected: Dictionary = {}
	for id: StringName in ContentLibrary.ids_in(&"star_systems"):
		for dest: StringName in SectorGraph.neighbors(id):
			var a: String = String(id)
			var b: String = String(dest)
			var key: String = a + "|" + b if a < b else b + "|" + a
			expected[key] = true
	var edges: PackedStringArray = map.chart_edge_keys()
	assert_eq(edges.size(), expected.size())
	for key: String in edges:
		assert_true(expected.has(key), "edge %s from content" % key)


func test_current_system_highlight_updates_on_enter() -> void:
	var map: SectorMapPanel = SectorMapPanel.new()
	add_child_autofree(map)
	EventBus.on_system_entered.emit(&"system_alpha")
	EventBus.on_sector_map_open_requested.emit()
	await get_tree().process_frame
	assert_eq(map.current_system_id(), &"system_alpha")
	EventBus.on_system_entered.emit(&"system_zeta")
	await get_tree().process_frame
	assert_eq(map.current_system_id(), &"system_zeta")


func test_pause_menu_has_sector_map_button() -> void:
	var pause: PauseMenu = PauseMenu.new()
	add_child_autofree(pause)
	await get_tree().process_frame
	var found: bool = false
	for node: Node in pause.find_children("*", "Button", true, false):
		var btn: Button = node as Button
		if btn != null and btn.text == BalanceSession.PAUSE_SECTOR_MAP:
			found = true
			break
	assert_true(found, "pause offers Sector map")
