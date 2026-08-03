class_name HullConditionService
extends Node

## Ship hull condition — wear, combat damage, repair, cripple fail-state
## (S5 Session B split from WalletService).
##
## Single writer for condition. Child of Main (not an autoload).
## Group: `hull_condition_service`. Spends credits via group `wallet_service`
## on repair. Optional save key `condition` inside the combined `wallet`
## section (CareerSave merges all three). No envelope bump.

var _condition: float = BalanceEconomy.STARTING_CONDITION


func _ready() -> void:
	add_to_group(&"hull_condition_service")
	EventBus.on_repair_requested.connect(_on_repair_requested)
	EventBus.on_condition_changed.emit(_condition, BalanceEconomy.CONDITION_MAX)


func _exit_tree() -> void:
	if EventBus.on_repair_requested.is_connected(_on_repair_requested):
		EventBus.on_repair_requested.disconnect(_on_repair_requested)


func _on_repair_requested() -> void:
	repair_full()


func condition() -> float:
	return _condition


func condition_max() -> float:
	return BalanceEconomy.CONDITION_MAX


## Reset to boot defaults (tests / new session).
func reset() -> void:
	_set_condition(BalanceEconomy.STARTING_CONDITION)


## Wear hull while afterburning.
func wear_condition(delta_seconds: float, afterburning: bool) -> void:
	if not afterburning or delta_seconds <= 0.0:
		return
	var next: float = (
		_condition - BalanceEconomy.CONDITION_WEAR_PER_SECOND_AFTERBURN * delta_seconds
	)
	_set_condition(clampf(next, BalanceEconomy.CONDITION_MIN, BalanceEconomy.CONDITION_MAX))


## Combat (or test) hull damage. Returns applied amount. Emits player damage bus.
## S5: scales by ShipService.damage_taken_multiplier() when a ship service exists.
func apply_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var scaled: float = amount * _damage_taken_multiplier()
	if scaled <= 0.0:
		return 0.0
	var before: float = _condition
	_set_condition(_condition - scaled)
	EventBus.on_player_damaged.emit(_condition)
	return before - _condition


## True when the ship can still fly (condition above the cripple floor).
func can_fly() -> bool:
	return _condition > BalanceEconomy.CONDITION_MIN


## Speed factor from hull condition (1.0 healthy → CONDITION_MIN_SPEED_FACTOR).
func speed_factor() -> float:
	var t: float = _condition / BalanceEconomy.CONDITION_MAX
	return lerpf(BalanceEconomy.CONDITION_MIN_SPEED_FACTOR, 1.0, clampf(t, 0.0, 1.0))


## True when repair is allowed at this station (Hostile/Hated refuse).
## Empty id uses currently docked station; undocked → allow (tests / non-menu).
func can_repair_at_station(station_id: StringName = &"") -> bool:
	var resolved: StringName = station_id
	if String(resolved).is_empty():
		resolved = _docked_station_id()
	if String(resolved).is_empty():
		return true
	var system_id: StringName = _system_id_for_station(resolved)
	var tier: StringName = _standing_tier_for_place(system_id, resolved)
	return not BalanceEconomy.service_repair_denied_for_tier(tier)


## Full repair toward CONDITION_MAX. Returns true if any repair applied.
## Hostile/Hated at docked controller station: refused (E1.5). Cost uses mult.
## Credits spent through WalletService (group lookup).
func repair_full() -> bool:
	if _condition >= BalanceEconomy.CONDITION_MAX:
		return false
	if not can_repair_at_station():
		return false
	var was_crippled: bool = _condition <= BalanceEconomy.CONDITION_MIN
	var missing: float = BalanceEconomy.CONDITION_MAX - _condition
	var fraction: float = missing / BalanceEconomy.CONDITION_MAX
	var mult: float = _service_cost_mult_for_station()
	var cost: int = _ceil_credits(float(BalanceEconomy.REPAIR_FULL_COST) * fraction * mult)
	var wallet: Node = _wallet_service()
	if cost <= 0:
		_set_condition(BalanceEconomy.CONDITION_MAX)
		if was_crippled:
			EventBus.on_player_repaired_from_cripple.emit()
		return true
	if wallet == null or not wallet.has_method(&"try_spend"):
		return false
	if wallet.call(&"try_spend", cost) != true:
		return false
	_emit_money(wallet, BalanceTelemetry.REASON_REPAIR, -cost)
	_set_condition(BalanceEconomy.CONDITION_MAX)
	if was_crippled:
		EventBus.on_player_repaired_from_cripple.emit()
	return true


## Optional save keys owned by this service (condition only).
func to_section() -> Dictionary:
	return {
		BalanceEconomy.SAVE_KEY_CONDITION: _condition,
	}


## Apply condition key from the combined wallet section. Ignores other keys.
func apply_section(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		reset()
		return
	var data: Dictionary = raw
	if data.has(BalanceEconomy.SAVE_KEY_CONDITION):
		_set_condition(
			clampf(
				_variant_to_float(data[BalanceEconomy.SAVE_KEY_CONDITION]),
				BalanceEconomy.CONDITION_MIN,
				BalanceEconomy.CONDITION_MAX
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


func _damage_taken_multiplier() -> float:
	var ships: Node = _ship_service()
	if ships == null or not ships.has_method(&"damage_taken_multiplier"):
		return 1.0
	var mult: float = _variant_to_float(ships.call(&"damage_taken_multiplier"))
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


func _set_condition(value: float) -> void:
	var previous: float = _condition
	var next: float = clampf(value, BalanceEconomy.CONDITION_MIN, BalanceEconomy.CONDITION_MAX)
	if is_equal_approx(next, _condition):
		return
	_condition = next
	EventBus.on_condition_changed.emit(_condition, BalanceEconomy.CONDITION_MAX)
	# Fail state: first time condition hits the floor, ship is dead in the water.
	if previous > BalanceEconomy.CONDITION_MIN and next <= BalanceEconomy.CONDITION_MIN:
		EventBus.on_player_crippled.emit()
