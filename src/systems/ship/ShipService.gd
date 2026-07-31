class_name ShipService
extends Node

## Active player hull ownership + switch — E2.4 / E2.5.
##
## Implements: docs/BETA_E2_COMBAT_HULL.md E2.4–E2.5
##
## Child of Main (not an autoload). Single writer for which hull is flying and
## which hulls are owned. New game: Hauler only. Fighter bought once for credits
## at a docked Services desk; switch blocked when cargo volume exceeds target
## hold. Optional save section `ship` (schema v1).

var _active_hull_id: StringName = BalanceFlight.PLAYER_HULL_ID
## Owned hull content ids (always includes starter Hauler after reset).
var _owned_hull_ids: Array[StringName] = []


func _ready() -> void:
	add_to_group(BalanceFlight.GROUP_SHIP_SERVICE)
	if _owned_hull_ids.is_empty():
		_owned_hull_ids = _default_owned()
	EventBus.on_buy_fighter_requested.connect(_on_buy_fighter_requested)
	EventBus.on_switch_hull_requested.connect(_on_switch_hull_requested)


func _exit_tree() -> void:
	if EventBus.on_buy_fighter_requested.is_connected(_on_buy_fighter_requested):
		EventBus.on_buy_fighter_requested.disconnect(_on_buy_fighter_requested)
	if EventBus.on_switch_hull_requested.is_connected(_on_switch_hull_requested):
		EventBus.on_switch_hull_requested.disconnect(_on_switch_hull_requested)


## Current flyable hull content id.
func active_hull_id() -> StringName:
	return _active_hull_id


## Copy of owned hull ids (starter always present after reset/apply).
func owned_hull_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for hull_id: StringName in _owned_hull_ids:
		out.append(hull_id)
	return out


## True when this hull id is owned.
func owns(hull_id: StringName) -> bool:
	return _owned_hull_ids.has(hull_id)


## Set the active hull id (must exist in ContentLibrary as a Hull). Returns false
## if the id is missing or not a Hull. Does not check cargo fit or ownership —
## use switch_hull for docked player switches (E2.5).
func set_active_hull_id(hull_id: StringName) -> bool:
	if String(hull_id).is_empty():
		return false
	if not ContentLibrary.has_item(hull_id):
		return false
	var item: ContentItem = ContentLibrary.item(hull_id)
	if not (item is Hull):
		return false
	if hull_id == _active_hull_id:
		return true
	var old_id: StringName = _active_hull_id
	_active_hull_id = hull_id
	EventBus.on_hull_changed.emit(old_id, _active_hull_id)
	return true


## Resolved Hull resource for the active id, or null if missing.
func active_hull() -> Hull:
	return _hull_for(_active_hull_id)


## Cargo capacity from the active hull, or BalanceEconomy.CARGO_CAPACITY fallback.
func active_cargo_capacity() -> int:
	var hull: Hull = active_hull()
	if hull == null:
		return BalanceEconomy.CARGO_CAPACITY
	return maxi(0, hull.cargo_capacity)


## True when Fighter is not owned, player is docked, and wallet can pay.
func can_buy_fighter() -> bool:
	if owns(BalanceFlight.FIGHTER_HULL_ID):
		return false
	if not _is_docked():
		return false
	if not ContentLibrary.has_item(BalanceFlight.FIGHTER_HULL_ID):
		return false
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"can_afford"):
		return false
	return wallet.call(&"can_afford", BalanceEconomy.FIGHTER_PURCHASE_COST) == true


## Pay once for Fighter ownership (D1). Does not switch hull. Docked only.
func buy_fighter() -> bool:
	var ok: bool = false
	if not owns(BalanceFlight.FIGHTER_HULL_ID) and _is_docked():
		if ContentLibrary.has_item(BalanceFlight.FIGHTER_HULL_ID):
			var item: ContentItem = ContentLibrary.item(BalanceFlight.FIGHTER_HULL_ID)
			var wallet: Node = _wallet_service()
			if item is Hull and wallet != null and wallet.has_method(&"try_spend"):
				if wallet.call(&"try_spend", BalanceEconomy.FIGHTER_PURCHASE_COST) == true:
					_owned_hull_ids.append(BalanceFlight.FIGHTER_HULL_ID)
					EventBus.on_hull_purchased.emit(BalanceFlight.FIGHTER_HULL_ID)
					ok = true
	return ok


## True when target is owned, different from active, and cargo volume fits.
func can_switch_to(hull_id: StringName) -> bool:
	if String(hull_id).is_empty() or hull_id == _active_hull_id:
		return false
	if not owns(hull_id):
		return false
	if not ContentLibrary.has_item(hull_id):
		return false
	var item: ContentItem = ContentLibrary.item(hull_id)
	if not (item is Hull):
		return false
	var target: Hull = item as Hull
	var used: int = _cargo_used_volume()
	return used <= maxi(0, target.cargo_capacity)


## Switch active hull while docked (D2 cargo fit). Applies immediately via bus.
func switch_hull(hull_id: StringName) -> bool:
	if not _is_docked():
		return false
	if not can_switch_to(hull_id):
		return false
	return set_active_hull_id(hull_id)


## Reset to starter Hauler only (new game / tests).
func reset() -> void:
	var old_id: StringName = _active_hull_id
	_active_hull_id = BalanceFlight.PLAYER_HULL_ID
	_owned_hull_ids = _default_owned()
	if old_id != _active_hull_id:
		EventBus.on_hull_changed.emit(old_id, _active_hull_id)


## Optional save section: active_hull_id + owned_hull_ids.
func to_section() -> Dictionary:
	var owned: Array = []
	for hull_id: StringName in _owned_hull_ids:
		owned.append(String(hull_id))
	return {
		BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(_active_hull_id),
		BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: owned,
	}


## Apply optional ship section. Missing/invalid → Hauler only.
## If cargo already exceeds the restored active hold (or cargo loads after and
## CareerSave re-clamps), active is forced to the largest owned hull that fits.
func apply_section(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		reset()
		return
	var data: Dictionary = raw
	var owned: Array[StringName] = []
	if data.has(BalanceFlight.SAVE_KEY_OWNED_HULL_IDS):
		var owned_raw: Variant = data[BalanceFlight.SAVE_KEY_OWNED_HULL_IDS]
		if typeof(owned_raw) == TYPE_ARRAY:
			var owned_array: Array = owned_raw
			for entry: Variant in owned_array:
				var hull_id: StringName = _as_name(entry)
				if String(hull_id).is_empty():
					continue
				if not ContentLibrary.has_item(hull_id):
					continue
				var item: ContentItem = ContentLibrary.item(hull_id)
				if item is Hull and not owned.has(hull_id):
					owned.append(hull_id)
	if owned.is_empty() or not owned.has(BalanceFlight.PLAYER_HULL_ID):
		# Always keep starter ownership.
		if not owned.has(BalanceFlight.PLAYER_HULL_ID):
			owned.insert(0, BalanceFlight.PLAYER_HULL_ID)
	_owned_hull_ids = owned

	var next_active: StringName = BalanceFlight.PLAYER_HULL_ID
	if data.has(BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID):
		var active_raw: StringName = _as_name(data[BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID])
		if owns(active_raw) and ContentLibrary.has_item(active_raw):
			var active_item: ContentItem = ContentLibrary.item(active_raw)
			if active_item is Hull:
				next_active = active_raw
	var old_id: StringName = _active_hull_id
	_active_hull_id = next_active
	if old_id != _active_hull_id:
		EventBus.on_hull_changed.emit(old_id, _active_hull_id)
	# D2: never leave an overweight active hull after load/apply.
	clamp_active_to_cargo_fit()


## If used cargo volume exceeds the active hull hold, switch active to the
## largest-capacity owned hull that fits (Hauler when owned). Player switch
## still goes through switch_hull only; this is load / apply safety.
func clamp_active_to_cargo_fit() -> void:
	var used: int = _cargo_used_volume()
	var active: Hull = active_hull()
	if active != null and used <= maxi(0, active.cargo_capacity):
		return
	var best_id: StringName = &""
	var best_cap: int = -1
	for hull_id: StringName in _owned_hull_ids:
		var hull: Hull = _hull_for(hull_id)
		if hull == null:
			continue
		var cap: int = maxi(0, hull.cargo_capacity)
		if used <= cap and cap > best_cap:
			best_cap = cap
			best_id = hull_id
	if String(best_id).is_empty():
		# Nothing fits — fall back to starter Hauler if owned, else leave.
		if owns(BalanceFlight.PLAYER_HULL_ID):
			best_id = BalanceFlight.PLAYER_HULL_ID
		else:
			return
	if best_id != _active_hull_id:
		set_active_hull_id(best_id)


func _on_buy_fighter_requested() -> void:
	buy_fighter()


func _on_switch_hull_requested(hull_id: StringName) -> void:
	switch_hull(hull_id)


func _default_owned() -> Array[StringName]:
	var owned: Array[StringName] = []
	owned.append(BalanceFlight.PLAYER_HULL_ID)
	return owned


func _hull_for(hull_id: StringName) -> Hull:
	if String(hull_id).is_empty() or not ContentLibrary.has_item(hull_id):
		return null
	var item: ContentItem = ContentLibrary.item(hull_id)
	if item is Hull:
		return item as Hull
	return null


func _cargo_used_volume() -> int:
	var cargo: Node = _cargo_service()
	if cargo == null or not cargo.has_method(&"used_volume"):
		return 0
	var raw: Variant = cargo.call(&"used_volume")
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return maxi(0, as_int)
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return maxi(0, int(as_float))
	return 0


func _is_docked() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var docking: Node = tree.get_first_node_in_group(&"docking_service")
	if docking == null or not docking.has_method(&"docked_station_id"):
		return false
	var station_raw: Variant = docking.call(&"docked_station_id")
	if typeof(station_raw) == TYPE_STRING_NAME:
		var as_name: StringName = station_raw
		return as_name != &""
	if typeof(station_raw) == TYPE_STRING:
		var as_text: String = station_raw
		return not as_text.is_empty()
	return false


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


func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""
