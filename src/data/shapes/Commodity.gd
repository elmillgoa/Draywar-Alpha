class_name Commodity
extends ContentItem

## A tradable good — full-sized Alpha shape, thin B3 content.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B3
## E3.3: optional jurisdictional contraband list (per Entity, not global ban).
##
## Global base buy/sell prices. Same-station round-trips may lose credits when
## sell < buy; station/system spreads can layer on later without reshaping.

## Credits charged when the player buys one unit at a station.
@export var base_buy_price: int = 0

## Credits paid when the player sells one unit at a station.
@export var base_sell_price: int = 0

## Cargo volume consumed per unit (default 1).
@export var unit_volume: int = 1

## Entity ids that treat this good as restricted open-market contraband.
## At stations they control: no buy/sell; docking with hold → fine + standing
## hit (+ seize when balance flag is on). Empty = legal everywhere.
@export var contraband_for_entity_ids: Array[StringName] = []


## True when this commodity is restricted for the given controller Entity.
func is_contraband_for(entity_id: StringName) -> bool:
	if String(entity_id).strip_edges().is_empty():
		return false
	if entity_id == Station.CONTROLLER_NOBODY:
		return false
	for listed: StringName in contraband_for_entity_ids:
		if listed == entity_id:
			return true
	return false


## Everything wrong with this commodity. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if base_buy_price <= 0:
		problems.append("`base_buy_price` must be greater than zero.")
	if base_sell_price <= 0:
		problems.append("`base_sell_price` must be greater than zero.")
	if unit_volume <= 0:
		problems.append("`unit_volume` must be greater than zero.")

	problems.append_array(_contraband_list_problems())
	return problems


func _contraband_list_problems() -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen: Dictionary = {}
	for raw: StringName in contraband_for_entity_ids:
		var entity_id: String = String(raw).strip_edges()
		if entity_id.is_empty():
			problems.append(
				(
					"`contraband_for_entity_ids` has an empty entry. "
					+ "List Entity content ids, or leave the list empty."
				)
			)
			continue
		if entity_id == String(Station.CONTROLLER_NOBODY):
			problems.append(
				(
					(
						"`contraband_for_entity_ids` cannot list '%s'. "
						+ "Nobody cannot enforce contraband."
					)
					% Station.CONTROLLER_NOBODY
				)
			)
			continue
		for character: String in entity_id:
			if not ID_ALPHABET.contains(character):
				problems.append(
					(
						(
							"`contraband_for_entity_ids` entry '%s' is not a valid content id "
							+ "(lowercase snake_case)."
						)
						% entity_id
					)
				)
				break
		if seen.has(entity_id):
			problems.append("`contraband_for_entity_ids` lists '%s' more than once." % entity_id)
		else:
			seen[entity_id] = true
	return problems
