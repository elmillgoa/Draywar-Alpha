extends Node

## Boot entry and composition root for Draywar Alpha — A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1–A5
##
## Owns ConsoleService, wires DebugConsole, holds Save / Attribution / Mission /
## Recovery / Wallet services (scene children), boots the playable system, and
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
var _hud: FlightHUD = null
var _station_menu: StationMenu = null

@onready var _debug_console: CanvasLayer = $DebugConsole


func _ready() -> void:
	print(BOOT_BANNER)
	FlightInput.ensure_actions()
	_console = ConsoleService.new()
	# Children declared in Main.tscn are ready before this runs, so save and
	# time (autoload) commands are listening when the console asks who is out.
	_console.start()
	_boot_play_session()


## Connected in Main.tscn to the console view's line_submitted.
func _on_debug_console_line_submitted(line: String) -> void:
	_console.submit(line)


func _boot_play_session() -> void:
	# UI must exist before SystemWorld.build() emits on_system_entered.
	# Wallet after HUD so seed emissions for credits/fuel/condition hit the HUD.
	_hud = FlightHUD.new()
	_hud.name = "FlightHUD"
	add_child(_hud)

	_wallet = WalletService.new()
	_wallet.name = "WalletService"
	add_child(_wallet)

	_station_menu = StationMenu.new()
	_station_menu.name = "StationMenu"
	add_child(_station_menu)

	_world = SystemWorld.new()
	_world.name = "SystemWorld"
	_world.add_to_group(&"system_world")
	_world.system_id = BalanceFlight.PLAYABLE_SYSTEM_ID
	add_child(_world)
	_world.build()

	_ship = PlayerShip.new()
	_ship.name = "PlayerShip"
	_ship.hull_id = BalanceFlight.PLAYER_HULL_ID
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

	# Console stays on top of play UI.
	move_child(_debug_console, get_child_count() - 1)


func _on_jump_requested(destination_system_id: StringName) -> void:
	if not _jump_allowed(destination_system_id):
		return
	if not _wallet.try_spend_jump_fuel():
		return

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

	move_child(_debug_console, get_child_count() - 1)


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
