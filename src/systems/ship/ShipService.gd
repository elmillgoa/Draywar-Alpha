class_name ShipService
extends Node

## Active player hull ownership + switch + outfitting — E2.4 / E2.5 / S5.
##
## Implements: docs/BETA_E2_COMBAT_HULL.md E2.4–E2.5, docs/STEAM_PHASE_PLAN.md S5
##
## Child of Main (not an autoload). Single writer for which hull is flying,
## which hulls are owned, and per-hull weapon/equipment loadouts. Optional
## save section `ship` (schema v1). Loadout helpers live in ShipOutfit.

var _active_hull_id: StringName = BalanceFlight.PLAYER_HULL_ID
## Owned hull content ids (always includes starter Hauler after reset).
var _owned_hull_ids: Array[StringName] = []
## hull_id → { weapons: Array[StringName], equipment: Array[StringName] }
var _loadouts: Dictionary = {}


func _ready() -> void:
	add_to_group(BalanceFlight.GROUP_SHIP_SERVICE)
	if _owned_hull_ids.is_empty():
		_owned_hull_ids = _default_owned()
	EventBus.on_buy_fighter_requested.connect(_on_buy_fighter_requested)
	EventBus.on_switch_hull_requested.connect(_on_switch_hull_requested)
	EventBus.on_outfit_install_requested.connect(_on_outfit_install_requested)
	EventBus.on_outfit_uninstall_requested.connect(_on_outfit_uninstall_requested)


func _exit_tree() -> void:
	if EventBus.on_buy_fighter_requested.is_connected(_on_buy_fighter_requested):
		EventBus.on_buy_fighter_requested.disconnect(_on_buy_fighter_requested)
	if EventBus.on_switch_hull_requested.is_connected(_on_switch_hull_requested):
		EventBus.on_switch_hull_requested.disconnect(_on_switch_hull_requested)
	if EventBus.on_outfit_install_requested.is_connected(_on_outfit_install_requested):
		EventBus.on_outfit_install_requested.disconnect(_on_outfit_install_requested)
	if EventBus.on_outfit_uninstall_requested.is_connected(_on_outfit_uninstall_requested):
		EventBus.on_outfit_uninstall_requested.disconnect(_on_outfit_uninstall_requested)


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


## Cargo capacity from active hull + equipment cargo_bonus, or economy fallback.
func active_cargo_capacity() -> int:
	return _cargo_capacity_for(_active_hull_id)


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
					_ensure_loadout(BalanceFlight.FIGHTER_HULL_ID)
					EventBus.on_hull_purchased.emit(BalanceFlight.FIGHTER_HULL_ID)
					ok = true
	return ok


## True when target is owned, different from active, and cargo volume fits
## the target hold **with that hull's equipment cargo bonus**.
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
	var used: int = _cargo_used_volume()
	return used <= _cargo_capacity_for(hull_id)


## Switch active hull while docked (D2 cargo fit). Applies immediately via bus.
func switch_hull(hull_id: StringName) -> bool:
	if not _is_docked():
		return false
	if not can_switch_to(hull_id):
		return false
	return set_active_hull_id(hull_id)


## Weapon hardpoint count for a hull (role via BalanceOutfit).
func weapon_slots_for(hull_id: StringName) -> int:
	var hull: Hull = _hull_for(hull_id)
	if hull == null:
		return BalanceOutfit.HAULER_WEAPON_SLOTS
	return BalanceOutfit.weapon_slots_for_role(hull.role)


## Equipment module count for a hull (role via BalanceOutfit).
func equipment_slots_for(hull_id: StringName) -> int:
	var hull: Hull = _hull_for(hull_id)
	if hull == null:
		return BalanceOutfit.HAULER_EQUIPMENT_SLOTS
	return BalanceOutfit.equipment_slots_for_role(hull.role)


## Installed weapon ids for a hull (default active). Copy; empty = EMPTY_SLOT.
func installed_weapons(hull_id: StringName = &"") -> Array[StringName]:
	var id: StringName = hull_id if not String(hull_id).is_empty() else _active_hull_id
	return ShipOutfit.copy_ids(_weapons_mut(id))


## Installed equipment ids for a hull (default active). Copy.
func installed_equipment(hull_id: StringName = &"") -> Array[StringName]:
	var id: StringName = hull_id if not String(hull_id).is_empty() else _active_hull_id
	return ShipOutfit.copy_ids(_equipment_mut(id))


## First installed weapon damage on active hull, else hull baseline.
func effective_weapon_damage() -> float:
	var weapon: Weapon = _first_active_weapon()
	if weapon != null:
		return weapon.damage
	var hull: Hull = active_hull()
	if hull != null and hull.weapon_damage > 0.0:
		return hull.weapon_damage
	return BalanceCombat.PLAYER_WEAPON_DAMAGE


## First installed weapon cooldown on active hull, else hull baseline.
func effective_weapon_cooldown() -> float:
	var weapon: Weapon = _first_active_weapon()
	if weapon != null:
		return weapon.cooldown
	var hull: Hull = active_hull()
	if hull != null and hull.weapon_cooldown > 0.0:
		return hull.weapon_cooldown
	return BalanceCombat.PLAYER_FIRE_COOLDOWN


## First installed weapon projectile speed on active hull, else hull baseline.
func effective_weapon_projectile_speed() -> float:
	var weapon: Weapon = _first_active_weapon()
	if weapon != null:
		return weapon.projectile_speed
	var hull: Hull = active_hull()
	if hull != null and hull.projectile_speed > 0.0:
		return hull.projectile_speed
	return BalanceCombat.PROJECTILE_SPEED


## Product of damage_taken_mult on active hull equipment (default 1.0).
func damage_taken_multiplier() -> float:
	return ShipOutfit.damage_taken_multiplier_from(installed_equipment())


## Product of fuel_burn_mult on active hull equipment (default 1.0).
func fuel_burn_multiplier() -> float:
	return ShipOutfit.fuel_burn_multiplier_from(installed_equipment())


## Sum of turn_rate_bonus on active hull equipment.
func turn_rate_bonus() -> float:
	return ShipOutfit.turn_rate_bonus_from(installed_equipment())


## Sum of afterburner_bonus on active hull equipment.
func afterburner_bonus() -> float:
	return ShipOutfit.afterburner_bonus_from(installed_equipment())


## True when item can install on active hull (docked, role, free slot, afford).
func can_install(item_id: StringName) -> bool:
	if not _is_docked():
		return false
	if String(item_id).is_empty() or not ContentLibrary.has_item(item_id):
		return false
	var item: ContentItem = ContentLibrary.item(item_id)
	var hull: Hull = active_hull()
	if hull == null:
		return false
	if item is Weapon:
		return _can_install_weapon(item as Weapon, hull)
	if item is Equipment:
		return _can_install_equipment(item as Equipment, hull)
	return false


## Buy and install a weapon into the first free active hardpoint.
func install_weapon(item_id: StringName) -> bool:
	if not can_install(item_id):
		return false
	var item: ContentItem = ContentLibrary.item(item_id)
	if not (item is Weapon):
		return false
	var weapon: Weapon = item as Weapon
	var weapons: Array[StringName] = _weapons_mut(_active_hull_id)
	var slot: int = ShipOutfit.first_free_slot(weapons)
	if slot < 0:
		return false
	if not _try_spend_outfit(weapon.buy_price, item_id):
		return false
	weapons[slot] = item_id
	_set_weapons(_active_hull_id, weapons)
	EventBus.on_loadout_changed.emit(_active_hull_id)
	return true


## Buy and install equipment into the first free active module slot.
func install_equipment(item_id: StringName) -> bool:
	if not can_install(item_id):
		return false
	var item: ContentItem = ContentLibrary.item(item_id)
	if not (item is Equipment):
		return false
	var equip: Equipment = item as Equipment
	var equipment: Array[StringName] = _equipment_mut(_active_hull_id)
	var slot: int = ShipOutfit.first_free_slot(equipment)
	if slot < 0:
		return false
	if not _try_spend_outfit(equip.buy_price, item_id):
		return false
	equipment[slot] = item_id
	_set_equipment(_active_hull_id, equipment)
	EventBus.on_loadout_changed.emit(_active_hull_id)
	return true


## Uninstall weapon at slot; refund floor(price * SELL_FRACTION).
func uninstall_weapon(slot_index: int) -> bool:
	if not _is_docked():
		return false
	var weapons: Array[StringName] = _weapons_mut(_active_hull_id)
	if slot_index < 0 or slot_index >= weapons.size():
		return false
	var item_id: StringName = weapons[slot_index]
	if item_id == BalanceOutfit.EMPTY_SLOT or String(item_id).is_empty():
		return false
	var refund: int = 0
	if ContentLibrary.has_item(item_id):
		var item: ContentItem = ContentLibrary.item(item_id)
		if item is Weapon:
			refund = BalanceOutfit.sell_refund((item as Weapon).buy_price)
	weapons[slot_index] = BalanceOutfit.EMPTY_SLOT
	_set_weapons(_active_hull_id, weapons)
	_refund_outfit(refund, item_id)
	EventBus.on_loadout_changed.emit(_active_hull_id)
	return true


## Uninstall equipment at slot; refund floor(price * SELL_FRACTION).
func uninstall_equipment(slot_index: int) -> bool:
	if not _is_docked():
		return false
	var equipment: Array[StringName] = _equipment_mut(_active_hull_id)
	if slot_index < 0 or slot_index >= equipment.size():
		return false
	var item_id: StringName = equipment[slot_index]
	if item_id == BalanceOutfit.EMPTY_SLOT or String(item_id).is_empty():
		return false
	var refund: int = 0
	if ContentLibrary.has_item(item_id):
		var item: ContentItem = ContentLibrary.item(item_id)
		if item is Equipment:
			refund = BalanceOutfit.sell_refund((item as Equipment).buy_price)
	equipment[slot_index] = BalanceOutfit.EMPTY_SLOT
	_set_equipment(_active_hull_id, equipment)
	_refund_outfit(refund, item_id)
	EventBus.on_loadout_changed.emit(_active_hull_id)
	return true


## Reset to starter Hauler only (new game / tests). Clears loadouts.
func reset() -> void:
	var old_id: StringName = _active_hull_id
	_active_hull_id = BalanceFlight.PLAYER_HULL_ID
	_owned_hull_ids = _default_owned()
	_loadouts = {}
	_ensure_loadout(_active_hull_id)
	if old_id != _active_hull_id:
		EventBus.on_hull_changed.emit(old_id, _active_hull_id)


## Optional save section: active_hull_id + owned_hull_ids + loadouts.
func to_section() -> Dictionary:
	var owned: Array = []
	for hull_id: StringName in _owned_hull_ids:
		owned.append(String(hull_id))
	var loadouts: Dictionary = {}
	for hull_id: Variant in _loadouts.keys():
		var hid: StringName = _as_name(hull_id)
		if String(hid).is_empty():
			continue
		loadouts[String(hid)] = ShipOutfit.loadout_to_dict(_weapons_mut(hid), _equipment_mut(hid))
	return {
		BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(_active_hull_id),
		BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: owned,
		BalanceFlight.SAVE_KEY_LOADOUTS: loadouts,
	}


## Apply optional ship section. Missing/invalid → Hauler only. Bad outfit ids drop.
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
		if not owned.has(BalanceFlight.PLAYER_HULL_ID):
			owned.insert(0, BalanceFlight.PLAYER_HULL_ID)
	_owned_hull_ids = owned
	_loadouts = {}
	_apply_loadouts_from_save(data)

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
	clamp_active_to_cargo_fit()


## If used cargo exceeds active hold (with equipment), switch to largest owned fit.
func clamp_active_to_cargo_fit() -> void:
	var used: int = _cargo_used_volume()
	if used <= _cargo_capacity_for(_active_hull_id):
		return
	var best_id: StringName = &""
	var best_cap: int = -1
	for hull_id: StringName in _owned_hull_ids:
		var cap: int = _cargo_capacity_for(hull_id)
		if used <= cap and cap > best_cap:
			best_cap = cap
			best_id = hull_id
	if String(best_id).is_empty():
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


func _on_outfit_install_requested(item_id: StringName) -> void:
	if String(item_id).is_empty() or not ContentLibrary.has_item(item_id):
		return
	var item: ContentItem = ContentLibrary.item(item_id)
	if item is Weapon:
		install_weapon(item_id)
	elif item is Equipment:
		install_equipment(item_id)


func _on_outfit_uninstall_requested(item_id: StringName, slot_index: int) -> void:
	if String(item_id).is_empty():
		return
	if not ContentLibrary.has_item(item_id):
		return
	var item: ContentItem = ContentLibrary.item(item_id)
	if item is Weapon:
		uninstall_weapon(slot_index)
	elif item is Equipment:
		uninstall_equipment(slot_index)


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


## Hold capacity for a hull id including that hull's cargo equipment.
func _cargo_capacity_for(hull_id: StringName) -> int:
	var hull: Hull = _hull_for(hull_id)
	if hull == null:
		if hull_id == _active_hull_id or String(hull_id).is_empty():
			return BalanceEconomy.CARGO_CAPACITY
		return 0
	return maxi(0, hull.cargo_capacity + _cargo_bonus(hull_id))


## Sum of cargo_bonus equipment on a hull (default active).
func _cargo_bonus(hull_id: StringName = &"") -> int:
	var id: StringName = hull_id if not String(hull_id).is_empty() else _active_hull_id
	return ShipOutfit.cargo_bonus_from(installed_equipment(id))


func _ensure_loadout(hull_id: StringName) -> void:
	if String(hull_id).is_empty():
		return
	if _loadouts.has(hull_id):
		return
	var w_slots: int = weapon_slots_for(hull_id)
	var e_slots: int = equipment_slots_for(hull_id)
	_loadouts[hull_id] = {
		String(BalanceOutfit.SAVE_KEY_WEAPONS): ShipOutfit.empty_slots(w_slots),
		String(BalanceOutfit.SAVE_KEY_EQUIPMENT): ShipOutfit.empty_slots(e_slots),
	}


func _weapons_mut(hull_id: StringName) -> Array[StringName]:
	_ensure_loadout(hull_id)
	var entry: Dictionary = _loadouts[hull_id]
	var key: String = String(BalanceOutfit.SAVE_KEY_WEAPONS)
	if not entry.has(key):
		return ShipOutfit.empty_slots(weapon_slots_for(hull_id))
	return _coerce_id_array(entry[key], weapon_slots_for(hull_id))


func _equipment_mut(hull_id: StringName) -> Array[StringName]:
	_ensure_loadout(hull_id)
	var entry: Dictionary = _loadouts[hull_id]
	var key: String = String(BalanceOutfit.SAVE_KEY_EQUIPMENT)
	if not entry.has(key):
		return ShipOutfit.empty_slots(equipment_slots_for(hull_id))
	return _coerce_id_array(entry[key], equipment_slots_for(hull_id))


func _set_weapons(hull_id: StringName, weapons: Array[StringName]) -> void:
	_ensure_loadout(hull_id)
	var entry: Dictionary = _loadouts[hull_id]
	entry[String(BalanceOutfit.SAVE_KEY_WEAPONS)] = weapons
	_loadouts[hull_id] = entry


func _set_equipment(hull_id: StringName, equipment: Array[StringName]) -> void:
	_ensure_loadout(hull_id)
	var entry: Dictionary = _loadouts[hull_id]
	entry[String(BalanceOutfit.SAVE_KEY_EQUIPMENT)] = equipment
	_loadouts[hull_id] = entry


func _coerce_id_array(raw: Variant, slot_count: int) -> Array[StringName]:
	var out: Array[StringName] = ShipOutfit.empty_slots(slot_count)
	if typeof(raw) != TYPE_ARRAY:
		return out
	var arr: Array = raw
	var i: int = 0
	while i < slot_count and i < arr.size():
		out[i] = _as_name(arr[i])
		i += 1
	return out


func _apply_loadouts_from_save(data: Dictionary) -> void:
	if not data.has(BalanceFlight.SAVE_KEY_LOADOUTS):
		for hull_id: StringName in _owned_hull_ids:
			_ensure_loadout(hull_id)
		return
	var raw: Variant = data[BalanceFlight.SAVE_KEY_LOADOUTS]
	if typeof(raw) != TYPE_DICTIONARY:
		for hull_id: StringName in _owned_hull_ids:
			_ensure_loadout(hull_id)
		return
	var table: Dictionary = raw
	for hull_id: StringName in _owned_hull_ids:
		_ensure_loadout(hull_id)
		var key: String = String(hull_id)
		if not table.has(key) and not table.has(hull_id):
			continue
		var entry_raw: Variant = table[key] if table.has(key) else table[hull_id]
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_raw
		var w_raw: Variant = null
		var e_raw: Variant = null
		if entry.has(BalanceOutfit.SAVE_KEY_WEAPONS):
			w_raw = entry[BalanceOutfit.SAVE_KEY_WEAPONS]
		elif entry.has(String(BalanceOutfit.SAVE_KEY_WEAPONS)):
			w_raw = entry[String(BalanceOutfit.SAVE_KEY_WEAPONS)]
		if entry.has(BalanceOutfit.SAVE_KEY_EQUIPMENT):
			e_raw = entry[BalanceOutfit.SAVE_KEY_EQUIPMENT]
		elif entry.has(String(BalanceOutfit.SAVE_KEY_EQUIPMENT)):
			e_raw = entry[String(BalanceOutfit.SAVE_KEY_EQUIPMENT)]
		_loadouts[hull_id] = {
			String(BalanceOutfit.SAVE_KEY_WEAPONS):
			ShipOutfit.parse_weapon_ids(w_raw, weapon_slots_for(hull_id)),
			String(BalanceOutfit.SAVE_KEY_EQUIPMENT):
			ShipOutfit.parse_equipment_ids(e_raw, equipment_slots_for(hull_id)),
		}


func _first_active_weapon() -> Weapon:
	var weapons: Array[StringName] = _weapons_mut(_active_hull_id)
	var id: StringName = ShipOutfit.first_weapon_id(weapons)
	if String(id).is_empty() or id == BalanceOutfit.EMPTY_SLOT:
		return null
	if not ContentLibrary.has_item(id):
		return null
	var item: ContentItem = ContentLibrary.item(id)
	if item is Weapon:
		return item as Weapon
	return null


func _can_install_weapon(weapon: Weapon, hull: Hull) -> bool:
	if not ShipOutfit.role_allows(hull.role, weapon.hauler_ok, weapon.fighter_ok):
		return false
	if ShipOutfit.first_free_slot(_weapons_mut(_active_hull_id)) < 0:
		return false
	return _can_afford(weapon.buy_price)


func _can_install_equipment(equip: Equipment, hull: Hull) -> bool:
	if not ShipOutfit.role_allows(hull.role, equip.hauler_ok, equip.fighter_ok):
		return false
	if ShipOutfit.first_free_slot(_equipment_mut(_active_hull_id)) < 0:
		return false
	return _can_afford(equip.buy_price)


func _can_afford(cost: int) -> bool:
	if cost <= 0:
		return true
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"can_afford"):
		return false
	return wallet.call(&"can_afford", cost) == true


func _try_spend_outfit(cost: int, item_id: StringName) -> bool:
	if cost <= 0:
		return true
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"try_spend"):
		return false
	if wallet.call(&"try_spend", cost) != true:
		return false
	var credits_after: int = 0
	if wallet.has_method(&"credits"):
		var raw: Variant = wallet.call(&"credits")
		if typeof(raw) == TYPE_INT:
			credits_after = raw
	EventBus.on_money_event.emit(
		BalanceTelemetry.REASON_OUTFIT_BUY,
		-cost,
		credits_after,
		{BalanceTelemetry.DETAIL_KEY_ITEM_ID: item_id}
	)
	return true


func _refund_outfit(refund: int, item_id: StringName) -> void:
	if refund <= 0:
		return
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"add_credits"):
		return
	wallet.call(&"add_credits", refund)
	var credits_after: int = 0
	if wallet.has_method(&"credits"):
		var raw: Variant = wallet.call(&"credits")
		if typeof(raw) == TYPE_INT:
			credits_after = raw
	EventBus.on_money_event.emit(
		BalanceTelemetry.REASON_OUTFIT_SELL,
		refund,
		credits_after,
		{BalanceTelemetry.DETAIL_KEY_ITEM_ID: item_id}
	)


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
