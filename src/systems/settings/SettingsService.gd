extends Node

## Player options single writer — Steam S10.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10
##
## Autoload `SettingsService`. Persists to user://settings.cfg (not career save).
## Applies FOV, sensitivity, volumes, fullscreen, and key rebinds via InputMap
## (does not reach into the entities layer).

## Tests only — empty means BalanceSettings.SETTINGS_PATH.
var settings_path_override: String = ""
## Tests only — empty means sibling `.tmp` of the resolved settings path.
## Point at a missing directory to force a failed temp write (REPAIR-23).
var settings_tmp_path_override: String = ""

var _fov: float = BalanceSettings.DEFAULT_FOV
var _sensitivity: float = BalanceSettings.DEFAULT_SENSITIVITY
var _master_volume: float = BalanceSettings.DEFAULT_MASTER_VOLUME
var _ui_volume: float = BalanceSettings.DEFAULT_UI_VOLUME
var _sfx_volume: float = BalanceSettings.DEFAULT_SFX_VOLUME
var _fullscreen: bool = BalanceSettings.DEFAULT_FULLSCREEN
## action StringName → physical_keycode int (KEY_*).
var _binds: Dictionary = {}


func _ready() -> void:
	_ensure_audio_buses()
	load_from_disk()
	apply_all()


func fov() -> float:
	return _fov


func sensitivity() -> float:
	return _sensitivity


func master_volume() -> float:
	return _master_volume


func ui_volume() -> float:
	return _ui_volume


func sfx_volume() -> float:
	return _sfx_volume


func fullscreen() -> bool:
	return _fullscreen


## Effective ship turn rate = base * sensitivity.
func turn_rate_multiplier() -> float:
	return _sensitivity


func set_fov(value: float) -> void:
	_fov = clampf(value, BalanceSettings.FOV_MIN, BalanceSettings.FOV_MAX)
	_apply_fov()
	_emit_changed()


func set_sensitivity(value: float) -> void:
	_sensitivity = clampf(value, BalanceSettings.SENSITIVITY_MIN, BalanceSettings.SENSITIVITY_MAX)
	_emit_changed()


func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, BalanceSettings.VOLUME_MIN, BalanceSettings.VOLUME_MAX)
	_apply_volumes()
	_emit_changed()


func set_ui_volume(value: float) -> void:
	_ui_volume = clampf(value, BalanceSettings.VOLUME_MIN, BalanceSettings.VOLUME_MAX)
	_apply_volumes()
	_emit_changed()


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, BalanceSettings.VOLUME_MIN, BalanceSettings.VOLUME_MAX)
	_apply_volumes()
	_emit_changed()


func set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	_apply_fullscreen()
	_emit_changed()


## Store a keyboard rebind for a rebindable action.
## Returns empty string on success; a player-facing reject reason otherwise (REPAIR-6).
func set_bind(action: StringName, physical_key: Key) -> String:
	if not _is_rebindable(action):
		return ""
	if _is_reserved_rebind_key(physical_key):
		return BalanceSettings.OPTIONS_REBIND_RESERVED
	var conflict_label: String = _conflict_label_for_key(action, physical_key)
	if not conflict_label.is_empty():
		return BalanceSettings.OPTIONS_REBIND_CONFLICT % conflict_label
	_binds[action] = int(physical_key)
	_apply_binds()
	_emit_changed()
	return ""


func bind_keycode(action: StringName) -> int:
	if _binds.has(action):
		return _as_int(_binds[action])
	return _default_keycode(action)


func bind_label(action: StringName) -> String:
	return OS.get_keycode_string(bind_keycode(action) as Key)


func reset_to_defaults() -> void:
	_fov = BalanceSettings.DEFAULT_FOV
	_sensitivity = BalanceSettings.DEFAULT_SENSITIVITY
	_master_volume = BalanceSettings.DEFAULT_MASTER_VOLUME
	_ui_volume = BalanceSettings.DEFAULT_UI_VOLUME
	_sfx_volume = BalanceSettings.DEFAULT_SFX_VOLUME
	_fullscreen = BalanceSettings.DEFAULT_FULLSCREEN
	_binds.clear()
	apply_all()
	save_to_disk()
	_emit_changed()


func apply_all() -> void:
	_apply_binds()
	_apply_fov()
	_apply_volumes()
	_apply_fullscreen()


func save_to_disk() -> void:
	## Atomic write (REPAIR-23): temp → check OK → optional bak of previous →
	## rename over the live file. Same ConfigFile format as before.
	var path: String = _settings_path()
	var tmp_path: String = _settings_tmp_path()
	var bak_path: String = _settings_bak_path()

	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_FOV, _fov)
	cfg.set_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_SENSITIVITY, _sensitivity)
	cfg.set_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_MASTER_VOLUME, _master_volume)
	cfg.set_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_UI_VOLUME, _ui_volume)
	cfg.set_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_SFX_VOLUME, _sfx_volume)
	cfg.set_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_FULLSCREEN, _fullscreen)
	for action_key: Variant in _binds.keys():
		var action_name: String = _as_string(action_key)
		cfg.set_value(BalanceSettings.CFG_SECTION_BINDS, action_name, _as_int(_binds[action_key]))

	var save_err: Error = cfg.save(tmp_path)
	if save_err != OK:
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		return

	## Move previous good file aside (cheap bak). Abort if we cannot — never
	## delete the original without a successful replace lined up.
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var bak_err: Error = DirAccess.rename_absolute(path, bak_path)
		if bak_err != OK:
			DirAccess.remove_absolute(tmp_path)
			return

	var ren_err: Error = DirAccess.rename_absolute(tmp_path, path)
	if ren_err != OK:
		if FileAccess.file_exists(bak_path) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(bak_path, path)
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)


func load_from_disk() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(_settings_path()) != OK:
		return
	_fov = clampf(
		_as_float(cfg.get_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_FOV, _fov)),
		BalanceSettings.FOV_MIN,
		BalanceSettings.FOV_MAX
	)
	_sensitivity = clampf(
		_as_float(
			cfg.get_value(
				BalanceSettings.CFG_SECTION, BalanceSettings.KEY_SENSITIVITY, _sensitivity
			)
		),
		BalanceSettings.SENSITIVITY_MIN,
		BalanceSettings.SENSITIVITY_MAX
	)
	_master_volume = clampf(
		_as_float(
			cfg.get_value(
				BalanceSettings.CFG_SECTION, BalanceSettings.KEY_MASTER_VOLUME, _master_volume
			)
		),
		BalanceSettings.VOLUME_MIN,
		BalanceSettings.VOLUME_MAX
	)
	_ui_volume = clampf(
		_as_float(
			cfg.get_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_UI_VOLUME, _ui_volume)
		),
		BalanceSettings.VOLUME_MIN,
		BalanceSettings.VOLUME_MAX
	)
	_sfx_volume = clampf(
		_as_float(
			cfg.get_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_SFX_VOLUME, _sfx_volume)
		),
		BalanceSettings.VOLUME_MIN,
		BalanceSettings.VOLUME_MAX
	)
	_fullscreen = _as_bool(
		cfg.get_value(BalanceSettings.CFG_SECTION, BalanceSettings.KEY_FULLSCREEN, _fullscreen)
	)
	_binds.clear()
	if cfg.has_section(BalanceSettings.CFG_SECTION_BINDS):
		for key: String in cfg.get_section_keys(BalanceSettings.CFG_SECTION_BINDS):
			var action: StringName = StringName(key)
			if not _is_rebindable(action):
				continue
			_binds[action] = _as_int(cfg.get_value(BalanceSettings.CFG_SECTION_BINDS, key))


func _settings_path() -> String:
	if not settings_path_override.is_empty():
		return settings_path_override
	return BalanceSettings.SETTINGS_PATH


func _settings_tmp_path() -> String:
	if not settings_tmp_path_override.is_empty():
		return settings_tmp_path_override
	return _settings_path() + ".tmp"


func _settings_bak_path() -> String:
	return _settings_path() + ".bak"


func _emit_changed() -> void:
	EventBus.on_settings_changed.emit()


func _apply_fov() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(BalanceFlight.GROUP_CHASE_CAMERA):
		var cam: Camera3D = node as Camera3D
		if cam != null:
			cam.fov = _fov


func _apply_volumes() -> void:
	_ensure_audio_buses()
	_set_bus_linear(BalanceSettings.BUS_MASTER, _master_volume)
	_set_bus_linear(BalanceSettings.BUS_UI, _ui_volume)
	_set_bus_linear(BalanceSettings.BUS_SFX, _sfx_volume)


## Ensure UI/SFX buses exist. Layout is also declared in project.godot
## (`audio/buses/default_bus_layout`); this creates them if the layout did not
## load (headless tests, missing resource). REPAIR-6.
func _ensure_audio_buses() -> void:
	_ensure_bus_exists(BalanceSettings.BUS_UI)
	_ensure_bus_exists(BalanceSettings.BUS_SFX)


## Create the named bus under Master if missing (REPAIR-6).
func _ensure_bus_exists(bus_name: StringName) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	if bus_name == BalanceSettings.BUS_MASTER:
		return AudioServer.get_bus_index(BalanceSettings.BUS_MASTER)
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, String(bus_name))
	AudioServer.set_bus_send(idx, String(BalanceSettings.BUS_MASTER))
	return idx


func _set_bus_linear(bus_name: StringName, linear: float) -> void:
	var idx: int = _ensure_bus_exists(bus_name)
	if idx < 0:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	if clamped <= BalanceSettings.VOLUME_MUTE_EPSILON:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, BalanceSettings.VOLUME_MUTE_DB)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))


func _apply_fullscreen() -> void:
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_binds() -> void:
	## Always write every rebindable action into InputMap (REPAIR-6). Empty
	## `_binds` (reset / first boot) must restore defaults live — not leave old keys.
	for row: Dictionary in BalanceSettings.REBIND_ROWS:
		var action_raw: Variant = row.get("action", &"")
		var action: StringName = &""
		if typeof(action_raw) == TYPE_STRING_NAME:
			action = action_raw
		elif typeof(action_raw) == TYPE_STRING:
			var action_s: String = action_raw
			action = StringName(action_s)
		if action == &"":
			continue
		var keycode: int = bind_keycode(action)
		if keycode == int(KEY_NONE):
			continue
		_rebind_key(action, keycode as Key)


## Replace keyboard events for an action; keep mouse bindings (no entities import).
func _rebind_key(action: StringName, physical_key: Key) -> void:
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


func _is_rebindable(action: StringName) -> bool:
	for row: Dictionary in BalanceSettings.REBIND_ROWS:
		if row["action"] == action:
			return true
	return false


func _default_keycode(action: StringName) -> int:
	var result: int = int(KEY_NONE)
	match action:
		&"throttle_up":
			result = int(KEY_W)
		&"throttle_down":
			result = int(KEY_S)
		&"strafe_left":
			result = int(KEY_A)
		&"strafe_right":
			result = int(KEY_D)
		&"afterburner":
			result = int(KEY_SHIFT)
		&"dock":
			result = int(KEY_F)
		&"fire_weapon":
			result = int(BalanceCombat.FIRE_KEY)
		&"target_lock":
			result = int(BalanceCombat.TARGET_LOCK_KEY)
		&"sector_map":
			result = int(KEY_M)
		&"incident_a":
			result = int(KEY_1)
		&"incident_b":
			result = int(KEY_2)
		&"call_tow":
			## Must match FlightInput._bind(ACTION_TOW, KEY_T) (IF-12 / REPAIR-6).
			result = int(KEY_T)
		_:
			result = int(KEY_NONE)
	return result


func _is_reserved_rebind_key(physical_key: Key) -> bool:
	for reserved: Key in BalanceSettings.RESERVED_REBIND_KEYS:
		if physical_key == reserved:
			return true
	return false


## Empty when free; otherwise the display label of the conflicting rebind row.
func _conflict_label_for_key(for_action: StringName, physical_key: Key) -> String:
	for row: Dictionary in BalanceSettings.REBIND_ROWS:
		var action_raw: Variant = row.get("action", &"")
		var other: StringName = &""
		if typeof(action_raw) == TYPE_STRING_NAME:
			other = action_raw
		elif typeof(action_raw) == TYPE_STRING:
			var action_s: String = action_raw
			other = StringName(action_s)
		if other == &"" or other == for_action:
			continue
		if bind_keycode(other) == int(physical_key):
			return str(row.get("label", String(other)))
	return ""


func _as_int(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			var as_i: int = value
			return as_i
		TYPE_FLOAT:
			var as_f: float = value
			return int(as_f)
		TYPE_BOOL:
			var as_b: bool = value
			if as_b:
				return 1
			return 0
		TYPE_STRING:
			var as_s: String = value
			return as_s.to_int()
		_:
			return 0


func _as_float(value: Variant) -> float:
	match typeof(value):
		TYPE_FLOAT:
			var as_f: float = value
			return as_f
		TYPE_INT:
			var as_i: int = value
			return float(as_i)
		TYPE_BOOL:
			var as_b: bool = value
			if as_b:
				return 1.0
			return 0.0
		TYPE_STRING:
			var as_s: String = value
			return as_s.to_float()
		_:
			return 0.0


func _as_bool(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			var as_b: bool = value
			return as_b
		TYPE_INT:
			var as_i: int = value
			return as_i != 0
		TYPE_FLOAT:
			var as_f: float = value
			return not is_zero_approx(as_f)
		TYPE_STRING:
			var as_s: String = value
			var text: String = as_s.to_lower()
			return text == "true" or text == "1" or text == "yes"
		_:
			return false


func _as_string(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			var as_s: String = value
			return as_s
		TYPE_STRING_NAME:
			var as_sn: StringName = value
			return String(as_sn)
		TYPE_NODE_PATH:
			var as_np: NodePath = value
			return String(as_np)
		_:
			return str(value)
