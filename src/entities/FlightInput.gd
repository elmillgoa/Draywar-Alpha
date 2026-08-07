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
## Pause menu (Escape). Same id as BalanceSession.ACTION_PAUSE.
const ACTION_PAUSE: StringName = &"pause_menu"
## Combat fire (Space). Name matches BalanceCombat.ACTION_FIRE.
const ACTION_FIRE: StringName = &"fire_weapon"
## Target lock cycle (Tab). Name matches BalanceCombat.ACTION_TARGET_LOCK.
const ACTION_TARGET_LOCK: StringName = &"target_lock"
## Sector chart (M) — E5.5.
const ACTION_SECTOR_MAP: StringName = &"sector_map"
## Incident primary choice (1) — S4. Same id as BalanceEnforcement.ACTION_INCIDENT_A.
const ACTION_INCIDENT_A: StringName = BalanceEnforcement.ACTION_INCIDENT_A
## Incident secondary choice (2) — S4.
const ACTION_INCIDENT_B: StringName = BalanceEnforcement.ACTION_INCIDENT_B
## Emergency tow when the tank is dry (T) — Job 10 / PT-11.
const ACTION_TOW: StringName = &"call_tow"


## Ensures every flight action exists with its default key. Idempotent.
static func ensure_actions() -> void:
	_bind(ACTION_THROTTLE_UP, KEY_W)
	_bind(ACTION_THROTTLE_DOWN, KEY_S)
	_bind(ACTION_STRAFE_LEFT, KEY_A)
	_bind(ACTION_STRAFE_RIGHT, KEY_D)
	_bind(ACTION_AFTERBURNER, KEY_SHIFT)
	_bind(ACTION_DOCK, KEY_F)
	_bind(ACTION_PAUSE, KEY_ESCAPE)
	_bind(ACTION_FIRE, BalanceCombat.FIRE_KEY)
	_bind_mouse(ACTION_FIRE, BalanceCombat.FIRE_MOUSE_BUTTON)
	_bind(ACTION_TARGET_LOCK, BalanceCombat.TARGET_LOCK_KEY)
	_bind(ACTION_SECTOR_MAP, KEY_M)
	_bind(ACTION_INCIDENT_A, KEY_1)
	_bind(ACTION_INCIDENT_B, KEY_2)
	_bind(ACTION_TOW, KEY_T)


static func _bind(action: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	## REPAIR-6: if the action already has any keyboard event (player rebind from
	## SettingsService), do not stack the default key back on top of it.
	var has_keyboard: bool = false
	for existing: InputEvent in InputMap.action_get_events(action):
		var existing_key: InputEventKey = existing as InputEventKey
		if existing_key == null:
			continue
		has_keyboard = true
		if existing_key.physical_keycode == physical_key:
			return
	if has_keyboard:
		return
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = physical_key
	InputMap.action_add_event(action, key)


static func _bind_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing: InputEvent in InputMap.action_get_events(action):
		var existing_mouse: InputEventMouseButton = existing as InputEventMouseButton
		if existing_mouse != null and existing_mouse.button_index == button:
			return
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = button
	InputMap.action_add_event(action, mouse)


## Replace keyboard events for an action (keeps mouse bindings). S10 rebinds.
static func rebind_key(action: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var keep_mouse: Array[InputEvent] = []
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventMouseButton:
			keep_mouse.append(existing)
	InputMap.action_erase_events(action)
	for mouse_event: InputEvent in keep_mouse:
		InputMap.action_add_event(action, mouse_event)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = physical_key
	InputMap.action_add_event(action, key)
