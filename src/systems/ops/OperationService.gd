class_name OperationService
extends Node

## Abstract fleet, warehouse, and charter retainers — Steam S6.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S6
##
## Child of Main (not an autoload). Hired ships never spawn in the world.
## Standing mutations only via StandingService. Money via WalletService.
## Cross-system traffic is EventBus-only for requests / announcements.

## StringName ops_ship_id → ship dict (mutable working copy).
var _hired: Dictionary = {}
## station_id StringName → { commodity_id StringName → int qty }
var _warehouse: Dictionary = {}
## Fractional upkeep remainder per ship (runtime only; not saved).
var _upkeep_frac: Dictionary = {}


func _ready() -> void:
	add_to_group(BalanceOps.GROUP_OPERATION_SERVICE)
	ServiceRegistry.register_resettable(reset)
	WorldClock.register_category_subscriber(BalanceWorldClock.CATEGORY_OPS, _on_world_tick)
	EventBus.on_ops_hire_requested.connect(_on_hire_requested)
	EventBus.on_ops_fire_requested.connect(_on_fire_requested)
	EventBus.on_ops_order_requested.connect(_on_order_requested)
	EventBus.on_ops_warehouse_deposit_requested.connect(_on_deposit_requested)
	EventBus.on_ops_warehouse_withdraw_requested.connect(_on_withdraw_requested)


func _exit_tree() -> void:
	ServiceRegistry.unregister_resettable(reset)
	WorldClock.unregister_category_subscriber(BalanceWorldClock.CATEGORY_OPS, _on_world_tick)
	_disconnect(EventBus.on_ops_hire_requested, _on_hire_requested)
	_disconnect(EventBus.on_ops_fire_requested, _on_fire_requested)
	_disconnect(EventBus.on_ops_order_requested, _on_order_requested)
	_disconnect(EventBus.on_ops_warehouse_deposit_requested, _on_deposit_requested)
	_disconnect(EventBus.on_ops_warehouse_withdraw_requested, _on_withdraw_requested)


func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_world_tick(delta_seconds: float) -> void:
	tick_ops(delta_seconds)


func _on_hire_requested(ship_type: StringName) -> void:
	var station_id: StringName = _docked_station_id()
	if String(station_id).is_empty():
		return
	try_hire(ship_type, station_id)


func _on_fire_requested(ops_ship_id: StringName) -> void:
	try_fire(ops_ship_id)


func _on_order_requested(
	ops_ship_id: StringName,
	order: StringName,
	origin_station: StringName,
	dest_station: StringName,
	commodity_id: StringName
) -> void:
	try_set_order(ops_ship_id, order, origin_station, dest_station, commodity_id)


func _on_deposit_requested(commodity_id: StringName, quantity: int) -> void:
	var station_id: StringName = _docked_station_id()
	if String(station_id).is_empty():
		return
	try_deposit(station_id, commodity_id, quantity)


func _on_withdraw_requested(commodity_id: StringName, quantity: int) -> void:
	var station_id: StringName = _docked_station_id()
	if String(station_id).is_empty():
		return
	try_withdraw(station_id, commodity_id, quantity)


# --- Public API -------------------------------------------------------------


## Clear fleet and warehouse (tests / new career / missing save section).
func reset() -> void:
	_hired.clear()
	_warehouse.clear()
	_upkeep_frac.clear()


## Optional `operation` save section body.
func to_section() -> Dictionary:
	var hired_list: Array = []
	for ship_id: Variant in _hired.keys():
		var id: StringName = _as_name(ship_id)
		hired_list.append(_ship_to_save(_ship_dict(id)))
	var warehouse_out: Dictionary = {}
	for station_key: Variant in _warehouse.keys():
		var station_id: StringName = _as_name(station_key)
		var shelf_raw: Variant = _warehouse[station_id]
		if typeof(shelf_raw) != TYPE_DICTIONARY:
			continue
		var shelf: Dictionary = shelf_raw
		var shelf_out: Dictionary = {}
		for commodity_key: Variant in shelf.keys():
			var commodity_id: StringName = _as_name(commodity_key)
			var qty: int = _as_int(shelf[commodity_id])
			if qty > 0:
				shelf_out[String(commodity_id)] = qty
		if not shelf_out.is_empty():
			warehouse_out[String(station_id)] = shelf_out
	return {
		BalanceOps.KEY_HIRED: hired_list,
		BalanceOps.KEY_WAREHOUSE: warehouse_out,
	}


## Restore from save. Missing / invalid → empty ops.
func apply_section(raw: Variant) -> void:
	reset()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	if data.has(BalanceOps.KEY_HIRED):
		_apply_hired(data[BalanceOps.KEY_HIRED])
	if data.has(BalanceOps.KEY_WAREHOUSE):
		_apply_warehouse(data[BalanceOps.KEY_WAREHOUSE])


func hired_count() -> int:
	return _hired.size()


func hired_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _hired.keys():
		out.append(_as_name(key))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## Copy of ship dict, or empty if unknown.
func get_ship(ops_ship_id: StringName) -> Dictionary:
	if not _hired.has(ops_ship_id):
		return {}
	var raw: Variant = _hired[ops_ship_id]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var ship: Dictionary = raw
	return ship.duplicate(true)


## True when hire is allowed: known type, docked, credits, standing, capacity.
func can_hire(ship_type: StringName, station_id: StringName) -> bool:
	if not _hire_context_ok(ship_type, station_id):
		return false
	var wallet: Node = _wallet_service()
	return (
		wallet != null
		and wallet.has_method(&"can_afford")
		and wallet.call(&"can_afford", BalanceOps.HIRE_COST) == true
	)


func _hire_context_ok(ship_type: StringName, station_id: StringName) -> bool:
	if (
		not BalanceOps.is_known_type(ship_type)
		or hired_count() >= BalanceOps.MAX_HIRED
		or String(station_id).is_empty()
		or _docked_station_id() != station_id
	):
		return false
	var controller: StringName = _station_controller(station_id)
	if String(controller).is_empty():
		return false
	return StandingService.get_entity_standing(controller) >= BalanceStanding.TIER_FRIENDLY_MIN


## Hire if allowed. Returns new ops ship id, or empty on refuse.
func try_hire(ship_type: StringName, station_id: StringName) -> StringName:
	if not can_hire(ship_type, station_id):
		return &""
	var controller: StringName = _station_controller(station_id)
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"try_spend"):
		return &""
	if wallet.call(&"try_spend", BalanceOps.HIRE_COST) != true:
		return &""
	_emit_money(BalanceTelemetry.REASON_OPS_HIRE, -BalanceOps.HIRE_COST)
	var new_id: StringName = _next_ship_id()
	var ship: Dictionary = {
		BalanceOps.SHIP_KEY_ID: new_id,
		BalanceOps.SHIP_KEY_TYPE: ship_type,
		BalanceOps.SHIP_KEY_ORDER: BalanceOps.ORDER_PARK,
		BalanceOps.SHIP_KEY_ORIGIN: &"",
		BalanceOps.SHIP_KEY_DEST: &"",
		BalanceOps.SHIP_KEY_COMMODITY: &"",
		BalanceOps.SHIP_KEY_CHARTER: controller,
		BalanceOps.SHIP_KEY_UPKEEP_MISSES: 0,
		BalanceOps.SHIP_KEY_HAUL_PROGRESS: 0.0,
		BalanceOps.SHIP_KEY_HOME: station_id,
	}
	_hired[new_id] = ship
	_upkeep_frac[new_id] = 0.0
	EventBus.on_ops_ship_hired.emit(new_id, ship_type, controller)
	return new_id


## Fire a hired ship. No standing hit for a normal fire. Returns false if unknown.
func try_fire(ops_ship_id: StringName) -> bool:
	if not _hired.has(ops_ship_id):
		return false
	_hired.erase(ops_ship_id)
	_upkeep_frac.erase(ops_ship_id)
	EventBus.on_ops_ship_fired.emit(ops_ship_id)
	return true


## Set order. Invalid params → false, no change.
func try_set_order(
	ops_ship_id: StringName,
	order: StringName,
	origin: StringName,
	dest: StringName,
	commodity: StringName
) -> bool:
	if not _hired.has(ops_ship_id) or not BalanceOps.is_known_order(order):
		return false
	var ship: Dictionary = _ship_dict(ops_ship_id)
	if ship.is_empty():
		return false
	if order == BalanceOps.ORDER_PARK or order == BalanceOps.ORDER_ESCORT:
		_apply_simple_order(ops_ship_id, ship, order)
		return true
	if order != BalanceOps.ORDER_HAUL:
		return false
	return _try_set_haul_order(ops_ship_id, ship, origin, dest, commodity)


func _apply_simple_order(ops_ship_id: StringName, ship: Dictionary, order: StringName) -> void:
	ship[BalanceOps.SHIP_KEY_ORDER] = order
	ship[BalanceOps.SHIP_KEY_ORIGIN] = &""
	ship[BalanceOps.SHIP_KEY_DEST] = &""
	ship[BalanceOps.SHIP_KEY_COMMODITY] = &""
	ship[BalanceOps.SHIP_KEY_HAUL_PROGRESS] = 0.0
	_hired[ops_ship_id] = ship
	EventBus.on_ops_order_changed.emit(ops_ship_id, order)


func _try_set_haul_order(
	ops_ship_id: StringName,
	ship: Dictionary,
	origin: StringName,
	dest: StringName,
	commodity: StringName
) -> bool:
	var ok: bool = (
		not String(origin).is_empty()
		and not String(dest).is_empty()
		and origin != dest
		and ContentLibrary.has_item(origin)
		and ContentLibrary.has_item(dest)
	)
	if not ok:
		return false
	var commodity_id: StringName = commodity
	if String(commodity_id).is_empty():
		commodity_id = BalanceOps.DEFAULT_HAUL_COMMODITY
	if not ContentLibrary.has_item(commodity_id):
		return false
	if not _has_market(origin, commodity_id) or not _has_market(dest, commodity_id):
		return false
	var ship_type: StringName = _as_name(ship.get(BalanceOps.SHIP_KEY_TYPE, &""))
	if BalanceOps.type_cargo_cap(ship_type) <= 0:
		return false
	ship[BalanceOps.SHIP_KEY_ORDER] = BalanceOps.ORDER_HAUL
	ship[BalanceOps.SHIP_KEY_ORIGIN] = origin
	ship[BalanceOps.SHIP_KEY_DEST] = dest
	ship[BalanceOps.SHIP_KEY_COMMODITY] = commodity_id
	ship[BalanceOps.SHIP_KEY_HAUL_PROGRESS] = 0.0
	_hired[ops_ship_id] = ship
	EventBus.on_ops_order_changed.emit(ops_ship_id, BalanceOps.ORDER_HAUL)
	return true


func warehouse_qty(station_id: StringName, commodity_id: StringName) -> int:
	if not _warehouse.has(station_id):
		return 0
	var shelf: Dictionary = _warehouse[station_id]
	if not shelf.has(commodity_id):
		return 0
	return maxi(0, _as_int(shelf[commodity_id]))


func warehouse_used_volume(station_id: StringName) -> int:
	if not _warehouse.has(station_id):
		return 0
	var total: int = 0
	var shelf: Dictionary = _warehouse[station_id]
	for key: Variant in shelf.keys():
		var commodity_id: StringName = _as_name(key)
		var qty: int = maxi(0, _as_int(shelf[key]))
		if qty <= 0:
			continue
		total += _commodity_volume(commodity_id) * qty
	return total


## Deposit from player cargo into warehouse at station (must be docked there).
func try_deposit(station_id: StringName, commodity_id: StringName, qty: int) -> bool:
	var cargo: Node = _deposit_ready_cargo(station_id, commodity_id, qty)
	if cargo == null:
		return false
	if cargo.call(&"remove", commodity_id, qty) != true:
		return false
	_set_warehouse_qty(station_id, commodity_id, warehouse_qty(station_id, commodity_id) + qty)
	EventBus.on_warehouse_changed.emit(station_id)
	return true


func _deposit_ready_cargo(station_id: StringName, commodity_id: StringName, qty: int) -> Node:
	if not _warehouse_action_precheck(station_id, commodity_id, qty):
		return null
	if not ContentLibrary.has_item(commodity_id):
		return null
	var unit_vol: int = _commodity_volume(commodity_id)
	var need: int = unit_vol * qty
	if unit_vol <= 0 or warehouse_used_volume(station_id) + need > BalanceOps.WAREHOUSE_CAPACITY:
		return null
	var cargo: Node = _cargo_service()
	if cargo == null or not cargo.has_method(&"quantity") or not cargo.has_method(&"remove"):
		return null
	if _as_int(cargo.call(&"quantity", commodity_id)) < qty:
		return null
	return cargo


## Withdraw from warehouse into player cargo (must be docked; must fit).
func try_withdraw(station_id: StringName, commodity_id: StringName, qty: int) -> bool:
	if not _warehouse_action_precheck(station_id, commodity_id, qty):
		return false
	var have: int = warehouse_qty(station_id, commodity_id)
	if have < qty:
		return false
	var cargo: Node = _cargo_service()
	if cargo == null or not cargo.has_method(&"can_add") or not cargo.has_method(&"add"):
		return false
	if cargo.call(&"can_add", commodity_id, qty) != true:
		return false
	if cargo.call(&"add", commodity_id, qty) != true:
		return false
	_set_warehouse_qty(station_id, commodity_id, have - qty)
	EventBus.on_warehouse_changed.emit(station_id)
	return true


func _warehouse_action_precheck(station_id: StringName, commodity_id: StringName, qty: int) -> bool:
	if qty <= 0 or String(station_id).is_empty() or String(commodity_id).is_empty():
		return false
	return _docked_station_id() == station_id


## Thin dashboard snapshot for station UI / captain sheet.
func dashboard_summary() -> Dictionary:
	var active_orders: Array = []
	for ship_id: StringName in hired_ids():
		var ship: Dictionary = _ship_dict(ship_id)
		var order: StringName = _as_name(ship.get(BalanceOps.SHIP_KEY_ORDER, BalanceOps.ORDER_PARK))
		if order != BalanceOps.ORDER_PARK:
			(
				active_orders
				. append(
					{
						&"id": ship_id,
						&"order": order,
						&"origin": _as_name(ship.get(BalanceOps.SHIP_KEY_ORIGIN, &"")),
						&"dest": _as_name(ship.get(BalanceOps.SHIP_KEY_DEST, &"")),
					}
				)
			)
	var warehouse_stations: Array = []
	for station_key: Variant in _warehouse.keys():
		var station_id: StringName = _as_name(station_key)
		if warehouse_used_volume(station_id) > 0:
			warehouse_stations.append(station_id)
	return {
		&"hired": hired_count(),
		&"upkeep_per_hour": hired_count() * BalanceOps.UPKEEP_CREDITS_PER_HOUR,
		&"warehouse_stations": warehouse_stations,
		&"active_orders": active_orders,
	}


## Upkeep + haul progress for a world-clock delta (seconds of game time).
func tick_ops(delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return
	var hours: float = delta_seconds / BalanceWorldClock.SECONDS_PER_HOUR
	if hours <= 0.0:
		return
	_tick_upkeep(hours)
	_tick_hauls(hours)


# --- Upkeep / breach --------------------------------------------------------


func _tick_upkeep(hours: float) -> void:
	if _hired.is_empty():
		return
	var total_paid: int = 0
	var to_breach: Array[StringName] = []
	for ship_id: StringName in hired_ids():
		var frac: float = 0.0
		if _upkeep_frac.has(ship_id):
			frac = _as_float(_upkeep_frac[ship_id])
		frac += float(BalanceOps.UPKEEP_CREDITS_PER_HOUR) * hours
		var whole: int = int(floorf(frac))
		frac -= float(whole)
		_upkeep_frac[ship_id] = frac
		if whole <= 0:
			continue
		var paid: int = _spend_up_to(whole)
		total_paid += paid
		var ship: Dictionary = _ship_dict(ship_id)
		if paid < whole:
			var misses: int = _as_int(ship.get(BalanceOps.SHIP_KEY_UPKEEP_MISSES, 0)) + 1
			ship[BalanceOps.SHIP_KEY_UPKEEP_MISSES] = misses
			_hired[ship_id] = ship
			if misses >= BalanceOps.UPKEEP_MISS_BREACH_COUNT:
				to_breach.append(ship_id)
		else:
			ship[BalanceOps.SHIP_KEY_UPKEEP_MISSES] = 0
			_hired[ship_id] = ship
	if total_paid > 0:
		_emit_money(BalanceTelemetry.REASON_OPS_UPKEEP, -total_paid)
		EventBus.on_ops_upkeep_paid.emit(total_paid)
	for ship_id: StringName in to_breach:
		_breach_charter(ship_id)


func _breach_charter(ops_ship_id: StringName) -> void:
	var ship: Dictionary = _ship_dict(ops_ship_id)
	if ship.is_empty():
		return
	var entity_id: StringName = _as_name(ship.get(BalanceOps.SHIP_KEY_CHARTER, &""))
	if not String(entity_id).is_empty():
		StandingService.apply_entity_delta(
			entity_id,
			BalanceOps.CHARTER_BREACH_STANDING_DELTA,
			BalanceStanding.REASON_CHARTER_BREACH,
			false
		)
	EventBus.on_ops_charter_breached.emit(ops_ship_id, entity_id)
	try_fire(ops_ship_id)


func _spend_up_to(amount: int) -> int:
	if amount <= 0:
		return 0
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"credits") or not wallet.has_method(&"try_spend"):
		return 0
	var have: int = _as_int(wallet.call(&"credits"))
	var pay: int = mini(amount, have)
	if pay <= 0:
		return 0
	if wallet.call(&"try_spend", pay) != true:
		return 0
	return pay


# --- Haul -------------------------------------------------------------------


func _tick_hauls(hours: float) -> void:
	for ship_id: StringName in hired_ids():
		var ship: Dictionary = _ship_dict(ship_id)
		if ship.is_empty():
			continue
		var order: StringName = _as_name(ship.get(BalanceOps.SHIP_KEY_ORDER, &""))
		if order != BalanceOps.ORDER_HAUL:
			continue
		var progress: float = _as_float(ship.get(BalanceOps.SHIP_KEY_HAUL_PROGRESS, 0.0))
		progress += hours
		while progress >= BalanceOps.HAUL_LEG_HOURS:
			progress -= BalanceOps.HAUL_LEG_HOURS
			_resolve_haul_leg(ship_id)
			if not _hired.has(ship_id):
				break
			ship = _ship_dict(ship_id)
		if _hired.has(ship_id):
			ship[BalanceOps.SHIP_KEY_HAUL_PROGRESS] = progress
			_hired[ship_id] = ship


## One abstract round-trip: buy at origin, sell at dest (no intermediate cargo).
func _resolve_haul_leg(ops_ship_id: StringName) -> void:
	var ship: Dictionary = _ship_dict(ops_ship_id)
	if ship.is_empty():
		return
	var origin: StringName = _as_name(ship.get(BalanceOps.SHIP_KEY_ORIGIN, &""))
	var dest: StringName = _as_name(ship.get(BalanceOps.SHIP_KEY_DEST, &""))
	var commodity_id: StringName = _as_name(ship.get(BalanceOps.SHIP_KEY_COMMODITY, &""))
	if String(origin).is_empty() or String(dest).is_empty() or String(commodity_id).is_empty():
		return
	_execute_haul_buy_sell(origin, dest, commodity_id)


func _execute_haul_buy_sell(origin: StringName, dest: StringName, commodity_id: StringName) -> void:
	var buy_quote: Dictionary = MarketService.quote_buy(origin, commodity_id, BalanceOps.HAUL_UNITS)
	var buy_units: int = _as_int(buy_quote.get(BalanceMarket.QUOTE_KEY_UNITS, 0))
	var buy_total: int = _as_int(buy_quote.get(BalanceMarket.QUOTE_KEY_TOTAL, 0))
	var wallet: Node = _wallet_service()
	var can_pay: bool = (
		buy_units > 0
		and buy_total >= 0
		and wallet != null
		and wallet.has_method(&"can_afford")
		and wallet.has_method(&"try_spend")
		and wallet.call(&"can_afford", buy_total) == true
		and wallet.call(&"try_spend", buy_total) == true
	)
	if not can_pay:
		return
	var charged: int = MarketService.commit_buy(origin, commodity_id, buy_units)
	if charged <= 0:
		if wallet.has_method(&"add_credits"):
			wallet.call(&"add_credits", buy_total)
		return
	if charged != buy_total and wallet.has_method(&"add_credits"):
		wallet.call(&"add_credits", buy_total - charged)
	_emit_money(
		BalanceTelemetry.REASON_OPS_HAUL_PAY,
		-charged,
		{
			BalanceTelemetry.DETAIL_KEY_COMMODITY_ID: commodity_id,
			BalanceTelemetry.DETAIL_KEY_UNITS: buy_units,
			BalanceTelemetry.DETAIL_KEY_STATION_ID: origin,
		}
	)
	var sell_total: int = MarketService.commit_sell(dest, commodity_id, buy_units)
	if sell_total > 0 and wallet.has_method(&"add_credits"):
		wallet.call(&"add_credits", sell_total)
		_emit_money(
			BalanceTelemetry.REASON_OPS_HAUL_PAY,
			sell_total,
			{
				BalanceTelemetry.DETAIL_KEY_COMMODITY_ID: commodity_id,
				BalanceTelemetry.DETAIL_KEY_UNITS: buy_units,
				BalanceTelemetry.DETAIL_KEY_STATION_ID: dest,
			}
		)


func _has_market(station_id: StringName, commodity_id: StringName) -> bool:
	var quote: Dictionary = MarketService.quote_buy(station_id, commodity_id, 1)
	var reason: StringName = _as_name(quote.get(BalanceMarket.QUOTE_KEY_REASON, &""))
	if reason == BalanceMarket.QUOTE_REASON_NO_MARKET:
		return false
	# Sell side also required for the round trip.
	var sell_quote: Dictionary = MarketService.quote_sell(station_id, commodity_id, 1)
	var sell_reason: StringName = _as_name(sell_quote.get(BalanceMarket.QUOTE_KEY_REASON, &""))
	return sell_reason != BalanceMarket.QUOTE_REASON_NO_MARKET


# --- Save helpers -----------------------------------------------------------


func _apply_hired(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var list: Array = raw
	for entry: Variant in list:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = entry
		var ship_id: StringName = _as_name(data.get(BalanceOps.SHIP_KEY_ID, &""))
		if String(ship_id).is_empty():
			continue
		if _hired.size() >= BalanceOps.MAX_HIRED:
			break
		var ship_type: StringName = _as_name(data.get(BalanceOps.SHIP_KEY_TYPE, &""))
		if not BalanceOps.is_known_type(ship_type):
			continue
		var order: StringName = _as_name(data.get(BalanceOps.SHIP_KEY_ORDER, BalanceOps.ORDER_PARK))
		if not BalanceOps.is_known_order(order):
			order = BalanceOps.ORDER_PARK
		var ship: Dictionary = {
			BalanceOps.SHIP_KEY_ID: ship_id,
			BalanceOps.SHIP_KEY_TYPE: ship_type,
			BalanceOps.SHIP_KEY_ORDER: order,
			BalanceOps.SHIP_KEY_ORIGIN: _as_name(data.get(BalanceOps.SHIP_KEY_ORIGIN, &"")),
			BalanceOps.SHIP_KEY_DEST: _as_name(data.get(BalanceOps.SHIP_KEY_DEST, &"")),
			BalanceOps.SHIP_KEY_COMMODITY: _as_name(data.get(BalanceOps.SHIP_KEY_COMMODITY, &"")),
			BalanceOps.SHIP_KEY_CHARTER: _as_name(data.get(BalanceOps.SHIP_KEY_CHARTER, &"")),
			BalanceOps.SHIP_KEY_UPKEEP_MISSES:
			maxi(0, _as_int(data.get(BalanceOps.SHIP_KEY_UPKEEP_MISSES, 0))),
			BalanceOps.SHIP_KEY_HAUL_PROGRESS:
			maxf(0.0, _as_float(data.get(BalanceOps.SHIP_KEY_HAUL_PROGRESS, 0.0))),
			BalanceOps.SHIP_KEY_HOME: _as_name(data.get(BalanceOps.SHIP_KEY_HOME, &"")),
		}
		_hired[ship_id] = ship
		_upkeep_frac[ship_id] = 0.0


func _apply_warehouse(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	for station_key: Variant in data.keys():
		var station_id: StringName = _as_name(station_key)
		if String(station_id).is_empty():
			continue
		var shelf_raw: Variant = data[station_key]
		if typeof(shelf_raw) != TYPE_DICTIONARY:
			continue
		var shelf_in: Dictionary = shelf_raw
		var shelf: Dictionary = {}
		for commodity_key: Variant in shelf_in.keys():
			var commodity_id: StringName = _as_name(commodity_key)
			var qty: int = maxi(0, _as_int(shelf_in[commodity_key]))
			if qty > 0 and ContentLibrary.has_item(commodity_id):
				shelf[commodity_id] = qty
		if not shelf.is_empty():
			_warehouse[station_id] = shelf


func _ship_to_save(ship: Dictionary) -> Dictionary:
	return {
		String(BalanceOps.SHIP_KEY_ID): String(_as_name(ship.get(BalanceOps.SHIP_KEY_ID, &""))),
		String(BalanceOps.SHIP_KEY_TYPE): String(_as_name(ship.get(BalanceOps.SHIP_KEY_TYPE, &""))),
		String(BalanceOps.SHIP_KEY_ORDER):
		String(_as_name(ship.get(BalanceOps.SHIP_KEY_ORDER, BalanceOps.ORDER_PARK))),
		String(BalanceOps.SHIP_KEY_ORIGIN):
		String(_as_name(ship.get(BalanceOps.SHIP_KEY_ORIGIN, &""))),
		String(BalanceOps.SHIP_KEY_DEST): String(_as_name(ship.get(BalanceOps.SHIP_KEY_DEST, &""))),
		String(BalanceOps.SHIP_KEY_COMMODITY):
		String(_as_name(ship.get(BalanceOps.SHIP_KEY_COMMODITY, &""))),
		String(BalanceOps.SHIP_KEY_CHARTER):
		String(_as_name(ship.get(BalanceOps.SHIP_KEY_CHARTER, &""))),
		String(BalanceOps.SHIP_KEY_UPKEEP_MISSES):
		_as_int(ship.get(BalanceOps.SHIP_KEY_UPKEEP_MISSES, 0)),
		String(BalanceOps.SHIP_KEY_HAUL_PROGRESS):
		_as_float(ship.get(BalanceOps.SHIP_KEY_HAUL_PROGRESS, 0.0)),
		String(BalanceOps.SHIP_KEY_HOME): String(_as_name(ship.get(BalanceOps.SHIP_KEY_HOME, &""))),
	}


func _next_ship_id() -> StringName:
	var max_n: int = 0
	for key: Variant in _hired.keys():
		var text: String = String(_as_name(key))
		if text.begins_with(BalanceOps.SHIP_ID_PREFIX):
			var suffix: String = text.substr(BalanceOps.SHIP_ID_PREFIX.length())
			if suffix.is_valid_int():
				max_n = maxi(max_n, int(suffix))
	return StringName("%s%d" % [BalanceOps.SHIP_ID_PREFIX, max_n + 1])


func _set_warehouse_qty(station_id: StringName, commodity_id: StringName, qty: int) -> void:
	if qty <= 0:
		if _warehouse.has(station_id):
			var shelf: Dictionary = _warehouse[station_id]
			shelf.erase(commodity_id)
			if shelf.is_empty():
				_warehouse.erase(station_id)
			else:
				_warehouse[station_id] = shelf
		return
	var next_shelf: Dictionary = {}
	if _warehouse.has(station_id):
		next_shelf = _warehouse[station_id]
	next_shelf[commodity_id] = qty
	_warehouse[station_id] = next_shelf


func _commodity_volume(commodity_id: StringName) -> int:
	if not ContentLibrary.has_item(commodity_id):
		return 1
	var item: ContentItem = ContentLibrary.item(commodity_id)
	if item is Commodity:
		return maxi(1, (item as Commodity).unit_volume)
	return 1


func _emit_money(reason: StringName, delta: int, detail: Dictionary = {}) -> void:
	if delta == 0:
		return
	var credits_after: int = 0
	var wallet: Node = _wallet_service()
	if wallet != null and wallet.has_method(&"credits"):
		credits_after = _as_int(wallet.call(&"credits"))
	EventBus.on_money_event.emit(reason, delta, credits_after, detail)


func _wallet_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"wallet_service")


func _cargo_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"cargo_service")


func _docked_station_id() -> StringName:
	var tree: SceneTree = get_tree()
	if tree == null:
		return &""
	var dock_node: Node = tree.get_first_node_in_group(&"docking_service")
	if dock_node == null or not dock_node.has_method(&"docked_station_id"):
		return &""
	return _as_name(dock_node.call(&"docked_station_id"))


func _station_controller(station_id: StringName) -> StringName:
	if String(station_id).is_empty() or not ContentLibrary.has_item(station_id):
		return &""
	var item: ContentItem = ContentLibrary.item(station_id)
	if not (item is Station):
		return &""
	var station: Station = item as Station
	var controller_id: StringName = station.controller_entity_id
	if controller_id == Station.CONTROLLER_NOBODY or String(controller_id).is_empty():
		return &""
	return controller_id


func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""


func _ship_dict(ops_ship_id: StringName) -> Dictionary:
	if not _hired.has(ops_ship_id):
		return {}
	var raw: Variant = _hired[ops_ship_id]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var ship: Dictionary = raw
	return ship


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float_val: float = value
		return int(as_float_val)
	return 0


func _as_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float_val: float = value
		return as_float_val
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	return 0.0
