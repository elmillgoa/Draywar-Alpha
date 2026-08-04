class_name StationMenu
extends CanvasLayer

## Station menu â€” jobs, services, outfitting, ops, trade, contacts (EventBus only).

const StationHullUiScript = preload("res://src/ui/station/StationHullUi.gd")
const StationOutfitUiScript = preload("res://src/ui/station/StationOutfitUi.gd")
const StationOpsUiScript = preload("res://src/ui/station/StationOpsUi.gd")
const StationCampaignUiScript = preload("res://src/ui/station/StationCampaignUi.gd")
const StationHoldingUiScript = preload("res://src/ui/station/StationHoldingUi.gd")
const StationTradeUiScript = preload("res://src/ui/station/StationTradeUi.gd")
const StationBoardUiScript = preload("res://src/ui/station/StationBoardUi.gd")
const StationLoanUiScript = preload("res://src/ui/station/StationLoanUi.gd")
const StationNewsUiScript = preload("res://src/ui/station/StationNewsUi.gd")
const Chrome = preload("res://src/ui/station/StationMenuChrome.gd")

var _panel: PanelContainer = null
var _title: Label = null
var _flavor_label: Label = null
## One-line sector headline, pinned above the scrolling body (S2 ticker).
var _news_label: Label = null
var _scroll: ScrollContainer = null
## Dynamic accept-job buttons (one per offered template for the dock controller).
var _jobs_box: VBoxContainer = null
var _turn_in_job_btn: Button = null
var _abandon_job_btn: Button = null
var _contacts_header: Label = null
## Named people for the dock controller (Contacts list â€” E1.2).
var _contacts_list: VBoxContainer = null
var _recovery_hint: Label = null
var _recovery_btn: Button = null
var _complete_recovery_btn: Button = null
var _abandon_recovery_btn: Button = null
var _favor_btn: Button = null
var _betray_btn: Button = null
var _refuel_btn: Button = null
var _repair_btn: Button = null
var _borrow_btn: Button = null
var _repay_btn: Button = null
var _buy_fighter_btn: Button = null
var _switch_hull_btn: Button = null
var _outfit_box: VBoxContainer = null
var _ops_box: VBoxContainer = null
var _story_box: VBoxContainer = null
var _holding_box: VBoxContainer = null
var _dock_fee_label: Label = null
var _undock_btn: Button = null
var _status_label: Label = null
var _trade_box: VBoxContainer = null
var _trade_denied_label: Label = null
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
	EventBus.on_debt_changed.connect(_on_debt_changed)
	EventBus.on_fuel_changed.connect(_on_fuel_changed)
	EventBus.on_condition_changed.connect(_on_condition_changed)
	EventBus.on_cargo_changed.connect(_on_cargo_changed)
	EventBus.on_hull_purchased.connect(_on_hull_purchased)
	EventBus.on_hull_changed.connect(_on_hull_changed)
	EventBus.on_loadout_changed.connect(_on_loadout_changed)
	EventBus.on_market_news.connect(_on_market_news)
	EventBus.on_market_ticked.connect(_on_market_ticked)
	EventBus.on_market_changed.connect(_on_market_changed)
	StationOpsUiScript.connect_refresh(_request_ops_refresh)
	StationCampaignUiScript.connect_refresh(_request_story_refresh)
	StationHoldingUiScript.connect_refresh(_request_holding_refresh)


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
	_disconnect(EventBus.on_debt_changed, _on_debt_changed)
	_disconnect(EventBus.on_fuel_changed, _on_fuel_changed)
	_disconnect(EventBus.on_condition_changed, _on_condition_changed)
	_disconnect(EventBus.on_cargo_changed, _on_cargo_changed)
	_disconnect(EventBus.on_hull_purchased, _on_hull_purchased)
	_disconnect(EventBus.on_hull_changed, _on_hull_changed)
	_disconnect(EventBus.on_loadout_changed, _on_loadout_changed)
	_disconnect(EventBus.on_market_news, _on_market_news)
	_disconnect(EventBus.on_market_ticked, _on_market_ticked)
	_disconnect(EventBus.on_market_changed, _on_market_changed)
	StationOpsUiScript.disconnect_refresh(_request_ops_refresh)
	StationCampaignUiScript.disconnect_refresh(_request_story_refresh)
	StationHoldingUiScript.disconnect_refresh(_request_holding_refresh)


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

	_news_label = StationNewsUiScript.make_label(outer)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_status_label.text = ""
	_status_label.visible = false
	outer.add_child(_status_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0.0, BalanceEconomy.STATION_MENU_SCROLL_MIN_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(_scroll)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.add_child(layout)

	var button_size: Vector2 = Vector2(
		BalanceFlight.STATION_MENU_BUTTON_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
	)

	_story_box = StationCampaignUiScript.make_box(layout)

	Chrome.add_section_header(layout, BalanceEconomy.STATION_SECTION_JOBS)
	_jobs_box = VBoxContainer.new()
	_jobs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_jobs_box)

	_turn_in_job_btn = Chrome.make_button(
		layout, button_size, BalanceEconomy.STATION_TURN_IN_JOB_LABEL
	)
	_turn_in_job_btn.pressed.connect(_on_turn_in_job_pressed)
	_turn_in_job_btn.visible = false

	_abandon_job_btn = Chrome.make_button(
		layout, button_size, BalanceEconomy.STATION_ABANDON_JOB_LABEL
	)
	_abandon_job_btn.pressed.connect(_on_abandon_job_pressed)
	_abandon_job_btn.visible = false

	Chrome.add_section_header(layout, BalanceEconomy.STATION_SECTION_SERVICES)
	_dock_fee_label = Label.new()
	_dock_fee_label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	_dock_fee_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock_fee_label.text = ""
	_dock_fee_label.visible = false
	layout.add_child(_dock_fee_label)

	_refuel_btn = Chrome.make_button(layout, button_size, BalanceEconomy.STATION_REFUEL_LABEL)
	_refuel_btn.pressed.connect(_on_refuel_pressed)

	_repair_btn = Chrome.make_button(layout, button_size, BalanceEconomy.STATION_REPAIR_LABEL)
	_repair_btn.pressed.connect(_on_repair_pressed)

	var loan_btns: Array[Button] = StationLoanUiScript.make_buttons(layout, button_size)
	_borrow_btn = loan_btns[0]
	_repay_btn = loan_btns[1]
	_borrow_btn.pressed.connect(_on_borrow_pressed)
	_repay_btn.pressed.connect(_on_repay_pressed)

	_buy_fighter_btn = Chrome.make_button(
		layout,
		button_size,
		BalanceEconomy.STATION_BUY_FIGHTER_FORMAT % BalanceEconomy.FIGHTER_PURCHASE_COST
	)
	_buy_fighter_btn.pressed.connect(_on_buy_fighter_pressed)
	_buy_fighter_btn.visible = false

	_switch_hull_btn = Chrome.make_button(layout, button_size, "Switch hull")
	_switch_hull_btn.pressed.connect(_on_switch_hull_pressed)
	_switch_hull_btn.visible = false

	_outfit_box = StationOutfitUiScript.make_box(layout)

	_ops_box = StationOpsUiScript.make_box(layout)

	_holding_box = StationHoldingUiScript.make_box(layout)

	Chrome.add_section_header(layout, BalanceEconomy.STATION_SECTION_TRADE)
	_trade_denied_label = Label.new()
	_trade_denied_label.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_trade_denied_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_denied_label.text = BalanceEconomy.STATION_TRADE_DENIED_MESSAGE
	_trade_denied_label.visible = false
	layout.add_child(_trade_denied_label)
	_trade_box = VBoxContainer.new()
	_trade_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_trade_box)

	_contacts_header = Chrome.add_section_header(layout, BalanceEconomy.STATION_SECTION_CONTACTS)
	_contacts_list = VBoxContainer.new()
	_contacts_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_contacts_list)
	_recovery_hint = Label.new()
	_recovery_hint.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_recovery_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recovery_hint.text = ""
	_recovery_hint.visible = false
	layout.add_child(_recovery_hint)

	_recovery_btn = Chrome.make_button(layout, button_size, "Talk")
	_recovery_btn.pressed.connect(_on_recovery_pressed)
	_recovery_btn.visible = false

	_complete_recovery_btn = Chrome.make_button(
		layout, button_size, BalanceEconomy.STATION_COMPLETE_RECOVERY_LABEL
	)
	_complete_recovery_btn.pressed.connect(_on_complete_recovery_pressed)
	_complete_recovery_btn.visible = false

	_abandon_recovery_btn = Chrome.make_button(
		layout, button_size, BalanceEconomy.STATION_ABANDON_RECOVERY_LABEL
	)
	_abandon_recovery_btn.pressed.connect(_on_abandon_recovery_pressed)
	_abandon_recovery_btn.visible = false

	_favor_btn = Chrome.make_button(layout, button_size, "Ask favor")
	_favor_btn.pressed.connect(_on_favor_pressed)
	_favor_btn.visible = false

	_betray_btn = Chrome.make_button(layout, button_size, "Betray")
	_betray_btn.pressed.connect(_on_betray_pressed)
	_betray_btn.visible = false

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
	_undock_btn = Chrome.make_button(outer, undock_size, BalanceEconomy.STATION_UNDOCK_LABEL)
	_undock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undock_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_undock_btn.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_undock_btn.pressed.connect(_on_undock_pressed)


func undock_button() -> Button:
	return _undock_btn


func _on_docked(station_id: StringName) -> void:
	_docked_station_id = station_id
	_title.text = Chrome.content_name(station_id)
	_refresh_flavor()
	_set_status("")
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
	if _dock_fee_label != null:
		_dock_fee_label.visible = false
		_dock_fee_label.text = ""
	if _trade_denied_label != null:
		_trade_denied_label.visible = false
	visible = false
	_refresh_news()


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
					pay = StationDockQueries.as_int(result[&"pay_credits"])
				elif result.has("pay_credits"):
					pay = StationDockQueries.as_int(result["pay_credits"])
				_set_status(BalanceEconomy.STATION_TURN_IN_OK_FORMAT % pay)
				_refresh_all()
				return
		if before_active and _mission_is_active():
			_set_status(_turn_in_block_reason())
			return
		if not before_active:
			_set_status(BalanceEconomy.STATION_TURN_IN_NO_JOB)
			return
	EventBus.on_mission_complete_requested.emit()
	_refresh_all()


func _turn_in_block_reason() -> String:
	var dest_id: StringName = &""
	var service: Node = _mission_service_node()
	if service != null and service.has_method(&"active_destination_station_id"):
		dest_id = StationDockQueries.as_name(service.call(&"active_destination_station_id"))
	if not String(dest_id).is_empty() and dest_id != _docked_station_id:
		return BalanceEconomy.STATION_TURN_IN_WRONG_STATION_FORMAT % Chrome.content_name(dest_id)
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


func _on_borrow_pressed() -> void:
	EventBus.on_loan_borrow_requested.emit()
	call_deferred(&"_after_borrow")


func _after_borrow() -> void:
	_set_status(StationLoanUiScript.borrow_status_text(_wallet_service()))
	_refresh_services()


func _on_repay_pressed() -> void:
	var before_owed: int = StationLoanUiScript.debt_owed_from_wallet(_wallet_service())
	if before_owed <= 0:
		call_deferred(&"_refresh_services")
		return
	EventBus.on_loan_repay_requested.emit()
	call_deferred(&"_after_repay", before_owed)


func _after_repay(before_owed: int) -> void:
	_set_status(StationLoanUiScript.repay_status_text(before_owed, _wallet_service()))
	_refresh_services()


func _on_buy_fighter_pressed() -> void:
	var ships: Node = _ship_service()
	if ships == null or StationHullUiScript.owns_fighter(ships):
		return
	if not StationHullUiScript.can_buy_fighter(ships):
		_set_status(BalanceEconomy.STATION_BUY_FIGHTER_BROKE)
		return
	EventBus.on_buy_fighter_requested.emit()
	call_deferred(&"_after_buy_fighter")


func _after_buy_fighter() -> void:
	var ships: Node = _ship_service()
	if StationHullUiScript.owns_fighter(ships):
		_set_status(BalanceEconomy.STATION_BUY_FIGHTER_OK)
	else:
		_set_status(BalanceEconomy.STATION_BUY_FIGHTER_BROKE)
	_refresh_services()


func _on_switch_hull_pressed() -> void:
	var ships: Node = _ship_service()
	if ships == null:
		return
	var target: StringName = StationHullUiScript.switch_target_hull_id(ships)
	if String(target).is_empty():
		return
	if not StationHullUiScript.can_switch_to(ships, target):
		_set_status(BalanceEconomy.STATION_SWITCH_BLOCKED_CARGO)
		call_deferred(&"_refresh_services")
		return
	EventBus.on_switch_hull_requested.emit(target)
	call_deferred(&"_after_switch_hull", target)


func _after_switch_hull(target: StringName) -> void:
	var ships: Node = _ship_service()
	if ships != null and ships.has_method(&"active_hull_id"):
		var active: StringName = StationDockQueries.as_name(ships.call(&"active_hull_id"))
		if active == target:
			_set_status(BalanceEconomy.STATION_SWITCH_OK_FORMAT % Chrome.content_name(target))
		else:
			_set_status(BalanceEconomy.STATION_SWITCH_FAILED)
	_refresh_services()
	_refresh_trade()


func _on_mission_accepted(_template_id: StringName, _entity_id: StringName) -> void:
	# rebuilding the jobs box must not free that button mid-signal.
	call_deferred(&"_refresh_all")


func _on_mission_closed(_template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	call_deferred(&"_refresh_all")


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
		call_deferred(&"_refresh_trade")
		call_deferred(&"_refresh_ops")


func _on_debt_changed(_debt_owed: int, _lender_id: StringName, _grace_docks_left: int) -> void:
	if visible:
		call_deferred(&"_refresh_services")


func _on_fuel_changed(_fuel: float, _fuel_max: float) -> void:
	if visible:
		_refresh_services()


func _on_condition_changed(_condition: float, _condition_max: float) -> void:
	if visible:
		_refresh_services()


func _on_cargo_changed() -> void:
	if visible:
		call_deferred(&"_refresh_trade")
		call_deferred(&"_refresh_ops")
		_refresh_services()


func _on_hull_purchased(_hull_id: StringName) -> void:
	if visible:
		call_deferred(&"_refresh_services")


func _on_hull_changed(_old_hull_id: StringName, _new_hull_id: StringName) -> void:
	if visible:
		call_deferred(&"_refresh_services")
		call_deferred(&"_refresh_trade")


func _on_loadout_changed(_hull_id: StringName) -> void:
	if visible:
		call_deferred(&"_refresh_services")


func _on_market_news(_line: String) -> void:
	_refresh_news()


func _on_market_ticked(_steps_applied: int, _elapsed_seconds: float) -> void:
	if visible:
		_refresh_news()
		call_deferred(&"_refresh_trade")


func _on_market_changed(
	_station_id: StringName, _commodity_id: StringName, _stock: int, _unit_buy_price: int
) -> void:
	if visible:
		call_deferred(&"_refresh_trade")


func _refresh_news() -> void:
	StationNewsUiScript.refresh(_news_label, visible)


func _refresh_all() -> void:
	_refresh_story()
	_refresh_job_buttons()
	_refresh_contacts_list()
	_refresh_recovery_buttons()
	_refresh_services()
	_refresh_ops()
	_refresh_holding()
	_refresh_news()
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
			var btn: Button = Chrome.make_button(
				_jobs_box, button_size, _accept_job_label(template_id)
			)
			btn.pressed.connect(_on_accept_job_pressed.bind(template_id))
	var can_turn_in: bool = mission_busy and _mission_can_complete_here()
	_turn_in_job_btn.visible = can_turn_in and visible
	_abandon_job_btn.visible = mission_busy and visible


func _clear_jobs_box() -> void:
	StationBoardUiScript.clear_box(_jobs_box)


func _accept_job_label(template_id: StringName) -> String:
	return StationBoardUiScript.accept_job_label(template_id)


func _refresh_contacts_list() -> void:
	StationBoardUiScript.refresh_contacts(_contacts_list, _dock_controller(), visible)


func _clear_contacts_list() -> void:
	StationBoardUiScript.clear_box(_contacts_list)


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

	var deep_negative: bool = StationDockQueries.is_deep_negative_with_controller(
		_docked_station_id
	)
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
			BalanceStanding.STATION_RECOVERY_TALK_FORMAT % Chrome.content_name(_offer_person_id)
		)

	_complete_recovery_btn.visible = recovery_busy and visible
	if _complete_recovery_btn.visible and not String(_active_recovery_person_id).is_empty():
		_complete_recovery_btn.text = (
			BalanceEconomy.STATION_CONTACT_LINE_FORMAT
			% [
				BalanceEconomy.STATION_COMPLETE_RECOVERY_LABEL,
				Chrome.content_name(_active_recovery_person_id),
			]
		)
	else:
		_complete_recovery_btn.text = BalanceEconomy.STATION_COMPLETE_RECOVERY_LABEL

	_abandon_recovery_btn.visible = recovery_busy and visible

	var favor_visible: bool = (
		not String(_favor_person_id).is_empty() and not recovery_busy and visible
	)
	_favor_btn.visible = favor_visible
	if favor_visible:
		_favor_btn.text = (
			BalanceEconomy.STATION_ASK_FAVOR_FORMAT % Chrome.content_name(_favor_person_id)
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
		_betray_btn.text = (
			BalanceEconomy.STATION_BETRAY_FORMAT % Chrome.content_name(betray_target)
		)
		_active_recovery_person_id = betray_target


func _refresh_recovery_drama_header(deep_negative: bool, person_id: StringName) -> void:
	if _contacts_header == null:
		return
	if deep_negative and not String(person_id).is_empty() and visible:
		_contacts_header.text = BalanceEconomy.STATION_SECTION_RECOVERY_DRAMA
		_contacts_header.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
		if _recovery_hint != null:
			_recovery_hint.text = (
				BalanceEconomy.STATION_RECOVERY_DRAMA_HINT_FORMAT % Chrome.content_name(person_id)
			)
			_recovery_hint.visible = true
	else:
		_contacts_header.text = BalanceEconomy.STATION_SECTION_CONTACTS
		_contacts_header.add_theme_color_override("font_color", BalanceUi.ACCENT)
		if _recovery_hint != null:
			_recovery_hint.text = ""
			_recovery_hint.visible = false


func _refresh_services() -> void:
	if _refuel_btn == null:
		return
	StationLoanUiScript.refresh_core_services(
		_refuel_btn,
		_repair_btn,
		_dock_fee_label,
		_borrow_btn,
		_repay_btn,
		_wallet_service(),
		_docked_station_id,
		visible
	)
	StationHullUiScript.refresh_buttons(
		_buy_fighter_btn, _switch_hull_btn, _ship_service(), visible
	)
	StationOutfitUiScript.refresh_box(_outfit_box, _ship_service(), _wallet_service(), visible)


func _refresh_ops() -> void:
	if _ops_box == null:
		return
	var tree: SceneTree = get_tree()
	var ops: Node = null
	if tree != null:
		ops = tree.get_first_node_in_group(BalanceOps.GROUP_OPERATION_SERVICE)
	StationOpsUiScript.refresh_box(_ops_box, ops, _cargo_service(), _docked_station_id, visible)


func _request_ops_refresh() -> void:
	if visible:
		call_deferred(&"_refresh_ops")


func _refresh_story() -> void:
	if _story_box == null:
		return
	StationCampaignUiScript.refresh_for_tree(_story_box, get_tree(), _docked_station_id, visible)


func _request_story_refresh() -> void:
	if visible:
		call_deferred(&"_refresh_story")


func _refresh_holding() -> void:
	if _holding_box != null:
		StationHoldingUiScript.refresh_for_tree(
			_holding_box, get_tree(), _docked_station_id, visible
		)


func _request_holding_refresh() -> void:
	if visible:
		call_deferred(&"_refresh_holding")


func _clear_trade_rows() -> void:
	StationTradeUiScript.clear_rows(_trade_box)


func _refresh_trade() -> void:
	StationTradeUiScript.refresh(
		_trade_box,
		_trade_denied_label,
		_cargo_service(),
		visible,
		_on_trade_buy_pressed,
		_on_trade_sell_pressed
	)


func _on_trade_buy_pressed(commodity_id: StringName, units: int) -> void:
	EventBus.on_trade_buy_requested.emit(commodity_id, units)
	call_deferred(&"_refresh_trade")


func _on_trade_sell_pressed(commodity_id: StringName, units: int) -> void:
	EventBus.on_trade_sell_requested.emit(commodity_id, units)
	call_deferred(&"_refresh_trade")


func _cargo_service() -> Node:
	return _node_in_group(&"cargo_service")


func _wallet_service() -> Node:
	return _node_in_group(&"wallet_service")


func _ship_service() -> Node:
	return _node_in_group(BalanceFlight.GROUP_SHIP_SERVICE)


func _mission_is_active() -> bool:
	return _group_bool(&"mission_service", &"has_active")


func _mission_can_complete_here() -> bool:
	var service: Node = _node_in_group(&"mission_service")
	if service == null or not service.has_method(&"can_complete_at_station"):
		return false
	return service.call(&"can_complete_at_station", _docked_station_id) == true


func _recovery_is_active() -> bool:
	return _group_bool(&"recovery_service", &"has_active")


func _active_recovery_person() -> StringName:
	return StationDockQueries.active_recovery_person(_node_in_group(&"recovery_service"))


func _group_bool(group: StringName, method: StringName) -> bool:
	var service: Node = _node_in_group(group)
	if service == null or not service.has_method(method):
		return false
	return service.call(method) == true


func _node_in_group(group: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(group)


## First offered template for this dock (legacy single-pick callers / tests).
func _offered_template_for_dock() -> StringName:
	var offered: Array[StringName] = _offered_templates_for_dock()
	if offered.is_empty():
		return &""
	return offered[0]


func _offered_templates_for_dock() -> Array[StringName]:
	return StationDockQueries.offered_templates(_docked_station_id)


func _offered_recovery_person_for_dock() -> StringName:
	return StationDockQueries.offered_recovery_person(
		_docked_station_id, _node_in_group(&"recovery_service")
	)


func _favor_person_for_dock() -> StringName:
	return StationDockQueries.favor_person(_docked_station_id)


func _dock_controller() -> StringName:
	return StationDockQueries.controller(_docked_station_id)


func _docked_station() -> Station:
	return StationDockQueries.station_resource(_docked_station_id)
