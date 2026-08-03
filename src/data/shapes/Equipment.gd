class_name Equipment
extends ContentItem

## Installable ship equipment module — Steam S5 ship layer.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S5
##
## One effect kind + value per module. Loadout sums cargo/turn/afterburner
## bonuses and multiplies damage_taken_mult / fuel_burn_mult effects.

## Extra hold volume (integer-ish float summed, floored at use).
const EFFECT_CARGO_BONUS: StringName = &"cargo_bonus"

## Multiplier on incoming hull damage (product across modules; 1.0 = none).
const EFFECT_DAMAGE_TAKEN_MULT: StringName = &"damage_taken_mult"

## Multiplier on flight fuel burn rate (product; 1.0 = none).
const EFFECT_FUEL_BURN_MULT: StringName = &"fuel_burn_mult"

## Added to hull turn_rate (sum; radians/sec style bonus).
const EFFECT_TURN_RATE_BONUS: StringName = &"turn_rate_bonus"

## Added to hull afterburner_multiplier (sum).
const EFFECT_AFTERBURNER_BONUS: StringName = &"afterburner_bonus"

## Which effect this module applies.
@export var effect_kind: StringName = &""

## Magnitude for effect_kind (bonus absolute, or mult factor).
@export var effect_value: float = 0.0

## Credits charged to install this module.
@export var buy_price: int = 0

## True when a hauler-role hull may install this module.
@export var hauler_ok: bool = true

## True when a fighter-role hull may install this module.
@export var fighter_ok: bool = true


## Everything wrong with this equipment. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if not _is_known_effect(effect_kind):
		problems.append(
			(
				"`effect_kind` must be one of cargo_bonus / damage_taken_mult / "
				+ (
					"fuel_burn_mult / turn_rate_bonus / afterburner_bonus (got '%s')."
					% String(effect_kind)
				)
			)
		)
	else:
		problems.append_array(_effect_value_problems())

	if buy_price < 0:
		problems.append("`buy_price` must not be negative.")
	if not hauler_ok and not fighter_ok:
		problems.append("`hauler_ok` or `fighter_ok` must be true (equipment usable on a role).")

	return problems


func _is_known_effect(kind: StringName) -> bool:
	return (
		kind == EFFECT_CARGO_BONUS
		or kind == EFFECT_DAMAGE_TAKEN_MULT
		or kind == EFFECT_FUEL_BURN_MULT
		or kind == EFFECT_TURN_RATE_BONUS
		or kind == EFFECT_AFTERBURNER_BONUS
	)


func _effect_value_problems() -> PackedStringArray:
	var problems: PackedStringArray = []
	if effect_kind == EFFECT_CARGO_BONUS:
		if effect_value <= 0.0:
			problems.append("`effect_value` for cargo_bonus must be greater than zero.")
	elif effect_kind == EFFECT_DAMAGE_TAKEN_MULT or effect_kind == EFFECT_FUEL_BURN_MULT:
		if effect_value <= 0.0:
			problems.append("`effect_value` for mult effects must be greater than zero.")
	elif effect_kind == EFFECT_TURN_RATE_BONUS or effect_kind == EFFECT_AFTERBURNER_BONUS:
		if effect_value == 0.0:
			problems.append("`effect_value` for bonus effects must not be zero.")
	return problems
