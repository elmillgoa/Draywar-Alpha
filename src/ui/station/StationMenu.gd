class_name StationMenu
extends CanvasLayer

## Station menu Ã¢â‚¬â€ Path C B3 sections (jobs, services, trade, contacts).
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1Ã¢â‚¬â€œA5, Alpha/ALPHA_DECISION_PHASE_PLAN.md B3
##
## Undock, accept / turn in / abandon jobs, recovery talk / complete /
## abandon / favor / betray, refuel and repair, buy/sell commodities.
## All actions go through EventBus.

var _panel: PanelContainer = null
var _title: Label = null
var _flavor_label: Label = null
var _scroll: ScrollContainer = null
## Dynamic accept-job buttons (one per offered template for the dock controller).
var _jobs_box: VBoxContainer = null
var _turn_in_job_btn: Button = null
var _abandon_job_btn: Button = null
var _contacts_header: Label = null
## Named people for the dock controller (Contacts list Ã¢â‚¬â€ E1.2).
var _contacts_list: VBoxContainer = null
var _recovery_hint: Label = null
var _recovery_btn: Button = null
var _complete_recovery_btn: Button = null
var _abandon_recovery_btn: Button = null
var _favor_btn: Button = null
var _betray_btn: Button = null
var _refuel_btn: Button = null
var _repair_btn: Button = null
var _undock_btn: Button = null
var _status_label: Label = null
var _trade_box: VBoxContainer = null
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
	EventBus.on_entity_standing_changed.connect(_on_entity_standing_changed)
	EventBus.on_credits_changed.connect(_on_wallet_changed)
	EventBus.on_fuel_changed.connect(_on_fuel_changed)
	EventBus.on_condition_changed.connect(_on_condition_changed)
	EventBus.on_cargo_changed.connect(_on_cargo_changed)


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
	_disconnect(EventBus.on_entity_standing_changed, _on_entity_standing_changed)
	_disconnect(EventBus.on_credits_changed, _on_wallet_changed)
	_disconnect(EventBus.on_fuel_changed, _on_fuel_changed)
	_disconnect(EventBus.on_condition_changed, _on_condition_changed)
	_disconnect(EventBus.on_cargo_changed, _on_cargo_changed)


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

	# Viewport-anchored height so the footer (Undock) is never clipped off-screen.
	_panel = PanelContainer.new()
	_panel.theme = DraywarUiTheme.build()
	_panel.clip_contents = true
	_panel.anchor_left = BalanceEconomy.STATION_MENU_ANCHOR_CENTER
	_panel.anchor_right = BalanceEconomy.STATION_MENU_ANCHOR_CENTER
	_panel.anchor_top = BalanceEconomy.STATION_MENU_ANCHOR_TOP
	_panel.anchor_bottom = BalanceEconomy.STATION_MENU_ANCHOR_BOTTOM
	_panel.offset_left = -BalanceEconomy.STATION_MENU_HALF_WIDTH_B3
	_panel.offset_right = BalanceEconomy.STATION_MENU_HALF_WIDTH_B3
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_panel)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_BEGIN
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(outer)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_title.text = "Station"
	outer.add_child(_title)

	_flavor_label = Label.new()
	_flavor_label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_flavor_label.text = ""
	_flavor_label.visible = false
	outer.add_child(_flavor_label)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_status_label.text = ""
	_status_label.visible = false
	outer.add_child(_status_label)

	# Body scrolls; footer Undock stays pinned below.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0.0, BalanceEconomy.STATION_MENU_SCROLL_MIN_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(_scroll)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Shrink-begin so content height drives scroll (expand would steal the bar).
	layout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.add_child(layout)

	var button_size: Vector2 = Vector2(
		BalanceFlight.STATION_MENU_BUTTON_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
	)

	# --- Jobs ---
	_add_section_header(layout, BalanceEconomy.STATION_SECTION_JOBS)
	_jobs_box = VBoxContainer.new()
	_jobs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_jobs_box)

	_turn_in_job_btn = _make_button(layout, button_size, BalanceEconomy.STATION_TURN_IN_JOB_LABEL)
	_turn_in_job_btn.pressed.connect(_on_turn_in_job_pressed)
	_turn_in_job_btn.visible = false

	_abandon_job_btn = _make_button(layout, button_size, BalanceEconomy.STATION_ABANDON_JOB_LABEL)
	_abandon_job_btn.pressed.connect(_on_abandon_job_pressed)
	_abandon_job_btn.visible = false

	# --- Services ---
	_add_section_header(layout, BalanceEconomy.STATION_SECTION_SERVICES)
	_refuel_btn = _make_button(layout, button_size, BalanceEconomy.STATION_REFUEL_LABEL)
	_refuel_btn.pressed.connect(_on_refuel_pressed)

	_repair_btn = _make_button(layout, button_size, BalanceEconomy.STATION_REPAIR_LABEL)
	_repair_btn.pressed.connect(_on_repair_pressed)

	# --- Trade ---
	_add_section_header(layout, BalanceEconomy.STATION_SECTION_TRADE)
	_trade_box = VBoxContainer.new()
	_trade_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_trade_box)

	# --- Contacts / recovery foothold (B5 drama when deep negative) ---
	_contacts_header = _add_section_header(layout, BalanceEconomy.STATION_SECTION_CONTACTS)
	_contacts_list = VBoxContainer.new()
	_contacts_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_contacts_list)
	_recovery_hint = Label.new()
	_recovery_hint.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_recovery_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recovery_hint.text = ""
	_recovery_hint.visible = false
	layout.add_child(_recovery_hint)

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

	# Footer always visible Ã¢â‚¬â€ leave dock without scrolling past trade/contacts.
	var undock_spacer: Control = Control.new()
	undock_spacer.custom_minimum_size = Vector2(0.0, BalanceEconomy.STATION_UNDOCK_SPACER)
	undock_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(undock_spacer)

	var undock_size: Vector2 = Vector2(
		(
			BalanceEconomy.STATION_MENU_WIDTH_B3
			- float(BalanceUi.CONTENT_MARGIN) * BalanceEconomy.STATION_MENU_SIDE_MARGINS
		),
		BalanceFlight.STATION_MENU_BUTTON_HEIGHT
	)
	_undock_btn = _make_button(outer, undock_size, BalanceEconomy.STATION_UNDOCK_LABEL)
	_undock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undock_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_undock_btn.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_undock_btn.pressed.connect(_on_undock_pressed)


## Undock control (tests / external readers). Always outside the scroll body.
func undock_button() -> Button:
	return _undock_btn


func _add_section_header(parent: Control, text: String) -> Label:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceEconomy.STATION_SECTION_SPACER)
	parent.add_child(spacer)
	var header: Label = Label.new()
	header.add_theme_color_override("font_color", BalanceUi.ACCENT)
	header.text = text
	parent.add_child(header)
	return header


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
	_refresh_flavor()
	_set_status("")
	# visible first so section refresh can show jobs/trade/services.
	visible = true
	_refresh_all()


func _on_undocked(_station_id: StringName) -> void:
	_docked_station_id = &""
	_offer_person_id = &""
	_favor_person_id = &""
	_active_recovery_person_id = &""
	if _flavor_label != null:
		_flavor_label.text = ""
		_flavor_label.visible = false
	_set_status("")
	if _recovery_hint != null:
		_recovery_hint.visible = false
		_recovery_hint.text = ""
	if _contacts_header != null:
		_contacts_header.text = BalanceEconomy.STATION_SECTION_CONTACTS
		_contacts_header.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_hide_action_buttons()
	_clear_trade_rows()
	visible = false


func _set_status(text: String) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.visible = not text.is_empty()


func _refresh_flavor() -> void:
	if _flavor_label == null:
		return
	var line: String = ""
	if ContentLibrary.has_item(_docked_station_id):
		var item: ContentItem = ContentLibrary.item(_docked_station_id)
		if item is Station:
			var station: Station = item as Station
			if not station.flavor_line.is_empty():
				line = station.flavor_line
			elif ContentLibrary.has_item(station.system_id):
				var sys_item: ContentItem = ContentLibrary.item(station.system_id)
				if sys_item is StarSystem:
					var system: StarSystem = sys_item as StarSystem
					if not system.flavor_line.is_empty():
						line = system.flavor_line
	_flavor_label.text = line
	_flavor_label.visible = not line.is_empty()


func _hide_action_buttons() -> void:
	_clear_jobs_box()
	_clear_contacts_list()
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


func _on_accept_job_pressed(template_id: StringName) -> void:
	if String(template_id).is_empty():
		return
	EventBus.on_mission_accept_requested.emit(template_id)


func _on_turn_in_job_pressed() -> void:
	# Prefer direct complete at this menu's docked station (no silent dock lookup miss).
	var service: Node = _mission_service_node()
	if service != null and service.has_method(&"try_complete_at"):
		var before_active: bool = _mission_is_active()
		var result_raw: Variant = service.call(&"try_complete_at", _docked_station_id)
		if typeof(result_raw) == TYPE_DICTIONARY:
			var result: Dictionary = result_raw
			var attributed: bool = result.get(BalanceStanding.REPORT_KEY_ATTRIBUTED, false) == true
			if attributed:
				var pay: int = 0
				if result.has(&"pay_credits"):
					pay = _variant_to_int(result[&"pay_credits"])
				elif result.has("pay_credits"):
					pay = _variant_to_int(result["pay_credits"])
				_set_status(BalanceEconomy.STATION_TURN_IN_OK_FORMAT % pay)
				_refresh_all()
				return
		if before_active and _mission_is_active():
			_set_status(_turn_in_block_reason())
			return
		if not before_active:
			_set_status(BalanceEconomy.STATION_TURN_IN_NO_JOB)
			return
	# Fallback: EventBus (console / tests).
	EventBus.on_mission_complete_requested.emit()
	_refresh_all()


func _turn_in_block_reason() -> String:
	var dest_id: StringName = &""
	var service: Node = _mission_service_node()
	if service != null and service.has_method(&"active_destination_station_id"):
		dest_id = _variant_to_name(service.call(&"active_destination_station_id"))
	if not String(dest_id).is_empty() and dest_id != _docked_station_id:
		return BalanceEconomy.STATION_TURN_IN_WRONG_STATION_FORMAT % _content_name(dest_id)
	return BalanceEconomy.STATION_TURN_IN_FAILED


func _mission_service_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"mission_service")


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


func _on_entity_standing_changed(
	_entity_id: StringName, _old_value: float, _new_value: float, _tier: StringName
) -> void:
	if visible:
		_refresh_recovery_buttons()


func _on_wallet_changed(_credits: int) -> void:
	if visible:
		_refresh_services()
		_refresh_trade()


func _on_fuel_changed(_fuel: float, _fuel_max: float) -> void:
	if visible:
		_refresh_services()


func _on_condition_changed(_condition: float, _condition_max: float) -> void:
	if visible:
		_refresh_services()


func _on_cargo_changed() -> void:
	if visible:
		_refresh_trade()


func _refresh_all() -> void:
	_refresh_job_buttons()
	_refresh_contacts_list()
	_refresh_recovery_buttons()
	_refresh_services()
	_refresh_trade()


func _refresh_job_buttons() -> void:
	if _jobs_box == null:
		return
	_clear_jobs_box()
	var mission_busy: bool = _mission_is_active()
	if visible and not mission_busy:
		var button_size: Vector2 = Vector2(
			BalanceFlight.STATION_MENU_BUTTON_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
		)
		for template_id: StringName in _offered_templates_for_dock():
			var btn: Button = _make_button(_jobs_box, button_size, _accept_job_label(template_id))
			btn.pressed.connect(_on_accept_job_pressed.bind(template_id))
	var can_turn_in: bool = mission_busy and _mission_can_complete_here()
	_turn_in_job_btn.visible = can_turn_in and visible
	_abandon_job_btn.visible = mission_busy and visible


func _clear_jobs_box() -> void:
	if _jobs_box == null:
		return
	# free() not queue_free(): refresh rebuilds children in the same frame.
	while _jobs_box.get_child_count() > 0:
		var child: Node = _jobs_box.get_child(0)
		_jobs_box.remove_child(child)
		child.free()


func _accept_job_label(template_id: StringName) -> String:
	if String(template_id).is_empty() or not ContentLibrary.has_item(template_id):
		return BalanceStanding.STATION_ACCEPT_JOB_LABEL
	var item: ContentItem = ContentLibrary.item(template_id)
	var kind: StringName = _variant_to_name(item.get("kind"))
	if kind == BalanceStanding.MISSION_KIND_BOUNTY:
		var target_id: StringName = _variant_to_name(item.get("target_system_id"))
		if String(target_id).is_empty():
			return BalanceStanding.STATION_ACCEPT_BOUNTY_LABEL
		return BalanceStanding.STATION_ACCEPT_BOUNTY_FORMAT % _content_name(target_id)
	var dest_id: StringName = _variant_to_name(item.get("destination_station_id"))
	if String(dest_id).is_empty():
		return BalanceStanding.STATION_ACCEPT_JOB_LABEL
	return BalanceStanding.STATION_ACCEPT_JOB_TO_FORMAT % _content_name(dest_id)


func _refresh_contacts_list() -> void:
	if _contacts_list == null:
		return
	_clear_contacts_list()
	if not visible:
		return
	var controller: StringName = _dock_controller()
	if String(controller).is_empty():
		return
	for person_id: StringName in ContentLibrary.ids_in(&"people"):
		var item: ContentItem = ContentLibrary.item(person_id)
		if item == null or not (item is Person):
			continue
		var person: Person = item as Person
		if person.primary_entity_id != controller:
			continue
		var line: Label = Label.new()
		line.text = (
			BalanceEconomy.STATION_CONTACT_LINE_FORMAT % [person.display_name, String(person.rank)]
		)
		line.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_contacts_list.add_child(line)


func _clear_contacts_list() -> void:
	if _contacts_list == null:
		return
	while _contacts_list.get_child_count() > 0:
		var child: Node = _contacts_list.get_child(0)
		_contacts_list.remove_child(child)
		child.free()


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

	var deep_negative: bool = _is_deep_negative_with_controller()
	var drama_person: StringName = _favor_person_id
	if String(drama_person).is_empty():
		drama_person = _offer_person_id
	_refresh_recovery_drama_header(deep_negative, drama_person)

	var offer_visible: bool = (
		not String(_offer_person_id).is_empty() and not recovery_busy and visible
	)
	_recovery_btn.visible = offer_visible
	if offer_visible:
		_recovery_btn.text = (
			BalanceStanding.STATION_RECOVERY_TALK_FORMAT % _content_name(_offer_person_id)
		)

	_complete_recovery_btn.visible = recovery_busy and visible
	if _complete_recovery_btn.visible and not String(_active_recovery_person_id).is_empty():
		_complete_recovery_btn.text = (
			"%s Ã¢â‚¬â€ %s"
			% [
				BalanceEconomy.STATION_COMPLETE_RECOVERY_LABEL,
				_content_name(_active_recovery_person_id),
			]
		)
	else:
		_complete_recovery_btn.text = BalanceEconomy.STATION_COMPLETE_RECOVERY_LABEL

	_abandon_recovery_btn.visible = recovery_busy and visible

	# Deep-negative path: always surface the recovery contact by name via favor.
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


func _refresh_recovery_drama_header(deep_negative: bool, person_id: StringName) -> void:
	if _contacts_header == null:
		return
	if deep_negative and not String(person_id).is_empty() and visible:
		_contacts_header.text = BalanceEconomy.STATION_SECTION_RECOVERY_DRAMA
		_contacts_header.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
		if _recovery_hint != null:
			_recovery_hint.text = (
				BalanceEconomy.STATION_RECOVERY_DRAMA_HINT_FORMAT % _content_name(person_id)
			)
			_recovery_hint.visible = true
	else:
		_contacts_header.text = BalanceEconomy.STATION_SECTION_CONTACTS
		_contacts_header.add_theme_color_override("font_color", BalanceUi.ACCENT)
		if _recovery_hint != null:
			_recovery_hint.text = ""
			_recovery_hint.visible = false


## Sticky-deep with the dock controller (hostile hole Ã¢â‚¬â€ recovery foothold path).
func _is_deep_negative_with_controller() -> bool:
	var controller: StringName = _dock_controller()
	if String(controller).is_empty():
		return false
	return StandingService.get_entity_standing(controller) <= BalanceStanding.STICKY_NEGATIVE_FLOOR


func _refresh_services() -> void:
	if _refuel_btn == null:
		return
	# Always show while docked; wallet refuses if full/broke.
	_refuel_btn.visible = visible
	_repair_btn.visible = visible


func _clear_trade_rows() -> void:
	if _trade_box == null:
		return
	for child: Node in _trade_box.get_children():
		child.queue_free()


func _refresh_trade() -> void:
	if _trade_box == null:
		return
	_clear_trade_rows()
	if not visible:
		return
	var cargo: Node = _cargo_service()
	var system_id: StringName = _dock_system_id()
	for commodity_id: StringName in ContentLibrary.ids_in(
		BalanceEconomy.COMMODITY_CONTENT_CATEGORY
	):
		if not ContentLibrary.has_item(commodity_id):
			continue
		var item: ContentItem = ContentLibrary.item(commodity_id)
		if not (item is Commodity):
			continue
		var commodity: Commodity = item as Commodity
		var hold: int = 0
		if cargo != null and cargo.has_method(&"quantity"):
			hold = _variant_to_int(cargo.call(&"quantity", commodity_id))
		var buy_price: int = BalanceEconomy.buy_price_at(commodity, system_id)
		var sell_price: int = BalanceEconomy.sell_price_at(commodity, system_id)
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_trade_box.add_child(row)

		var line: Label = Label.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = (
			BalanceEconomy.STATION_TRADE_LINE_FORMAT
			% [
				commodity.display_name,
				buy_price,
				sell_price,
				hold,
			]
		)
		row.add_child(line)

		var buy_btn: Button = Button.new()
		buy_btn.text = BalanceEconomy.STATION_TRADE_BUY_LABEL
		buy_btn.custom_minimum_size = Vector2(
			BalanceEconomy.STATION_TRADE_BUTTON_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
		)
		var can_buy: bool = false
		if cargo != null and cargo.has_method(&"can_buy"):
			can_buy = cargo.call(&"can_buy", commodity_id, BalanceEconomy.TRADE_QTY_UNIT) == true
		buy_btn.disabled = not can_buy
		buy_btn.pressed.connect(_on_trade_buy_pressed.bind(commodity_id))
		row.add_child(buy_btn)

		var sell_btn: Button = Button.new()
		sell_btn.text = BalanceEconomy.STATION_TRADE_SELL_LABEL
		sell_btn.custom_minimum_size = Vector2(
			BalanceEconomy.STATION_TRADE_BUTTON_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
		)
		var can_sell: bool = false
		if cargo != null and cargo.has_method(&"can_sell"):
			can_sell = cargo.call(&"can_sell", commodity_id, BalanceEconomy.TRADE_QTY_UNIT) == true
		sell_btn.disabled = not can_sell
		sell_btn.pressed.connect(_on_trade_sell_pressed.bind(commodity_id))
		row.add_child(sell_btn)


func _on_trade_buy_pressed(commodity_id: StringName) -> void:
	EventBus.on_trade_buy_requested.emit(commodity_id, BalanceEconomy.TRADE_QTY_UNIT)


func _on_trade_sell_pressed(commodity_id: StringName) -> void:
	EventBus.on_trade_sell_requested.emit(commodity_id, BalanceEconomy.TRADE_QTY_UNIT)


func _cargo_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"cargo_service")


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


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


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


## First offered template for this dock (legacy single-pick callers / tests).
func _offered_template_for_dock() -> StringName:
	var offered: Array[StringName] = _offered_templates_for_dock()
	if offered.is_empty():
		return &""
	return offered[0]


## All contract templates offered by the dock controller (board stock).
func _offered_templates_for_dock() -> Array[StringName]:
	var out: Array[StringName] = []
	if String(_docked_station_id).is_empty():
		return out
	if not ContentLibrary.has_item(_docked_station_id):
		return out
	var station_item: ContentItem = ContentLibrary.item(_docked_station_id)
	if not (station_item is Station):
		return out
	var station: Station = station_item as Station
	var controller: StringName = station.controller_entity_id
	if controller == Station.CONTROLLER_NOBODY or String(controller).is_empty():
		return out
	for id: StringName in ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY):
		var item: ContentItem = ContentLibrary.item(id)
		if item == null:
			continue
		var offering_raw: Variant = item.get("offering_entity_id")
		if offering_raw == null:
			continue
		var offering: StringName = StringName(str(offering_raw))
		if offering == controller:
			out.append(id)
	return out


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
			# Already offerable Ã¢â‚¬â€ talk button covers it; favor still ok for top-up.
			return person_id
		return person_id
	return &""


func _dock_controller() -> StringName:
	var station: Station = _docked_station()
	if station == null:
		return &""
	var controller: StringName = station.controller_entity_id
	if controller == Station.CONTROLLER_NOBODY or String(controller).is_empty():
		return &""
	return controller


func _dock_system_id() -> StringName:
	var station: Station = _docked_station()
	if station == null:
		return &""
	return station.system_id


func _docked_station() -> Station:
	if String(_docked_station_id).is_empty() or not ContentLibrary.has_item(_docked_station_id):
		return null
	var station_item: ContentItem = ContentLibrary.item(_docked_station_id)
	if station_item is Station:
		return station_item as Station
	return null


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
