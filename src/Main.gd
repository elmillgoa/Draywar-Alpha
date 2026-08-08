extends Node

## Boot entry and composition root for Draywar Alpha — B2/B3 session shell.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1–A5, Alpha/ALPHA_DECISION_PHASE_PLAN.md B2–B3
##
## Owns ConsoleService, wires DebugConsole, holds Save / Attribution / Mission /
## Recovery / Wallet / Fuel / Hull / Cargo / Ship / Ops / Campaign / MoneyLog
## services, boots play from the main menu, and rebuilds the world on gate jumps.

const BOOT_BANNER: String = BalanceSettings.BOOT_BANNER

## REPAIR-24: build gate for the debug console. Default is the real engine
## flag; tests set false before add_child so the real `_ready` path can be
## asserted without a release export. No config unlock.
var build_is_debug: bool = OS.is_debug_build()

## The debug console's parser and roster. Not a global.
var _console: ConsoleService = null

var _world: SystemWorld = null
var _ship: PlayerShip = null
var _camera: ChaseCamera = null
var _docking: DockingService = null
var _gate_travel: GateTravelService = null
var _rescue: RescueService = null
var _autosave: AutosaveService = null
var _wallet: WalletService = null
var _fuel: FuelService = null
var _hull: HullConditionService = null
var _cargo: CargoService = null
var _money_log: MoneyLog = null
var _ship_service: ShipService = null
var _operation: OperationService = null
var _campaign: CampaignService = null
var _hud: FlightHUD = null
var _station_menu: StationMenu = null

var _main_menu: MainMenu = null
var _pause_menu: PauseMenu = null
var _options_menu: OptionsMenu = null
var _captain_sheet: CaptainSheet = null
var _campaign_journal: CampaignJournal = null
var _sector_map: SectorMapPanel = null
var _new_game_tip: NewGameTip = null
var _life_path_create: LifePathCreate = null
var _opening_annexation: OpeningAnnexation = null
var _loss_screen: LossScreen = null

var _in_play: bool = false
## True while create / annexation are open — no tip, dock, or undock yet.
var _opening_in_progress: bool = false
var _pause_open: bool = false
## True only when focus-loss opened the pause. An intentional Escape pause must
## survive alt-tab, and focus-in resumes only what focus-out opened.
var _pause_from_focus_loss: bool = false
## True while the window has no focus. Freezing the sim (#47) and opening the
## pause menu (#58 forbids it at a berth) are two different things, so two flags.
var _focus_freeze: bool = false
var _console_open: bool = false
var _jump_busy: bool = false
## True only while a career is genuinely playable. Boot, load and teardown all
## clear it, which is what stops an autosave writing a half-built session and
## stops a save taken at zero hull opening the loss screen on top of its own load.
var _session_live: bool = false
## True from the moment the hull reaches zero until the run restarts (Job 10).
var _dead: bool = false

@onready var _debug_console: CanvasLayer = $DebugConsole


func _ready() -> void:
	# REPAIR-5: Main stays live while the tree is paused so input, focus
	# notifications, and session menus still run. Sim children are demoted to
	# PAUSABLE so they do not inherit ALWAYS.
	process_mode = Node.PROCESS_MODE_ALWAYS
	print(BOOT_BANNER)
	FlightInput.ensure_actions()
	# REPAIR-24: release exports never create or start the debug console.
	# Editor / debug builds keep today's behaviour. No config unlock.
	if ConsoleService.is_enabled_for_build(build_is_debug):
		_console = ConsoleService.new()
		# Children declared in Main.tscn are ready before this runs, so save and
		# time (autoload) commands are listening when the console asks who is out.
		_console.start()
	_mark_scene_sim_pausable()
	_wire_session_bus()
	_create_session_ui()
	_show_main_menu()


func _notification(what: int) -> void:
	# REPAIR-5: engine focus constants — tests must drive these via
	# notification(...), not by calling the handlers directly.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_on_application_focus_out()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_on_application_focus_in()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(FlightInput.ACTION_SECTOR_MAP):
		_try_toggle_sector_map()
		return
	if not event.is_action_pressed(FlightInput.ACTION_PAUSE):
		return
	# The loss screen is the only thing on offer once the run has ended: its two
	# buttons are the way out, so pause may not be opened over the top of it.
	if not _in_play or _console_open or _jump_busy or _opening_in_progress or _dead:
		return
	if _try_close_play_overlay():
		get_viewport().set_input_as_handled()
		return
	# #58's refusal lives inside _set_pause, not here — a second copy is exactly
	# what regressed the finding once already.
	if _set_pause(not _pause_open):
		get_viewport().set_input_as_handled()


## Sector map hotkey. No-op behind pause/Options (#57) or when not in flight.
func _try_toggle_sector_map() -> void:
	if not _in_play or _console_open or _jump_busy or _opening_in_progress or _dead:
		return
	if _flight_overlay_blocks_actions():
		return
	if _sector_map != null and _sector_map.visible:
		EventBus.on_sector_map_close_requested.emit()
	else:
		EventBus.on_sector_map_open_requested.emit()
	get_viewport().set_input_as_handled()


## Close map / captain sheet / journal / options if open. True when an overlay was closed.
func _try_close_play_overlay() -> bool:
	if _options_menu != null and _options_menu.visible:
		EventBus.on_options_close_requested.emit()
		return true
	if _sector_map != null and _sector_map.visible:
		EventBus.on_sector_map_close_requested.emit()
		return true
	if _captain_sheet != null and _captain_sheet.visible:
		EventBus.on_captain_sheet_close_requested.emit()
		return true
	if _campaign_journal != null and _campaign_journal.visible:
		EventBus.on_campaign_journal_close_requested.emit()
		return true
	return false


## Connected in Main.tscn to the console view's line_submitted.
func _on_debug_console_line_submitted(line: String) -> void:
	if _console == null:
		return
	_console.submit(line)


func _wire_session_bus() -> void:
	EventBus.on_new_game_requested.connect(_on_new_game_requested)
	EventBus.on_continue_requested.connect(_on_continue_requested)
	EventBus.on_quit_to_desktop_requested.connect(_on_quit_to_desktop_requested)
	EventBus.on_quit_to_menu_requested.connect(_on_quit_to_menu_requested)
	EventBus.on_life_path_confirmed.connect(_on_life_path_confirmed)
	EventBus.on_life_path_cancel_requested.connect(_on_life_path_cancel_requested)
	EventBus.on_annexation_continue_requested.connect(_on_annexation_continue_requested)
	EventBus.on_manual_save_requested.connect(_on_manual_save_requested)
	EventBus.on_manual_load_requested.connect(_on_manual_load_requested)
	EventBus.on_player_crippled.connect(_on_player_crippled_session)
	EventBus.on_run_restart_requested.connect(_on_run_restart_requested)
	EventBus.on_console_visibility_changed.connect(_on_console_visibility_changed)
	EventBus.on_pause_changed.connect(_on_pause_changed_bus)


func _create_session_ui() -> void:
	_main_menu = MainMenu.new()
	_main_menu.name = "MainMenu"
	add_child(_main_menu)
	_mark_session_overlay_always(_main_menu)

	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	_mark_session_overlay_always(_pause_menu)

	_options_menu = OptionsMenu.new()
	_options_menu.name = "OptionsMenu"
	add_child(_options_menu)
	_mark_session_overlay_always(_options_menu)

	_captain_sheet = CaptainSheet.new()
	_captain_sheet.name = "CaptainSheet"
	add_child(_captain_sheet)
	_mark_session_overlay_always(_captain_sheet)

	_campaign_journal = CampaignJournal.new()
	_campaign_journal.name = "CampaignJournal"
	add_child(_campaign_journal)
	_mark_session_overlay_always(_campaign_journal)

	_sector_map = SectorMapPanel.new()
	_sector_map.name = "SectorMapPanel"
	add_child(_sector_map)
	_mark_session_overlay_always(_sector_map)

	_new_game_tip = NewGameTip.new()
	_new_game_tip.name = "NewGameTip"
	add_child(_new_game_tip)
	_mark_session_overlay_always(_new_game_tip)

	_life_path_create = LifePathCreate.new()
	_life_path_create.name = "LifePathCreate"
	add_child(_life_path_create)
	_mark_session_overlay_always(_life_path_create)

	_opening_annexation = OpeningAnnexation.new()
	_opening_annexation.name = "OpeningAnnexation"
	add_child(_opening_annexation)
	_mark_session_overlay_always(_opening_annexation)

	_loss_screen = LossScreen.new()
	_loss_screen.name = "LossScreen"
	add_child(_loss_screen)
	_mark_session_overlay_always(_loss_screen)

	_raise_debug_console()


func _show_main_menu() -> void:
	_set_pause(false)
	if _captain_sheet != null:
		_captain_sheet.visible = false
	if _main_menu != null:
		_main_menu.visible = true
		_main_menu.refresh_continue(not SaveService.most_recent_path().is_empty())
		_main_menu.show_feedback("")
	SteamService.set_presence(BalanceSettings.STEAM_PRESENCE_MENU)
	_raise_debug_console()


func _hide_main_menu() -> void:
	if _main_menu != null:
		_main_menu.visible = false


func _on_console_visibility_changed(open: bool) -> void:
	_console_open = open


func _on_pause_changed_bus(open: bool) -> void:
	# PauseMenu Resume emits this; keep Main flag + SceneTree pause in sync. The
	# bus is the third way into `_pause_open`, so it asks what `_set_pause` asks —
	# no route to a paused docked session skips #58. It does NOT cover PauseMenu's
	# own `visible` (set off this signal, connected after Main): filed proposal,
	# and no live path, since nothing emits true from outside Main today.
	if open and not _may_open_pause_menu():
		return
	_pause_open = open
	if not open:
		_pause_from_focus_loss = false
	_apply_tree_paused()
	if not open and _captain_sheet != null:
		_captain_sheet.visible = false


## The one door the pause menu opens and closes by. Returns true when the state
## actually changed, so a caller can tell a refusal from a no-op. #58 is enforced
## HERE and nowhere else, and that placement is the fix, not an implementation
## detail — docs/traps.md #29 is what happened when it lived at each caller.
func _set_pause(open: bool) -> bool:
	if _pause_open == open:
		return false
	if open and not _may_open_pause_menu():
		return false
	_pause_open = open
	if not open:
		_pause_from_focus_loss = false
	_apply_tree_paused()
	EventBus.on_pause_changed.emit(open)
	if not open and _captain_sheet != null:
		_captain_sheet.visible = false
	if not open and _sector_map != null and _sector_map.visible:
		# Keep map open when resuming from pause if it was opened there — OK.
		pass
	return true


## #58: the menu carries Load and loading out of a berth is the broken path, so
## it may not open while docked — by any route, present or future.
func _may_open_pause_menu() -> bool:
	return not _is_session_docked()


## REPAIR-5: SceneTree pause is the real freeze, not the UI flag. The player's
## pause or a lost window freezes it; both must clear before the sim runs again.
func _apply_tree_paused() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.paused = _pause_open or _focus_freeze


## Focus lost while playing. Two separate things, which is what lets #47 and #58
## both hold: the sim always freezes; the menu opens only if `_set_pause` allows.
func _on_application_focus_out() -> void:
	if not _in_play or _console_open or _jump_busy or _opening_in_progress or _dead:
		return
	_focus_freeze = true
	_apply_tree_paused()
	if _pause_open:
		# Already paused (Escape, menu) — do not claim ownership for focus-in.
		return
	if _set_pause(true):
		_pause_from_focus_loss = true


## Focus regained. The freeze belongs to the window, so it always lifts; the menu
## closes only if focus-loss opened it, and never under another session overlay.
func _on_application_focus_in() -> void:
	_focus_freeze = false
	if _pause_from_focus_loss and not _session_overlay_blocks_focus_resume():
		_pause_from_focus_loss = false
		_set_pause(false)
	_apply_tree_paused()


## Options / map / sheet / journal still up → leave the sim paused.
func _session_overlay_blocks_focus_resume() -> bool:
	if _options_menu != null and _options_menu.visible:
		return true
	if _sector_map != null and _sector_map.visible:
		return true
	if _captain_sheet != null and _captain_sheet.visible:
		return true
	if _campaign_journal != null and _campaign_journal.visible:
		return true
	return false


## Pause or Options blocks flight hotkeys (sector map).
func _flight_overlay_blocks_actions() -> bool:
	if _pause_open:
		return true
	if _options_menu != null and _options_menu.visible:
		return true
	return false


## True while the player is in a berth (controller docked state).
func _is_session_docked() -> bool:
	if _docking == null:
		return false
	return _docking.controller().is_docked()


## Session menus must keep processing while the tree is paused.
func _mark_session_overlay_always(node: Node) -> void:
	if node == null:
		return
	node.process_mode = Node.PROCESS_MODE_ALWAYS


## Sim services / world under Main: demote from ALWAYS inherit to PAUSABLE so
## get_tree().paused actually freezes hostiles, fuel, hull, and upkeep.
func _mark_sim_pausable(node: Node) -> void:
	if node == null:
		return
	node.process_mode = Node.PROCESS_MODE_PAUSABLE


## Scene-declared services in Main.tscn (not DebugConsole — that stays ALWAYS).
func _mark_scene_sim_pausable() -> void:
	_mark_sim_pausable(get_node_or_null("SaveConsoleCommands"))
	_mark_sim_pausable(get_node_or_null("AttributionService"))
	_mark_sim_pausable(get_node_or_null("MissionService"))
	_mark_sim_pausable(get_node_or_null("RecoveryService"))


## Arm or disarm everything that must only run against a real, finished session.
##
## Two things hang off this and both were bugs waiting to happen. `on_system_entered`
## fires part-way through `_boot_play_session()` (no ship yet) and again while a
## load is applied, so an armed autosave would file a session that does not exist
## or overwrite the file being read. And a save written at zero hull re-emits
## `on_player_crippled` when its wallet section is applied, which would open the
## loss screen on top of its own load.
func _set_session_live(live: bool) -> void:
	_session_live = live
	if _autosave != null:
		_autosave.set_armed(live)
	if _loss_screen != null:
		_loss_screen.set_armed(live)
	# Either direction ends the dead state: a session is being built or torn
	# down, so whatever the last run ended as is no longer on screen.
	_dead = false


## Hull reached zero. The run is over; the loss screen has already put itself on
## screen off the same signal. Nothing here decides the ship is finished —
## `HullConditionService` did, and `can_fly()` remains the only word on it.
func _on_player_crippled_session() -> void:
	if not _session_live or _dead:
		return
	_dead = true
	# Never autosave a destroyed ship: the restart point must stay the last
	# place the player was actually alive.
	if _autosave != null:
		_autosave.set_armed(false)


## Loss screen: start again from the most recent save. That is a full session
## rebuild, not an in-place patch — the run ended, so the ship, the world and
## every service are built fresh from the file.
func _on_run_restart_requested() -> void:
	if not _dead:
		return
	if _loss_screen != null:
		_loss_screen.hide_loss()
	if SaveService.most_recent_path().is_empty():
		# Nothing to restart from (a career whose autosave could not be written).
		# The menu is still a way out; a frozen wreck is not.
		await _return_to_menu()
		return
	await _continue_career()


func _on_new_game_requested() -> void:
	await _start_new_game()


func _start_new_game() -> void:
	# E4.2–E4.3 order (locked): create → annexation → fly tip → station dock.
	# Boot services first so Confirm can apply teeth + wallet debt; do not dock
	# or set _in_play until annexation continues. Cancel tears everything down.
	_reset_career_services()
	await _tear_down_play_session()
	_boot_play_session()
	_set_session_live(false)
	_freeze_ship_for_opening()
	_opening_in_progress = true
	_in_play = false
	_hide_main_menu()
	_set_pause(false)
	if _new_game_tip != null:
		_new_game_tip.hide_tip()
	if _opening_annexation != null:
		_opening_annexation.hide_annexation()
	if _life_path_create != null:
		_life_path_create.show_create()


func _on_life_path_confirmed(
	origin_id: StringName, trade_id: StringName, mark_id: StringName
) -> void:
	if not _opening_in_progress:
		return
	if _wallet == null:
		return
	# StandingService is the only writer (via CareerStart). No world-control mutate.
	CareerStart.apply(origin_id, trade_id, mark_id, _wallet)
	# Status moment for system + starter station after path (E4.3 / D6).
	if _world != null:
		StandingService.emit_status_for_system(_world.system_id)
		var station_id: StringName = _primary_station_id()
		if not String(station_id).is_empty():
			StandingService.emit_status_for_station(station_id)
	if _life_path_create != null:
		_life_path_create.hide_create()
	var baggage: String = BalanceSession.ANNEXATION_BAGGAGE_UNCONTROLLED
	if _world != null:
		var status: Dictionary = StandingService.status_for_system(_world.system_id)
		baggage = OpeningAnnexation.baggage_from_status(status)
	if _opening_annexation != null:
		_opening_annexation.show_annexation(baggage)


func _on_life_path_cancel_requested() -> void:
	if not _opening_in_progress:
		return
	_opening_in_progress = false
	if _life_path_create != null:
		_life_path_create.hide_create()
	if _opening_annexation != null:
		_opening_annexation.hide_annexation()
	CareerStart.reset()
	# Tear down so no partial career (standing reset + no live world) remains.
	await _return_to_menu()


func _on_annexation_continue_requested() -> void:
	if not _opening_in_progress:
		return
	_opening_in_progress = false
	if _opening_annexation != null:
		_opening_annexation.hide_annexation()
	CareerStart.mark_opening_complete()
	# Arm before the storyboard dock, not after: that dock is the first
	# `on_docked` of the career, so it is what gives a brand-new captain who has
	# never touched Save something to come back to. The session is fully built by
	# now — world, ship, services, life path — so the save is complete.
	_set_session_live(true)
	# Storyboard entry: always wake up docked at the starter station.
	_enter_career_docked()
	_in_play = true
	SteamService.set_presence(BalanceSettings.STEAM_PRESENCE_DOCKED)
	_set_pause(false)
	if _new_game_tip != null:
		_new_game_tip.show_tip()


## Hold the ship still while create / annexation block the viewport.
func _freeze_ship_for_opening() -> void:
	if _ship != null:
		_ship.set_flight_enabled(false)
		_ship.velocity = Vector3.ZERO


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
	_set_session_live(false)
	CareerSave.apply_meta_sections(get_tree(), sections, path)
	await _apply_world_section(sections)
	_set_session_live(true)
	# D11: Continue/load skips create + annexation entirely.
	_opening_in_progress = false
	if _life_path_create != null:
		_life_path_create.hide_create()
	if _opening_annexation != null:
		_opening_annexation.hide_annexation()
	_in_play = true
	# A save taken in a berth now restores into that berth, so the presence line
	# has to ask rather than assume the player came back flying.
	var back_in_flight: bool = _docking == null or String(_docking.docked_station_id()).is_empty()
	if back_in_flight:
		SteamService.set_presence(BalanceSettings.STEAM_PRESENCE_FLIGHT)
	else:
		SteamService.set_presence(BalanceSettings.STEAM_PRESENCE_DOCKED)
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
	_opening_in_progress = false
	_set_session_live(false)
	if _captain_sheet != null:
		_captain_sheet.visible = false
	if _new_game_tip != null:
		_new_game_tip.hide_tip()
	if _life_path_create != null:
		_life_path_create.hide_create()
	if _opening_annexation != null:
		_opening_annexation.hide_annexation()
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
	_set_session_live(false)
	CareerSave.apply_meta_sections(get_tree(), sections, path)
	await _apply_world_section(sections)
	_set_session_live(true)
	# D11: load never re-shows create / annexation.
	_opening_in_progress = false
	if _life_path_create != null:
		_life_path_create.hide_create()
	if _opening_annexation != null:
		_opening_annexation.hide_annexation()
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
	# S1: registered services (WorldClock, StandingService, Mission, Recovery, …).
	ServiceRegistry.reset_all()
	CareerStart.reset()
	# Recovery progress wipe is more than reset() on some paths — keep explicit.
	var recovery: Node = get_node_or_null("RecoveryService")
	if recovery != null and recovery.has_method(&"apply_progress_section"):
		recovery.call(&"apply_progress_section", {})


func _boot_play_session() -> void:
	# UI must exist before SystemWorld.build() emits on_system_entered.
	# Wallet/fuel/hull after HUD so seed emissions for credits/fuel/condition hit the HUD.
	# REPAIR-5: every sim node under ALWAYS Main must be PAUSABLE or hostiles /
	# fuel / hull keep running while the tree is paused.
	_hud = FlightHUD.new()
	_hud.name = "FlightHUD"
	add_child(_hud)
	_mark_sim_pausable(_hud)

	_wallet = WalletService.new()
	_wallet.name = "WalletService"
	add_child(_wallet)
	_mark_sim_pausable(_wallet)

	_fuel = FuelService.new()
	_fuel.name = "FuelService"
	add_child(_fuel)
	_mark_sim_pausable(_fuel)

	_hull = HullConditionService.new()
	_hull.name = "HullConditionService"
	add_child(_hull)
	_mark_sim_pausable(_hull)

	_money_log = MoneyLog.new()
	_money_log.name = "MoneyLog"
	add_child(_money_log)
	_mark_sim_pausable(_money_log)

	_cargo = CargoService.new()
	_cargo.name = "CargoService"
	add_child(_cargo)
	_mark_sim_pausable(_cargo)

	_ship_service = ShipService.new()
	_ship_service.name = "ShipService"
	add_child(_ship_service)
	_mark_sim_pausable(_ship_service)
	_ship_service.reset()

	# S6: ops after wallet/cargo/ship (hire spends, warehouse uses hold).
	_operation = OperationService.new()
	_operation.name = "OperationService"
	add_child(_operation)
	_mark_sim_pausable(_operation)
	_operation.reset()

	# S7: campaign after ops; spine uses MissionService (created in scene / later).
	_campaign = CampaignService.new()
	_campaign.name = "CampaignService"
	add_child(_campaign)
	_mark_sim_pausable(_campaign)
	_campaign.reset()

	_station_menu = StationMenu.new()
	_station_menu.name = "StationMenu"
	add_child(_station_menu)
	_mark_sim_pausable(_station_menu)

	_world = SystemWorld.new()
	_world.name = "SystemWorld"
	_world.add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)
	_world.system_id = BalanceFlight.PLAYABLE_SYSTEM_ID
	add_child(_world)
	_mark_sim_pausable(_world)
	_world.build()

	_ship = PlayerShip.new()
	_ship.name = "PlayerShip"
	_ship.hull_id = _ship_service.active_hull_id()
	_ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	_world.add_child(_ship)
	_mark_sim_pausable(_ship)
	_ship.global_position = _world.player_spawn_position()

	_camera = ChaseCamera.new()
	_camera.name = "ChaseCamera"
	_world.add_child(_camera)
	_mark_sim_pausable(_camera)
	_camera.set_target(_ship)
	_ship.set_aim_camera(_camera)

	_docking = DockingService.new()
	_docking.name = "DockingService"
	add_child(_docking)
	_mark_sim_pausable(_docking)
	_docking.setup(_ship, _world.station_positions())

	_gate_travel = GateTravelService.new()
	_gate_travel.name = "GateTravelService"
	add_child(_gate_travel)
	_mark_sim_pausable(_gate_travel)
	_gate_travel.setup(_ship, _world.gate_positions(), _docking)

	# Job 10: the way out of a dry tank, and the thing that gives every other
	# way out something to fall back on. Both start disarmed — see
	# `_set_session_live` for why arming is explicit.
	_rescue = RescueService.new()
	_rescue.name = "RescueService"
	add_child(_rescue)
	_mark_sim_pausable(_rescue)
	_rescue.setup(_ship, _docking, _world.station_positions())

	_autosave = AutosaveService.new()
	_autosave.name = "AutosaveService"
	add_child(_autosave)
	_mark_sim_pausable(_autosave)

	if not EventBus.on_jump_requested.is_connected(_on_jump_requested):
		EventBus.on_jump_requested.connect(_on_jump_requested)

	_raise_debug_console()


func _tear_down_play_session() -> void:
	_set_session_live(false)
	if EventBus.on_jump_requested.is_connected(_on_jump_requested):
		EventBus.on_jump_requested.disconnect(_on_jump_requested)

	if _autosave != null:
		_autosave.queue_free()
		_autosave = null
	if _rescue != null:
		_rescue.queue_free()
		_rescue = null
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
	if _ship_service != null:
		_ship_service.queue_free()
		_ship_service = null
	if _operation != null:
		_operation.queue_free()
		_operation = null
	if _campaign != null:
		_campaign.queue_free()
		_campaign = null
	if _wallet != null:
		_wallet.queue_free()
		_wallet = null
	if _fuel != null:
		_fuel.queue_free()
		_fuel = null
	if _hull != null:
		_hull.queue_free()
		_hull = null
	if _money_log != null:
		_money_log.queue_free()
		_money_log = null
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
		# REPAIR-3: on_system_exited emit removed (zero listeners). Declaration kept.
		_world.clear_world()
		await get_tree().process_frame
		_world.system_id = system_id
		_world.build()
		if _docking != null:
			_docking.setup(_ship, _world.station_positions())
		if _gate_travel != null:
			_gate_travel.setup(_ship, _world.gate_positions(), _docking)
		if _rescue != null:
			_rescue.setup(_ship, _docking, _world.station_positions())

	# The berth the save was written in, asked before anything is moved. It
	# either takes the ship — parking it at the anchor, hiding it, cutting
	# flight and announcing `on_docked`, exactly the way a new career wakes up
	# docked — or it refuses, and the ship goes back into free flight at the
	# coordinates the save recorded.
	#
	# Asking first is the point of this order. Placing the ship and asking
	# afterwards left a refusal (a station this build no longer has, or one
	# standing now turns away) with the player still docked at whatever berth
	# the live session happened to be sitting in — a berth the save never named.
	var saved_dock_id: StringName = CareerSave.docked_station_from_world(world_data)
	if not String(saved_dock_id).is_empty() and _restore_docked(saved_dock_id):
		_raise_debug_console()
		return

	# Free flight from here. Leaving the berth has to happen before the ship is
	# placed, or the undock would fling it back to the station anchor.
	_undock_if_docked()

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
		_ship.apply_load_flight_from_can_fly(_hull != null and _hull.can_fly())
		_ship.visible = true
	_raise_debug_console()


## Put the ship back in the berth the save was written in, and say whether the
## berth took it. Same call a new career uses, so a restored berth behaves like
## any other berth and no new rule about what a docked player may do is invented
## here: it parks the ship at the anchor, hides it, cuts flight and announces
## `on_docked`, which is what opens the station menu and re-shows the status.
##
## False means the berth refused — a station the world no longer has, or one
## standing now turns away. The caller then restores free flight instead, which
## is what keeps a refusal from leaving the player docked somewhere the save
## never named.
func _restore_docked(station_id: StringName) -> bool:
	if _docking == null:
		return false
	return _docking.begin_session_docked(station_id)


## Loading a free-flying save while docked has to leave the berth first.
func _undock_if_docked() -> void:
	if _docking == null:
		return
	var current: StringName = _docking.docked_station_id()
	if String(current).is_empty():
		return
	EventBus.on_undock_requested.emit(current)


func _on_jump_requested(destination_system_id: StringName) -> void:
	if _jump_busy:
		return
	if not _jump_allowed(destination_system_id):
		return
	if _fuel == null or not _fuel.try_spend_jump_fuel():
		return

	# S1: compressed transit time on the world clock (same accumulators as live).
	WorldClock.advance_hours(BalanceWorldClock.JUMP_AWAY_HOURS)

	_jump_busy = true
	var from_id: StringName = _world.system_id
	# REPAIR-3: on_system_exited emit removed (zero listeners). Destination uses entered.

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
	if _rescue != null:
		_rescue.setup(_ship, _docking, _world.station_positions())

	_raise_debug_console()
	_jump_busy = false


func _jump_allowed(destination_system_id: StringName) -> bool:
	if _fuel == null or _world == null or _ship == null:
		return false
	if _docking != null and _docking.controller().is_docked():
		return false
	if String(destination_system_id).is_empty():
		return false
	if destination_system_id == _world.system_id:
		return false
	if not ContentLibrary.has_item(destination_system_id):
		return false
	return _fuel.can_jump()


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
