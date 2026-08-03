class_name FuelService
extends Node

## Ship tank fuel — burn, jump spend, station refuel (S5 Session B split).
##
## Single writer for fuel level. Child of Main (not an autoload).
## Group: `fuel_service`. Spends credits via group `wallet_service` on refuel.
## Optional save key `fuel` inside the combined `wallet` section (CareerSave
## merges WalletService + FuelService + HullConditionService). No envelope bump.

var _fuel: float = BalanceEconomy.STARTING_FUEL


func _ready() -> void:
	add_to_group(&"fuel_service")
	EventBus.on_refuel_requested.connect(_on_refuel_requested)
	EventBus.on_fuel_changed.emit(_fuel, BalanceEconomy.FUEL_MAX)


func _exit_tree() -> void:
	if EventBus.on_refuel_requested.is_connected(_on_refuel_requested):
		EventBus.on_refuel_requested.disconnect(_on_refuel_requested)


func _on_refuel_requested() -> void:
	refuel_chunk()


func fuel() -> float:
	return _fuel


func fuel_max() -> float:
	return BalanceEconomy.FUEL_MAX


## Reset to boot defaults (tests / new session).
func reset() -> void:
	_set_fuel(BalanceEconomy.STARTING_FUEL)


## Burn fuel for flight this frame. `throttle` 0..1; afterburn multiplies.
## S5: multiplies rate by ShipService.fuel_burn_multiplier() when present.
func burn_fuel(delta_seconds: float, throttle: float, afterburning: bool) -> void:
	if delta_seconds <= 0.0 or throttle <= 0.0:
		return
	if _fuel <= BalanceEconomy.FUEL_EMPTY_EPSILON:
		_set_fuel(0.0)
		return
	var rate: float = BalanceEconomy.FUEL_BURN_PER_SECOND_AT_FULL * throttle
	if afterburning:
		rate *= BalanceEconomy.FUEL_AFTERBURNER_MULTIPLIER
	rate *= _fuel_burn_multiplier()
	_set_fuel(maxf(0.0, _fuel - rate * delta_seconds))


## True when fuel is enough to move (above empty epsilon).
func has_fuel() -> bool:
	return _fuel > BalanceEconomy.FUEL_EMPTY_EPSILON


## True when fuel can pay a jump.
func can_jump() -> bool:
	return _fuel >= BalanceEconomy.JUMP_FUEL_COST


## Spend jump fuel. Returns false if not enough.
func try_spend_jump_fuel() -> bool:
	if not can_jump():
		return false
	_set_fuel(_fuel - BalanceEconomy.JUMP_FUEL_COST)
	return true


## Refuel one chunk (or remaining capacity). Returns fuel added (0 if broke/full).
## Applies standing service mult when docked at a controlled station (E1.5).
## Credits spent through WalletService (group lookup).
func refuel_chunk() -> float:
	var room: float = BalanceEconomy.FUEL_MAX - _fuel
	var added: float = 0.0
	if room > BalanceEconomy.FUEL_EMPTY_EPSILON:
		added = _try_refuel_amount(room)
	return added


func _try_refuel_amount(room: float) -> float:
	var mult: float = _service_cost_mult_for_station()
	var unit_rate: float = BalanceEconomy.REFUEL_CREDITS_PER_UNIT * mult
	var units: float = minf(BalanceEconomy.REFUEL_CHUNK, room)
	var cost: int = _ceil_credits(units * unit_rate)
	var wallet: Node = _wallet_service()
	if cost > 0:
		if wallet == null or not wallet.has_method(&"try_spend"):
			return 0.0
		if wallet.call(&"try_spend", cost) != true:
			units = _affordable_units(wallet, unit_rate, room)
			if units <= BalanceEconomy.FUEL_EMPTY_EPSILON:
				return 0.0
			cost = _ceil_credits(units * unit_rate)
			if wallet.call(&"try_spend", cost) != true:
				return 0.0
	if cost > 0:
		_emit_money(wallet, BalanceTelemetry.REASON_REFUEL, -cost)
	_set_fuel(minf(BalanceEconomy.FUEL_MAX, _fuel + units))
	return units


func _affordable_units(wallet: Node, unit_rate: float, room: float) -> float:
	var credits: int = _wallet_credits(wallet)
	if credits <= 0 or unit_rate <= 0.0:
		return 0.0
	return minf(float(credits) / unit_rate, room)


## Optional save keys owned by this service (fuel only).
func to_section() -> Dictionary:
	return {
		BalanceEconomy.SAVE_KEY_FUEL: _fuel,
	}


## Apply fuel key from the combined wallet section. Ignores other keys.
func apply_section(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		reset()
		return
	var data: Dictionary = raw
	if data.has(BalanceEconomy.SAVE_KEY_FUEL):
		_set_fuel(
			clampf(
				_variant_to_float(data[BalanceEconomy.SAVE_KEY_FUEL]), 0.0, BalanceEconomy.FUEL_MAX
			)
		)


func _wallet_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"wallet_service")


func _wallet_credits(wallet: Node) -> int:
	if wallet == null or not wallet.has_method(&"credits"):
		return 0
	return _variant_to_int(wallet.call(&"credits"))


func _emit_money(wallet: Node, reason: StringName, delta: int) -> void:
	if delta == 0:
		return
	EventBus.on_money_event.emit(reason, delta, _wallet_credits(wallet), {})


func _service_cost_mult_for_station(station_id: StringName = &"") -> float:
	var resolved: StringName = station_id
	if String(resolved).is_empty():
		resolved = _docked_station_id()
	if String(resolved).is_empty():
		return BalanceEconomy.SERVICE_COST_MULT_DEFAULT
	var system_id: StringName = _system_id_for_station(resolved)
	return BalanceEconomy.service_cost_mult_for_tier(_standing_tier_for_place(system_id, resolved))


func _standing_tier_for_place(system_id: StringName, station_id: StringName = &"") -> StringName:
	var controller: StringName = &""
	if not String(station_id).is_empty() and ContentLibrary.has_item(station_id):
		var station_item: ContentItem = ContentLibrary.item(station_id)
		if station_item is Station:
			var station: Station = station_item as Station
			controller = station.controller_entity_id
	if String(controller).is_empty() or controller == Station.CONTROLLER_NOBODY:
		if ContentLibrary.has_item(system_id):
			var sys_item: ContentItem = ContentLibrary.item(system_id)
			if sys_item is StarSystem:
				var system: StarSystem = sys_item as StarSystem
				controller = system.held_by
	if (
		String(controller).is_empty()
		or controller == Station.CONTROLLER_NOBODY
		or controller == StarSystem.HELD_BY_NOBODY
	):
		return BalanceStanding.TIER_NEUTRAL
	var standing: float = StandingService.get_entity_standing(controller)
	return StandingService.tier_for(standing)


func _docked_station_id() -> StringName:
	var tree: SceneTree = get_tree()
	if tree == null:
		return &""
	var dock_node: Node = tree.get_first_node_in_group(&"docking_service")
	if dock_node == null or not dock_node.has_method(&"docked_station_id"):
		return &""
	var raw: Variant = dock_node.call(&"docked_station_id")
	if typeof(raw) == TYPE_STRING_NAME:
		var as_name: StringName = raw
		return as_name
	if typeof(raw) == TYPE_STRING:
		var as_text: String = raw
		return StringName(as_text)
	return &""


func _system_id_for_station(station_id: StringName) -> StringName:
	if String(station_id).is_empty() or not ContentLibrary.has_item(station_id):
		return &""
	var item: ContentItem = ContentLibrary.item(station_id)
	if item is Station:
		var station: Station = item as Station
		return station.system_id
	return &""


func _fuel_burn_multiplier() -> float:
	var ships: Node = _ship_service()
	if ships == null or not ships.has_method(&"fuel_burn_multiplier"):
		return 1.0
	var mult: float = _variant_to_float(ships.call(&"fuel_burn_multiplier"))
	if mult > 0.0:
		return mult
	return 1.0


func _ship_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(BalanceFlight.GROUP_SHIP_SERVICE)


func _ceil_credits(amount: float) -> int:
	if amount <= 0.0:
		return 0
	return int(ceilf(amount))


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


func _variant_to_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return as_float
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	if typeof(value) == TYPE_STRING:
		var text: String = value
		if text.is_valid_float():
			return float(text)
	return 0.0


func _set_fuel(value: float) -> void:
	var next: float = clampf(value, 0.0, BalanceEconomy.FUEL_MAX)
	if is_equal_approx(next, _fuel):
		return
	_fuel = next
	EventBus.on_fuel_changed.emit(_fuel, BalanceEconomy.FUEL_MAX)
