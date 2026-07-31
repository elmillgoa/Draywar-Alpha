extends Node

## Boot entry and composition root for Draywar Alpha — A0.
##
## Owns ConsoleService, wires DebugConsole, holds SaveConsoleCommands as a child.
## Autoloads (EventBus, ContentLibrary, TimeScale) live outside this scene.

const BOOT_BANNER: String = "Draywar Alpha — boot OK"

## The debug console's parser and roster. Not a global.
var _console: ConsoleService = null

@onready var _debug_console: CanvasLayer = $DebugConsole


func _ready() -> void:
	print(BOOT_BANNER)
	_console = ConsoleService.new()
	# Children declared in Main.tscn are ready before this runs, so save and
	# time (autoload) commands are listening when the console asks who is out.
	_console.start()


## Connected in Main.tscn to the console view's line_submitted.
func _on_debug_console_line_submitted(line: String) -> void:
	_console.submit(line)
