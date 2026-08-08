class_name StationTradeRow
extends VBoxContainer

## One commodity's row on the station trade board — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2 + §5.5, docs/economy_sim.md §8
##
## Four lines, top to bottom:
##
##   1. name, stock held **at this dock**, unit buy, unit sell, what is aboard
##   2. the market's own reason line ("Shortage — 12 in stock, wants 90")
##   3. the amount box, Max buy and Max sell
##   4. Buy and Sell, each carrying the live total for the amount chosen
##
## with a fifth line that appears only when the amount asked for is more than
## the dock, the hold or the wallet will allow, and says which of the three it
## was. One-unit-per-click is gone.
##
## Holds no prices and works none out. Every number on screen arrives from a
## CargoService quote, which is a MarketService quote (strict MVC —
## DRAYWAR_CONVENTIONS.md §3). The amount box deliberately accepts more than the
## station will sell, because a row that cannot be over-asked can never explain
## its own limits.

var _commodity_id: StringName = &""
var _cargo: Node = null
var _on_buy: Callable = Callable()
var _on_sell: Callable = Callable()

var _headline: Label = null
var _reason: Label = null
var _note: Label = null
var _amount: SpinBox = null
var _max_buy_btn: Button = null
var _max_sell_btn: Button = null
var _buy_btn: Button = null
var _sell_btn: Button = null
var _controls: VBoxContainer = null

var _max_buy: int = 0
var _max_sell: int = 0
var _buy_limit: StringName = BalanceEconomy.TRADE_LIMIT_MARKET
var _sell_limit: StringName = BalanceEconomy.TRADE_LIMIT_MARKET
var _restricted: bool = false


## Build the row and fill it for the first time. `on_buy` and `on_sell` are
## called with (commodity_id: StringName, units: int).
func setup(commodity_id: StringName, cargo: Node, on_buy: Callable, on_sell: Callable) -> void:
	_commodity_id = commodity_id
	_cargo = cargo
	_on_buy = on_buy
	_on_sell = on_sell
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	refresh()


## The commodity this row shows (so a rebuild can be skipped when the dock's
## line-up has not changed and the captain's typed amount should survive).
func row_commodity_id() -> StringName:
	return _commodity_id


## Re-read the market and redraw. Cheap enough to call on every cargo, credit or
## market change while docked.
func refresh() -> void:
	var row: Dictionary = {}
	if _cargo != null and _cargo.has_method(&"trade_row"):
		row = _cargo.call(&"trade_row", _commodity_id)
	_restricted = _asks_bool(&"is_restricted_at_dock")
	var traded: bool = _row_bool(row, BalanceEconomy.TRADE_ROW_KEY_TRADED) and not _restricted
	_max_buy = _row_int(row, BalanceEconomy.TRADE_ROW_KEY_MAX_BUY) if traded else 0
	_max_sell = _row_int(row, BalanceEconomy.TRADE_ROW_KEY_MAX_SELL) if traded else 0
	_buy_limit = _row_name(row, BalanceEconomy.TRADE_ROW_KEY_BUY_LIMIT)
	_sell_limit = _row_name(row, BalanceEconomy.TRADE_ROW_KEY_SELL_LIMIT)

	_headline.text = _headline_text(row, traded)
	_reason.text = _row_text(row, BalanceEconomy.TRADE_ROW_KEY_REASON)
	_reason.visible = traded and not _reason.text.is_empty()
	_controls.visible = traded
	_max_buy_btn.disabled = _max_buy <= 0
	_max_sell_btn.disabled = _max_sell <= 0
	if traded:
		_update_totals()
	else:
		_note.visible = false


func _build() -> void:
	_headline = _make_label(BalanceUi.FONT_COLOR)
	add_child(_headline)
	_reason = _make_label(BalanceUi.FONT_COLOR_MUTED)
	_reason.add_theme_font_size_override("font_size", BalanceEconomy.STATION_TRADE_SMALL_FONT_SIZE)
	add_child(_reason)

	_controls = VBoxContainer.new()
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_controls)
	_build_amount_line()
	_build_action_line()

	_note = _make_label(BalanceUi.TITLE_COLOR)
	_note.add_theme_font_size_override("font_size", BalanceEconomy.STATION_TRADE_SMALL_FONT_SIZE)
	_note.visible = false
	_controls.add_child(_note)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceEconomy.STATION_TRADE_ROW_SPACER)
	add_child(spacer)


func _build_amount_line() -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls.add_child(line)

	_amount = SpinBox.new()
	_amount.min_value = BalanceEconomy.STATION_TRADE_QTY_MIN
	_amount.max_value = BalanceEconomy.STATION_TRADE_QTY_MAX
	_amount.step = BalanceEconomy.STATION_TRADE_QTY_STEP
	_amount.value = BalanceEconomy.STATION_TRADE_QTY_MIN
	_amount.custom_minimum_size = Vector2(
		BalanceEconomy.STATION_TRADE_QTY_WIDTH, BalanceFlight.STATION_MENU_BUTTON_HEIGHT
	)
	_amount.value_changed.connect(_on_amount_changed)
	line.add_child(_amount)

	_max_buy_btn = _make_button(
		line,
		BalanceEconomy.STATION_TRADE_MAX_BUY_LABEL,
		BalanceEconomy.STATION_TRADE_MAX_BUTTON_WIDTH
	)
	_max_buy_btn.pressed.connect(_on_max_buy_pressed)
	_max_sell_btn = _make_button(
		line,
		BalanceEconomy.STATION_TRADE_MAX_SELL_LABEL,
		BalanceEconomy.STATION_TRADE_MAX_BUTTON_WIDTH
	)
	_max_sell_btn.pressed.connect(_on_max_sell_pressed)


func _build_action_line() -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls.add_child(line)
	_buy_btn = _make_button(line, "", BalanceEconomy.STATION_TRADE_ACTION_BUTTON_WIDTH)
	_buy_btn.pressed.connect(_on_buy_pressed)
	_sell_btn = _make_button(line, "", BalanceEconomy.STATION_TRADE_ACTION_BUTTON_WIDTH)
	_sell_btn.pressed.connect(_on_sell_pressed)


## The live total. Not units × unit price: the marginal ladder charges each unit
## at the stock level it moves through, so the only honest number is the one the
## market quotes for this exact quantity (docs/economy_sim.md §5).
func _update_totals() -> void:
	var asked: int = int(_amount.value)
	var buy_units: int = mini(asked, _max_buy)
	var sell_units: int = mini(asked, _max_sell)
	_buy_btn.text = (
		BalanceEconomy.STATION_TRADE_BUY_FORMAT % [buy_units, _quote_total(&"quote_buy", buy_units)]
	)
	_sell_btn.text = (
		BalanceEconomy.STATION_TRADE_SELL_FORMAT
		% [sell_units, _quote_total(&"quote_sell", sell_units)]
	)
	_buy_btn.disabled = buy_units <= 0
	_sell_btn.disabled = sell_units <= 0
	_note.text = _cap_note(asked)
	_note.visible = not _note.text.is_empty()


## Why the amount asked for cannot all happen. Buy first — it is the side a
## captain is usually reaching for — then the sell side when they hold any.
func _cap_note(asked: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if asked > _max_buy:
		lines.append(_buy_cap_line())
	if asked > _max_sell and _max_sell > 0:
		lines.append(_sell_cap_line())
	elif _max_sell <= 0:
		var none_sell: String = _sell_none_line()
		if not none_sell.is_empty():
			lines.append(none_sell)
	return " ".join(lines)


## Sell-side "you asked for more than N" — dock market vs what is in the hold.
func _sell_cap_line() -> String:
	if _sell_limit == BalanceEconomy.TRADE_LIMIT_HOLD:
		return BalanceEconomy.STATION_TRADE_CAP_SELL_HOLD_FORMAT % _max_sell
	return BalanceEconomy.STATION_TRADE_CAP_SELL_MARKET_FORMAT % _max_sell


## Sell-side empty limit wording (nothing left to sell / dock takes none).
func _sell_none_line() -> String:
	if _sell_limit == BalanceEconomy.TRADE_LIMIT_HOLD:
		return BalanceEconomy.STATION_TRADE_NONE_SELL_HOLD
	if _sell_limit == BalanceEconomy.TRADE_LIMIT_MARKET:
		return BalanceEconomy.STATION_TRADE_NONE_SELL_MARKET
	return ""


func _buy_cap_line() -> String:
	var capped: String = BalanceEconomy.STATION_TRADE_CAP_MARKET_FORMAT
	var none: String = BalanceEconomy.STATION_TRADE_NONE_MARKET
	if _buy_limit == BalanceEconomy.TRADE_LIMIT_CREDITS:
		capped = BalanceEconomy.STATION_TRADE_CAP_CREDITS_FORMAT
		none = BalanceEconomy.STATION_TRADE_NONE_CREDITS
	elif _buy_limit == BalanceEconomy.TRADE_LIMIT_HOLD:
		capped = BalanceEconomy.STATION_TRADE_CAP_HOLD_FORMAT
		none = BalanceEconomy.STATION_TRADE_NONE_HOLD
	if _max_buy <= 0:
		return none
	return capped % _max_buy


func _headline_text(row: Dictionary, traded: bool) -> String:
	var display: String = _display_name()
	var held: int = _held()
	if _restricted:
		return BalanceEconomy.STATION_TRADE_RESTRICTED_FORMAT % [display, held]
	if not traded:
		return BalanceEconomy.STATION_TRADE_NO_MARKET_FORMAT % [display, held]
	return (
		BalanceEconomy.STATION_TRADE_LINE_FORMAT
		% [
			display,
			_row_int(row, BalanceEconomy.TRADE_ROW_KEY_STOCK),
			_row_int(row, BalanceEconomy.TRADE_ROW_KEY_UNIT_BUY),
			_row_int(row, BalanceEconomy.TRADE_ROW_KEY_UNIT_SELL),
			held,
		]
	)


func _on_amount_changed(_value: float) -> void:
	if _controls.visible:
		_update_totals()


func _on_max_buy_pressed() -> void:
	_amount.value = float(maxi(_max_buy, int(BalanceEconomy.STATION_TRADE_QTY_MIN)))


func _on_max_sell_pressed() -> void:
	_amount.value = float(maxi(_max_sell, int(BalanceEconomy.STATION_TRADE_QTY_MIN)))


func _on_buy_pressed() -> void:
	var units: int = mini(int(_amount.value), _max_buy)
	if units > 0 and _on_buy.is_valid():
		_on_buy.call(_commodity_id, units)


func _on_sell_pressed() -> void:
	var units: int = mini(int(_amount.value), _max_sell)
	if units > 0 and _on_sell.is_valid():
		_on_sell.call(_commodity_id, units)


func _quote_total(method: StringName, units: int) -> int:
	if units <= 0 or _cargo == null or not _cargo.has_method(method):
		return 0
	var quote: Variant = _cargo.call(method, _commodity_id, units)
	if typeof(quote) != TYPE_DICTIONARY:
		return 0
	var as_dictionary: Dictionary = quote
	return _row_int(as_dictionary, BalanceMarket.QUOTE_KEY_TOTAL)


func _display_name() -> String:
	if ContentLibrary.has_item(_commodity_id):
		var item: ContentItem = ContentLibrary.item(_commodity_id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(_commodity_id)


func _held() -> int:
	if _cargo == null or not _cargo.has_method(&"quantity"):
		return 0
	return _as_int(_cargo.call(&"quantity", _commodity_id))


func _asks_bool(method: StringName) -> bool:
	if _cargo == null or not _cargo.has_method(method):
		return false
	return _cargo.call(method, _commodity_id) == true


func _make_label(colour: Color) -> Label:
	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_button(parent: Control, text: String, width: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, BalanceFlight.STATION_MENU_BUTTON_HEIGHT)
	parent.add_child(button)
	return button


## A Dictionary value cannot be used directly under this project's warning
## settings (docs/traps.md #17) — every read lands in a typed local first.
func _row_int(row: Dictionary, key: StringName) -> int:
	if not row.has(key):
		return 0
	return _as_int(row[key])


func _row_bool(row: Dictionary, key: StringName) -> bool:
	if not row.has(key):
		return false
	return row[key] == true


func _row_text(row: Dictionary, key: StringName) -> String:
	if not row.has(key):
		return ""
	var raw: Variant = row[key]
	if typeof(raw) == TYPE_STRING:
		var as_text: String = raw
		return as_text
	return ""


func _row_name(row: Dictionary, key: StringName) -> StringName:
	if not row.has(key):
		return BalanceEconomy.TRADE_LIMIT_MARKET
	var raw: Variant = row[key]
	if typeof(raw) == TYPE_STRING_NAME:
		var as_name: StringName = raw
		return as_name
	if typeof(raw) == TYPE_STRING:
		var as_text: String = raw
		return StringName(as_text)
	return BalanceEconomy.TRADE_LIMIT_MARKET


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0
