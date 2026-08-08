extends GutTest

## REPAIR-18: load leaves flight matching hull (PT-8 + IF-22).
##
## One placement line in `Main._apply_world_section` called
## `set_flight_enabled(true)` as the last word on flight. Two opposite
## failures share that line:
##
## - **PT-8** — a healthy-hull load into a ship still flagged crippled never
##   flies (the `_crippled` guard silently discards the enable).
## - **IF-22** — a grounded-hull load can still be handed flight when the
##   flag and `can_fly()` disagree, because placement forces true instead of
##   asking the hull.
##
## Contract both share: after the placement path finishes,
## `is_flight_enabled()` must equal `HullConditionService.can_fly()`.
## Derive `_crippled` from `can_fly()` once; do not clear it unconditionally
## (that would green PT-8 and open IF-22).

const MainScene: PackedScene = preload("res://src/Main.tscn")

const AUTOSAVE_FIXTURE: String = "repair18_load_flight_autosave"
const SAVE_FIXTURE: String = "repair18_load_flight_save"
const ADRIFT_POS: Vector3 = Vector3(12000.0, 0.0, 0.0)
## More than a full hull so one call is a kill however damage scales.
const LETHAL_DAMAGE: float = 10000.0


func after_each() -> void:
	ServiceRegistry.reset_all()
	StandingService.reset_to_defaults()
	CareerStart.reset()
	_remove_fixture(SAVE_FIXTURE)
	_remove_fixture(AUTOSAVE_FIXTURE)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


# --- PT-8: healthy hull load must restore flight --------------------------------


func test_pt8_healthy_hull_load_restores_flight_after_cripple() -> void:
	# Measured PT-8: after hull hit zero, Load restored hull=100 but left
	# crippled=true / flight=false. Continue (full rebuild) worked; Load did not.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_to_flight(main)
	var ship: PlayerShip = _player_ship()
	var hull: HullConditionService = main.get_node("HullConditionService")

	# Healthy free-flight save first — the file Load will re-apply.
	await _write_free_flight_save_at(ADRIFT_POS)
	assert_true(hull.can_fly(), "fixture save must be healthy-hull")
	assert_false(ship.is_crippled(), "fixture starts free and uncrippled")

	# Cripple the live ship the way combat does.
	hull.apply_damage(LETHAL_DAMAGE)
	assert_false(hull.can_fly(), "hull is finished")
	assert_true(ship.is_crippled(), "ship took the cripple signal")
	assert_false(ship.is_flight_enabled(), "cripple cuts flight")

	# In-place Load (pause menu path) — same ship node, not a rebuild.
	EventBus.on_manual_load_requested.emit()
	await _frames(12)

	assert_true(hull.can_fly(), "load restored a healthy hull")
	assert_true(
		ship.is_flight_enabled(), "PT-8: a healthy-hull load must put the ship back under power"
	)
	assert_eq(
		ship.is_flight_enabled(), hull.can_fly(), "placement finished: flight must match can_fly()"
	)
	assert_false(ship.is_crippled(), "crippled flag must follow the restored hull")

	await _close_career()
	assert_false(String(berth).is_empty())


# --- IF-22: grounded hull load must not hand flight back ------------------------


func test_if22_grounded_hull_load_keeps_flight_off() -> void:
	# Placement used to call set_flight_enabled(true) as the last word, after
	# undock had already set flight from can_fly(). That override only sticks
	# when _crippled is false while can_fly() is false — undock already reasons
	# from can_fly alone. Drive the hull via apply_damage, write that grounded
	# free-flight save, then leave the flag clear so the placement line is what
	# decides flight (the live IF-22 shape). Applying the same zero condition
	# again does not re-fire on_player_crippled, so the flag stays clear.
	# An unconditional clear of _crippled would green PT-8 and fail this test.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	await _career_to_flight(main)
	var ship: PlayerShip = _player_ship()
	var hull: HullConditionService = main.get_node("HullConditionService")

	hull.apply_damage(LETHAL_DAMAGE)
	assert_false(hull.can_fly(), "hull is at or below the cripple floor")
	assert_true(ship.is_crippled(), "apply_damage raised on_player_crippled")

	# Grounded free-flight save — Load will re-apply this hull and placement.
	await _write_free_flight_save_at(ADRIFT_POS)

	# Leave can_fly as the only ground truth, the way DockingService undock
	# already does. Placement must not force flight on over that.
	ship._crippled = false
	ship.set_flight_enabled(false)
	assert_false(ship.is_crippled(), "flag cleared so placement is the decider")
	assert_false(hull.can_fly(), "hull still grounded")

	EventBus.on_manual_load_requested.emit()
	await _frames(12)

	assert_false(hull.can_fly(), "load kept a grounded hull")
	assert_false(ship.is_flight_enabled(), "IF-22: a grounded-hull load must not hand flight back")
	assert_eq(
		ship.is_flight_enabled(), hull.can_fly(), "placement finished: flight must match can_fly()"
	)

	await _close_career()


# --- Rig ----------------------------------------------------------------------


func _career_to_flight(main: Node) -> StringName:
	await _frames(4)
	EventBus.on_new_game_requested.emit()
	await _frames(12)
	var autosave: AutosaveService = main.get_node_or_null("AutosaveService")
	if autosave != null:
		autosave.save_name = AUTOSAVE_FIXTURE
	EventBus.on_life_path_confirmed.emit(&"origin_core", &"trade_navy", &"mark_clean")
	await _frames(6)
	EventBus.on_annexation_continue_requested.emit()
	await _frames(8)
	var docking: DockingService = main.get_node("DockingService")
	var berth: StringName = docking.docked_station_id()
	assert_false(String(berth).is_empty(), "storyboard must open docked")
	EventBus.on_undock_requested.emit(berth)
	await _frames(4)
	assert_false(docking.controller().is_docked(), "must be free-flying")
	return berth


func _write_free_flight_save_at(position: Vector3) -> String:
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	sections[BalanceSession.SAVE_SECTION_WORLD] = CareerSave.make_world_section(
		BalanceFlight.PLAYABLE_SYSTEM_ID, position, &""
	)
	var service: SaveService = SaveService.new()
	var save_path: String = SaveService.path_for(SAVE_FIXTURE)
	var written: SaveResult = service.save_to(
		save_path, SaveService.envelope(sections, "REPAIR-18 flight")
	)
	assert_true(written.ok(), "fixture save refused: %s" % written.summary())
	assert_eq(SaveService.most_recent_path(), save_path, "load must pick this test's file")
	await _frames(2)
	return save_path


func _close_career() -> void:
	EventBus.on_quit_to_menu_requested.emit()
	await _frames(6)


func _player_ship() -> PlayerShip:
	var ship: PlayerShip = get_tree().get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP)
	assert_not_null(ship, "session must have a ship")
	return ship


func _remove_fixture(file_name: String) -> void:
	var path: String = SaveService.path_for(file_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
