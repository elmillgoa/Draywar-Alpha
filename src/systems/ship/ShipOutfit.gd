class_name ShipOutfit
extends RefCounted

## Pure loadout helpers for ShipService — Steam S5.
##
## Keeps ShipService under the method/line caps. No scene tree; callers pass
## loadout dictionaries and resolve ContentLibrary themselves when needed.


## Empty slot-sized array of EMPTY_SLOT markers.
static func empty_slots(count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var i: int = 0
	while i < count:
		out.append(BalanceOutfit.EMPTY_SLOT)
		i += 1
	return out


## Copy of a loadout id array (empty-safe).
static func copy_ids(source: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in source:
		out.append(id)
	return out


## First free index with EMPTY_SLOT, or -1.
static func first_free_slot(slots: Array[StringName]) -> int:
	var i: int = 0
	while i < slots.size():
		if slots[i] == BalanceOutfit.EMPTY_SLOT or String(slots[i]).is_empty():
			return i
		i += 1
	return -1


## True when role allows install for hauler_ok / fighter_ok flags.
static func role_allows(role: StringName, hauler_ok: bool, fighter_ok: bool) -> bool:
	if role == Hull.ROLE_FIGHTER:
		return fighter_ok
	if role == Hull.ROLE_HAULER:
		return hauler_ok
	return false


## First installed weapon id, or EMPTY_SLOT.
static func first_weapon_id(weapons: Array[StringName]) -> StringName:
	for id: StringName in weapons:
		if id != BalanceOutfit.EMPTY_SLOT and not String(id).is_empty():
			return id
	return BalanceOutfit.EMPTY_SLOT


## Sum of cargo_bonus effect values for installed equipment ids.
static func cargo_bonus_from(equipment_ids: Array[StringName]) -> int:
	var total: float = 0.0
	for id: StringName in equipment_ids:
		var value: float = _equipment_effect(id, Equipment.EFFECT_CARGO_BONUS)
		if value > 0.0:
			total += value
	return maxi(0, int(floorf(total)))


## Product of damage_taken_mult effects (default 1.0 when none).
static func damage_taken_multiplier_from(equipment_ids: Array[StringName]) -> float:
	return _product_mult(equipment_ids, Equipment.EFFECT_DAMAGE_TAKEN_MULT)


## Product of fuel_burn_mult effects (default 1.0 when none).
static func fuel_burn_multiplier_from(equipment_ids: Array[StringName]) -> float:
	return _product_mult(equipment_ids, Equipment.EFFECT_FUEL_BURN_MULT)


## Sum of turn_rate_bonus effects.
static func turn_rate_bonus_from(equipment_ids: Array[StringName]) -> float:
	return _sum_bonus(equipment_ids, Equipment.EFFECT_TURN_RATE_BONUS)


## Sum of afterburner_bonus effects.
static func afterburner_bonus_from(equipment_ids: Array[StringName]) -> float:
	return _sum_bonus(equipment_ids, Equipment.EFFECT_AFTERBURNER_BONUS)


## Serialize one hull loadout to a save dictionary.
static func loadout_to_dict(weapons: Array[StringName], equipment: Array[StringName]) -> Dictionary:
	var w: Array = []
	for id: StringName in weapons:
		w.append(String(id))
	var e: Array = []
	for id: StringName in equipment:
		e.append(String(id))
	return {
		String(BalanceOutfit.SAVE_KEY_WEAPONS): w,
		String(BalanceOutfit.SAVE_KEY_EQUIPMENT): e,
	}


## Parse weapons array from a loadout dict; pad/truncate to slot_count; drop bad ids.
static func parse_weapon_ids(raw: Variant, slot_count: int) -> Array[StringName]:
	return _parse_id_list(raw, slot_count, true)


## Parse equipment array from a loadout dict; pad/truncate; drop bad ids.
static func parse_equipment_ids(raw: Variant, slot_count: int) -> Array[StringName]:
	return _parse_id_list(raw, slot_count, false)


static func _parse_id_list(raw: Variant, slot_count: int, expect_weapon: bool) -> Array[StringName]:
	var out: Array[StringName] = empty_slots(slot_count)
	if typeof(raw) != TYPE_ARRAY:
		return out
	var arr: Array = raw
	var i: int = 0
	while i < slot_count and i < arr.size():
		var id: StringName = _as_name(arr[i])
		if String(id).is_empty() or id == BalanceOutfit.EMPTY_SLOT:
			i += 1
			continue
		if not ContentLibrary.has_item(id):
			i += 1
			continue
		var item: ContentItem = ContentLibrary.item(id)
		if expect_weapon:
			if item is Weapon:
				out[i] = id
		elif item is Equipment:
			out[i] = id
		i += 1
	return out


static func _product_mult(equipment_ids: Array[StringName], kind: StringName) -> float:
	var product: float = 1.0
	var any: bool = false
	for id: StringName in equipment_ids:
		var value: float = _equipment_effect(id, kind)
		if value > 0.0:
			product *= value
			any = true
	if not any:
		return 1.0
	return product


static func _sum_bonus(equipment_ids: Array[StringName], kind: StringName) -> float:
	var total: float = 0.0
	for id: StringName in equipment_ids:
		total += _equipment_effect(id, kind)
	return total


static func _equipment_effect(id: StringName, kind: StringName) -> float:
	if String(id).is_empty() or id == BalanceOutfit.EMPTY_SLOT:
		return 0.0
	if not ContentLibrary.has_item(id):
		return 0.0
	var item: ContentItem = ContentLibrary.item(id)
	if not (item is Equipment):
		return 0.0
	var equip: Equipment = item as Equipment
	if equip.effect_kind != kind:
		return 0.0
	return equip.effect_value


static func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""
