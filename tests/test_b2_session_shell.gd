extends GutTest

## B2 session shell — menu, captain sheet, career save sections.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B2

const FIXTURE_PATH: String = "user://b2_session_shell_test.sav"
const TEMPLATE_ID: StringName = &"contract_courier_alpha"
const POS: Vector3 = Vector3(11.0, 22.0, 33.0)
const CREDITS_MARK: int = 777


func after_each() -> void:
	StandingService.reset_to_defaults()
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)


func test_career_save_gathers_standing_wallet_world_mission() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	await get_tree().process_frame
	wallet.set_credits(CREDITS_MARK)

	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	await get_tree().process_frame
	assert_true(mission.accept(TEMPLATE_ID), "accept mission for gather")

	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_beta"
	world.add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)
	host.add_child(world)

	var ship: CharacterBody3D = CharacterBody3D.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	world.add_child(ship)
	ship.global_position = POS
	await get_tree().process_frame

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceStanding.SAVE_SECTION_KEY), "standing section")
	assert_true(sections.has(BalanceEconomy.SAVE_SECTION_KEY), "wallet section")
	assert_true(sections.has(BalanceSession.SAVE_SECTION_WORLD), "world section")
	assert_true(sections.has(BalanceSession.SAVE_SECTION_MISSION), "mission section")

	var wallet_sec: Dictionary = sections[BalanceEconomy.SAVE_SECTION_KEY]
	assert_eq(_as_int(wallet_sec[BalanceEconomy.SAVE_KEY_CREDITS]), CREDITS_MARK)

	var world_sec: Dictionary = sections[BalanceSession.SAVE_SECTION_WORLD]
	assert_eq(str(world_sec[BalanceSession.WORLD_KEY_SYSTEM_ID]), "system_beta")
	assert_almost_eq(_as_float(world_sec[BalanceSession.WORLD_KEY_POS_X]), POS.x, 0.001)
	assert_almost_eq(_as_float(world_sec[BalanceSession.WORLD_KEY_POS_Y]), POS.y, 0.001)
	assert_almost_eq(_as_float(world_sec[BalanceSession.WORLD_KEY_POS_Z]), POS.z, 0.001)

	var mission_sec: Dictionary = sections[BalanceSession.SAVE_SECTION_MISSION]
	assert_eq(str(mission_sec[BalanceSession.MISSION_KEY_TEMPLATE_ID]), String(TEMPLATE_ID))


func test_career_save_round_trip_wallet_mission_world() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	await get_tree().process_frame

	wallet.set_credits(CREDITS_MARK)
	assert_true(mission.accept(TEMPLATE_ID))

	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_gamma"
	world.add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)
	host.add_child(world)
	var ship: CharacterBody3D = CharacterBody3D.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	world.add_child(ship)
	ship.global_position = POS
	await get_tree().process_frame

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	var service: SaveService = SaveService.new()
	var written: SaveResult = service.save_to(
		FIXTURE_PATH, SaveService.envelope(sections, "b2_test")
	)
	assert_true(written.ok(), written.summary())

	wallet.set_credits(0)
	mission.reset()
	world.system_id = &"system_alpha"
	ship.global_position = Vector3.ZERO

	var loaded: SaveResult = CareerSave.load_envelope(FIXTURE_PATH)
	assert_true(loaded.ok(), loaded.summary())
	var loaded_sections: Dictionary = loaded.envelope[SaveService.KEY_SECTIONS]
	CareerSave.apply_meta_sections(get_tree(), loaded_sections)

	assert_eq(wallet.credits(), CREDITS_MARK)
	assert_true(mission.has_active())
	assert_eq(mission.active_template_id(), TEMPLATE_ID)

	var world_back: Dictionary = CareerSave.world_from_sections(loaded_sections)
	assert_eq(str(world_back[BalanceSession.WORLD_KEY_SYSTEM_ID]), "system_gamma")
	assert_almost_eq(_as_float(world_back[BalanceSession.WORLD_KEY_POS_X]), POS.x, 0.001)
	assert_almost_eq(_as_float(world_back[BalanceSession.WORLD_KEY_POS_Y]), POS.y, 0.001)
	assert_almost_eq(_as_float(world_back[BalanceSession.WORLD_KEY_POS_Z]), POS.z, 0.001)


func test_main_menu_has_new_continue_quit_buttons() -> void:
	var menu: MainMenu = MainMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	var texts: PackedStringArray = _button_texts(menu)
	assert_true(texts.has(BalanceSession.MAIN_NEW_GAME), "New Game button")
	assert_true(texts.has(BalanceSession.MAIN_CONTINUE), "Continue button")
	assert_true(texts.has(BalanceSession.MAIN_QUIT), "Quit button")


func test_pause_menu_and_captain_sheet_use_theme() -> void:
	var pause: PauseMenu = PauseMenu.new()
	add_child_autofree(pause)
	var sheet: CaptainSheet = CaptainSheet.new()
	add_child_autofree(sheet)
	await get_tree().process_frame
	var pause_panel: PanelContainer = _find_panel(pause)
	var sheet_panel: PanelContainer = _find_panel(sheet)
	assert_ne(pause_panel, null, "pause panel")
	assert_ne(sheet_panel, null, "sheet panel")
	assert_ne(pause_panel.theme, null, "pause theme")
	assert_ne(sheet_panel.theme, null, "sheet theme")
	assert_true(pause_panel.theme.has_stylebox("panel", "PanelContainer"))
	assert_true(sheet_panel.theme.has_stylebox("panel", "PanelContainer"))


func test_mission_service_section_round_trip() -> void:
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	await get_tree().process_frame
	assert_true(mission.accept(TEMPLATE_ID))
	var section: Dictionary = mission.to_section()
	assert_false(section.is_empty())
	assert_eq(str(section[BalanceSession.MISSION_KEY_TEMPLATE_ID]), String(TEMPLATE_ID))
	mission.reset()
	assert_false(mission.has_active())
	mission.apply_section(section)
	assert_true(mission.has_active())
	assert_eq(mission.active_template_id(), TEMPLATE_ID)


func test_career_save_used_for_named_save_path() -> void:
	# Prove CareerSave.save_to_name writes a usable envelope (console + menu path).
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	await get_tree().process_frame
	wallet.set_credits(CREDITS_MARK)

	var file_name: String = "b2_career_named"
	var path: String = SaveService.path_for(file_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var written: SaveResult = CareerSave.save_to_name(get_tree(), file_name)
	assert_true(written.ok(), written.summary())
	assert_true(FileAccess.file_exists(path), "save file on disk")

	wallet.set_credits(0)
	var loaded: SaveResult = CareerSave.load_envelope(path)
	assert_true(loaded.ok(), loaded.summary())
	var sections: Dictionary = loaded.envelope[SaveService.KEY_SECTIONS]
	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_eq(wallet.credits(), CREDITS_MARK)

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_hud_job_line_includes_destination_name() -> void:
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	assert_true(mission.accept(TEMPLATE_ID))
	await get_tree().process_frame
	var mission_label: Label = null
	for child: Node in hud.get_children():
		mission_label = _find_label_with_prefix(child, "JOB")
		if mission_label != null:
			break
	assert_ne(mission_label, null, "JOB label present")
	assert_true(mission_label.text.contains("JOB"), mission_label.text)
	var has_arrow: bool = mission_label.text.contains("→") or mission_label.text.contains("->")
	assert_true(has_arrow, mission_label.text)
	# Destination display name should appear (not only template id).
	var dest_id: StringName = mission.active_destination_station_id()
	if not String(dest_id).is_empty() and ContentLibrary.has_item(dest_id):
		var item: ContentItem = ContentLibrary.item(dest_id)
		assert_true(
			mission_label.text.contains(item.display_name),
			"destination name in job line: %s" % mission_label.text
		)


func _button_texts(root: Node) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_collect_button_texts(root, out)
	return out


func _collect_button_texts(node: Node, out: PackedStringArray) -> void:
	if node is Button:
		var btn: Button = node as Button
		out.append(btn.text)
	for child: Node in node.get_children():
		_collect_button_texts(child, out)


func _find_panel(node: Node) -> PanelContainer:
	if node is PanelContainer:
		return node as PanelContainer
	for child: Node in node.get_children():
		var found: PanelContainer = _find_panel(child)
		if found != null:
			return found
	return null


func _find_label_with_prefix(node: Node, prefix: String) -> Label:
	if node is Label:
		var label: Label = node as Label
		if label.text.begins_with(prefix) or label.text.contains(prefix):
			return label
	for child: Node in node.get_children():
		var found: Label = _find_label_with_prefix(child, prefix)
		if found != null:
			return found
	return null


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _as_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return as_float
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	return 0.0
