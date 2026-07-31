extends CanvasLayer

## The debug console on screen — Alpha A0.
##
## Backtick toggles. Type a line, press return, read what comes back.
## Computes nothing: emits `line_submitted`, prints `EventBus.on_console_output`.
## Main wires the view to the service.

## A line the player typed and submitted, exactly as typed.
signal line_submitted(line: String)

## The key above Tab. Registered in code so it survives editor rewrites of
## project.godot.
const TOGGLE_ACTION: StringName = &"debug_console_toggle"

## What an echoed line is prefixed with.
const PROMPT: String = "> "

@onready var _output: RichTextLabel = $Frame/Layout/Output
@onready var _entry: LineEdit = $Frame/Layout/Entry


func _ready() -> void:
	_register_toggle_action()
	visible = false
	EventBus.on_console_output.connect(_on_output)
	_entry.text_submitted.connect(_on_entry_submitted)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(TOGGLE_ACTION):
		return
	set_open(not visible)
	get_viewport().set_input_as_handled()


## Shows or hides the console, and moves the caret with it.
func set_open(open: bool) -> void:
	var changed: bool = open != visible
	visible = open
	if open:
		_entry.grab_focus()
	else:
		_entry.release_focus()
	if changed:
		EventBus.on_console_visibility_changed.emit(open)


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
