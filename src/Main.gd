extends Node

## Boot entry and composition root for Draywar Alpha — B2/B3 session shell.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1–A5, Alpha/ALPHA_DECISION_PHASE_PLAN.md B2–B3
##
## Owns ConsoleService, wires DebugConsole, holds Save / Attribution / Mission /
## Recovery / Wallet / Cargo services, boots play from the main menu, and
## rebuilds the world on gate jumps.

const BOOT_BANNER: String = "Draywar Alpha — boot OK"

## The debug console's parser and roster. Not a global.
var _console: ConsoleService = null

var _world: SystemWorld = null
var _ship: PlayerShip = null
var _camera: ChaseCamera = null
var _docking: DockingService = null
var _gate_travel: GateTravelService = null
var _wallet: WalletService = null
var _cargo: CargoService = null
var _hud: FlightHUD = null
var _station_menu: StationMenu = null

var _main_menu: MainMenu = null
var _pause_menu: PauseMenu = null
var _captain_sheet: CaptainSheet = null
var _new_game_tip: NewGameTip = null

var _in_play: bool = false
var _pause_open: bool = false
var _console_open: bool = false
var _jump_busy: bool = false

@onready var _debug_console: CanvasLayer = $DebugConsole


func _ready() -> void:
	print(BOOT_BANNER)
	FlightInput.ensure_actions()
	_console = ConsoleService.new()
	# Children declared in Main.tscn are ready before this runs, so save and
	# time (autoload) commands are listening when the console asks who is out.
	_console.start()
	_wire_session_bus()
	_create_session_ui()
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(FlightInput.ACTION_PAUSE):
		return
	if not _in_play or _console_open or _jump_busy:
		return
	if _captain_sheet != null and _captain_sheet.visible:
		EventBus.on_captain_sheet_close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	_set_pause(not _pause_open)
	get_viewport().set_input_as_handled()


## Connected in Main.tscn to the console view's line_submitted.
func _on_debug_console_line_submitted(line: String) -> void:
	_console.submit(line)


func _wire_session_bus() -> void:
	EventBus.on_new_game_requested.connect(_on_new_game_requested)
	EventBus.on_continue_requested.connect(_on_continue_requested)
	EventBus.on_quit_to_desktop_requested.connect(_on_quit_to_desktop_requested)
	EventBus.on_quit_to_menu_requested.connect(_on_quit_to_menu_requested)
	EventBus.on_manual_save_requested.connect(_on_manual_save_requested)
	EventBus.on_manual_load_requested.connect(_on_manual_load_requested)
	EventBus.on_console_visibility_changed.connect(_on_console_visibility_changed)
	EventBus.on_pause_changed.connect(_on_pause_changed_bus)


func _create_session_ui() -> void:
	_main_menu = MainMenu.new()
	_main_menu.name = "MainMenu"
	add_child(_main_menu)

	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)

	_captain_sheet = CaptainSheet.new()
	_captain_sheet.name = "CaptainSheet"
	add_child(_captain_sheet)

	_new_game_tip = NewGameTip.new()
	_new_game_tip.name = "NewGameTip"
	add_child(_new_game_tip)

	_raise_debug_console()


func _show_main_menu() -> void:
	_set_pause(false)
	if _captain_sheet != null:
		_captain_sheet.visible = false
	if _main_menu != null:
		_main_menu.visible = true
		_main_menu.refresh_continue(not SaveService.most_recent_path().is_empty())
		_main_menu.show_feedback("")
	_raise_debug_console()


func _hide_main_menu() -> void:
	if _main_menu != null:
		_main_menu.visible = false


func _on_console_visibility_changed(open: bool) -> void:
	_console_open = open


func _on_pause_changed_bus(open: bool) -> void:
	# PauseMenu Resume emits this; keep Main flag in sync.
	_pause_open = open
	if not open and _captain_sheet != null:
		_captain_sheet.visible = false


func _set_pause(open: bool) -> void:
	if _pause_open == open:
		return
	_pause_open = open
	EventBus.on_pause_changed.emit(open)
	if not open and _captain_sheet != null:
		_captain_sheet.visible = false


func _on_new_game_requested() -> void:
	await _start_new_game()


func _start_new_game() -> void:
	_reset_career_services()
	await _tear_down_play_session()
	_boot_play_session()
	# Storyboard entry: always wake up docked at the starter station, not
	# free-flying into pirates. Government Alpha has no combat hostiles.
	_enter_career_docked()
	_in_play = true
	_hide_main_menu()
	_set_pause(false)
	if _new_game_tip != null:
		_new_game_tip.show_tip()


## Dock at the primary station of the current system (new career only; no fee).
func _enter_career_docked() -> void:
	if _docking == null or _world == null:
		return
	var station_id: StringName = _primary_station_id()
	if String(station_id).is_empty():
		return
	_docking.begin_session_docked(station_id)


## First station id in the live world map (starter ship storyboard berth).
func _primary_station_id() -> StringName:
	if _world == null:
		return &""
	var positions: Dictionary = _world.station_positions()
	if positions.is_empty():
		return &""
	var ids: Array = positions.keys()
	ids.sort()
	return StringName(str(ids[0]))


func _on_continue_requested() -> void:
	await _continue_career()


func _continue_career() -> void:
	var path: String = SaveService.most_recent_path()
	if path.is_empty():
		if _main_menu != null:
			_main_menu.show_feedback(BalanceSession.LOAD_NONE)
		return
	var loaded: SaveResult = CareerSave.load_envelope(path)
	if not loaded.ok():
		if _main_menu != null:
			_main_menu.show_feedback(BalanceSession.LOAD_FAIL_FORMAT % loaded.summary())
		return
	var sections: Dictionary = _sections_of(loaded.envelope)
	_reset_career_services()
	await _tear_down_play_session()
	_boot_play_session()
	CareerSave.apply_meta_sections(get_tree(), sections)
	await _apply_world_section(sections)
	_in_play = true
	_hide_main_menu()
	_set_pause(false)
	if _new_game_tip != null:
		_new_game_tip.hide_tip()


func _on_quit_to_desktop_requested() -> void:
	get_tree().quit()


func _on_quit_to_menu_requested() -> void:
	await _return_to_menu()


func _return_to_menu() -> void:
	_set_pause(false)
	if _captain_sheet != null:
		_captain_sheet.visible = false
	if _new_game_tip != null:
		_new_game_tip.hide_tip()
	await _tear_down_play_session()
	_reset_career_services()
	_in_play = false
	_show_main_menu()


func _on_manual_save_requested() -> void:
	if not _in_play:
		return
	var written: SaveResult = CareerSave.save_to_name(get_tree(), BalanceSession.DEFAULT_SAVE_NAME)
	if _pause_menu == null:
		return
	if written.ok():
		_pause_menu.show_feedback(BalanceSession.SAVE_OK_FORMAT % BalanceSession.DEFAULT_SAVE_NAME)
	else:
		_pause_menu.show_feedback(BalanceSession.SAVE_FAIL_FORMAT % written.summary())


func _on_manual_load_requested() -> void:
	if not _in_play:
		return
	await _load_into_play()


func _load_into_play() -> void:
	var path: String = SaveService.most_recent_path()
	if path.is_empty():
		if _pause_menu != null:
			_pause_menu.show_feedback(BalanceSession.LOAD_NONE)
		return
	var loaded: SaveResult = CareerSave.load_envelope(path)
	if not loaded.ok():
		if _pause_menu != null:
			_pause_menu.show_feedback(BalanceSession.LOAD_FAIL_FORMAT % loaded.summary())
		return
	var sections: Dictionary = _sections_of(loaded.envelope)
	CareerSave.apply_meta_sections(get_tree(), sections)
	await _apply_world_section(sections)
	if _pause_menu != null:
		_pause_menu.show_feedback(BalanceSession.LOAD_OK_FORMAT % path.get_file())
	_set_pause(false)


func _sections_of(envelope: Dictionary) -> Dictionary:
	if not envelope.has(SaveService.KEY_SECTIONS):
		return {}
	var sections_raw: Variant = envelope[SaveService.KEY_SECTIONS]
	if typeof(sections_raw) != TYPE_DICTIONARY:
		return {}
	return sections_raw


func _reset_career_services() -> void:
	StandingService.reset_to_defaults()
	var mission: Node = get_node_or_null("MissionService")
	if mission != null and mission.has_method(&"reset"):
		mission.call(&"reset")
	var recovery: Node = get_node_or_null("RecoveryService")
	if recovery != null and recovery.has_method(&"reset"):
		recovery.call(&"reset")
	if recovery != null and recovery.has_method(&"apply_progress_section"):
		recovery.call(&"apply_progress_section", {})


func _boot_play_session() -> void:
	# UI must exist before SystemWorld.build() emits on_system_entered.
	# Wallet after HUD so seed emissions for credits/fuel/condition hit the HUD.
	_hud = FlightHUD.new()
	_hud.name = "FlightHUD"
	add_child(_hud)

	_wallet = WalletService.new()
	_wallet.name = "WalletService"
	add_child(_wallet)

	_cargo = CargoService.new()
	_cargo.name = "CargoService"
	add_child(_cargo)

	_station_menu = StationMenu.new()
	_station_menu.name = "StationMenu"
	add_child(_station_menu)

	_world = SystemWorld.new()
	_world.name = "SystemWorld"
	_world.add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)
	_world.system_id = BalanceFlight.PLAYABLE_SYSTEM_ID
	add_child(_world)
	_world.build()

	_ship = PlayerShip.new()
	_ship.name = "PlayerShip"
	_ship.hull_id = BalanceFlight.PLAYER_HULL_ID
	_ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	_world.add_child(_ship)
	_ship.global_position = _world.player_spawn_position()

	_camera = ChaseCamera.new()
	_camera.name = "ChaseCamera"
	_world.add_child(_camera)
	_camera.set_target(_ship)
	_ship.set_aim_camera(_camera)

	_docking = DockingService.new()
	_docking.name = "DockingService"
	add_child(_docking)
	_docking.setup(_ship, _world.station_positions())

	_gate_travel = GateTravelService.new()
	_gate_travel.name = "GateTravelService"
	add_child(_gate_travel)
	_gate_travel.setup(_ship, _world.gate_positions(), _docking)

	if not EventBus.on_jump_requested.is_connected(_on_jump_requested):
		EventBus.on_jump_requested.connect(_on_jump_requested)

	_raise_debug_console()


func _tear_down_play_session() -> void:
	if EventBus.on_jump_requested.is_connected(_on_jump_requested):
		EventBus.on_jump_requested.disconnect(_on_jump_requested)

	if _gate_travel != null:
		_gate_travel.queue_free()
		_gate_travel = null
	if _docking != null:
		_docking.queue_free()
		_docking = null
	if _station_menu != null:
		_station_menu.queue_free()
		_station_menu = null
	if _hud != null:
		_hud.queue_free()
		_hud = null
	if _cargo != null:
		_cargo.queue_free()
		_cargo = null
	if _wallet != null:
		_wallet.queue_free()
		_wallet = null
	if _world != null:
		# Ship and camera are children of the world.
		_world.queue_free()
		_world = null
	_ship = null
	_camera = null

	await get_tree().process_frame
	_raise_debug_console()


func _apply_world_section(sections: Dictionary) -> void:
	var world_data: Dictionary = CareerSave.world_from_sections(sections)
	if world_data.is_empty() or _world == null or _ship == null:
		return

	var system_id: StringName = BalanceFlight.PLAYABLE_SYSTEM_ID
	if world_data.has(BalanceSession.WORLD_KEY_SYSTEM_ID):
		var raw_id: String = str(world_data[BalanceSession.WORLD_KEY_SYSTEM_ID])
		if not raw_id.is_empty() and ContentLibrary.has_item(StringName(raw_id)):
			system_id = StringName(raw_id)

	if system_id != _world.system_id:
		var from_id: StringName = _world.system_id
		EventBus.on_system_exited.emit(from_id)
		_world.clear_world()
		await get_tree().process_frame
		_world.system_id = system_id
		_world.build()
		if _docking != null:
			_docking.setup(_ship, _world.station_positions())
		if _gate_travel != null:
			_gate_travel.setup(_ship, _world.gate_positions(), _docking)

	var has_pos: bool = (
		world_data.has(BalanceSession.WORLD_KEY_POS_X)
		and world_data.has(BalanceSession.WORLD_KEY_POS_Y)
		and world_data.has(BalanceSession.WORLD_KEY_POS_Z)
	)
	if has_pos:
		_ship.global_position = Vector3(
			_variant_to_float(world_data[BalanceSession.WORLD_KEY_POS_X]),
			_variant_to_float(world_data[BalanceSession.WORLD_KEY_POS_Y]),
			_variant_to_float(world_data[BalanceSession.WORLD_KEY_POS_Z])
		)
		_ship.velocity = Vector3.ZERO
		_ship.set_flight_enabled(true)
		_ship.visible = true

	# Free-fly restore preferred; docked restore is deferred (hard with state machine).
	_raise_debug_console()


func _on_jump_requested(destination_system_id: StringName) -> void:
	if _jump_busy:
		return
	if not _jump_allowed(destination_system_id):
		return
	if not _wallet.try_spend_jump_fuel():
		return

	_jump_busy = true
	var from_id: StringName = _world.system_id
	EventBus.on_system_exited.emit(from_id)

	_world.clear_world()
	# Wait one frame so queue_free finishes before re-adding environment nodes.
	await get_tree().process_frame

	_world.system_id = destination_system_id
	_world.build()

	_ship.global_position = _world.jump_arrival_position(from_id)
	_ship.velocity = Vector3.ZERO
	_ship.set_throttle(BalanceFlight.UNDOCK_THROTTLE)
	_ship.set_flight_enabled(true)
	_ship.visible = true

	_docking.setup(_ship, _world.station_positions())
	_gate_travel.setup(_ship, _world.gate_positions(), _docking)

	_raise_debug_console()
	_jump_busy = false


func _jump_allowed(destination_system_id: StringName) -> bool:
	if _wallet == null or _world == null or _ship == null:
		return false
	if _docking != null and _docking.controller().is_docked():
		return false
	if String(destination_system_id).is_empty():
		return false
	if destination_system_id == _world.system_id:
		return false
	if not ContentLibrary.has_item(destination_system_id):
		return false
	return _wallet.can_jump()


func _raise_debug_console() -> void:
	if _debug_console != null and is_instance_valid(_debug_console):
		move_child(_debug_console, get_child_count() - 1)


func _variant_to_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return as_float
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	if typeof(value) == TYPE_STRING:
		var text: String = value
		if text.is_valid_float():
			return float(text)
	return 0.0
