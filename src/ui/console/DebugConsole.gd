extends CanvasLayer

## The debug console on screen — Alpha A0.
##
## Backtick toggles. Type a line, press return, read what comes back.
## Computes nothing: emits `line_submitted`, prints `EventBus.on_console_output`.
## Main wires the view to the service.
##
## REPAIR-24: release exports never arm the toggle or process input. Dev/editor
## behaviour is unchanged. No config flag re-enables this in release.
## `build_is_debug` is injectable so tests can exercise the real `_ready` path
## without a release export; production leaves the default
## (`OS.is_debug_build()`).

## A line the player typed and submitted, exactly as typed.
signal line_submitted(line: String)

## The key above Tab. Registered in code so it survives editor rewrites of
## project.godot.
const TOGGLE_ACTION: StringName = &"debug_console_toggle"

## What an echoed line is prefixed with.
const PROMPT: String = "> "

## Build gate. Default is the real engine flag; tests set false before add_child.
var build_is_debug: bool = OS.is_debug_build()

@onready var _output: RichTextLabel = $Frame/Layout/Output
@onready var _entry: LineEdit = $Frame/Layout/Entry


func _ready() -> void:
	if not is_enabled_for_build(build_is_debug):
		visible = false
		set_process_input(false)
		return
	try_register_toggle_action(build_is_debug)
	visible = false
	EventBus.on_console_output.connect(_on_output)
	_entry.text_submitted.connect(_on_entry_submitted)


func _input(event: InputEvent) -> void:
	if not is_enabled_for_build(build_is_debug):
		return
	if not event.is_action_pressed(TOGGLE_ACTION):
		return
	set_open(not visible)
	get_viewport().set_input_as_handled()


## Shows or hides the console, and moves the caret with it.
func set_open(open: bool) -> void:
	if open and not is_enabled_for_build(build_is_debug):
		return
	var changed: bool = open != visible
	visible = open
	if open:
		_entry.grab_focus()
	else:
		_entry.release_focus()
	if changed:
		EventBus.on_console_visibility_changed.emit(open)


## Pure build gate. True only when `is_debug_build` is true (editor / dev).
## Release must never arm the console view. No config unlock.
static func is_enabled_for_build(is_debug_build: bool) -> bool:
	return is_debug_build


## Registers the backtick binding only when the build is allowed.
## Returns true when the toggle action is present after the call.
static func try_register_toggle_action(is_debug_build: bool) -> bool:
	if not is_enabled_for_build(is_debug_build):
		return false
	_register_toggle_action()
	return InputMap.has_action(TOGGLE_ACTION)


## Registers the backtick binding if nothing has yet. Idempotent.
static func _register_toggle_action() -> void:
	if InputMap.has_action(TOGGLE_ACTION):
		return
	InputMap.add_action(TOGGLE_ACTION)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_QUOTELEFT
	InputMap.action_add_event(TOGGLE_ACTION, key)


func _on_entry_submitted(text: String) -> void:
	_entry.clear()
	_output.add_text(PROMPT + text + "\n")
	line_submitted.emit(text)


func _on_output(line: String) -> void:
	_output.add_text(line + "\n")
