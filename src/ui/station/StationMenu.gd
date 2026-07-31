class_name StationMenu
extends CanvasLayer

## Minimal station menu — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Display only. Undock / Launch emit `on_undock_requested`. Names via
## ContentLibrary. No market, jobs, standing, or money.

var _panel: PanelContainer = null
var _title: Label = null
var _docked_station_id: StringName = &""


func _ready() -> void:
	layer = BalanceFlight.STATION_MENU_CANVAS_LAYER
	visible = false
	_build_ui()
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_undocked.connect(_on_undocked)


func _exit_tree() -> void:
	if EventBus.on_docked.is_connected(_on_docked):
		EventBus.on_docked.disconnect(_on_docked)
	if EventBus.on_undocked.is_connected(_on_undocked):
		EventBus.on_undocked.disconnect(_on_undocked)


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, BalanceFlight.STATION_MENU_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(
		BalanceFlight.STATION_MENU_WIDTH, BalanceFlight.STATION_MENU_HEIGHT
	)
	_panel.offset_left = -BalanceFlight.STATION_MENU_HALF_WIDTH
	_panel.offset_top = -BalanceFlight.STATION_MENU_HALF_HEIGHT
	_panel.offset_right = BalanceFlight.STATION_MENU_HALF_WIDTH
	_panel.offset_bottom = BalanceFlight.STATION_MENU_HALF_HEIGHT
	root.add_child(_panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(layout)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text = "Station"
	layout.add_child(_title)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceFlight.HUD_MARGIN)
	layout.add_child(spacer)

	var button_size: Vector2 = Vector2(
		BalanceFlight.STATION_MENU_BUTTON_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
	)

	var undock_btn: Button = Button.new()
	undock_btn.text = "Undock"
	undock_btn.custom_minimum_size = button_size
	undock_btn.pressed.connect(_on_undock_pressed)
	layout.add_child(undock_btn)

	var launch_btn: Button = Button.new()
	launch_btn.text = "Launch"
	launch_btn.custom_minimum_size = button_size
	launch_btn.pressed.connect(_on_undock_pressed)
	layout.add_child(launch_btn)


func _content_name(id: StringName) -> String:
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


func _on_docked(station_id: StringName) -> void:
	_docked_station_id = station_id
	_title.text = _content_name(station_id)
	visible = true


func _on_undocked(_station_id: StringName) -> void:
	_docked_station_id = &""
	visible = false


func _on_undock_pressed() -> void:
	if _docked_station_id == &"":
		return
	EventBus.on_undock_requested.emit(_docked_station_id)
