class_name StationTradeUi
extends RefCounted

## Station trade board — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2 + §5.5, docs/economy_sim.md §8
##
## Builds one StationTradeRow per commodity and keeps the Hostile/Hated
## trade-denied banner. The board is **station-keyed, not system-keyed**: it
## asks the docked CargoService, which asks MarketService about this dock, so
## two docks in one system show different stock and different prices.
##
## Rows are grouped so the board reads top-down: what can be traded here first,
## then anything this dock's controller restricts (E3.3), then goods this dock
## keeps no market in at all. Within a group the order is content order, which
## never moves — a list that re-sorted itself as prices moved would throw the
## captain's eye off the row they were working, and would also throw away the
## amount they had typed into it.
##
## When the line-up has not changed, existing rows are refreshed in place rather
## than rebuilt. That keeps the typed amount alive across a trade — press Buy 10
## twice and watch the price climb — and it means no Control is ever freed from
## inside its own pressed handler (docs/traps.md #11).


static func clear_rows(trade_box: VBoxContainer) -> void:
	if trade_box == null:
		return
	var doomed: Array[Node] = []
	for child: Node in trade_box.get_children():
		doomed.append(child)
	for child: Node in doomed:
		trade_box.remove_child(child)
		child.queue_free()


## Rebuild or refresh the trade rows. `on_buy` and `on_sell` are called with
## (commodity_id: StringName, units: int).
static func refresh(
	trade_box: VBoxContainer,
	denied_label: Label,
	cargo: Node,
	menu_visible: bool,
	on_buy: Callable,
	on_sell: Callable
) -> void:
	if trade_box == null:
		return
	if denied_label != null:
		denied_label.visible = false
	if not menu_visible:
		clear_rows(trade_box)
		return
	var trade_ok: bool = true
	if cargo != null and cargo.has_method(&"trade_allowed_at_dock"):
		trade_ok = cargo.call(&"trade_allowed_at_dock") == true
	if not trade_ok:
		clear_rows(trade_box)
		if denied_label != null:
			denied_label.text = BalanceEconomy.STATION_TRADE_DENIED_MESSAGE
			denied_label.visible = true
		return
	var wanted: Array[StringName] = row_order(cargo)
	if _rows_match(trade_box, wanted):
		_refresh_in_place(trade_box)
		return
	clear_rows(trade_box)
	for commodity_id: StringName in wanted:
		var row: StationTradeRow = StationTradeRow.new()
		trade_box.add_child(row)
		row.setup(commodity_id, cargo, on_buy, on_sell)


## Commodity ids in board order: tradable here, then restricted here, then goods
## this dock keeps no market in.
static func row_order(cargo: Node) -> Array[StringName]:
	var tradable: Array[StringName] = []
	var restricted: Array[StringName] = []
	var no_market: Array[StringName] = []
	for commodity_id: StringName in ContentLibrary.ids_in(
		BalanceEconomy.COMMODITY_CONTENT_CATEGORY
	):
		if not ContentLibrary.has_item(commodity_id):
			continue
		var item: ContentItem = ContentLibrary.item(commodity_id)
		if not (item is Commodity):
			continue
		if _cargo_says(cargo, &"is_restricted_at_dock", commodity_id):
			restricted.append(commodity_id)
		elif _trades_here(cargo, commodity_id):
			tradable.append(commodity_id)
		else:
			no_market.append(commodity_id)
	var out: Array[StringName] = []
	out.append_array(tradable)
	out.append_array(restricted)
	out.append_array(no_market)
	return out


static func _trades_here(cargo: Node, commodity_id: StringName) -> bool:
	if cargo == null or not cargo.has_method(&"trade_row"):
		return false
	var raw: Variant = cargo.call(&"trade_row", commodity_id)
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var row: Dictionary = raw
	if not row.has(BalanceEconomy.TRADE_ROW_KEY_TRADED):
		return false
	return row[BalanceEconomy.TRADE_ROW_KEY_TRADED] == true


static func _cargo_says(cargo: Node, method: StringName, commodity_id: StringName) -> bool:
	if cargo == null or not cargo.has_method(method):
		return false
	return cargo.call(method, commodity_id) == true


static func _rows_match(trade_box: VBoxContainer, wanted: Array[StringName]) -> bool:
	var children: Array[Node] = trade_box.get_children()
	if children.size() != wanted.size():
		return false
	for index: int in children.size():
		var row: StationTradeRow = children[index] as StationTradeRow
		if row == null or row.row_commodity_id() != wanted[index]:
			return false
	return true


static func _refresh_in_place(trade_box: VBoxContainer) -> void:
	for child: Node in trade_box.get_children():
		var row: StationTradeRow = child as StationTradeRow
		if row != null:
			row.refresh()
