extends GutTest

## REPAIR-5: pause freezes the sim; focus-loss auto-pauses; intentional pause
## survives alt-tab; sector map blocked behind Options; no pause open while docked.
##
## These tests are load-bearing against the two silent-removal shapes that killed
## attempt 1:
## 1. Deleting `_mark_sim_pausable` demotion (sim keeps processing under paused tree)
## 2. Deleting `_notification` (focus handlers never connected to the engine)
##
## And against the shape that killed attempt 2, which is the reason the docked
## rule now lives inside `_set_pause` instead of at each caller: #58 was tested
## only through the Escape key, so when the focus-loss handler was rewritten
## without its copy of the check, every test stayed green while alt-tabbing at a
## berth put the pause menu back on screen. The docked assertions below test the
## invariant at the door (`_set_pause`) and on every route to it, so a third
## route added later cannot pass by being untested.
##
## Prove red by removing only those production lines with tests left in place —
## not by reverting the whole commit.

const MainScene: PackedScene = preload("res://src/Main.tscn")

const AUTOSAVE_FIXTURE: String = "repair5_pause_autosave"


func after_each() -> void:
	# Never leave the SceneTree paused for the next script.
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false
	ServiceRegistry.reset_all()
	StandingService.reset_to_defaults()
	CareerStart.reset()
	var path: String = SaveService.path_for(AUTOSAVE_FIXTURE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _press(action: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## main.get returns Variant; this project's strict typing refuses bool(Variant).
func _main_bool(main: Node, property: String) -> bool:
	var value: Variant = main.get(property)
	if typeof(value) != TYPE_BOOL:
		return false
	var as_bool: bool = value
	return as_bool


## Same trap on the call side: Node.call returns Variant, and a Variant may not
## be handed to GUT's typed asserts under this project's warnings-as-errors.
func _call_bool(main: Node, method: String, arg: Variant) -> bool:
	var value: Variant = main.call(method, arg)
	if typeof(value) != TYPE_BOOL:
		return false
	var as_bool: bool = value
	return as_bool


## New career through annexation to the storyboard berth.
func _career_at_storyboard(main: Node) -> StringName:
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
	return berth


func _undock_to_flight(main: Node, berth: StringName) -> void:
	EventBus.on_undock_requested.emit(berth)
	await _frames(4)
	var docking: DockingService = main.get_node("DockingService")
	assert_false(docking.controller().is_docked(), "must be free-flying for pause tests")


func _close_career() -> void:
	EventBus.on_quit_to_menu_requested.emit()
	await _frames(6)


## A live hostile under this world, guaranteed.
##
## The start system spawns none of its own — measured, 0 in GROUP_HOSTILE under
## SystemWorld — so the previous version of this file wrapped every hostile
## assertion in `if hostile != null` and never ran one of them. "Hostiles keep
## simulating while paused" is the headline of #46, so it is spawned rather than
## hoped for, and the assertions below are unconditional.
func _spawned_hostile(world: SystemWorld) -> HostileNpc:
	var hostile: HostileNpc = world.spawn_hostile_at(Vector3(60.0, 0.0, 60.0))
	assert_not_null(hostile, "#46 needs a real hostile to freeze")
	assert_true(world.is_ancestor_of(hostile), "hostile must live under SystemWorld")
	assert_true(
		hostile.is_in_group(BalanceCombat.GROUP_HOSTILE), "spawned hostile joins GROUP_HOSTILE"
	)
	return hostile


# --- SceneTree pause freezes real sim nodes ---------------------------------


func test_opening_pause_sets_tree_paused_and_freezes_sim_nodes() -> void:
	# Definition of done: open pause freezes hostiles, fuel, hull, upkeep.
	# The can_process() asserts go red if `_mark_sim_pausable` is deleted while
	# tests stay — nodes inherit Main's ALWAYS and keep processing.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	var fuel: FuelService = main.get_node("FuelService")
	var hull: HullConditionService = main.get_node("HullConditionService")
	var world: SystemWorld = main.get_node("SystemWorld")
	var ship: PlayerShip = get_tree().get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP)
	var pause_menu: PauseMenu = main.get_node("PauseMenu")
	var hostile: HostileNpc = _spawned_hostile(world)
	await _frames(1)

	assert_false(get_tree().paused, "starts unpaused")
	assert_true(fuel.can_process(), "fuel processes while live")
	assert_true(hull.can_process(), "hull processes while live")
	assert_true(world.can_process(), "world processes while live")
	assert_true(ship.can_process(), "ship processes while live")
	assert_true(WorldClock.can_process(), "WorldClock processes while live")
	assert_true(hostile.can_process(), "hostile processes while live")

	main.call("_set_pause", true)

	assert_true(get_tree().paused, "pause must set SceneTree.paused")
	assert_true(_main_bool(main, "_pause_open"), "Main pause flag open")
	assert_true(pause_menu.visible, "pause menu visible")
	assert_true(main.can_process(), "Main stays ALWAYS")
	assert_true(pause_menu.can_process(), "PauseMenu stays ALWAYS")
	assert_false(fuel.can_process(), "FuelService must freeze while paused")
	assert_false(hull.can_process(), "HullConditionService must freeze while paused")
	assert_false(world.can_process(), "SystemWorld must freeze while paused")
	assert_false(ship.can_process(), "PlayerShip must freeze while paused")
	assert_false(WorldClock.can_process(), "WorldClock must freeze while paused")
	assert_false(hostile.can_process(), "HostileNpc must freeze while paused")

	main.call("_set_pause", false)
	assert_false(get_tree().paused, "resume clears SceneTree.paused")
	assert_true(fuel.can_process(), "fuel runs again after resume")

	await _close_career()


# --- Focus via engine notification (not direct handler calls) ---------------


func test_focus_out_notification_auto_pauses() -> void:
	# Deleting `_notification` leaves this green-for-wrong-reason if tests only
	# call `_on_application_focus_out` directly. Drive Object.notification.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

	assert_true(get_tree().paused, "focus-out must pause the tree")
	assert_true(_main_bool(main, "_pause_open"), "focus-out opens pause")
	assert_true(_main_bool(main, "_pause_from_focus_loss"), "tagged as focus-loss pause")

	main.call("_set_pause", false)
	await _close_career()


func test_focus_in_resumes_only_focus_loss_pause() -> void:
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused, "auto-paused")

	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(get_tree().paused, "focus-in resumes a focus-loss pause")
	assert_false(_main_bool(main, "_pause_open"), "pause menu closed")
	assert_false(_main_bool(main, "_pause_from_focus_loss"), "flag cleared")

	await _close_career()


func test_focus_in_does_not_cancel_intentional_pause() -> void:
	# Bounce reason 1: Escape → alt-tab away → alt-tab back must stay paused.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	main.call("_set_pause", true)
	assert_true(get_tree().paused, "intentional pause")
	assert_false(_main_bool(main, "_pause_from_focus_loss"), "not a focus-loss pause")

	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

	assert_true(get_tree().paused, "intentional pause survives focus cycle")
	assert_true(_main_bool(main, "_pause_open"), "pause menu still open")

	main.call("_set_pause", false)
	await _close_career()


func test_focus_in_refuses_while_options_overlay_visible() -> void:
	# Bounce reason 1b: focus-loss pause + Options open → focus-in must not
	# unpause under an open Options panel.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(_main_bool(main, "_pause_from_focus_loss"), "focus-loss pause")

	EventBus.on_options_open_requested.emit()
	await _frames(1)
	var options: OptionsMenu = main.get_node("OptionsMenu")
	assert_true(options.visible, "Options open")

	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

	assert_true(get_tree().paused, "must stay paused under Options")
	assert_true(_main_bool(main, "_pause_open"), "pause flag stays")
	assert_true(options.visible, "Options still open")
	assert_true(_main_bool(main, "_pause_from_focus_loss"), "still owned by focus-loss")

	EventBus.on_options_close_requested.emit()
	main.call("_set_pause", false)
	await _close_career()


func test_wm_window_focus_constants_also_route() -> void:
	# All four focus constants must hit the handlers through _notification.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	main.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_true(get_tree().paused, "WM_WINDOW_FOCUS_OUT pauses")
	main.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	assert_false(get_tree().paused, "WM_WINDOW_FOCUS_IN resumes focus-loss pause")

	await _close_career()


# --- Input gates (#57 sector map, #58 docked) -------------------------------


func test_sector_map_blocked_while_options_open() -> void:
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	EventBus.on_options_open_requested.emit()
	await _frames(1)
	var options: OptionsMenu = main.get_node("OptionsMenu")
	var sector_map: SectorMapPanel = main.get_node("SectorMapPanel")
	assert_true(options.visible, "Options open")
	assert_false(sector_map.visible, "map starts closed")

	main._unhandled_input(_press(FlightInput.ACTION_SECTOR_MAP))
	await _frames(1)

	assert_false(sector_map.visible, "M must not open sector map behind Options")

	EventBus.on_options_close_requested.emit()
	await _close_career()


func test_sector_map_blocked_while_pause_open() -> void:
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	main.call("_set_pause", true)
	var sector_map: SectorMapPanel = main.get_node("SectorMapPanel")
	assert_false(sector_map.visible, "map starts closed")

	main._unhandled_input(_press(FlightInput.ACTION_SECTOR_MAP))
	await _frames(1)

	assert_false(sector_map.visible, "M must not open sector map while paused")

	main.call("_set_pause", false)
	await _close_career()


func test_pause_key_does_nothing_while_docked() -> void:
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	await _career_at_storyboard(main)
	var pause_menu: PauseMenu = main.get_node("PauseMenu")

	# Without this the test cannot tell a docked refusal from `_in_play` being
	# false, and would stay green if the docked check were deleted outright.
	assert_true(_main_bool(main, "_in_play"), "berth is a live session, so #58 is the only gate")
	assert_false(_main_bool(main, "_pause_open"), "not paused at berth")

	main._unhandled_input(_press(FlightInput.ACTION_PAUSE))
	await _frames(1)

	assert_false(_main_bool(main, "_pause_open"), "Escape must not open pause while docked")
	assert_false(pause_menu.visible, "and the menu itself must not appear")
	assert_false(get_tree().paused, "tree stays live while docked Escape is ignored")

	await _close_career()


# --- #58 at the door, not at the callers ------------------------------------
#
# Three routes reach `_pause_open`. Each is asserted separately, because the
# regression that sent this brief to a third attempt was one route rewritten
# without the check while the others still had it.


func test_set_pause_refuses_to_open_the_menu_while_docked() -> void:
	# The invariant itself, with no route involved: the door is shut.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	await _career_at_storyboard(main)
	var pause_menu: PauseMenu = main.get_node("PauseMenu")

	assert_true(_main_bool(main, "_in_play"), "live session")
	var changed: bool = _call_bool(main, "_set_pause", true)

	assert_false(changed, "_set_pause must report the refusal, not a silent no-op")
	assert_false(_main_bool(main, "_pause_open"), "docked pause refused at the door")
	assert_false(pause_menu.visible, "no pause menu over the station menu")
	assert_false(get_tree().paused, "and nothing froze")

	await _close_career()


func test_focus_loss_while_docked_freezes_without_opening_the_menu() -> void:
	# The route that regressed. Alt-tab at a berth: #47 still freezes the sim,
	# #58 still keeps the Load-bearing pause menu off the station menu.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	await _career_at_storyboard(main)
	var pause_menu: PauseMenu = main.get_node("PauseMenu")
	var station_menu: StationMenu = main.get_node("StationMenu")

	assert_true(_main_bool(main, "_in_play"), "live session")
	assert_false(get_tree().paused, "starts live")

	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

	assert_true(get_tree().paused, "#47: alt-tab freezes the sim at a berth too")
	assert_false(_main_bool(main, "_pause_open"), "#58: no pause menu while docked")
	assert_false(pause_menu.visible, "#58: and it is not on screen")
	assert_false(
		_main_bool(main, "_pause_from_focus_loss"), "nothing was opened, so nothing is owned"
	)
	assert_false(station_menu.can_process(), "the station menu freezes with everything else")

	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

	assert_false(get_tree().paused, "focus-in lifts a freeze the window caused")
	assert_true(station_menu.can_process(), "station menu runs again")
	assert_false(pause_menu.visible, "and no menu was ever opened to close")

	await _close_career()


func test_pause_bus_cannot_pause_the_session_while_docked() -> void:
	# The third route into `_pause_open`: anything emitting on_pause_changed(true)
	# from outside Main. Main refuses it the same way it refuses the other two.
	#
	# Scope, stated so the next reader does not mistake this test for more than
	# it is: nothing in the game emits true from outside Main today — PauseMenu's
	# Resume only ever emits false — so this is the rule holding on a route that
	# has no caller yet, not a live bug. It does NOT cover the panel's own
	# visibility. PauseMenu sets `visible = open` straight off this signal and
	# connects after Main (Main._wire_session_bus at _ready, PauseMenu in its own
	# _ready one line later), so Main's handler runs first and cannot put the
	# panel back down within the same emission. Measured, and filed as a proposed
	# finding rather than fixed here: an outside emitter of true would show the
	# panel while docked even though the session stays unpaused.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	await _career_at_storyboard(main)

	EventBus.on_pause_changed.emit(true)
	await _frames(1)

	assert_false(_main_bool(main, "_pause_open"), "bus cannot open a docked pause either")
	assert_false(get_tree().paused, "and cannot freeze the session through that door")

	await _close_career()


func test_focus_loss_in_flight_still_opens_the_menu() -> void:
	# The refusal must be scoped to a berth: undocked alt-tab keeps its menu, or
	# #58's fix would have quietly eaten #47's.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)
	var pause_menu: PauseMenu = main.get_node("PauseMenu")

	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

	assert_true(get_tree().paused, "flight alt-tab freezes")
	assert_true(_main_bool(main, "_pause_open"), "and opens the menu when not docked")
	assert_true(pause_menu.visible, "menu on screen in flight")
	assert_true(_main_bool(main, "_pause_from_focus_loss"), "owned by focus loss")

	main.call("_set_pause", false)
	await _close_career()


# --- The demotion is opt-out, so something has to walk the children ---------


func test_every_sim_child_of_main_freezes_under_a_paused_tree() -> void:
	# Main is PROCESS_MODE_ALWAYS, so a child added by any later brief inherits
	# ALWAYS and keeps simulating behind the pause menu unless somebody
	# remembers `_mark_sim_pausable`. Nothing enforces remembering, so this walks
	# the real child list instead of trusting the 26 call sites that exist today.
	var overlays_that_may_run_while_paused: Array[String] = [
		"MainMenu",
		"PauseMenu",
		"OptionsMenu",
		"CaptainSheet",
		"CampaignJournal",
		"SectorMapPanel",
		"NewGameTip",
		"LifePathCreate",
		"OpeningAnnexation",
		"LossScreen",
		"DebugConsole",
	]
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	main.call("_set_pause", true)
	assert_true(get_tree().paused, "tree paused for the walk")

	var still_running: Array[String] = []
	for child: Node in main.get_children():
		if overlays_that_may_run_while_paused.has(String(child.name)):
			assert_true(child.can_process(), "%s must stay interactive while paused" % child.name)
			continue
		if child.can_process():
			still_running.append(String(child.name))

	assert_true(
		still_running.is_empty(),
		(
			"every non-overlay child of Main must be PAUSABLE, but these kept "
			+ "running under a paused tree: %s — add _mark_sim_pausable at their "
			+ "add_child, or add them to the overlay list above if they are session UI"
		) % str(still_running)
	)

	main.call("_set_pause", false)
	await _close_career()


func test_pause_key_opens_while_flying() -> void:
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_storyboard(main)
	await _undock_to_flight(main, berth)

	main._unhandled_input(_press(FlightInput.ACTION_PAUSE))
	await _frames(1)

	assert_true(_main_bool(main, "_pause_open"), "Escape opens pause in flight")
	assert_true(get_tree().paused, "and freezes the tree")

	main.call("_set_pause", false)
	await _close_career()
