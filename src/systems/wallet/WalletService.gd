class_name WalletService
extends Node

## Credits, fuel, and hull condition — Alpha A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5
##
## Single writer for money/fuel/condition. Child of Main (not an autoload).
## Optional save section `wallet` (schema v1, no envelope bump).
## Console: `credits` / `credits set <n>`.

const CREDITS: StringName = BalanceEconomy.CREDITS_COMMAND
const ACTION_SET: String = "set"

var _credits: int = BalanceEconomy.STARTING_CREDITS
var _fuel: float = BalanceEconomy.STARTING_FUEL
var _condition: float = BalanceEconomy.STARTING_CONDITION


func _ready() -> void:
	add_to_group(&"wallet_service")
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)
	EventBus.on_refuel_requested.connect(_on_refuel_requested)
	EventBus.on_repair_requested.connect(_on_repair_requested)
	# Seed HUD listeners.
	EventBus.on_credits_changed.emit(_credits)
	EventBus.on_fuel_changed.emit(_fuel, BalanceEconomy.FUEL_MAX)
	EventBus.on_condition_changed.emit(_condition, BalanceEconomy.CONDITION_MAX)


func _exit_tree() -> void:
	if EventBus.on_console_commands_requested.is_connected(_on_commands_requested):
		EventBus.on_console_commands_requested.disconnect(_on_commands_requested)
	if EventBus.on_console_command_invoked.is_connected(_on_command_invoked):
		EventBus.on_console_command_invoked.disconnect(_on_command_invoked)
	if EventBus.on_refuel_requested.is_connected(_on_refuel_requested):
		EventBus.on_refuel_requested.disconnect(_on_refuel_requested)
	if EventBus.on_repair_requested.is_connected(_on_repair_requested):
		EventBus.on_repair_requested.disconnect(_on_repair_requested)


func _on_refuel_requested() -> void:
	refuel_chunk()


func _on_repair_requested() -> void:
	repair_full()


func credits() -> int:
	return _credits


func fuel() -> float:
	return _fuel


func fuel_max() -> float:
	return BalanceEconomy.FUEL_MAX


func condition() -> float:
	return _condition


func condition_max() -> float:
	return BalanceEconomy.CONDITION_MAX


## Reset to boot defaults (tests / new session).
func reset() -> void:
	_set_credits(BalanceEconomy.STARTING_CREDITS)
	_set_fuel(BalanceEconomy.STARTING_FUEL)
	_set_condition(BalanceEconomy.STARTING_CONDITION)


## Set absolute credits (clamped >= 0).
func set_credits(value: int) -> void:
	_set_credits(maxi(0, value))


## Add (or subtract) credits. Returns applied delta (may be partial if broke).
func add_credits(delta: int) -> int:
	if delta == 0:
		return 0
	var before: int = _credits
	var next: int = _credits + delta
	if next < 0:
		next = 0
	_set_credits(next)
	return _credits - before


## True when the wallet can pay `amount` (amount <= 0 always true).
func can_afford(amount: int) -> bool:
	if amount <= 0:
		return true
	return _credits >= amount


## Spend credits if affordable. Returns true on success.
func try_spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		return false
	_set_credits(_credits - amount)
	return true


## Burn fuel for flight this frame. `throttle` 0..1; afterburn multiplies.
func burn_fuel(delta_seconds: float, throttle: float, afterburning: bool) -> void:
	if delta_seconds <= 0.0 or throttle <= 0.0:
		return
	if _fuel <= BalanceEconomy.FUEL_EMPTY_EPSILON:
		_set_fuel(0.0)
		return
	var rate: float = BalanceEconomy.FUEL_BURN_PER_SECOND_AT_FULL * throttle
	if afterburning:
		rate *= BalanceEconomy.FUEL_AFTERBURNER_MULTIPLIER
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


## Wear hull while afterburning.
func wear_condition(delta_seconds: float, afterburning: bool) -> void:
	if not afterburning or delta_seconds <= 0.0:
		return
	var next: float = (
		_condition - BalanceEconomy.CONDITION_WEAR_PER_SECOND_AFTERBURN * delta_seconds
	)
	_set_condition(clampf(next, BalanceEconomy.CONDITION_MIN, BalanceEconomy.CONDITION_MAX))


## Combat (or test) hull damage. Returns applied amount. Emits player damage bus.
func apply_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before: float = _condition
	_set_condition(_condition - amount)
	EventBus.on_player_damaged.emit(_condition)
	return before - _condition


## True when the ship can still fly (condition above the cripple floor).
func can_fly() -> bool:
	return _condition > BalanceEconomy.CONDITION_MIN


## Speed factor from hull condition (1.0 healthy → CONDITION_MIN_SPEED_FACTOR).
func speed_factor() -> float:
	var t: float = _condition / BalanceEconomy.CONDITION_MAX
	return lerpf(BalanceEconomy.CONDITION_MIN_SPEED_FACTOR, 1.0, clampf(t, 0.0, 1.0))


## Docking fee for a system id from ContentLibrary policing.
func dock_fee_for_system(system_id: StringName) -> int:
	if not ContentLibrary.has_item(system_id):
		return BalanceEconomy.DOCK_FEE_DEFAULT
	var item: ContentItem = ContentLibrary.item(system_id)
	if not (item is StarSystem):
		return BalanceEconomy.DOCK_FEE_DEFAULT
	var system: StarSystem = item as StarSystem
	match system.policing:
		StarSystem.POLICED_BY_PATROLS:
			return BalanceEconomy.DOCK_FEE_PATROLLED
		StarSystem.POLICED_BY_CONTESTED:
			return BalanceEconomy.DOCK_FEE_CONTESTED
		StarSystem.POLICED_BY_NOBODY:
			return BalanceEconomy.DOCK_FEE_LAWLESS
		_:
			return BalanceEconomy.DOCK_FEE_DEFAULT


## Charge docking fee (partial if broke — fee floors at remaining credits).
func charge_dock_fee(system_id: StringName) -> int:
	var fee: int = dock_fee_for_system(system_id)
	if fee <= 0:
		return 0
	var paid: int = mini(fee, _credits)
	if paid > 0:
		_set_credits(_credits - paid)
	return paid


## Refuel one chunk (or remaining capacity). Returns fuel added (0 if broke/full).
func refuel_chunk() -> float:
	var room: float = BalanceEconomy.FUEL_MAX - _fuel
	if room <= BalanceEconomy.FUEL_EMPTY_EPSILON:
		return 0.0
	var units: float = minf(BalanceEconomy.REFUEL_CHUNK, room)
	var cost: int = _ceil_credits(units * BalanceEconomy.REFUEL_CREDITS_PER_UNIT)
	if cost > 0 and not try_spend(cost):
		# Buy as much as credits allow.
		if _credits <= 0:
			return 0.0
		units = float(_credits) / BalanceEconomy.REFUEL_CREDITS_PER_UNIT
		units = minf(units, room)
		if units <= BalanceEconomy.FUEL_EMPTY_EPSILON:
			return 0.0
		cost = _ceil_credits(units * BalanceEconomy.REFUEL_CREDITS_PER_UNIT)
		if not try_spend(cost):
			return 0.0
	_set_fuel(minf(BalanceEconomy.FUEL_MAX, _fuel + units))
	return units


## Full repair toward CONDITION_MAX. Returns true if any repair applied.
func repair_full() -> bool:
	if _condition >= BalanceEconomy.CONDITION_MAX:
		return false
	var was_crippled: bool = _condition <= BalanceEconomy.CONDITION_MIN
	var missing: float = BalanceEconomy.CONDITION_MAX - _condition
	var fraction: float = missing / BalanceEconomy.CONDITION_MAX
	var cost: int = _ceil_credits(float(BalanceEconomy.REPAIR_FULL_COST) * fraction)
	if cost <= 0:
		_set_condition(BalanceEconomy.CONDITION_MAX)
		if was_crippled:
			EventBus.on_player_repaired_from_cripple.emit()
		return true
	if not try_spend(cost):
		return false
	_set_condition(BalanceEconomy.CONDITION_MAX)
	if was_crippled:
		EventBus.on_player_repaired_from_cripple.emit()
	return true


## Optional save section dictionary.
func to_section() -> Dictionary:
	return {
		BalanceEconomy.SAVE_KEY_CREDITS: _credits,
		BalanceEconomy.SAVE_KEY_FUEL: _fuel,
		BalanceEconomy.SAVE_KEY_CONDITION: _condition,
	}


## Apply optional wallet section (missing keys keep current / use defaults on reset).
func apply_section(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		reset()
		return
	var data: Dictionary = raw
	if data.has(BalanceEconomy.SAVE_KEY_CREDITS):
		_set_credits(maxi(0, _variant_to_int(data[BalanceEconomy.SAVE_KEY_CREDITS])))
	if data.has(BalanceEconomy.SAVE_KEY_FUEL):
		_set_fuel(
			clampf(
				_variant_to_float(data[BalanceEconomy.SAVE_KEY_FUEL]), 0.0, BalanceEconomy.FUEL_MAX
			)
		)
	if data.has(BalanceEconomy.SAVE_KEY_CONDITION):
		_set_condition(
			clampf(
				_variant_to_float(data[BalanceEconomy.SAVE_KEY_CONDITION]),
				BalanceEconomy.CONDITION_MIN,
				BalanceEconomy.CONDITION_MAX
			)
		)


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


func _set_credits(value: int) -> void:
	var next: int = maxi(0, value)
	if next == _credits:
		return
	_credits = next
	EventBus.on_credits_changed.emit(_credits)


func _set_fuel(value: float) -> void:
	var next: float = clampf(value, 0.0, BalanceEconomy.FUEL_MAX)
	if is_equal_approx(next, _fuel):
		return
	_fuel = next
	EventBus.on_fuel_changed.emit(_fuel, BalanceEconomy.FUEL_MAX)


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


# --- Console ---------------------------------------------------------------


static func usage() -> String:
	return "%s [set <n>]" % String(CREDITS)


func _on_commands_requested() -> void:
	EventBus.on_console_command_registered.emit(
		CREDITS, usage(), "Show or set credits (also shows fuel and hull)."
	)


func _on_command_invoked(name_of_command: StringName, args: PackedStringArray) -> void:
	if name_of_command != CREDITS:
		return
	if args.is_empty():
		_say_status()
		return
	var head: String = args[0].to_lower()
	if head == ACTION_SET:
		if args.size() != BalanceEconomy.CONSOLE_CREDITS_SET_ARGS:
			_say("Usage: %s" % usage())
			return
		var raw: String = args[BalanceEconomy.CONSOLE_CREDITS_VALUE_INDEX]
		if not raw.is_valid_int():
			_say("Credits must be a whole number.")
			return
		set_credits(int(raw))
		_say(BalanceEconomy.CONSOLE_CREDITS_SET_FORMAT % _credits)
		return
	_say("Usage: %s" % usage())


func _say_status() -> void:
	var fuel_pct: int = int(
		roundf((_fuel / BalanceEconomy.FUEL_MAX) * BalanceEconomy.PERCENT_SCALE)
	)
	var hull_pct: int = int(
		roundf((_condition / BalanceEconomy.CONDITION_MAX) * BalanceEconomy.PERCENT_SCALE)
	)
	_say(
		(
			BalanceEconomy.CONSOLE_CREDITS_SHOW_FORMAT
			% [_credits, str(fuel_pct) + "%", str(hull_pct) + "%"]
		)
	)


static func _say(line: String) -> void:
	EventBus.on_console_output.emit(line)
