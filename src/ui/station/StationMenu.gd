class_name StationMenu
extends CanvasLayer

## Station menu — Alpha A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1, A3, A4, A5
##
## Undock / Launch, accept / turn in / abandon jobs, recovery talk / complete /
## abandon / favor / betray, refuel and repair. All actions go through EventBus.

var _panel: PanelContainer = null
var _title: Label = null
var _accept_job_btn: Button = null
var _turn_in_job_btn: Button = null
var _abandon_job_btn: Button = null
var _recovery_btn: Button = null
var _complete_recovery_btn: Button = null
var _abandon_recovery_btn: Button = null
var _favor_btn: Button = null
var _betray_btn: Button = null
var _refuel_btn: Button = null
var _repair_btn: Button = null
var _docked_station_id: StringName = &""
var _offer_person_id: StringName = &""
var _favor_person_id: StringName = &""
var _active_recovery_person_id: StringName = &""


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
	EventBus.on_recovery_accepted.connect(_on_recovery_accepted)
	EventBus.on_recovery_completed.connect(_on_recovery_closed)
	EventBus.on_recovery_failed.connect(_on_recovery_soft_closed)
	EventBus.on_recovery_abandoned.connect(_on_recovery_soft_closed)
	EventBus.on_recovery_betrayed.connect(_on_recovery_betrayed)
	EventBus.on_person_closed.connect(_on_person_closed)
	EventBus.on_person_standing_changed.connect(_on_person_standing_changed)
	EventBus.on_credits_changed.connect(_on_wallet_changed)
	EventBus.on_fuel_changed.connect(_on_fuel_changed)
	EventBus.on_condition_changed.connect(_on_condition_changed)


func _exit_tree() -> void:
	_disconnect(EventBus.on_docked, _on_docked)
	_disconnect(EventBus.on_undocked, _on_undocked)
	_disconnect(EventBus.on_mission_accepted, _on_mission_accepted)
	_disconnect(EventBus.on_mission_completed, _on_mission_closed)
	_disconnect(EventBus.on_mission_failed, _on_mission_closed)
	_disconnect(EventBus.on_mission_abandoned, _on_mission_closed)
	_disconnect(EventBus.on_recovery_accepted, _on_recovery_accepted)
	_disconnect(EventBus.on_recovery_completed, _on_recovery_closed)
	_disconnect(EventBus.on_recovery_failed, _on_recovery_soft_closed)
	_disconnect(EventBus.on_recovery_abandoned, _on_recovery_soft_closed)
	_disconnect(EventBus.on_recovery_betrayed, _on_recovery_betrayed)
	_disconnect(EventBus.on_person_closed, _on_person_closed)
	_disconnect(EventBus.on_person_standing_changed, _on_person_standing_changed)
	_disconnect(EventBus.on_credits_changed, _on_wallet_changed)
	_disconnect(EventBus.on_fuel_changed, _on_fuel_changed)
	_disconnect(EventBus.on_condition_changed, _on_condition_changed)


func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


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
	_panel.theme = DraywarUiTheme.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(
		BalanceFlight.STATION_MENU_WIDTH, BalanceEconomy.STATION_MENU_HEIGHT_A5
	)
	_panel.offset_left = -BalanceFlight.STATION_MENU_HALF_WIDTH
	_panel.offset_top = -BalanceEconomy.STATION_MENU_HALF_HEIGHT_A5
	_panel.offset_right = BalanceFlight.STATION_MENU_HALF_WIDTH
	_panel.offset_bottom = BalanceEconomy.STATION_MENU_HALF_HEIGHT_A5
	root.add_child(_panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(layout)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text = "Station"
	layout.add_child(_title)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceFlight.HUD_MARGIN)
	layout.add_child(spacer)

	var button_size: Vector2 = Vector2(
		BalanceFlight.STATION_MENU_BUTTON_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
	)

	_accept_job_btn = _make_button(layout, button_size, BalanceStanding.STATION_ACCEPT_JOB_LABEL)
	_accept_job_btn.pressed.connect(_on_accept_job_pressed)
	_accept_job_btn.visible = false

	_turn_in_job_btn = _make_button(layout, button_size, BalanceEconomy.STATION_TURN_IN_JOB_LABEL)
	_turn_in_job_btn.pressed.connect(_on_turn_in_job_pressed)
	_turn_in_job_btn.visible = false

	_abandon_job_btn = _make_button(layout, button_size, BalanceEconomy.STATION_ABANDON_JOB_LABEL)
	_abandon_job_btn.pressed.connect(_on_abandon_job_pressed)
	_abandon_job_btn.visible = false

	_recovery_btn = _make_button(layout, button_size, "Talk")
	_recovery_btn.pressed.connect(_on_recovery_pressed)
	_recovery_btn.visible = false

	_complete_recovery_btn = _make_button(
		layout, button_size, BalanceEconomy.STATION_COMPLETE_RECOVERY_LABEL
	)
	_complete_recovery_btn.pressed.connect(_on_complete_recovery_pressed)
	_complete_recovery_btn.visible = false

	_abandon_recovery_btn = _make_button(
		layout, button_size, BalanceEconomy.STATION_ABANDON_RECOVERY_LABEL
	)
	_abandon_recovery_btn.pressed.connect(_on_abandon_recovery_pressed)
	_abandon_recovery_btn.visible = false

	_favor_btn = _make_button(layout, button_size, "Ask favor")
	_favor_btn.pressed.connect(_on_favor_pressed)
	_favor_btn.visible = false

	_betray_btn = _make_button(layout, button_size, "Betray")
	_betray_btn.pressed.connect(_on_betray_pressed)
	_betray_btn.visible = false

	_refuel_btn = _make_button(layout, button_size, BalanceEconomy.STATION_REFUEL_LABEL)
	_refuel_btn.pressed.connect(_on_refuel_pressed)

	_repair_btn = _make_button(layout, button_size, BalanceEconomy.STATION_REPAIR_LABEL)
	_repair_btn.pressed.connect(_on_repair_pressed)

	var undock_btn: Button = _make_button(layout, button_size, "Undock")
	undock_btn.pressed.connect(_on_undock_pressed)

	var launch_btn: Button = _make_button(layout, button_size, "Launch")
	launch_btn.pressed.connect(_on_undock_pressed)


func _make_button(parent: Control, size: Vector2, text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = size
	parent.add_child(btn)
	return btn


func _content_name(id: StringName) -> String:
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


func _on_docked(station_id: StringName) -> void:
	_docked_station_id = station_id
	_title.text = _content_name(station_id)
	_refresh_all()
	visible = true


func _on_undocked(_station_id: StringName) -> void:
	_docked_station_id = &""
	_offer_person_id = &""
	_favor_person_id = &""
	_active_recovery_person_id = &""
	_hide_action_buttons()
	visible = false


func _hide_action_buttons() -> void:
	if _accept_job_btn != null:
		_accept_job_btn.visible = false
	if _turn_in_job_btn != null:
		_turn_in_job_btn.visible = false
	if _abandon_job_btn != null:
		_abandon_job_btn.visible = false
	if _recovery_btn != null:
		_recovery_btn.visible = false
	if _complete_recovery_btn != null:
		_complete_recovery_btn.visible = false
	if _abandon_recovery_btn != null:
		_abandon_recovery_btn.visible = false
	if _favor_btn != null:
		_favor_btn.visible = false
	if _betray_btn != null:
		_betray_btn.visible = false


func _on_undock_pressed() -> void:
	if _docked_station_id == &"":
		return
	EventBus.on_undock_requested.emit(_docked_station_id)


func _on_accept_job_pressed() -> void:
	var template_id: StringName = _offered_template_for_dock()
	if String(template_id).is_empty():
		return
	EventBus.on_mission_accept_requested.emit(template_id)


func _on_turn_in_job_pressed() -> void:
	EventBus.on_mission_complete_requested.emit()


func _on_abandon_job_pressed() -> void:
	EventBus.on_mission_abandon_requested.emit()


func _on_recovery_pressed() -> void:
	if String(_offer_person_id).is_empty():
		return
	EventBus.on_recovery_accept_requested.emit(_offer_person_id)


func _on_complete_recovery_pressed() -> void:
	EventBus.on_recovery_complete_requested.emit()


func _on_abandon_recovery_pressed() -> void:
	EventBus.on_recovery_abandon_requested.emit()


func _on_favor_pressed() -> void:
	if String(_favor_person_id).is_empty():
		return
	EventBus.on_recovery_favor_requested.emit(_favor_person_id)


func _on_betray_pressed() -> void:
	EventBus.on_recovery_betray_requested.emit(_active_recovery_person_id)


func _on_refuel_pressed() -> void:
	EventBus.on_refuel_requested.emit()


func _on_repair_pressed() -> void:
	EventBus.on_repair_requested.emit()


func _on_mission_accepted(_template_id: StringName, _entity_id: StringName) -> void:
	_refresh_all()


func _on_mission_closed(_template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_refresh_all()


func _on_recovery_accepted(
	_chain_id: StringName, _step_id: StringName, person_id: StringName
) -> void:
	_active_recovery_person_id = person_id
	_refresh_all()


func _on_recovery_closed(
	_chain_id: StringName,
	_step_id: StringName,
	_person_id: StringName,
	_entity_id: StringName,
	_person_delta: float,
	_entity_delta: float
) -> void:
	_active_recovery_person_id = &""
	_refresh_all()


func _on_recovery_soft_closed(
	_chain_id: StringName, _step_id: StringName, _person_id: StringName, _person_delta: float
) -> void:
	_active_recovery_person_id = &""
	_refresh_all()


func _on_recovery_betrayed(
	_person_id: StringName, _person_delta: float, _entity_delta: float
) -> void:
	_active_recovery_person_id = &""
	_refresh_all()


func _on_person_closed(_person_id: StringName, _reason: StringName) -> void:
	_refresh_all()


func _on_person_standing_changed(
	_person_id: StringName, _old_value: float, _new_value: float, _tier: StringName
) -> void:
	if visible:
		_refresh_all()


func _on_wallet_changed(_credits: int) -> void:
	if visible:
		_refresh_services()


func _on_fuel_changed(_fuel: float, _fuel_max: float) -> void:
	if visible:
		_refresh_services()


func _on_condition_changed(_condition: float, _condition_max: float) -> void:
	if visible:
		_refresh_services()


func _refresh_all() -> void:
	_refresh_job_buttons()
	_refresh_recovery_buttons()
	_refresh_services()


func _refresh_job_buttons() -> void:
	if _accept_job_btn == null:
		return
	var template_id: StringName = _offered_template_for_dock()
	var mission_busy: bool = _mission_is_active()
	_accept_job_btn.visible = (not String(template_id).is_empty() and not mission_busy and visible)
	if _accept_job_btn.visible:
		_accept_job_btn.text = _accept_job_label(template_id)
	var can_turn_in: bool = mission_busy and _mission_can_complete_here()
	_turn_in_job_btn.visible = can_turn_in and visible
	_abandon_job_btn.visible = mission_busy and visible


func _accept_job_label(template_id: StringName) -> String:
	if String(template_id).is_empty() or not ContentLibrary.has_item(template_id):
		return BalanceStanding.STATION_ACCEPT_JOB_LABEL
	var item: ContentItem = ContentLibrary.item(template_id)
	var dest_id: StringName = _variant_to_name(item.get("destination_station_id"))
	if String(dest_id).is_empty():
		return BalanceStanding.STATION_ACCEPT_JOB_LABEL
	return BalanceStanding.STATION_ACCEPT_JOB_TO_FORMAT % _content_name(dest_id)


func _refresh_recovery_buttons() -> void:
	if _recovery_btn == null:
		return
	_offer_person_id = _offered_recovery_person_for_dock()
	_favor_person_id = _favor_person_for_dock()
	var recovery_busy: bool = _recovery_is_active()
	if recovery_busy:
		_active_recovery_person_id = _active_recovery_person()
	elif not recovery_busy:
		_active_recovery_person_id = &""

	var offer_visible: bool = (
		not String(_offer_person_id).is_empty() and not recovery_busy and visible
	)
	_recovery_btn.visible = offer_visible
	if offer_visible:
		_recovery_btn.text = (
			BalanceStanding.STATION_RECOVERY_TALK_FORMAT % _content_name(_offer_person_id)
		)

	_complete_recovery_btn.visible = recovery_busy and visible
	_abandon_recovery_btn.visible = recovery_busy and visible

	var favor_visible: bool = (
		not String(_favor_person_id).is_empty() and not recovery_busy and visible
	)
	_favor_btn.visible = favor_visible
	if favor_visible:
		_favor_btn.text = (
			BalanceEconomy.STATION_ASK_FAVOR_FORMAT % _content_name(_favor_person_id)
		)

	var betray_target: StringName = _active_recovery_person_id
	if String(betray_target).is_empty():
		betray_target = _favor_person_id
	var betray_visible: bool = (
		not String(betray_target).is_empty()
		and visible
		and not StandingService.is_person_closed(betray_target)
	)
	_betray_btn.visible = betray_visible
	if betray_visible:
		_betray_btn.text = BalanceEconomy.STATION_BETRAY_FORMAT % _content_name(betray_target)
		_active_recovery_person_id = betray_target


func _refresh_services() -> void:
	if _refuel_btn == null:
		return
	# Always show while docked; wallet refuses if full/broke.
	_refuel_btn.visible = visible
	_repair_btn.visible = visible


func _mission_is_active() -> bool:
	return _group_bool(&"mission_service", &"has_active")


func _mission_can_complete_here() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var service: Node = tree.get_first_node_in_group(&"mission_service")
	if service == null or not service.has_method(&"can_complete_at_station"):
		return false
	var ok: Variant = service.call(&"can_complete_at_station", _docked_station_id)
	return ok == true


func _recovery_is_active() -> bool:
	return _group_bool(&"recovery_service", &"has_active")


func _active_recovery_person() -> StringName:
	var found: StringName = &""
	var tree: SceneTree = get_tree()
	var service: Node = null
	if tree != null:
		service = tree.get_first_node_in_group(&"recovery_service")
	if service != null and service.has_method(&"active_chain_id"):
		var chain_id: StringName = _variant_to_name(service.call(&"active_chain_id"))
		if not String(chain_id).is_empty() and ContentLibrary.has_item(chain_id):
			var item: ContentItem = ContentLibrary.item(chain_id)
			found = _variant_to_name(item.get("person_id"))
	return found


func _variant_to_name(value: Variant) -> StringName:
	var result: StringName = &""
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		result = as_name
	elif typeof(value) == TYPE_STRING:
		var as_text: String = value
		result = StringName(as_text)
	return result


func _group_bool(group: StringName, method: StringName) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var service: Node = tree.get_first_node_in_group(group)
	if service == null:
		return false
	if not service.has_method(method):
		return false
	var active: Variant = service.call(method)
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
		var offering_raw: Variant = item.get("offering_entity_id")
		if offering_raw == null:
			continue
		var offering: StringName = StringName(str(offering_raw))
		if offering == controller:
			return id
	return &""


func _offered_recovery_person_for_dock() -> StringName:
	var found: StringName = &""
	var controller: StringName = _dock_controller()
	if String(controller).is_empty():
		return found
	var tree: SceneTree = get_tree()
	if tree == null:
		return found
	var service: Node = tree.get_first_node_in_group(&"recovery_service")
	if service == null:
		return found
	return _first_offerable_person(service, controller)


func _favor_person_for_dock() -> StringName:
	## Show favor for the recovery contact of this station's controller when
	## not closed and not yet Friendly enough for an offer (bootstrap path).
	var controller: StringName = _dock_controller()
	if String(controller).is_empty():
		return &""
	for chain_id: StringName in ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY):
		var item: ContentItem = ContentLibrary.item(chain_id)
		if item == null:
			continue
		var entity_raw: Variant = item.get("entity_id")
		var person_raw: Variant = item.get("person_id")
		if entity_raw == null or person_raw == null:
			continue
		var entity_id: StringName = StringName(str(entity_raw))
		var person_id: StringName = StringName(str(person_raw))
		if entity_id != controller:
			continue
		if StandingService.is_person_closed(person_id):
			continue
		if StandingService.can_offer_recovery(person_id):
			# Already offerable — talk button covers it; favor still ok for top-up.
			return person_id
		return person_id
	return &""


func _dock_controller() -> StringName:
	if String(_docked_station_id).is_empty() or not ContentLibrary.has_item(_docked_station_id):
		return &""
	var station_item: ContentItem = ContentLibrary.item(_docked_station_id)
	if not (station_item is Station):
		return &""
	var station: Station = station_item as Station
	var controller: StringName = station.controller_entity_id
	if controller == Station.CONTROLLER_NOBODY or String(controller).is_empty():
		return &""
	return controller


func _first_offerable_person(service: Node, controller: StringName) -> StringName:
	var found: StringName = &""
	for chain_id: StringName in ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY):
		var item: ContentItem = ContentLibrary.item(chain_id)
		if item == null:
			continue
		var entity_raw: Variant = item.get("entity_id")
		var person_raw: Variant = item.get("person_id")
		if entity_raw == null or person_raw == null:
			continue
		var entity_id: StringName = StringName(str(entity_raw))
		var person_id: StringName = StringName(str(person_raw))
		if entity_id != controller:
			continue
		if not service.has_method(&"has_offer_for_person"):
			continue
		var offerable: Variant = service.call(&"has_offer_for_person", person_id)
		if offerable == true:
			found = person_id
			break
	return found
