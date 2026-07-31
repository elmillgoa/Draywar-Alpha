class_name FlightHUD
extends CanvasLayer

## Readable flight HUD — Alpha A2.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1 + A2 status moment
##
## Display only. Listens to EventBus; resolves display names via ContentLibrary.
## Status line shows the protected standing moment (local controller only).

var _system_label: Label = null
var _speed_label: Label = null
var _throttle_label: Label = null
var _prompt_label: Label = null
var _status_label: Label = null

var _current_system_id: StringName = &""
var _docked_station_id: StringName = &""


func _ready() -> void:
	layer = BalanceFlight.HUD_CANVAS_LAYER
	_build_labels()
	EventBus.on_system_entered.connect(_on_system_entered)
	EventBus.on_player_speed_changed.connect(_on_speed_changed)
	EventBus.on_player_throttle_changed.connect(_on_throttle_changed)
	EventBus.on_dock_prompt_changed.connect(_on_dock_prompt_changed)
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_undocked.connect(_on_undocked)
	EventBus.on_status_moment.connect(_on_status_moment)
	EventBus.on_entity_standing_changed.connect(_on_entity_standing_changed)
	EventBus.on_dock_refused.connect(_on_dock_refused)


func _exit_tree() -> void:
	if EventBus.on_system_entered.is_connected(_on_system_entered):
		EventBus.on_system_entered.disconnect(_on_system_entered)
	if EventBus.on_player_speed_changed.is_connected(_on_speed_changed):
		EventBus.on_player_speed_changed.disconnect(_on_speed_changed)
	if EventBus.on_player_throttle_changed.is_connected(_on_throttle_changed):
		EventBus.on_player_throttle_changed.disconnect(_on_throttle_changed)
	if EventBus.on_dock_prompt_changed.is_connected(_on_dock_prompt_changed):
		EventBus.on_dock_prompt_changed.disconnect(_on_dock_prompt_changed)
	if EventBus.on_docked.is_connected(_on_docked):
		EventBus.on_docked.disconnect(_on_docked)
	if EventBus.on_undocked.is_connected(_on_undocked):
		EventBus.on_undocked.disconnect(_on_undocked)
	if EventBus.on_status_moment.is_connected(_on_status_moment):
		EventBus.on_status_moment.disconnect(_on_status_moment)
	if EventBus.on_entity_standing_changed.is_connected(_on_entity_standing_changed):
		EventBus.on_entity_standing_changed.disconnect(_on_entity_standing_changed)
	if EventBus.on_dock_refused.is_connected(_on_dock_refused):
		EventBus.on_dock_refused.disconnect(_on_dock_refused)


func _build_labels() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_system_label = _make_label(root, BalanceFlight.HUD_TITLE_FONT_SIZE)
	_system_label.position = Vector2(BalanceFlight.HUD_MARGIN, BalanceFlight.HUD_MARGIN)
	_system_label.text = "SYSTEM"

	_speed_label = _make_label(root, BalanceFlight.HUD_FONT_SIZE)
	_speed_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE) * BalanceFlight.HUD_LINE_SPEED
		)
	)
	_speed_label.text = "SPEED  0"

	_throttle_label = _make_label(root, BalanceFlight.HUD_FONT_SIZE)
	_throttle_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceFlight.HUD_LINE_SPEED
		)
	)
	_throttle_label.text = "THROTTLE  0%"

	_status_label = _make_label(root, BalanceFlight.HUD_FONT_SIZE)
	_status_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceFlight.HUD_LINE_THROTTLE
		)
	)
	_status_label.text = ""

	_prompt_label = _make_label(root, BalanceFlight.HUD_PROMPT_FONT_SIZE)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_label.offset_bottom = -BalanceFlight.HUD_MARGIN * BalanceFlight.HUD_LINE_THROTTLE
	_prompt_label.offset_top = (
		-BalanceFlight.HUD_MARGIN * BalanceFlight.HUD_LINE_THROTTLE
		- float(BalanceFlight.HUD_PROMPT_FONT_SIZE)
	)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.text = ""


func _make_label(parent: Control, font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
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


func _on_speed_changed(speed: float) -> void:
	var scaled: float = speed * BalanceFlight.HUD_SPEED_DISPLAY_SCALE
	var shown: int = int(roundf(scaled))
	_speed_label.text = "SPEED  %d" % shown


func _on_throttle_changed(throttle: float) -> void:
	var scaled: float = throttle * BalanceFlight.THROTTLE_PERCENT_SCALE
	var percent: int = int(roundf(scaled))
	_throttle_label.text = "THROTTLE  %d%%" % percent


func _on_system_entered(system_id: StringName) -> void:
	_current_system_id = system_id
	_system_label.text = "SYSTEM  %s" % _content_name(system_id).to_upper()
	# StandingService emits on_status_moment; refresh covers load races.
	_refresh_status_line()


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
	if station_id == &"":
		_prompt_label.text = ""
		return
	var station_label: String = _content_name(station_id)
	if can_dock:
		_prompt_label.text = "PRESS F TO DOCK — %s" % station_label
		return
	if not StandingService.can_dock_at_station(station_id):
		var status: Dictionary = StandingService.status_for_station(station_id)
		_prompt_label.text = (
			BalanceStanding.DOCK_REFUSED_PROMPT_FORMAT
			% [
				status[StandingService.STATUS_KEY_TIER_DISPLAY],
				status[StandingService.STATUS_KEY_ENTITY_DISPLAY],
			]
		)
		return
	_prompt_label.text = "APPROACHING %s" % station_label.to_upper()


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
	_prompt_label.text = ""
	_refresh_status_line()


func _on_undocked(_station_id: StringName) -> void:
	_docked_station_id = &""
	_refresh_status_line()
