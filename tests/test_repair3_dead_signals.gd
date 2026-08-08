extends GutTest

## REPAIR-3 — three signals that nothing connected to at all.
##
## Audit baseline ee17eab5: on_system_exited, SystemWorld.built, and
## on_ops_charter_breached were emitted in production with zero .connect
## anywhere (not even a test). Definition of done: each either has a
## production listener or no emit remains.
##
## Guards:
##   #19  StationOpsUi.connect_refresh wires charter breach (direct emit).
##        FlightHUD toasts on the same signal (own listener).
##   W4   SystemWorld no longer declares `built`; build still emits entered.
##   #65  Main no longer emits on_system_exited from either production site
##        (jump + save system change). Proved by booting Main.tscn, counting
##        bus emissions while driving both sites, and asserting zero. Putting
##        either emit back makes this test fail.

const MainScene: PackedScene = preload("res://src/Main.tscn")

const ENTITY_REACH: StringName = &"entity_reach_authority"
const SYSTEM_BETA: StringName = &"system_beta"
const AUTOSAVE_FIXTURE: String = "repair3_system_exit_autosave"

var _refresh_hits: int = 0
var _exit_hits: int = 0
var _exit_ids: Array[StringName] = []
var _entered_ids: Array[StringName] = []


func before_each() -> void:
	_refresh_hits = 0
	_exit_hits = 0
	_exit_ids.clear()
	_entered_ids.clear()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()
	MarketService.reset()


func after_each() -> void:
	StationOpsUi.disconnect_refresh(_on_refresh)
	_disconnect_exit_counter()
	_disconnect_enter_counter()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()
	ServiceRegistry.reset_all()
	CareerStart.reset()
	_remove_fixture(AUTOSAVE_FIXTURE)


func _on_refresh() -> void:
	_refresh_hits += 1


func _on_system_exited(system_id: StringName) -> void:
	_exit_hits += 1
	_exit_ids.append(system_id)


func _on_system_entered(system_id: StringName) -> void:
	_entered_ids.append(system_id)


func _disconnect_exit_counter() -> void:
	if EventBus.on_system_exited.is_connected(_on_system_exited):
		EventBus.on_system_exited.disconnect(_on_system_exited)


func _disconnect_enter_counter() -> void:
	if EventBus.on_system_entered.is_connected(_on_system_entered):
		EventBus.on_system_entered.disconnect(_on_system_entered)


# --- #19 charter breach production listeners ---------------------------------


## Red-before-green: connect_refresh must wire charter_breached so a breach
## emit drives the same zero-arg refresh the other ops signals use. Isolate
## the breach wire — do not count fire/upkeep, which also refresh.
func test_station_ops_connect_refresh_listens_to_charter_breach() -> void:
	StationOpsUi.connect_refresh(_on_refresh)
	assert_eq(_refresh_hits, 0, "connect alone must not refresh")
	EventBus.on_ops_charter_breached.emit(&"ops_ship_0", ENTITY_REACH)
	assert_eq(
		_refresh_hits,
		1,
		"on_ops_charter_breached must drive StationOpsUi refresh (production listener)"
	)
	StationOpsUi.disconnect_refresh(_on_refresh)
	EventBus.on_ops_charter_breached.emit(&"ops_ship_0", ENTITY_REACH)
	assert_eq(_refresh_hits, 1, "disconnect_refresh must drop the charter breach listener")


## Second production listener for #19: free-flying captain sees a toast, not a
## silent fleet loss. Isolates FlightHUD — not the ops fire path.
func test_flight_hud_toasts_on_charter_breach() -> void:
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await _frames(2)
	assert_eq(hud.kill_toast_text(), "", "toast starts empty")
	EventBus.on_ops_charter_breached.emit(&"ops_ship_0", ENTITY_REACH)
	var expected: String = BalanceOps.CHARTER_BREACH_TOAST_FORMAT % "Reach Authority"
	assert_eq(hud.kill_toast_text(), expected, "FlightHUD must toast the charter Entity")


# --- W4 SystemWorld.built removed --------------------------------------------


## SystemWorld.built was a node signal with zero connects — remove it entirely
## (not EventBus; declaration block is free). on_system_entered remains the
## contract surface for "world is ready".
func test_system_world_has_no_built_signal() -> void:
	var world: SystemWorld = SystemWorld.new()
	add_child_autofree(world)
	var names: PackedStringArray = PackedStringArray()
	for info: Dictionary in world.get_signal_list():
		names.append(str(info.get("name", "")))
	assert_false(
		names.has("built"),
		"SystemWorld.built must be gone — nothing connected; on_system_entered is the bus contract"
	)


func test_system_world_build_still_emits_system_entered() -> void:
	EventBus.on_system_entered.connect(_on_system_entered)
	var world: SystemWorld = SystemWorld.new()
	add_child_autofree(world)
	world.system_id = BalanceFlight.PLAYABLE_SYSTEM_ID
	world.build()
	assert_eq(_entered_ids.size(), 1, "build must still announce on_system_entered")
	assert_eq(_entered_ids[0], BalanceFlight.PLAYABLE_SYSTEM_ID)


# --- #65 on_system_exited emit removal (Main production sites) ----------------


## Boots the real session shell and drives BOTH sites that used to emit
## on_system_exited: the jump path and Main._apply_world_section on a system
## change. A counter on the bus must stay at zero. Putting either emit back
## (fix alone, tests left in place) makes this fail — that is the whole point.
##
## Shape taken from tests/test_docked_restore.gd (Job 3 / #9), which already
## boots Main.tscn and drives _apply_world_section.
func test_main_never_emits_on_system_exited_from_jump_or_world_apply() -> void:
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	var berth: StringName = await _career_at_the_storyboard_berth(main)

	# Leave the berth so the jump path is allowed.
	EventBus.on_undock_requested.emit(berth)
	await _frames(4)

	EventBus.on_system_exited.connect(_on_system_exited)
	EventBus.on_system_entered.connect(_on_system_entered)
	_entered_ids.clear()
	_exit_hits = 0
	_exit_ids.clear()

	# Site 1: jump path (Main._on_jump_requested).
	EventBus.on_jump_requested.emit(SYSTEM_BETA)
	await _frames(12)
	assert_true(
		_entered_ids.has(SYSTEM_BETA),
		"jump must rebuild into system_beta or the exit guard never ran"
	)
	assert_eq(
		_exit_hits,
		0,
		"jump must not emit on_system_exited (REPAIR-3 #65 — put the emit back and this fails)"
	)

	# Site 2: save/load system change (Main._apply_world_section). Typed as
	# Node so the private method is reached through call(), same pattern as
	# other Main path tests that cannot name Main's script class.
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	sections[BalanceSession.SAVE_SECTION_WORLD] = CareerSave.make_world_section(
		BalanceFlight.PLAYABLE_SYSTEM_ID, Vector3(200.0, 0.0, 0.0), &""
	)
	await main.call(&"_apply_world_section", sections)
	await _frames(8)
	assert_true(
		_entered_ids.has(BalanceFlight.PLAYABLE_SYSTEM_ID),
		"world apply must rebuild into system_alpha or the exit guard never ran"
	)
	assert_eq(
		_exit_hits,
		0,
		"system-changing _apply_world_section must not emit on_system_exited (REPAIR-3 #65)"
	)

	await _close_the_career()


# --- Rig ----------------------------------------------------------------------


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _career_at_the_storyboard_berth(main: Node) -> StringName:
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
	assert_false(String(berth).is_empty(), "the storyboard must open docked, or nothing here holds")
	return berth


func _close_the_career() -> void:
	EventBus.on_quit_to_menu_requested.emit()
	await _frames(6)


func _remove_fixture(file_name: String) -> void:
	var path: String = SaveService.path_for(file_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
