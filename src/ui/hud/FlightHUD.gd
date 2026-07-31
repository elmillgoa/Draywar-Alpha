class_name FlightHUD
extends CanvasLayer

## Readable flight HUD — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Display only. Listens to EventBus; resolves display names via ContentLibrary.

var _system_label: Label = null
var _speed_label: Label = null
var _throttle_label: Label = null
var _prompt_label: Label = null
var _status_label: Label = null


func _ready() -> void:
	layer = BalanceFlight.HUD_CANVAS_LAYER
	_build_labels()
	EventBus.on_system_entered.connect(_on_system_entered)
	EventBus.on_player_speed_changed.connect(_on_speed_changed)
	EventBus.on_player_throttle_changed.connect(_on_throttle_changed)
	EventBus.on_dock_prompt_changed.connect(_on_dock_prompt_changed)
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_undocked.connect(_on_undocked)


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


func _on_speed_changed(speed: float) -> void:
	var scaled: float = speed * BalanceFlight.HUD_SPEED_DISPLAY_SCALE
	var shown: int = int(roundf(scaled))
	_speed_label.text = "SPEED  %d" % shown


func _on_throttle_changed(throttle: float) -> void:
	var scaled: float = throttle * BalanceFlight.THROTTLE_PERCENT_SCALE
	var percent: int = int(roundf(scaled))
	_throttle_label.text = "THROTTLE  %d%%" % percent


func _on_system_entered(system_id: StringName) -> void:
	_system_label.text = "SYSTEM  %s" % _content_name(system_id).to_upper()


func _on_dock_prompt_changed(station_id: StringName, can_dock: bool) -> void:
	if station_id == &"":
		_prompt_label.text = ""
		return
	var station_label: String = _content_name(station_id)
	if can_dock:
		_prompt_label.text = "PRESS F TO DOCK — %s" % station_label
	else:
		_prompt_label.text = "APPROACHING %s" % station_label.to_upper()


func _on_docked(station_id: StringName) -> void:
	_status_label.text = "DOCKED — %s" % _content_name(station_id)
	_prompt_label.text = ""


func _on_undocked(_station_id: StringName) -> void:
	_status_label.text = ""
