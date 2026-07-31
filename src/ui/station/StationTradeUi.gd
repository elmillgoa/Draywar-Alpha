class_name StationTradeUi
extends RefCounted

## Trade list rebuild for StationMenu (keeps menu under file-length lint).


static func clear_rows(trade_box: VBoxContainer) -> void:
	if trade_box == null:
		return
	for child: Node in trade_box.get_children():
		child.queue_free()


## Rebuild commodity buy/sell rows. Callables receive commodity_id: StringName.
static func refresh(
	trade_box: VBoxContainer,
	denied_label: Label,
	system_id: StringName,
	cargo: Node,
	menu_visible: bool,
	on_buy: Callable,
	on_sell: Callable
) -> void:
	if trade_box == null:
		return
	clear_rows(trade_box)
	if denied_label != null:
		denied_label.visible = false
	if not menu_visible:
		return
	var trade_ok: bool = true
	if cargo != null and cargo.has_method(&"trade_allowed_at_dock"):
		trade_ok = cargo.call(&"trade_allowed_at_dock") == true
	if not trade_ok:
		if denied_label != null:
			denied_label.text = BalanceEconomy.STATION_TRADE_DENIED_MESSAGE
			denied_label.visible = true
		return
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
		var restricted: bool = false
		if cargo != null and cargo.has_method(&"is_restricted_at_dock"):
			restricted = cargo.call(&"is_restricted_at_dock", commodity_id) == true
		var buy_price: int = BalanceEconomy.buy_price_at(commodity, system_id)
		var sell_price: int = BalanceEconomy.sell_price_at(commodity, system_id)
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trade_box.add_child(row)

		var line: Label = Label.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if restricted:
			line.text = (
				BalanceEconomy.STATION_TRADE_RESTRICTED_FORMAT % [commodity.display_name, hold]
			)
		else:
			line.text = (
				BalanceEconomy.STATION_TRADE_LINE_FORMAT
				% [commodity.display_name, buy_price, sell_price, hold]
			)
		row.add_child(line)

		var buy_btn: Button = Button.new()
		buy_btn.text = BalanceEconomy.STATION_TRADE_BUY_LABEL
		buy_btn.custom_minimum_size = Vector2(
			BalanceEconomy.STATION_TRADE_BUTTON_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
		)
		var can_buy: bool = false
		if not restricted and cargo != null and cargo.has_method(&"can_buy"):
			can_buy = cargo.call(&"can_buy", commodity_id, BalanceEconomy.TRADE_QTY_UNIT) == true
		buy_btn.disabled = not can_buy
		buy_btn.pressed.connect(on_buy.bind(commodity_id))
		row.add_child(buy_btn)

		var sell_btn: Button = Button.new()
		sell_btn.text = BalanceEconomy.STATION_TRADE_SELL_LABEL
		sell_btn.custom_minimum_size = Vector2(
			BalanceEconomy.STATION_TRADE_BUTTON_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
		)
		var can_sell: bool = false
		if not restricted and cargo != null and cargo.has_method(&"can_sell"):
			can_sell = cargo.call(&"can_sell", commodity_id, BalanceEconomy.TRADE_QTY_UNIT) == true
		sell_btn.disabled = not can_sell
		sell_btn.pressed.connect(on_sell.bind(commodity_id))
		row.add_child(sell_btn)


static func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0
