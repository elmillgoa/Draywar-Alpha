class_name StationMenu
extends CanvasLayer

## Minimal station menu — Alpha A3.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1, A3
##
## Undock / Launch emit `on_undock_requested`. Accept courier job emits
## `on_mission_accept_requested` when the dock controller offers a contract.

var _panel: PanelContainer = null
var _title: Label = null
var _accept_job_btn: Button = null
var _docked_station_id: StringName = &""


func _ready() -> void:
	layer = BalanceFlight.STATION_MENU_CANVAS_LAYER
	visible = false
	_build_ui()
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_undocked.connect(_on_undocked)
	EventBus.on_mission_accepted.connect(_on_mission_accepted)
	EventBus.on_mission_completed.connect(_on_mission_closed)
	EventBus.on_mission_failed.connect(_on_mission_closed)
	EventBus.on_mission_abandoned.connect(_on_mission_closed)


func _exit_tree() -> void:
	if EventBus.on_docked.is_connected(_on_docked):
		EventBus.on_docked.disconnect(_on_docked)
	if EventBus.on_undocked.is_connected(_on_undocked):
		EventBus.on_undocked.disconnect(_on_undocked)
	if EventBus.on_mission_accepted.is_connected(_on_mission_accepted):
		EventBus.on_mission_accepted.disconnect(_on_mission_accepted)
	if EventBus.on_mission_completed.is_connected(_on_mission_closed):
		EventBus.on_mission_completed.disconnect(_on_mission_closed)
	if EventBus.on_mission_failed.is_connected(_on_mission_closed):
		EventBus.on_mission_failed.disconnect(_on_mission_closed)
	if EventBus.on_mission_abandoned.is_connected(_on_mission_closed):
		EventBus.on_mission_abandoned.disconnect(_on_mission_closed)


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

	_accept_job_btn = Button.new()
	_accept_job_btn.text = BalanceStanding.STATION_ACCEPT_JOB_LABEL
	_accept_job_btn.custom_minimum_size = button_size
	_accept_job_btn.pressed.connect(_on_accept_job_pressed)
	_accept_job_btn.visible = false
	layout.add_child(_accept_job_btn)

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
	_refresh_job_button()
	visible = true


func _on_undocked(_station_id: StringName) -> void:
	_docked_station_id = &""
	if _accept_job_btn != null:
		_accept_job_btn.visible = false
	visible = false


func _on_undock_pressed() -> void:
	if _docked_station_id == &"":
		return
	EventBus.on_undock_requested.emit(_docked_station_id)


func _on_accept_job_pressed() -> void:
	var template_id: StringName = _offered_template_for_dock()
	if String(template_id).is_empty():
		return
	EventBus.on_mission_accept_requested.emit(template_id)


func _on_mission_accepted(_template_id: StringName, _entity_id: StringName) -> void:
	_refresh_job_button()


func _on_mission_closed(_template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_refresh_job_button()


func _refresh_job_button() -> void:
	if _accept_job_btn == null:
		return
	var template_id: StringName = _offered_template_for_dock()
	var mission_busy: bool = _mission_is_active()
	_accept_job_btn.visible = (not String(template_id).is_empty() and not mission_busy and visible)


func _mission_is_active() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var service: Node = tree.get_first_node_in_group(&"mission_service")
	if service == null:
		return false
	if not service.has_method(&"has_active"):
		return false
	# Duck-call only — UI must not type-reference MissionService (layer rule).
	var active: Variant = service.call(&"has_active")
	return active == true


func _offered_template_for_dock() -> StringName:
	if String(_docked_station_id).is_empty():
		return &""
	if not ContentLibrary.has_item(_docked_station_id):
		return &""
	var station_item: ContentItem = ContentLibrary.item(_docked_station_id)
	if not (station_item is Station):
		return &""
	var station: Station = station_item as Station
	var controller: StringName = station.controller_entity_id
	if controller == Station.CONTROLLER_NOBODY or String(controller).is_empty():
		return &""
	for id: StringName in ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY):
		var item: ContentItem = ContentLibrary.item(id)
		if item == null:
			continue
		# ContractType exposes offering_entity_id; avoid class_name import in UI.
		var offering_raw: Variant = item.get("offering_entity_id")
		if offering_raw == null:
			continue
		var offering: StringName = StringName(str(offering_raw))
		if offering == controller:
			return id
	return &""
