extends GutTest

## Job 3 / ledger `#9` — a save written in a berth comes back in that berth.
##
## Why this file exists at all, and why it boots the whole session shell:
## the first attempt at this test restored the berth by calling
## `DockingService.begin_session_docked()` from its own body, which proved the
## codec records the berth and that a ship can dock — neither of which was ever
## broken. The thing that WAS broken lives in `Main._apply_world_section()`,
## and nothing in the suite called it, so reverting the fix left every test
## green. A test that has not been seen to fail has been named, not written.
##
## So these drive the real path: boot `Main.tscn`, run a career to the
## storyboard dock, save, leave the berth, and load through the pause menu's
## own signal. `Main` reads the file, applies it, and places the ship.
##
## Pattern copied from `tests/test_loss_and_rescue.gd`, which boots the same
## session shell and flies a ship to its death in it.

const MainScene: PackedScene = preload("res://src/Main.tscn")

## This test's own save slots. Never the real ones — a test may not tread on a
## player's career or their autosave.
const SAVE_FIXTURE: String = "job3_docked_restore_fixture"
const AUTOSAVE_FIXTURE: String = "job3_docked_restore_autosave"

## A berth id no build has ever shipped: the "station is gone" case.
const STATION_GONE: StringName = &"station_this_build_no_longer_has"

## Far enough out that being flung back to a station anchor is unmistakable.
const ADRIFT_POS: Vector3 = Vector3(12000.0, 0.0, 0.0)

## Anchor tolerance for a parked ship: docked means velocity zero and flight
## off, so this is exact bar float noise.
const PARKED_TOLERANCE_M: float = 1.0
## Free-flight tolerance. The restored ship is under power again (top speed is
## 70 m/s), so it has begun to move by the time the assertions run. Loose
## enough for that, nowhere near the 12 km back to the berth.
const FLYING_TOLERANCE_M: float = 100.0


func after_each() -> void:
	# A live session resets every registered service on its way through New
	# Game; put the shared autoloads back so nothing after this inherits it.
	ServiceRegistry.reset_all()
	StandingService.reset_to_defaults()
	CareerStart.reset()
	_remove_fixture(SAVE_FIXTURE)
	_remove_fixture(AUTOSAVE_FIXTURE)


# --- The berth you saved in ---------------------------------------------------


func test_a_save_written_docked_comes_back_docked_in_the_same_berth() -> void:
	# The reported failure: a save made while docked restored the player free-
	# flying, silently dropping the docked state the file already stored.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_the_storyboard_berth(main)
	var docking: DockingService = main.get_node("DockingService")
	var ship: PlayerShip = _player_ship()
	var anchor: Vector3 = ship.global_position

	var save_path: String = await _save_the_career_where_it_stands()

	# Leave and fly well clear, so a restore that does nothing is visible.
	EventBus.on_undock_requested.emit(berth)
	await _frames(2)
	ship.global_position = ADRIFT_POS
	await _frames(2)
	assert_false(docking.controller().is_docked(), "the fixture must be flying before the load")
	assert_true(ship.visible, "and be on screen")

	EventBus.on_manual_load_requested.emit()
	await _frames(12)

	assert_true(docking.controller().is_docked(), "a save written in a berth comes back in one")
	assert_eq(docking.docked_station_id(), berth, "and in the berth the file names")
	assert_false(ship.visible, "a docked ship is parked, not flying")
	assert_false(ship.is_flight_enabled(), "and it is not still under power")
	assert_lt(
		ship.global_position.distance_to(anchor),
		PARKED_TOLERANCE_M,
		"parked back at the berth's own anchor"
	)
	assert_eq(SaveService.most_recent_path(), save_path, "the load read this test's file")

	await _close_the_career()


func test_a_save_written_free_flying_takes_you_out_of_the_berth_you_are_in() -> void:
	# The other direction, and the reason the berth is asked about before the
	# ship is placed: loading a free-flying save while docked has to leave.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_the_storyboard_berth(main)
	var docking: DockingService = main.get_node("DockingService")
	var ship: PlayerShip = _player_ship()

	await _write_a_save_placed_at(ADRIFT_POS, &"")
	assert_eq(docking.docked_station_id(), berth, "still in the berth when the load starts")

	EventBus.on_manual_load_requested.emit()
	await _frames(12)

	assert_false(docking.controller().is_docked(), "a free-flying save does not leave you docked")
	assert_true(ship.visible, "the ship is back on screen")
	assert_true(ship.is_flight_enabled(), "and under power")
	assert_lt(
		ship.global_position.distance_to(ADRIFT_POS),
		FLYING_TOLERANCE_M,
		"at the coordinates the save recorded, not at the berth it left"
	)

	await _close_the_career()


func test_a_berth_this_build_no_longer_has_leaves_you_flying_not_in_the_wrong_one() -> void:
	# The edge the verification found by reading: if the save names a berth the
	# world cannot give back — station cut from the build, renamed, or standing
	# now turning the ship away — and the live session is sitting in a DIFFERENT
	# berth, the player used to be left docked where they already were. That is
	# a berth the save never named, presented as the one it did.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_the_storyboard_berth(main)
	var docking: DockingService = main.get_node("DockingService")
	var ship: PlayerShip = _player_ship()

	await _write_a_save_placed_at(ADRIFT_POS, STATION_GONE)
	assert_eq(docking.docked_station_id(), berth, "still in the live berth when the load starts")
	assert_ne(berth, STATION_GONE, "the save must name a different berth, or this proves nothing")

	EventBus.on_manual_load_requested.emit()
	await _frames(12)

	assert_false(
		docking.controller().is_docked(),
		"a berth that cannot be given back must not leave the player docked in another one"
	)
	assert_true(ship.visible, "the ship is in free flight instead")
	assert_true(ship.is_flight_enabled())
	assert_lt(
		ship.global_position.distance_to(ADRIFT_POS),
		FLYING_TOLERANCE_M,
		"at the coordinates the save recorded"
	)

	await _close_the_career()


# --- Rig ----------------------------------------------------------------------


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


## Run a brand-new career through create and annexation to the storyboard dock,
## and return the berth it opened in. Every one of these tests starts here
## because it is the only state the game itself ever writes a docked save from.
func _career_at_the_storyboard_berth(main: Node) -> StringName:
	await _frames(4)
	EventBus.on_new_game_requested.emit()
	await _frames(12)

	# Point the autosave at this test's slot before the storyboard dock, which
	# is the first `on_docked` of a career and therefore the first autosave.
	# `get_node_or_null`, not `get_node`: the red proof for this file reverts
	# `Main.gd` to the commit before Job 3, which has no autosave node at all,
	# and that run has to reach the assertions this file exists for rather than
	# dying on a missing child.
	var autosave: AutosaveService = main.get_node_or_null("AutosaveService")
	if autosave != null:
		autosave.save_name = AUTOSAVE_FIXTURE

	EventBus.on_life_path_confirmed.emit(&"origin_core", &"trade_navy", &"mark_clean")
	await _frames(6)
	EventBus.on_annexation_continue_requested.emit()
	await _frames(8)

	var docking: DockingService = main.get_node("DockingService")
	var berth: StringName = docking.docked_station_id()
	assert_false(String(berth).is_empty(), "the storyboard must open docked, or nothing here holds")
	return berth


## Close the career down the way the game does, so the session's queue_free
## calls flush inside the test instead of leaving orphans behind it.
func _close_the_career() -> void:
	EventBus.on_quit_to_menu_requested.emit()
	await _frames(6)


## Save the live session, exactly as the pause menu's Save does, into this
## test's own slot. Returns the path, and proves it is the file a load will
## pick up — `Main` loads the most recently written save, and a machine with a
## real career on it has other files in that folder.
func _save_the_career_where_it_stands() -> String:
	var written: SaveResult = CareerSave.save_to_name(get_tree(), SAVE_FIXTURE)
	assert_true(written.ok(), "the fixture save was refused: %s" % written.summary())
	var save_path: String = SaveService.path_for(SAVE_FIXTURE)
	assert_eq(
		SaveService.most_recent_path(),
		save_path,
		"a load reads the newest save in the folder, and that must be this test's"
	)
	await _frames(2)
	return save_path


## The same career save, with its world section rewritten to the placement the
## test needs, then pushed through a real file. Everything else in the envelope
## is the live session's, so the load applies a genuine save and not a stub.
func _write_a_save_placed_at(position: Vector3, docked_station_id: StringName) -> String:
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	sections[BalanceSession.SAVE_SECTION_WORLD] = CareerSave.make_world_section(
		BalanceFlight.PLAYABLE_SYSTEM_ID, position, docked_station_id
	)
	var service: SaveService = SaveService.new()
	var save_path: String = SaveService.path_for(SAVE_FIXTURE)
	var written: SaveResult = service.save_to(
		save_path, SaveService.envelope(sections, "Job 3 restore")
	)
	assert_true(written.ok(), "the fixture save was refused: %s" % written.summary())
	assert_eq(
		SaveService.most_recent_path(),
		save_path,
		"a load reads the newest save in the folder, and that must be this test's"
	)
	await _frames(2)
	return save_path


func _player_ship() -> PlayerShip:
	var ship: PlayerShip = get_tree().get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP)
	assert_not_null(ship, "the session must have built a ship")
	return ship


func _remove_fixture(file_name: String) -> void:
	var path: String = SaveService.path_for(file_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
