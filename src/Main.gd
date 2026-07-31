extends Node

## Boot entry and composition root for Draywar Alpha — A3.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1–A3
##
## Owns ConsoleService, wires DebugConsole, holds Save / Attribution / Mission
## services (scene children), and boots the playable system.

const BOOT_BANNER: String = "Draywar Alpha — boot OK"

## The debug console's parser and roster. Not a global.
var _console: ConsoleService = null

var _world: SystemWorld = null
var _ship: PlayerShip = null
var _camera: ChaseCamera = null
var _docking: DockingService = null
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
	_hud = FlightHUD.new()
	_hud.name = "FlightHUD"
	add_child(_hud)

	_station_menu = StationMenu.new()
	_station_menu.name = "StationMenu"
	add_child(_station_menu)

	_world = SystemWorld.new()
	_world.name = "SystemWorld"
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

	# Console stays on top of play UI.
	move_child(_debug_console, get_child_count() - 1)
