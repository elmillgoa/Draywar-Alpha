class_name FlightHUD
extends CanvasLayer

## Readable flight HUD — Alpha A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1–A2, A5
##
## Display only. Listens to EventBus; resolves display names via ContentLibrary.
## Status line shows the protected standing moment (local controller only).
## Credits, fuel, hull, and gate jump prompts are session readouts.

var _system_label: Label = null
var _speed_label: Label = null
var _throttle_label: Label = null
var _prompt_label: Label = null
var _status_label: Label = null
var _credits_label: Label = null
var _fuel_label: Label = null
var _condition_label: Label = null
var _mission_label: Label = null
var _nav_title_label: Label = null
var _nav_here_label: Label = null
var _nav_gates_label: Label = null
var _root: Control = null

var _current_system_id: StringName = &""
var _docked_station_id: StringName = &""
var _gate_dest_id: StringName = &""
var _gate_can_jump: bool = false
var _dock_prompt_id: StringName = &""
var _dock_can_dock: bool = false


func _ready() -> void:
	layer = BalanceFlight.HUD_CANVAS_LAYER
	_build_labels()
	EventBus.on_system_entered.connect(_on_system_entered)
	EventBus.on_player_speed_changed.connect(_on_speed_changed)
	EventBus.on_player_throttle_changed.connect(_on_throttle_changed)
	EventBus.on_dock_prompt_changed.connect(_on_dock_prompt_changed)
	EventBus.on_gate_prompt_changed.connect(_on_gate_prompt_changed)
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_undocked.connect(_on_undocked)
	EventBus.on_status_moment.connect(_on_status_moment)
	EventBus.on_entity_standing_changed.connect(_on_entity_standing_changed)
	EventBus.on_dock_refused.connect(_on_dock_refused)
	EventBus.on_credits_changed.connect(_on_credits_changed)
	EventBus.on_fuel_changed.connect(_on_fuel_changed)
	EventBus.on_condition_changed.connect(_on_condition_changed)
	EventBus.on_mission_accepted.connect(_on_mission_changed)
	EventBus.on_mission_completed.connect(_on_mission_closed)
	EventBus.on_mission_failed.connect(_on_mission_closed)
	EventBus.on_mission_abandoned.connect(_on_mission_closed)
	_refresh_mission_line()


func _exit_tree() -> void:
	_disconnect(EventBus.on_system_entered, _on_system_entered)
	_disconnect(EventBus.on_player_speed_changed, _on_speed_changed)
	_disconnect(EventBus.on_player_throttle_changed, _on_throttle_changed)
	_disconnect(EventBus.on_dock_prompt_changed, _on_dock_prompt_changed)
	_disconnect(EventBus.on_gate_prompt_changed, _on_gate_prompt_changed)
	_disconnect(EventBus.on_docked, _on_docked)
	_disconnect(EventBus.on_undocked, _on_undocked)
	_disconnect(EventBus.on_status_moment, _on_status_moment)
	_disconnect(EventBus.on_entity_standing_changed, _on_entity_standing_changed)
	_disconnect(EventBus.on_dock_refused, _on_dock_refused)
	_disconnect(EventBus.on_credits_changed, _on_credits_changed)
	_disconnect(EventBus.on_fuel_changed, _on_fuel_changed)
	_disconnect(EventBus.on_condition_changed, _on_condition_changed)
	_disconnect(EventBus.on_mission_accepted, _on_mission_changed)
	_disconnect(EventBus.on_mission_completed, _on_mission_closed)
	_disconnect(EventBus.on_mission_failed, _on_mission_closed)
	_disconnect(EventBus.on_mission_abandoned, _on_mission_closed)


func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _build_labels() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = DraywarUiTheme.build()
	add_child(_root)

	_system_label = _make_label(_root, BalanceFlight.HUD_TITLE_FONT_SIZE)
	_system_label.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_system_label.position = Vector2(BalanceFlight.HUD_MARGIN, BalanceFlight.HUD_MARGIN)
	_system_label.text = "SYSTEM"

	_speed_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_speed_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE) * BalanceFlight.HUD_LINE_SPEED
		)
	)
	_speed_label.text = "SPEED  0"

	_throttle_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_throttle_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceFlight.HUD_LINE_SPEED
		)
	)
	_throttle_label.text = "THROTTLE  0%"

	_status_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_status_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceFlight.HUD_LINE_THROTTLE
		)
	)
	_status_label.text = ""

	_credits_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_credits_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceFlight.HUD_LINE_STATUS
		)
	)
	_credits_label.text = BalanceEconomy.HUD_CREDITS_FORMAT % 0

	_fuel_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_fuel_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceEconomy.HUD_LINE_CREDITS
		)
	)
	_fuel_label.text = (BalanceEconomy.HUD_FUEL_FORMAT % int(BalanceEconomy.PERCENT_SCALE))

	_condition_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_condition_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceEconomy.HUD_LINE_FUEL
		)
	)
	_condition_label.text = (
		BalanceEconomy.HUD_CONDITION_FORMAT % int(BalanceEconomy.PERCENT_SCALE)
	)

	_mission_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_mission_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceEconomy.HUD_LINE_MISSION
		)
	)
	_mission_label.text = ""

	_build_nav_panel(_root)

	_prompt_label = _make_label(_root, BalanceFlight.HUD_PROMPT_FONT_SIZE)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_label.offset_bottom = -BalanceFlight.HUD_MARGIN * BalanceFlight.HUD_LINE_THROTTLE
	_prompt_label.offset_top = (
		-BalanceFlight.HUD_MARGIN * BalanceFlight.HUD_LINE_THROTTLE
		- float(BalanceFlight.HUD_PROMPT_FONT_SIZE)
	)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_prompt_label.text = ""


func _build_nav_panel(parent: Control) -> void:
	# Right-side nav: current system + gate destinations from ContentLibrary.
	_nav_title_label = _make_label(parent, BalanceFlight.HUD_TITLE_FONT_SIZE)
	_nav_title_label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_nav_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_nav_title_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_nav_title_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_nav_title_label.offset_right = -BalanceEconomy.NAV_PANEL_RIGHT_MARGIN
	_nav_title_label.offset_top = BalanceFlight.HUD_MARGIN
	_nav_title_label.text = BalanceEconomy.NAV_TITLE_TEXT

	_nav_here_label = _make_label(parent, BalanceFlight.HUD_FONT_SIZE)
	_nav_here_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_nav_here_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_nav_here_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_nav_here_label.offset_right = -BalanceEconomy.NAV_PANEL_RIGHT_MARGIN
	_nav_here_label.offset_top = (
		BalanceFlight.HUD_MARGIN
		+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
		+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceEconomy.HUD_LINE_NAV_HERE
	)
	_nav_here_label.text = BalanceEconomy.NAV_HERE_FORMAT % "—"

	_nav_gates_label = _make_label(parent, BalanceFlight.HUD_FONT_SIZE)
	_nav_gates_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_nav_gates_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_nav_gates_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_nav_gates_label.offset_right = -BalanceEconomy.NAV_PANEL_RIGHT_MARGIN
	_nav_gates_label.offset_top = (
		BalanceFlight.HUD_MARGIN
		+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
		+ float(BalanceFlight.HUD_FONT_SIZE) * (BalanceEconomy.HUD_LINE_NAV_GATES + 1.0)
	)
	_nav_gates_label.text = BalanceEconomy.NAV_GATES_HEADER


func _make_label(parent: Control, font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _content_name(id: StringName) -> String:
	if id == &"":
		return ""
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


func _refresh_status_line() -> void:
	if _docked_station_id != &"":
		var station_status: Dictionary = StandingService.status_for_station(_docked_station_id)
		_status_label.text = (
			BalanceStanding.DOCKED_STATUS_FORMAT
			% [
				_content_name(_docked_station_id),
				station_status[StandingService.STATUS_KEY_TIER_DISPLAY],
				station_status[StandingService.STATUS_KEY_ENTITY_DISPLAY],
			]
		)
		return
	if _current_system_id != &"":
		var system_status: Dictionary = StandingService.status_for_system(_current_system_id)
		_status_label.text = system_status[StandingService.STATUS_KEY_LINE]
		return
	_status_label.text = ""


func _refresh_prompt() -> void:
	# Station dock prompt wins over gate jump.
	if _dock_prompt_id != &"":
		var station_label: String = _content_name(_dock_prompt_id)
		if _dock_can_dock:
			_prompt_label.text = "PRESS F TO DOCK — %s" % station_label
			return
		if not StandingService.can_dock_at_station(_dock_prompt_id):
			var status: Dictionary = StandingService.status_for_station(_dock_prompt_id)
			_prompt_label.text = (
				BalanceStanding.DOCK_REFUSED_PROMPT_FORMAT
				% [
					status[StandingService.STATUS_KEY_TIER_DISPLAY],
					status[StandingService.STATUS_KEY_ENTITY_DISPLAY],
				]
			)
			return
		_prompt_label.text = "APPROACHING %s" % station_label.to_upper()
		return
	if _gate_dest_id != &"":
		var dest_label: String = _content_name(_gate_dest_id)
		if _gate_can_jump:
			_prompt_label.text = BalanceEconomy.JUMP_PROMPT_FORMAT % dest_label
		else:
			_prompt_label.text = (
				BalanceEconomy.JUMP_PROMPT_NO_FUEL_FORMAT
				% [str(int(BalanceEconomy.JUMP_FUEL_COST)), dest_label]
			)
		return
	_prompt_label.text = ""


func _on_speed_changed(speed: float) -> void:
	var scaled: float = speed * BalanceFlight.HUD_SPEED_DISPLAY_SCALE
	var shown: int = int(roundf(scaled))
	_speed_label.text = "SPEED  %d" % shown


func _on_throttle_changed(throttle: float) -> void:
	var scaled: float = throttle * BalanceFlight.THROTTLE_PERCENT_SCALE
	var percent: int = int(roundf(scaled))
	_throttle_label.text = "THROTTLE  %d%%" % percent


func _on_credits_changed(credits: int) -> void:
	_credits_label.text = BalanceEconomy.HUD_CREDITS_FORMAT % credits


func _on_fuel_changed(fuel: float, fuel_max: float) -> void:
	var pct: int = 0
	if fuel_max > 0.0:
		pct = int(roundf((fuel / fuel_max) * BalanceEconomy.PERCENT_SCALE))
	_fuel_label.text = BalanceEconomy.HUD_FUEL_FORMAT % pct


func _on_condition_changed(condition: float, condition_max: float) -> void:
	var pct: int = 0
	if condition_max > 0.0:
		pct = int(roundf((condition / condition_max) * BalanceEconomy.PERCENT_SCALE))
	_condition_label.text = BalanceEconomy.HUD_CONDITION_FORMAT % pct


func _on_mission_changed(_template_id: StringName, _entity_id: StringName) -> void:
	_refresh_mission_line()


func _on_mission_closed(_template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_refresh_mission_line()


func _refresh_mission_line() -> void:
	if _mission_label == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		_mission_label.text = ""
		return
	var service: Node = tree.get_first_node_in_group(&"mission_service")
	if service == null or not service.has_method(&"has_active"):
		_mission_label.text = ""
		return
	if service.call(&"has_active") != true:
		_mission_label.text = ""
		return
	var template_raw: Variant = service.call(&"active_template_id")
	var template_id: StringName = &""
	if typeof(template_raw) == TYPE_STRING_NAME:
		template_id = template_raw
	elif typeof(template_raw) == TYPE_STRING:
		var ttext: String = template_raw
		template_id = StringName(ttext)
	var job_name: String = _content_name(template_id)
	var dest_id: StringName = &""
	if service.has_method(&"active_destination_station_id"):
		var dest_raw: Variant = service.call(&"active_destination_station_id")
		if typeof(dest_raw) == TYPE_STRING_NAME:
			dest_id = dest_raw
		elif typeof(dest_raw) == TYPE_STRING:
			var dtext: String = dest_raw
			dest_id = StringName(dtext)
	if String(dest_id).is_empty():
		_mission_label.text = BalanceStanding.HUD_MISSION_NO_DEST_FORMAT % job_name
	else:
		_mission_label.text = (
			BalanceStanding.HUD_MISSION_FORMAT % [job_name, _content_name(dest_id)]
		)


func _on_system_entered(system_id: StringName) -> void:
	_current_system_id = system_id
	_system_label.text = "SYSTEM  %s" % _content_name(system_id).to_upper()
	_refresh_status_line()
	_refresh_nav_panel()


## Nav readout text for tests and external readers (HERE + GATES lines).
func nav_here_text() -> String:
	if _nav_here_label == null:
		return ""
	return _nav_here_label.text


## Gate list block from the nav panel (header + lines).
func nav_gates_text() -> String:
	if _nav_gates_label == null:
		return ""
	return _nav_gates_label.text


func _refresh_nav_panel() -> void:
	if _nav_here_label == null or _nav_gates_label == null:
		return
	var here_name: String = _content_name(_current_system_id)
	if here_name.is_empty():
		here_name = "—"
	_nav_here_label.text = BalanceEconomy.NAV_HERE_FORMAT % here_name.to_upper()

	var lines: PackedStringArray = PackedStringArray()
	lines.append(BalanceEconomy.NAV_GATES_HEADER)
	var destinations: Array[StringName] = _gate_destinations_for(_current_system_id)
	if destinations.is_empty():
		lines.append(BalanceEconomy.NAV_NO_GATES)
	else:
		var shown: int = 0
		for dest_id: StringName in destinations:
			if shown >= BalanceEconomy.NAV_MAX_GATE_LINES:
				break
			lines.append(BalanceEconomy.NAV_GATE_LINE_FORMAT % _content_name(dest_id))
			shown += 1
	_nav_gates_label.text = "\n".join(lines)


func _gate_destinations_for(system_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if String(system_id).is_empty() or not ContentLibrary.has_item(system_id):
		return result
	var item: ContentItem = ContentLibrary.item(system_id)
	var system: StarSystem = item as StarSystem
	if system == null:
		return result
	for dest_id: StringName in system.gate_destination_ids:
		result.append(dest_id)
	return result


func _on_status_moment(
	_kind: StringName,
	_place_id: StringName,
	_entity_id: StringName,
	_standing: float,
	_tier: StringName
) -> void:
	_refresh_status_line()


func _on_entity_standing_changed(
	_entity_id: StringName, _old_value: float, _new_value: float, _tier: StringName
) -> void:
	_refresh_status_line()


func _on_dock_prompt_changed(station_id: StringName, can_dock: bool) -> void:
	_dock_prompt_id = station_id
	_dock_can_dock = can_dock
	_refresh_prompt()


func _on_gate_prompt_changed(destination_system_id: StringName, can_jump: bool) -> void:
	_gate_dest_id = destination_system_id
	_gate_can_jump = can_jump
	_refresh_prompt()


func _on_dock_refused(
	_station_id: StringName, _entity_id: StringName, _standing: float, _tier: StringName
) -> void:
	var status: Dictionary = StandingService.status_for_station(_station_id)
	_prompt_label.text = (
		BalanceStanding.DOCK_REFUSED_PROMPT_FORMAT
		% [
			status[StandingService.STATUS_KEY_TIER_DISPLAY],
			status[StandingService.STATUS_KEY_ENTITY_DISPLAY],
		]
	)


func _on_docked(station_id: StringName) -> void:
	_docked_station_id = station_id
	_dock_prompt_id = &""
	_gate_dest_id = &""
	_prompt_label.text = ""
	_refresh_status_line()


func _on_undocked(_station_id: StringName) -> void:
	_docked_station_id = &""
	_refresh_status_line()
