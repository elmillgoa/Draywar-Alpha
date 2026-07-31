class_name CargoService
extends Node

## Player cargo hold and station buy/sell — Path C B3 / E3.3.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B3, docs/BETA_E3_ECONOMY.md E3.3
##
## Single writer for cargo inventory. Child of Main (not an autoload).
## Optional save section `cargo` (schema v1, no envelope bump).
## Standing writes only via StandingService (legal trade + contraband inspection).
## Console: `cargo` lists hold contents.
## E3.3: open-market buy/sell blocked when commodity is contraband for the
## dock controller; fee-charging docks call inspect_on_dock() (not session restore).

var _inventory: Dictionary = {}  # StringName commodity_id → int qty


func _ready() -> void:
	add_to_group(&"cargo_service")
	EventBus.on_trade_buy_requested.connect(_on_buy_requested)
	EventBus.on_trade_sell_requested.connect(_on_sell_requested)
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)
	EventBus.on_cargo_changed.emit()


func _exit_tree() -> void:
	if EventBus.on_trade_buy_requested.is_connected(_on_buy_requested):
		EventBus.on_trade_buy_requested.disconnect(_on_buy_requested)
	if EventBus.on_trade_sell_requested.is_connected(_on_sell_requested):
		EventBus.on_trade_sell_requested.disconnect(_on_sell_requested)
	if EventBus.on_console_commands_requested.is_connected(_on_commands_requested):
		EventBus.on_console_commands_requested.disconnect(_on_commands_requested)
	if EventBus.on_console_command_invoked.is_connected(_on_command_invoked):
		EventBus.on_console_command_invoked.disconnect(_on_command_invoked)


## Units currently held of this commodity.
func quantity(commodity_id: StringName) -> int:
	if not _inventory.has(commodity_id):
		return 0
	return maxi(0, _variant_to_int(_inventory[commodity_id]))


## Total volume used by all cargo.
func used_volume() -> int:
	var total: int = 0
	for commodity_id: Variant in _inventory:
		var id: StringName = _as_name(commodity_id)
		var qty: int = quantity(id)
		if qty <= 0:
			continue
		var commodity: Commodity = _commodity(id)
		if commodity == null:
			total += qty
			continue
		total += commodity.unit_volume * qty
	return total


## Hold capacity from the active hull when ShipService is present; otherwise
## BalanceEconomy.CARGO_CAPACITY (tests / no-hull fallback).
func capacity() -> int:
	var ship: Node = _ship_service()
	if ship != null and ship.has_method(&"active_cargo_capacity"):
		var raw: Variant = ship.call(&"active_cargo_capacity")
		if typeof(raw) == TYPE_INT:
			var as_int: int = raw
			return maxi(0, as_int)
		if typeof(raw) == TYPE_FLOAT:
			var as_float: float = raw
			return maxi(0, int(as_float))
	return BalanceEconomy.CARGO_CAPACITY


## Remaining free volume (capacity - used).
func free_volume() -> int:
	return maxi(0, capacity() - used_volume())


## True when qty of this commodity fits in free volume.
func can_add(commodity_id: StringName, qty: int) -> bool:
	if qty <= 0:
		return false
	var commodity: Commodity = _commodity(commodity_id)
	if commodity == null:
		return false
	var need: int = commodity.unit_volume * qty
	return free_volume() >= need


## Add cargo. Returns false if it would not fit or qty invalid.
func add(commodity_id: StringName, qty: int) -> bool:
	if qty <= 0:
		return false
	if not can_add(commodity_id, qty):
		return false
	var next: int = quantity(commodity_id) + qty
	_inventory[commodity_id] = next
	EventBus.on_cargo_changed.emit()
	return true


## Remove cargo. Returns false if not enough stock or qty invalid.
func remove(commodity_id: StringName, qty: int) -> bool:
	if qty <= 0:
		return false
	var have: int = quantity(commodity_id)
	if have < qty:
		return false
	var next: int = have - qty
	if next <= 0:
		_inventory.erase(commodity_id)
	else:
		_inventory[commodity_id] = next
	EventBus.on_cargo_changed.emit()
	return true


## Empty the hold (tests / new session).
func reset() -> void:
	_inventory.clear()
	EventBus.on_cargo_changed.emit()


## Optional save section: commodity id string → qty (non-zero only).
func to_section() -> Dictionary:
	var out: Dictionary = {}
	for commodity_id: Variant in _inventory:
		var id: StringName = _as_name(commodity_id)
		var qty: int = quantity(id)
		if qty > 0:
			out[String(id)] = qty
	return out


## Apply optional cargo section (missing/invalid → empty hold).
func apply_section(raw: Variant) -> void:
	_inventory.clear()
	if typeof(raw) != TYPE_DICTIONARY:
		EventBus.on_cargo_changed.emit()
		return
	var data: Dictionary = raw
	for key: Variant in data:
		var id: StringName = _as_name(key)
		if String(id).is_empty():
			continue
		var qty: int = _variant_to_int(data[key])
		if qty > 0:
			_inventory[id] = qty
	EventBus.on_cargo_changed.emit()


## True when the docked station controller allows trade (Hostile/Hated refuse).
func trade_allowed_at_dock() -> bool:
	if not _is_docked():
		return false
	var controller: StringName = _dock_controller()
	if String(controller).is_empty() or controller == Station.CONTROLLER_NOBODY:
		return true
	var standing: float = StandingService.get_entity_standing(controller)
	var tier: StringName = StandingService.tier_for(standing)
	return not BalanceEconomy.trade_denied_for_tier(tier)


## True when this commodity is open-market restricted for the dock controller (E3.3).
func is_restricted_at_dock(commodity_id: StringName) -> bool:
	if not _is_docked():
		return false
	return is_restricted_for_controller(commodity_id, _dock_controller())


## True when this commodity is restricted for a station controller Entity.
func is_restricted_for_controller(commodity_id: StringName, controller: StringName) -> bool:
	if String(controller).is_empty() or controller == Station.CONTROLLER_NOBODY:
		return false
	var commodity: Commodity = _commodity(commodity_id)
	if commodity == null:
		return false
	return commodity.is_contraband_for(controller)


## Fee-charging dock inspection (E3.3). Call only from real docks — not session
## restore. If hold has goods restricted for the controller: fine (partial if
## broke), standing hit via StandingService, optional seize-all. Returns a
## result dictionary for tests / UI.
func inspect_on_dock() -> Dictionary:
	var empty: Dictionary = {
		&"found": false,
		&"fine_paid": 0,
		&"standing_delta": 0.0,
		&"entity_id": &"",
		&"station_id": &"",
		&"seized_units": 0,
	}
	if not _is_docked():
		return empty
	var controller: StringName = _dock_controller()
	if String(controller).is_empty() or controller == Station.CONTROLLER_NOBODY:
		return empty

	var restricted_ids: Array[StringName] = []
	var restricted_units: int = 0
	for key: Variant in _inventory:
		var commodity_id: StringName = _as_name(key)
		if not is_restricted_for_controller(commodity_id, controller):
			continue
		var qty: int = quantity(commodity_id)
		if qty <= 0:
			continue
		restricted_ids.append(commodity_id)
		restricted_units += qty

	if restricted_units <= 0:
		return empty

	var seized_units: int = 0
	var seized_id_strings: PackedStringArray = []
	if BalanceEconomy.CONTRABAND_SEIZE_ALL:
		for commodity_id: StringName in restricted_ids:
			var qty: int = quantity(commodity_id)
			if qty > 0 and remove(commodity_id, qty):
				seized_units += qty
				seized_id_strings.append(String(commodity_id))
	else:
		for commodity_id: StringName in restricted_ids:
			seized_id_strings.append(String(commodity_id))

	var fine_paid: int = _charge_contraband_fine(BalanceEconomy.CONTRABAND_FINE_BASE)
	var standing_delta: float = StandingService.apply_entity_delta(
		controller,
		BalanceStanding.CONTRABAND_STANDING_DELTA,
		BalanceStanding.REASON_CONTRABAND,
		false
	)
	var station_id: StringName = _docked_station_id()
	var station_name: String = _content_display_name(station_id)
	var entity_name: String = _content_display_name(controller)
	var line: String = ""
	if BalanceEconomy.CONTRABAND_SEIZE_ALL and seized_units > 0:
		line = (
			BalanceEconomy.CONSOLE_CONTRABAND_SEIZED_FORMAT % [station_name, fine_paid, entity_name]
		)
	else:
		line = (
			BalanceEconomy.CONSOLE_CONTRABAND_FINE_FORMAT % [station_name, fine_paid, entity_name]
		)
	EventBus.on_console_output.emit(line)
	EventBus.on_contraband_seized.emit(
		station_id, controller, seized_id_strings, fine_paid, standing_delta
	)
	return {
		&"found": true,
		&"fine_paid": fine_paid,
		&"standing_delta": standing_delta,
		&"entity_id": controller,
		&"station_id": station_id,
		&"seized_units": seized_units,
	}


## True when docked and can afford + fit a buy of this qty.
func can_buy(commodity_id: StringName, qty: int = BalanceEconomy.TRADE_QTY_UNIT) -> bool:
	var allowed: bool = (
		qty > 0
		and _is_docked()
		and trade_allowed_at_dock()
		and not is_restricted_at_dock(commodity_id)
	)
	var commodity: Commodity = null
	if allowed:
		commodity = _commodity(commodity_id)
		allowed = commodity != null and can_add(commodity_id, qty)
	var wallet: Node = null
	if allowed:
		wallet = _wallet()
		allowed = wallet != null and wallet.has_method(&"can_afford")
	if allowed:
		var cost: int = _unit_buy_price(commodity) * qty
		allowed = wallet.call(&"can_afford", cost) == true
	return allowed


## True when docked and hold has at least qty to sell.
func can_sell(commodity_id: StringName, qty: int = BalanceEconomy.TRADE_QTY_UNIT) -> bool:
	var allowed: bool = (
		qty > 0
		and _is_docked()
		and trade_allowed_at_dock()
		and not is_restricted_at_dock(commodity_id)
		and _commodity(commodity_id) != null
	)
	if allowed:
		allowed = quantity(commodity_id) >= qty
	return allowed


## Buy from the docked station. Returns true on success.
func try_buy(commodity_id: StringName, qty: int = BalanceEconomy.TRADE_QTY_UNIT) -> bool:
	var ok: bool = false
	if (
		qty > 0
		and _is_docked()
		and trade_allowed_at_dock()
		and not is_restricted_at_dock(commodity_id)
	):
		var commodity: Commodity = _commodity(commodity_id)
		if commodity != null and can_add(commodity_id, qty):
			var cost: int = _unit_buy_price(commodity) * qty
			var wallet: Node = _wallet()
			if wallet != null and wallet.has_method(&"try_spend"):
				if wallet.call(&"try_spend", cost) == true:
					if add(commodity_id, qty):
						EventBus.on_trade_completed.emit(
							BalanceEconomy.TRADE_SIDE_BUY, commodity_id, qty, -cost
						)
						_record_legal_trade()
						ok = true
					elif wallet.has_method(&"add_credits"):
						# Refund if inventory race (should not happen after can_add).
						wallet.call(&"add_credits", cost)
	return ok


## Sell to the docked station. Returns true on success.
func try_sell(commodity_id: StringName, qty: int = BalanceEconomy.TRADE_QTY_UNIT) -> bool:
	var ok: bool = false
	if (
		qty > 0
		and _is_docked()
		and trade_allowed_at_dock()
		and not is_restricted_at_dock(commodity_id)
	):
		var commodity: Commodity = _commodity(commodity_id)
		if commodity != null and quantity(commodity_id) >= qty:
			var payout: int = _unit_sell_price(commodity) * qty
			if remove(commodity_id, qty):
				var wallet: Node = _wallet()
				if wallet != null and wallet.has_method(&"add_credits") and payout > 0:
					wallet.call(&"add_credits", payout)
				EventBus.on_trade_completed.emit(
					BalanceEconomy.TRADE_SIDE_SELL, commodity_id, qty, payout
				)
				_record_legal_trade()
				ok = true
	return ok


func _on_buy_requested(commodity_id: StringName, qty: int) -> void:
	try_buy(commodity_id, qty)


func _on_sell_requested(commodity_id: StringName, qty: int) -> void:
	try_sell(commodity_id, qty)


## Unit buy price at the currently docked station's system.
func _unit_buy_price(commodity: Commodity) -> int:
	return BalanceEconomy.buy_price_at(commodity, _dock_system_id())


## Unit sell price at the currently docked station's system.
func _unit_sell_price(commodity: Commodity) -> int:
	return BalanceEconomy.sell_price_at(commodity, _dock_system_id())


func _record_legal_trade() -> void:
	var controller: StringName = _dock_controller()
	if String(controller).is_empty() or controller == Station.CONTROLLER_NOBODY:
		return
	StandingService.record_legal_trade(controller)


## Partial fine if broke (same floor pattern as dock fees). Returns credits paid.
func _charge_contraband_fine(amount: int) -> int:
	if amount <= 0:
		return 0
	var wallet: Node = _wallet()
	if wallet == null:
		return 0
	var paid: int = 0
	if wallet.has_method(&"credits"):
		var have_raw: Variant = wallet.call(&"credits")
		var have: int = _variant_to_int(have_raw)
		paid = mini(amount, maxi(0, have))
	if paid > 0 and wallet.has_method(&"try_spend"):
		if wallet.call(&"try_spend", paid) != true:
			# Fall back to partial spend via add_credits if try_spend is all-or-nothing.
			if wallet.has_method(&"add_credits"):
				wallet.call(&"add_credits", -paid)
			else:
				paid = 0
	return paid


func _content_display_name(content_id: StringName) -> String:
	if String(content_id).is_empty():
		return ""
	if ContentLibrary.has_item(content_id):
		var item: ContentItem = ContentLibrary.item(content_id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(content_id)


func _is_docked() -> bool:
	return not String(_docked_station_id()).is_empty()


func _docked_station_id() -> StringName:
	var tree: SceneTree = get_tree()
	if tree == null:
		return &""
	var dock_node: Node = tree.get_first_node_in_group(&"docking_service")
	if dock_node == null or not dock_node.has_method(&"docked_station_id"):
		return &""
	return _as_name(dock_node.call(&"docked_station_id"))


func _dock_controller() -> StringName:
	var station: Station = _docked_station()
	if station == null:
		return &""
	return station.controller_entity_id


func _dock_system_id() -> StringName:
	var station: Station = _docked_station()
	if station == null:
		return &""
	return station.system_id


func _docked_station() -> Station:
	var station_id: StringName = _docked_station_id()
	if String(station_id).is_empty() or not ContentLibrary.has_item(station_id):
		return null
	var item: ContentItem = ContentLibrary.item(station_id)
	if item is Station:
		return item as Station
	return null


func _commodity(commodity_id: StringName) -> Commodity:
	if String(commodity_id).is_empty() or not ContentLibrary.has_item(commodity_id):
		return null
	var item: ContentItem = ContentLibrary.item(commodity_id)
	if item is Commodity:
		return item as Commodity
	return null


func _wallet() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"wallet_service")


func _ship_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(BalanceFlight.GROUP_SHIP_SERVICE)


func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return StringName(str(value))


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	if typeof(value) == TYPE_STRING:
		var text: String = value
		if text.is_valid_int():
			return int(text)
	return 0


func _id_less(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)


# --- Console ---------------------------------------------------------------


static func usage() -> String:
	return String(BalanceEconomy.CARGO_COMMAND)


func _on_commands_requested() -> void:
	EventBus.on_console_command_registered.emit(
		BalanceEconomy.CARGO_COMMAND, usage(), "List cargo hold contents."
	)


func _on_command_invoked(name_of_command: StringName, _args: PackedStringArray) -> void:
	if name_of_command != BalanceEconomy.CARGO_COMMAND:
		return
	var used: int = used_volume()
	var cap: int = capacity()
	if _inventory.is_empty():
		EventBus.on_console_output.emit(BalanceEconomy.CONSOLE_CARGO_EMPTY % [free_volume(), cap])
		return
	EventBus.on_console_output.emit(BalanceEconomy.CONSOLE_CARGO_HEADER_FORMAT % [used, cap])
	var ids: Array[StringName] = []
	for key: Variant in _inventory:
		ids.append(_as_name(key))
	ids.sort_custom(_id_less)
	for id: StringName in ids:
		var qty: int = quantity(id)
		if qty <= 0:
			continue
		var name_text: String = String(id)
		var vol: int = qty
		var commodity: Commodity = _commodity(id)
		if commodity != null:
			if not commodity.display_name.is_empty():
				name_text = commodity.display_name
			vol = commodity.unit_volume * qty
		EventBus.on_console_output.emit(
			BalanceEconomy.CONSOLE_CARGO_LINE_FORMAT % [name_text, qty, vol]
		)
