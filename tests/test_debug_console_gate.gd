extends GutTest

## REPAIR-24: debug console is debug/editor only — never armed in a release build.
##
## Audit finding #44: ConsoleService + backtick shipped in export builds and
## could rewrite standing, kill ships, and change time scale. Gate is
## OS.is_debug_build() only — no config flag, no cheat unlock.
##
## These tests drive the REAL `_ready` paths (Main.tscn / DebugConsole.tscn)
## with an injectable `build_is_debug` member. They must go red when only the
## production gate lines are removed — not when the whole commit is reverted.
##
## Editor check (not automated here): open the project in the editor, press
## backtick — console still opens. Export templates were absent at the audit
## and remain absent here; when present, an exported release build must leave
## backtick inert.

const MainScene: PackedScene = preload("res://src/Main.tscn")
const DebugConsoleScene: PackedScene = preload("res://src/ui/console/DebugConsole.tscn")

## No class_name on the view (keeps it out of the static-namespace catalog).
const DebugConsoleScr = preload("res://src/ui/console/DebugConsole.gd")


func after_each() -> void:
	_erase_toggle_if_present()
	# Full Main boots leave session services in a live state.
	ServiceRegistry.reset_all()
	StandingService.reset_to_defaults()
	CareerStart.reset()


func _erase_toggle_if_present() -> void:
	if InputMap.has_action(DebugConsoleScr.TOGGLE_ACTION):
		InputMap.erase_action(DebugConsoleScr.TOGGLE_ACTION)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


# --- Real DebugConsole._ready ------------------------------------------------


## Release path: instantiate the real scene, inject false, enter tree.
## `_ready` must not register backtick and must disable input processing.
func test_debug_console_ready_skips_toggle_on_release() -> void:
	_erase_toggle_if_present()
	var view: CanvasLayer = DebugConsoleScene.instantiate()
	view.set("build_is_debug", false)
	add_child_autofree(view)
	await _frames(1)

	assert_false(
		InputMap.has_action(DebugConsoleScr.TOGGLE_ACTION),
		"release DebugConsole._ready must never register debug_console_toggle"
	)
	assert_false(view.is_processing_input(), "release must not process console input")
	assert_false(view.visible, "release console stays hidden")


## Dev path: inject true, real `_ready` must arm backtick (editor behaviour).
func test_debug_console_ready_registers_toggle_on_debug() -> void:
	_erase_toggle_if_present()
	var view: CanvasLayer = DebugConsoleScene.instantiate()
	view.set("build_is_debug", true)
	add_child_autofree(view)
	await _frames(1)

	assert_true(
		InputMap.has_action(DebugConsoleScr.TOGGLE_ACTION),
		"debug DebugConsole._ready must register debug_console_toggle"
	)
	assert_true(view.is_processing_input(), "debug must process console input")


# --- Real Main._ready --------------------------------------------------------


## Release path: real Main.tscn `_ready` must not create ConsoleService.
func test_main_ready_skips_console_service_on_release() -> void:
	_erase_toggle_if_present()
	var main: Node = MainScene.instantiate()
	main.set("build_is_debug", false)
	var view: Node = main.get_node("DebugConsole")
	view.set("build_is_debug", false)
	add_child_autofree(main)
	await _frames(2)

	var console_ref: Variant = main.get("_console")
	assert_true(console_ref == null, "release Main._ready must not create ConsoleService")
	assert_false(
		InputMap.has_action(DebugConsoleScr.TOGGLE_ACTION),
		"release Main boot must leave backtick unregistered"
	)


## Dev path: real Main.tscn `_ready` still creates and starts ConsoleService.
func test_main_ready_boots_console_service_on_debug() -> void:
	_erase_toggle_if_present()
	var main: Node = MainScene.instantiate()
	main.set("build_is_debug", true)
	var view: Node = main.get_node("DebugConsole")
	view.set("build_is_debug", true)
	add_child_autofree(main)
	await _frames(2)

	var console_ref: Variant = main.get("_console")
	assert_true(console_ref is ConsoleService, "debug Main._ready must create ConsoleService")
	if console_ref is ConsoleService:
		var console: ConsoleService = console_ref
		assert_true(console.knows(ConsoleService.HELP), "started console must own help")
	assert_true(
		InputMap.has_action(DebugConsoleScr.TOGGLE_ACTION), "debug Main boot must register backtick"
	)
