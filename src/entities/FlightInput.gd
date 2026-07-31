class_name FlightInput
extends RefCounted

## Flight input action names and default key bindings — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Registers actions once at play boot so flight works even if project.godot
## input map is rewritten by the editor. Mirrors the [input] section.

const ACTION_THROTTLE_UP: StringName = &"throttle_up"
const ACTION_THROTTLE_DOWN: StringName = &"throttle_down"
const ACTION_STRAFE_LEFT: StringName = &"strafe_left"
const ACTION_STRAFE_RIGHT: StringName = &"strafe_right"
const ACTION_AFTERBURNER: StringName = &"afterburner"
const ACTION_DOCK: StringName = &"dock"


## Ensures every flight action exists with its default key. Idempotent.
static func ensure_actions() -> void:
	_bind(ACTION_THROTTLE_UP, KEY_W)
	_bind(ACTION_THROTTLE_DOWN, KEY_S)
	_bind(ACTION_STRAFE_LEFT, KEY_A)
	_bind(ACTION_STRAFE_RIGHT, KEY_D)
	_bind(ACTION_AFTERBURNER, KEY_SHIFT)
	_bind(ACTION_DOCK, KEY_F)


static func _bind(action: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing: InputEvent in InputMap.action_get_events(action):
		var existing_key: InputEventKey = existing as InputEventKey
		if existing_key != null and existing_key.physical_keycode == physical_key:
			return
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = physical_key
	InputMap.action_add_event(action, key)
