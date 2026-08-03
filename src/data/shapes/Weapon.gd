class_name Weapon
extends ContentItem

## Installable hardpoint weapon — Steam S5 ship layer.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S5
##
## Full-sized shape, thin content count (budget 12). Hull weapon fields remain
## the baseline when no weapon is installed. Role gates use hauler_ok / fighter_ok.

## Damage applied by one player bolt with this weapon.
@export var damage: float = 0.0

## Seconds between player shots with this weapon.
@export var cooldown: float = 0.0

## Player bolt travel speed (m/s).
@export var projectile_speed: float = 0.0

## Credits charged to install this weapon at a station outfitting desk.
@export var buy_price: int = 0

## True when a hauler-role hull may install this weapon.
@export var hauler_ok: bool = true

## True when a fighter-role hull may install this weapon.
@export var fighter_ok: bool = true


## Everything wrong with this weapon. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if damage <= 0.0:
		problems.append("`damage` must be greater than zero.")
	if cooldown <= 0.0:
		problems.append("`cooldown` must be greater than zero.")
	if projectile_speed <= 0.0:
		problems.append("`projectile_speed` must be greater than zero.")
	if buy_price < 0:
		problems.append("`buy_price` must not be negative.")
	if not hauler_ok and not fighter_ok:
		problems.append("`hauler_ok` or `fighter_ok` must be true (weapon usable on a role).")

	return problems
