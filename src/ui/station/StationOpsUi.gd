class_name StationOpsUi
extends RefCounted

## Pure operations helpers for StationMenu — Steam S6.
##
## Builds hire / fire / order / warehouse rows into a VBox.
## Buttons emit EventBus ops requests only (never call OperationService).


## Connect ops bus signals to a zero-arg refresh callable (args unbound).
static func connect_refresh(refresh: Callable) -> void:
	EventBus.on_ops_ship_hired.connect(refresh.unbind(BalanceOps.BUS_ARGS_SHIP_HIRED))
	EventBus.on_ops_ship_fired.connect(refresh.unbind(BalanceOps.BUS_ARGS_SHIP_FIRED))
	EventBus.on_ops_order_changed.connect(refresh.unbind(BalanceOps.BUS_ARGS_ORDER_CHANGED))
	EventBus.on_warehouse_changed.connect(refresh.unbind(BalanceOps.BUS_ARGS_WAREHOUSE_CHANGED))
	EventBus.on_ops_upkeep_paid.connect(refresh.unbind(BalanceOps.BUS_ARGS_UPKEEP_PAID))
	# REPAIR-3: breach was emitted with no production listener. Fire follows and
	# also refreshes, but the breach signal is the surface that names *why*
	# the ship left — keep it on the same refresh set as the other ops events.
	EventBus.on_ops_charter_breached.connect(refresh.unbind(BalanceOps.BUS_ARGS_CHARTER_BREACHED))


## Disconnect the refresh callables created by connect_refresh.
static func disconnect_refresh(refresh: Callable) -> void:
	_safe_disconnect(EventBus.on_ops_ship_hired, refresh.unbind(BalanceOps.BUS_ARGS_SHIP_HIRED))
	_safe_disconnect(EventBus.on_ops_ship_fired, refresh.unbind(BalanceOps.BUS_ARGS_SHIP_FIRED))
	_safe_disconnect(
		EventBus.on_ops_order_changed, refresh.unbind(BalanceOps.BUS_ARGS_ORDER_CHANGED)
	)
	_safe_disconnect(
		EventBus.on_warehouse_changed, refresh.unbind(BalanceOps.BUS_ARGS_WAREHOUSE_CHANGED)
	)
	_safe_disconnect(EventBus.on_ops_upkeep_paid, refresh.unbind(BalanceOps.BUS_ARGS_UPKEEP_PAID))
	_safe_disconnect(
		EventBus.on_ops_charter_breached, refresh.unbind(BalanceOps.BUS_ARGS_CHARTER_BREACHED)
	)


static func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


## Section header + empty box parented under `layout`. Returns the ops VBox.
static func make_box(layout: VBoxContainer) -> VBoxContainer:
	var header: Label = Label.new()
	header.text = BalanceOps.STATION_SECTION_OPS
	header.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	layout.add_child(header)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(box)
	return box


## Clear and rebuild operations rows for the docked station.
static func refresh_box(
	box: VBoxContainer, ops: Node, cargo: Node, station_id: StringName, menu_visible: bool
) -> void:
	if box == null:
		return
	_clear_children(box)
	if not menu_visible or ops == null or String(station_id).is_empty():
		return

	_add_dashboard(box, ops)
	_add_hire_buttons(box, ops, station_id)
	_add_fleet_rows(box, ops, station_id)
	_add_warehouse(box, ops, cargo, station_id)


static func _add_dashboard(box: VBoxContainer, ops: Node) -> void:
	if not ops.has_method(&"dashboard_summary"):
		return
	var summary_raw: Variant = ops.call(&"dashboard_summary")
	if typeof(summary_raw) != TYPE_DICTIONARY:
		return
	var summary: Dictionary = summary_raw
	var hired: int = _as_int(summary.get(&"hired", 0))
	var upkeep: int = _as_int(summary.get(&"upkeep_per_hour", 0))
	_add_label(box, BalanceOps.STATION_OPS_DASHBOARD_FORMAT % [hired, upkeep], true)
	var orders_raw: Variant = summary.get(&"active_orders", [])
	if typeof(orders_raw) == TYPE_ARRAY:
		var orders: Array = orders_raw
		for entry: Variant in orders:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = entry
			var order: StringName = _as_name(row.get(&"order", &""))
			var ship_id: StringName = _as_name(row.get(&"id", &""))
			if order == BalanceOps.ORDER_HAUL:
				var origin: String = _content_name(_as_name(row.get(&"origin", &"")))
				var dest: String = _content_name(_as_name(row.get(&"dest", &"")))
				_add_label(
					box,
					(
						"%s · %s"
						% [
							String(ship_id),
							BalanceOps.STATION_OPS_ORDER_HAUL_FORMAT % [origin, dest]
						]
					),
					false
				)
			elif order == BalanceOps.ORDER_ESCORT:
				_add_label(
					box, "%s · %s" % [String(ship_id), BalanceOps.STATION_OPS_ORDER_ESCORT], false
				)


static func _add_hire_buttons(box: VBoxContainer, ops: Node, station_id: StringName) -> void:
	_add_hire_button(
		box,
		ops,
		station_id,
		BalanceOps.TYPE_HAULER,
		BalanceOps.STATION_OPS_HIRE_HAULER_FORMAT % BalanceOps.HIRE_COST
	)
	_add_hire_button(
		box,
		ops,
		station_id,
		BalanceOps.TYPE_FIGHTER,
		BalanceOps.STATION_OPS_HIRE_FIGHTER_FORMAT % BalanceOps.HIRE_COST
	)


static func _add_hire_button(
	box: VBoxContainer, ops: Node, station_id: StringName, ship_type: StringName, label: String
) -> void:
	var btn: Button = Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var can: bool = false
	if ops.has_method(&"can_hire"):
		can = ops.call(&"can_hire", ship_type, station_id) == true
	btn.disabled = not can
	var captured: StringName = ship_type
	btn.pressed.connect(func() -> void: EventBus.on_ops_hire_requested.emit(captured))
	box.add_child(btn)


static func _add_fleet_rows(box: VBoxContainer, ops: Node, station_id: StringName) -> void:
	if not ops.has_method(&"hired_ids") or not ops.has_method(&"get_ship"):
		return
	var ids_raw: Variant = ops.call(&"hired_ids")
	if typeof(ids_raw) != TYPE_ARRAY:
		return
	var ids: Array = ids_raw
	var haul_dest: StringName = _pick_haul_dest(station_id)
	for entry: Variant in ids:
		var ship_id: StringName = _as_name(entry)
		var ship_raw: Variant = ops.call(&"get_ship", ship_id)
		if typeof(ship_raw) != TYPE_DICTIONARY:
			continue
		var ship: Dictionary = ship_raw
		var ship_type: StringName = _as_name(ship.get(BalanceOps.SHIP_KEY_TYPE, &""))
		var order: StringName = _as_name(ship.get(BalanceOps.SHIP_KEY_ORDER, BalanceOps.ORDER_PARK))
		var type_name: String = BalanceOps.type_display_name(ship_type)
		_add_label(
			box,
			BalanceOps.STATION_OPS_SHIP_LINE_FORMAT % [String(ship_id), type_name, String(order)],
			true
		)
		_add_fire_button(box, ship_id, type_name)
		_add_order_park(box, ship_id)
		_add_order_escort(box, ship_id)
		if BalanceOps.type_cargo_cap(ship_type) > 0 and not String(haul_dest).is_empty():
			_add_order_haul(box, ship_id, station_id, haul_dest)


static func _add_fire_button(box: VBoxContainer, ship_id: StringName, type_name: String) -> void:
	var btn: Button = Button.new()
	btn.text = BalanceOps.STATION_OPS_FIRE_FORMAT % type_name
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var captured: StringName = ship_id
	btn.pressed.connect(func() -> void: EventBus.on_ops_fire_requested.emit(captured))
	box.add_child(btn)


static func _add_order_park(box: VBoxContainer, ship_id: StringName) -> void:
	var btn: Button = Button.new()
	btn.text = BalanceOps.STATION_OPS_ORDER_PARK
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var captured: StringName = ship_id
	btn.pressed.connect(
		func() -> void:
			EventBus.on_ops_order_requested.emit(captured, BalanceOps.ORDER_PARK, &"", &"", &"")
	)
	box.add_child(btn)


static func _add_order_escort(box: VBoxContainer, ship_id: StringName) -> void:
	var btn: Button = Button.new()
	btn.text = BalanceOps.STATION_OPS_ORDER_ESCORT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var captured: StringName = ship_id
	btn.pressed.connect(
		func() -> void:
			EventBus.on_ops_order_requested.emit(captured, BalanceOps.ORDER_ESCORT, &"", &"", &"")
	)
	box.add_child(btn)


static func _add_order_haul(
	box: VBoxContainer, ship_id: StringName, origin: StringName, dest: StringName
) -> void:
	var btn: Button = Button.new()
	btn.text = (
		BalanceOps.STATION_OPS_ORDER_HAUL_FORMAT % [_content_name(origin), _content_name(dest)]
	)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var captured_id: StringName = ship_id
	var captured_origin: StringName = origin
	var captured_dest: StringName = dest
	btn.pressed.connect(
		func() -> void:
			EventBus.on_ops_order_requested.emit(
				captured_id,
				BalanceOps.ORDER_HAUL,
				captured_origin,
				captured_dest,
				BalanceOps.DEFAULT_HAUL_COMMODITY
			)
	)
	box.add_child(btn)


static func _add_warehouse(
	box: VBoxContainer, ops: Node, cargo: Node, station_id: StringName
) -> void:
	_add_label(box, BalanceOps.STATION_OPS_WAREHOUSE_HEADER, true)
	var used: int = 0
	if ops.has_method(&"warehouse_used_volume"):
		used = _as_int(ops.call(&"warehouse_used_volume", station_id))
	_add_label(
		box,
		BalanceOps.STATION_OPS_WAREHOUSE_CAP_FORMAT % [used, BalanceOps.WAREHOUSE_CAPACITY],
		false
	)
	# Deposit from hold (commodities currently carried).
	if cargo != null and cargo.has_method(&"quantity"):
		for commodity_id: StringName in ContentLibrary.ids_in(&"commodities"):
			var hold_qty: int = _as_int(cargo.call(&"quantity", commodity_id))
			if hold_qty <= 0:
				continue
			var deposit_qty: int = mini(hold_qty, BalanceEconomy.TRADE_QTY_UNIT)
			if deposit_qty <= 0:
				deposit_qty = 1
			var d_btn: Button = Button.new()
			d_btn.text = (
				BalanceOps.STATION_OPS_DEPOSIT_FORMAT % [_content_name(commodity_id), deposit_qty]
			)
			d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cap_c: StringName = commodity_id
			var cap_q: int = deposit_qty
			d_btn.pressed.connect(
				func() -> void: EventBus.on_ops_warehouse_deposit_requested.emit(cap_c, cap_q)
			)
			box.add_child(d_btn)
	# Withdraw from warehouse.
	if ops.has_method(&"warehouse_qty"):
		for commodity_id: StringName in ContentLibrary.ids_in(&"commodities"):
			var wh_qty: int = _as_int(ops.call(&"warehouse_qty", station_id, commodity_id))
			if wh_qty <= 0:
				continue
			var withdraw_qty: int = mini(wh_qty, BalanceEconomy.TRADE_QTY_UNIT)
			if withdraw_qty <= 0:
				withdraw_qty = 1
			var w_btn: Button = Button.new()
			w_btn.text = (
				BalanceOps.STATION_OPS_WITHDRAW_FORMAT % [_content_name(commodity_id), withdraw_qty]
			)
			w_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cap_c2: StringName = commodity_id
			var cap_q2: int = withdraw_qty
			w_btn.pressed.connect(
				func() -> void: EventBus.on_ops_warehouse_withdraw_requested.emit(cap_c2, cap_q2)
			)
			box.add_child(w_btn)


## Prefer another station in the same system; else any other station id.
static func _pick_haul_dest(origin: StringName) -> StringName:
	var origin_system: StringName = &""
	if ContentLibrary.has_item(origin):
		var item: ContentItem = ContentLibrary.item(origin)
		if item is Station:
			origin_system = (item as Station).system_id
	var fallback: StringName = &""
	for station_id: StringName in ContentLibrary.ids_in(&"stations"):
		if station_id == origin:
			continue
		if not ContentLibrary.has_item(station_id):
			continue
		var s_item: ContentItem = ContentLibrary.item(station_id)
		if not (s_item is Station):
			continue
		var station: Station = s_item as Station
		if station.system_id == origin_system:
			return station_id
		if String(fallback).is_empty():
			fallback = station_id
	return fallback


static func _content_name(id: StringName) -> String:
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


static func _add_label(box: VBoxContainer, text: String, emphasize: bool) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if emphasize:
		label.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	else:
		label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	box.add_child(label)


static func _clear_children(box: VBoxContainer) -> void:
	var children: Array[Node] = box.get_children()
	for child: Node in children:
		box.remove_child(child)
		child.queue_free()


static func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""


static func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0
