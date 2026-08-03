class_name BalanceOutfit
extends RefCounted

## Outfitting slots, sell-back, save keys, and station labels — Steam S5.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S5
##
## Slot counts are by hull role (not per-hull fields) so Hull validation stays
## unchanged. Loadouts live under optional ship.save key `loadouts`.

# --- Slot counts by role ----------------------------------------------------

## Hardpoint weapon slots on a hauler-role hull.
const HAULER_WEAPON_SLOTS: int = 1

## Equipment module slots on a hauler-role hull.
const HAULER_EQUIPMENT_SLOTS: int = 3

## Hardpoint weapon slots on a fighter-role hull.
const FIGHTER_WEAPON_SLOTS: int = 1

## Equipment module slots on a fighter-role hull.
const FIGHTER_EQUIPMENT_SLOTS: int = 2

# --- Economy ----------------------------------------------------------------

## Fraction of buy_price refunded on uninstall (floored to whole credits).
const SELL_FRACTION: float = 0.5

# --- Save keys (nested under ship section) ----------------------------------

## ship.loadouts → { hull_id: { weapons: [...], equipment: [...] } }
const SAVE_KEY_LOADOUTS: StringName = &"loadouts"
const SAVE_KEY_WEAPONS: StringName = &"weapons"
const SAVE_KEY_EQUIPMENT: StringName = &"equipment"

## Empty slot marker in loadout arrays.
const EMPTY_SLOT: StringName = &""

# --- Money detail keys ------------------------------------------------------

## Detail key on outfit buy/sell money events.
const DETAIL_KEY_ITEM_ID: StringName = &"item_id"

# --- Station UI copy --------------------------------------------------------

const STATION_SECTION_OUTFITTING: String = "Outfitting"
const STATION_OUTFIT_EMPTY_SLOT: String = "(empty)"
const STATION_OUTFIT_INSTALL_FORMAT: String = "Install %s — %d cr"
const STATION_OUTFIT_REMOVE_FORMAT: String = "Remove %s — refund %d cr"
const STATION_OUTFIT_ROLE_BLOCKED: String = "Not for this hull role"
const STATION_OUTFIT_NO_SLOT: String = "No free slot"
const STATION_OUTFIT_BROKE: String = "Not enough credits"
const STATION_OUTFIT_INSTALLED: String = "Installed"
const STATION_OUTFIT_REMOVED: String = "Removed"
const STATION_OUTFIT_WEAPONS_HEADER: String = "Weapons"
const STATION_OUTFIT_EQUIPMENT_HEADER: String = "Equipment"
const STATION_OUTFIT_INSTALLED_HEADER: String = "Installed"


## Weapon slot count for a hull role tag.
static func weapon_slots_for_role(role: StringName) -> int:
	if role == Hull.ROLE_FIGHTER:
		return FIGHTER_WEAPON_SLOTS
	return HAULER_WEAPON_SLOTS


## Equipment slot count for a hull role tag.
static func equipment_slots_for_role(role: StringName) -> int:
	if role == Hull.ROLE_FIGHTER:
		return FIGHTER_EQUIPMENT_SLOTS
	return HAULER_EQUIPMENT_SLOTS


## Credits refunded when uninstalling an item that cost `buy_price`.
static func sell_refund(buy_price: int) -> int:
	if buy_price <= 0:
		return 0
	return int(floorf(float(buy_price) * SELL_FRACTION))
