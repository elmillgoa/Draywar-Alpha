class_name Commodity
extends ContentItem

## A tradable good — full-sized Alpha shape, thin B3 content.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B3
##
## Global base buy/sell prices. Same-station round-trips may lose credits when
## sell < buy; station/system spreads can layer on later without reshaping.

## Credits charged when the player buys one unit at a station.
@export var base_buy_price: int = 0

## Credits paid when the player sells one unit at a station.
@export var base_sell_price: int = 0

## Cargo volume consumed per unit (default 1).
@export var unit_volume: int = 1


## Everything wrong with this commodity. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if base_buy_price <= 0:
		problems.append("`base_buy_price` must be greater than zero.")
	if base_sell_price <= 0:
		problems.append("`base_sell_price` must be greater than zero.")
	if unit_volume <= 0:
		problems.append("`unit_volume` must be greater than zero.")

	return problems
