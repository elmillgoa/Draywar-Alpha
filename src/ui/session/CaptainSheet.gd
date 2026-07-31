class_name CaptainSheet
extends CanvasLayer

## Read-only captain sheet — Path C B2.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B2
##
## Ship, credits, fuel, hull, active job + destination, local status, top
## entity standings. Standing is display-only (StandingService is the writer).

var _panel: PanelContainer = null
var _origin_label: Label = null
var _trade_label: Label = null
var _mark_label: Label = null
var _ship_label: Label = null
var _credits_label: Label = null
var _debt_label: Label = null
var _cargo_label: Label = null
var _fuel_label: Label = null
var _hull_label: Label = null
var _job_label: Label = null
var _job_status_label: Label = null
var _status_label: Label = null
var _standing_box: VBoxContainer = null


func _ready() -> void:
	layer = BalanceSession.CAPTAIN_SHEET_CANVAS_LAYER
	visible = false
	_build_ui()
	EventBus.on_captain_sheet_open_requested.connect(_on_open_requested)
	EventBus.on_captain_sheet_close_requested.connect(_on_close_requested)
	EventBus.on_cargo_changed.connect(_on_cargo_changed)
	EventBus.on_credits_changed.connect(_on_credits_changed)
	EventBus.on_debt_changed.connect(_on_debt_changed)
	EventBus.on_hull_changed.connect(_on_hull_changed)
	EventBus.on_hull_purchased.connect(_on_hull_purchased)


func _exit_tree() -> void:
	if EventBus.on_captain_sheet_open_requested.is_connected(_on_open_requested):
		EventBus.on_captain_sheet_open_requested.disconnect(_on_open_requested)
	if EventBus.on_captain_sheet_close_requested.is_connected(_on_close_requested):
		EventBus.on_captain_sheet_close_requested.disconnect(_on_close_requested)
	if EventBus.on_cargo_changed.is_connected(_on_cargo_changed):
		EventBus.on_cargo_changed.disconnect(_on_cargo_changed)
	if EventBus.on_credits_changed.is_connected(_on_credits_changed):
		EventBus.on_credits_changed.disconnect(_on_credits_changed)
	if EventBus.on_debt_changed.is_connected(_on_debt_changed):
		EventBus.on_debt_changed.disconnect(_on_debt_changed)
	if EventBus.on_hull_changed.is_connected(_on_hull_changed):
		EventBus.on_hull_changed.disconnect(_on_hull_changed)
	if EventBus.on_hull_purchased.is_connected(_on_hull_purchased):
		EventBus.on_hull_purchased.disconnect(_on_hull_purchased)


func _on_open_requested() -> void:
	_refresh()
	visible = true


func _on_close_requested() -> void:
	visible = false


func _on_cargo_changed() -> void:
	if visible:
		_refresh_wallet()


func _on_credits_changed(_credits: int) -> void:
	if visible:
		_refresh_wallet()


func _on_debt_changed(_debt_owed: int, _lender_id: StringName, _grace_docks_left: int) -> void:
	if visible:
		_refresh_wallet()


func _on_hull_changed(_old_hull_id: StringName, _new_hull_id: StringName) -> void:
	if visible:
		_refresh()


func _on_hull_purchased(_hull_id: StringName) -> void:
	if visible:
		_refresh()


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, BalanceSession.MENU_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.theme = DraywarUiTheme.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(BalanceSession.SHEET_WIDTH, BalanceSession.SHEET_HEIGHT)
	_panel.offset_left = -BalanceSession.SHEET_HALF_WIDTH
	_panel.offset_top = -BalanceSession.SHEET_HALF_HEIGHT
	_panel.offset_right = BalanceSession.SHEET_HALF_WIDTH
	_panel.offset_bottom = BalanceSession.SHEET_HALF_HEIGHT
	root.add_child(_panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_BEGIN
	_panel.add_child(layout)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = BalanceSession.SHEET_TITLE
	layout.add_child(title)

	_origin_label = _add_line(layout)
	_trade_label = _add_line(layout)
	_mark_label = _add_line(layout)
	_ship_label = _add_line(layout)
	_credits_label = _add_line(layout)
	_debt_label = _add_line(layout)
	_cargo_label = _add_line(layout)
	_fuel_label = _add_line(layout)
	_hull_label = _add_line(layout)
	_job_label = _add_line(layout)
	_job_status_label = _add_line(layout)
	_status_label = _add_line(layout)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceSession.SHEET_SPACER_HEIGHT)
	layout.add_child(spacer)

	var standing_header: Label = Label.new()
	standing_header.add_theme_color_override("font_color", BalanceUi.ACCENT)
	standing_header.text = BalanceSession.SHEET_STANDING_HEADER
	layout.add_child(standing_header)

	_standing_box = VBoxContainer.new()
	layout.add_child(_standing_box)

	var close_spacer: Control = Control.new()
	close_spacer.custom_minimum_size = Vector2(0.0, BalanceSession.SHEET_SPACER_HEIGHT)
	layout.add_child(close_spacer)

	var close_btn: Button = Button.new()
	close_btn.text = BalanceSession.SHEET_CLOSE
	close_btn.custom_minimum_size = Vector2(
		BalanceSession.SHEET_BUTTON_WIDTH, BalanceSession.SHEET_BUTTON_HEIGHT
	)
	close_btn.pressed.connect(_on_close_pressed)
	layout.add_child(close_btn)


func _add_line(parent: Control) -> Label:
	var label: Label = Label.new()
	label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _on_close_pressed() -> void:
	EventBus.on_captain_sheet_close_requested.emit()


func _refresh() -> void:
	_refresh_life_path()
	_ship_label.text = BalanceSession.SHEET_SHIP_FORMAT % _ship_display_name()
	_refresh_wallet()
	_refresh_job()
	_refresh_status()
	_refresh_standings()


## Origin / Trade / Mark when a life path is set (E4.5). Hidden for old saves.
func _refresh_life_path() -> void:
	if _origin_label == null or _trade_label == null or _mark_label == null:
		return
	if not CareerPathState.has_path():
		_origin_label.visible = false
		_trade_label.visible = false
		_mark_label.visible = false
		_origin_label.text = ""
		_trade_label.text = ""
		_mark_label.text = ""
		return
	_origin_label.visible = true
	_trade_label.visible = true
	_mark_label.visible = true
	_origin_label.text = (
		BalanceSession.SHEET_ORIGIN_FORMAT
		% CareerPathState.option_display_name(CareerPathState.origin_id)
	)
	_trade_label.text = (
		BalanceSession.SHEET_TRADE_FORMAT
		% CareerPathState.option_display_name(CareerPathState.trade_id)
	)
	_mark_label.text = (
		BalanceSession.SHEET_MARK_FORMAT
		% CareerPathState.option_display_name(CareerPathState.mark_id)
	)


func _ship_display_name() -> String:
	var hull_id: StringName = BalanceFlight.PLAYER_HULL_ID
	var tree: SceneTree = get_tree()
	if tree != null:
		var ships: Node = tree.get_first_node_in_group(BalanceFlight.GROUP_SHIP_SERVICE)
		if ships != null and ships.has_method(&"active_hull_id"):
			var raw_id: Variant = ships.call(&"active_hull_id")
			if typeof(raw_id) == TYPE_STRING_NAME:
				var as_name: StringName = raw_id
				if not String(as_name).is_empty():
					hull_id = as_name
			elif typeof(raw_id) == TYPE_STRING:
				var as_text: String = raw_id
				if not as_text.is_empty():
					hull_id = StringName(as_text)
		else:
			var ship: Node = tree.get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP)
			if ship != null and ship.get("hull_id") != null:
				hull_id = StringName(str(ship.get("hull_id")))
	return _content_name(hull_id)


func _refresh_wallet() -> void:
	var credits: int = 0
	var debt_owed: int = 0
	var debt_lender: StringName = &""
	var cargo_used: int = 0
	var cargo_cap: int = BalanceEconomy.CARGO_CAPACITY
	var fuel_pct: int = int(BalanceEconomy.PERCENT_SCALE)
	var hull_pct: int = int(BalanceEconomy.PERCENT_SCALE)
	var tree: SceneTree = get_tree()
	var wallet: Node = null
	var cargo: Node = null
	if tree != null:
		wallet = tree.get_first_node_in_group(&"wallet_service")
		cargo = tree.get_first_node_in_group(&"cargo_service")
	if wallet != null:
		if wallet.has_method(&"credits"):
			credits = _variant_to_int(wallet.call(&"credits"))
		if wallet.has_method(&"debt_state"):
			var debt_raw: Variant = wallet.call(&"debt_state")
			if typeof(debt_raw) == TYPE_DICTIONARY:
				var debt: Dictionary = debt_raw
				if debt.has(&"owed"):
					debt_owed = _variant_to_int(debt[&"owed"])
				if debt.has(&"lender_id"):
					debt_lender = _variant_to_name(debt[&"lender_id"])
		if wallet.has_method(&"fuel") and wallet.has_method(&"fuel_max"):
			var fuel: float = _variant_to_float(wallet.call(&"fuel"))
			var fuel_max: float = _variant_to_float(wallet.call(&"fuel_max"))
			if fuel_max > 0.0:
				fuel_pct = int(roundf((fuel / fuel_max) * BalanceEconomy.PERCENT_SCALE))
		if wallet.has_method(&"condition") and wallet.has_method(&"condition_max"):
			var condition: float = _variant_to_float(wallet.call(&"condition"))
			var condition_max: float = _variant_to_float(wallet.call(&"condition_max"))
			if condition_max > 0.0:
				hull_pct = int(roundf((condition / condition_max) * BalanceEconomy.PERCENT_SCALE))
	if cargo != null:
		if cargo.has_method(&"used_volume"):
			cargo_used = _variant_to_int(cargo.call(&"used_volume"))
		if cargo.has_method(&"capacity"):
			cargo_cap = _variant_to_int(cargo.call(&"capacity"))
	_credits_label.text = BalanceSession.SHEET_CREDITS_FORMAT % credits
	if _debt_label != null:
		if debt_owed > 0:
			var lender_name: String = _content_name(debt_lender)
			if lender_name.is_empty():
				lender_name = _content_name(BalanceEconomy.LOAN_LENDER_ENTITY_ID)
			_debt_label.text = BalanceSession.SHEET_DEBT_FORMAT % [debt_owed, lender_name]
		else:
			_debt_label.text = BalanceSession.SHEET_DEBT_NONE
	_cargo_label.text = BalanceSession.SHEET_CARGO_FORMAT % [cargo_used, cargo_cap]
	_fuel_label.text = BalanceSession.SHEET_FUEL_FORMAT % fuel_pct
	_hull_label.text = BalanceSession.SHEET_HULL_FORMAT % hull_pct


func _refresh_job() -> void:
	var tree: SceneTree = get_tree()
	var mission: Node = null
	if tree != null:
		mission = tree.get_first_node_in_group(&"mission_service")
	var active: bool = (
		mission != null
		and mission.has_method(&"has_active")
		and mission.call(&"has_active") == true
	)
	if not active:
		_job_label.text = BalanceSession.SHEET_NO_JOB
		_job_status_label.text = ""
		return
	var template_id: StringName = _variant_to_name(mission.call(&"active_template_id"))
	var kind: StringName = &""
	if mission.has_method(&"active_kind"):
		kind = _variant_to_name(mission.call(&"active_kind"))
	if kind == BalanceStanding.MISSION_KIND_BOUNTY:
		var objective_ready: bool = false
		if mission.has_method(&"is_objective_ready"):
			objective_ready = mission.call(&"is_objective_ready") == true
		if objective_ready:
			var dest_id: StringName = &""
			if mission.has_method(&"active_destination_station_id"):
				dest_id = _variant_to_name(mission.call(&"active_destination_station_id"))
			_job_label.text = (
				BalanceSession.SHEET_JOB_BOUNTY_READY_FORMAT % _content_name(dest_id)
			)
			_job_status_label.text = BalanceSession.SHEET_JOB_STATUS_BOUNTY_READY
		else:
			var target_id: StringName = &""
			if mission.has_method(&"active_target_system_id"):
				target_id = _variant_to_name(mission.call(&"active_target_system_id"))
			_job_label.text = (BalanceSession.SHEET_JOB_BOUNTY_FORMAT % _content_name(target_id))
			_job_status_label.text = BalanceSession.SHEET_JOB_STATUS_BOUNTY_HUNT
		return
	if kind == BalanceStanding.MISSION_KIND_SMUGGLE:
		var cargo_name: String = _smuggle_cargo_name(template_id)
		var smuggle_dest: StringName = &""
		if mission.has_method(&"active_destination_station_id"):
			smuggle_dest = _variant_to_name(mission.call(&"active_destination_station_id"))
		if String(smuggle_dest).is_empty():
			_job_label.text = (BalanceSession.SHEET_JOB_SMUGGLE_NO_DEST_FORMAT % cargo_name)
		else:
			_job_label.text = (
				BalanceSession.SHEET_JOB_SMUGGLE_FORMAT % [cargo_name, _content_name(smuggle_dest)]
			)
		_job_status_label.text = BalanceSession.SHEET_JOB_STATUS_SMUGGLE
		return
	var job_name: String = _content_name(template_id)
	var dest_id: StringName = &""
	if mission.has_method(&"active_destination_station_id"):
		dest_id = _variant_to_name(mission.call(&"active_destination_station_id"))
	if String(dest_id).is_empty():
		_job_label.text = BalanceSession.SHEET_JOB_NO_DEST_FORMAT % job_name
	else:
		_job_label.text = BalanceSession.SHEET_JOB_FORMAT % [job_name, _content_name(dest_id)]
	_job_status_label.text = BalanceSession.SHEET_JOB_STATUS_ACTIVE


func _refresh_status() -> void:
	var system_id: StringName = BalanceFlight.PLAYABLE_SYSTEM_ID
	var tree: SceneTree = get_tree()
	if tree != null:
		var world: Node = tree.get_first_node_in_group(BalanceSession.GROUP_SYSTEM_WORLD)
		if world != null and world.get("system_id") != null:
			system_id = StringName(str(world.get("system_id")))
	var status: Dictionary = StandingService.status_for_system(system_id)
	var line: String = str(status.get(StandingService.STATUS_KEY_LINE, ""))
	_status_label.text = BalanceSession.SHEET_STATUS_FORMAT % line


func _refresh_standings() -> void:
	for child: Node in _standing_box.get_children():
		child.queue_free()
	var rows: Array[Dictionary] = []
	for entity_id: StringName in ContentLibrary.ids_in(BalanceSession.ENTITY_CONTENT_CATEGORY):
		var standing: float = StandingService.get_entity_standing(entity_id)
		(
			rows
			. append(
				{
					&"id": entity_id,
					&"name": _content_name(entity_id),
					&"standing": standing,
					&"abs": absf(standing),
				}
			)
		)
	rows.sort_custom(_standing_sort)
	var shown: int = 0
	for row: Dictionary in rows:
		if shown >= BalanceSession.SHEET_MAX_STANDING_LINES:
			break
		var standing: float = row[&"standing"]
		var tier: StringName = StandingService.tier_for(standing)
		var tier_name: String = StandingService.tier_display_name(tier)
		var line: Label = Label.new()
		line.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
		line.text = (
			BalanceSession.SHEET_STANDING_LINE_FORMAT % [row[&"name"], tier_name, str(standing)]
		)
		_standing_box.add_child(line)
		shown += 1


func _standing_sort(a: Dictionary, b: Dictionary) -> bool:
	var abs_a: float = a[&"abs"]
	var abs_b: float = b[&"abs"]
	if not is_equal_approx(abs_a, abs_b):
		return abs_a > abs_b
	return str(a[&"name"]) < str(b[&"name"])


func _content_name(id: StringName) -> String:
	if id == &"":
		return ""
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


## Commodity display name for an active smuggle template, or "cargo".
func _smuggle_cargo_name(template_id: StringName) -> String:
	if String(template_id).is_empty() or not ContentLibrary.has_item(template_id):
		return "cargo"
	var item: ContentItem = ContentLibrary.item(template_id)
	if item == null or not (item is ContractType):
		return "cargo"
	var contract: ContractType = item as ContractType
	var cargo_id: StringName = contract.cargo_commodity_id
	if String(cargo_id).is_empty():
		return "cargo"
	return _content_name(cargo_id)


func _variant_to_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _variant_to_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return as_float
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	return 0.0
