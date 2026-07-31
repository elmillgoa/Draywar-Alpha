class_name WalletService
extends Node

## Credits, fuel, hull condition, and thin emergency debt — A5 / E3.1 / E3.2.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5, docs/BETA_E3_ECONOMY.md E3.1–E3.2
##
## Single writer for money/fuel/condition/debt. Child of Main (not an autoload).
## Optional save section `wallet` (schema v1, no envelope bump).
## Console: `credits` / `credits set <n>`.
## Undocked life-support upkeep drains credits via tick_upkeep (never negative).
## Free Haulers loan: borrow once while clear; job garnish; manual repay; grace
## dock standing hit only (no repossession, no game-over).

const CREDITS: StringName = BalanceEconomy.CREDITS_COMMAND
const ACTION_SET: String = "set"

var _credits: int = BalanceEconomy.STARTING_CREDITS
var _fuel: float = BalanceEconomy.STARTING_FUEL
var _condition: float = BalanceEconomy.STARTING_CONDITION
## Fractional upkeep remainder until a whole credit is owed (rate can be < 1/s).
var _upkeep_debt: float = 0.0
## E3.2 flat amount still owed on the emergency loan (0 = no debt).
var _debt_owed: int = 0
## Lender Entity id while debt is open (empty when clear).
var _debt_lender_id: StringName = &""
## Grace dock events remaining before Free Haulers standing hit.
var _debt_grace_docks_left: int = 0
## True after grace already fired for the current open loan (no re-hit spam).
var _debt_grace_hit_applied: bool = false


func _ready() -> void:
	add_to_group(&"wallet_service")
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)
	EventBus.on_refuel_requested.connect(_on_refuel_requested)
	EventBus.on_repair_requested.connect(_on_repair_requested)
	EventBus.on_loan_borrow_requested.connect(_on_loan_borrow_requested)
	EventBus.on_loan_repay_requested.connect(_on_loan_repay_requested)
	# Seed HUD listeners.
	EventBus.on_credits_changed.emit(_credits)
	EventBus.on_fuel_changed.emit(_fuel, BalanceEconomy.FUEL_MAX)
	EventBus.on_condition_changed.emit(_condition, BalanceEconomy.CONDITION_MAX)
	EventBus.on_debt_changed.emit(_debt_owed, _debt_lender_id, _debt_grace_docks_left)


func _exit_tree() -> void:
	if EventBus.on_console_commands_requested.is_connected(_on_commands_requested):
		EventBus.on_console_commands_requested.disconnect(_on_commands_requested)
	if EventBus.on_console_command_invoked.is_connected(_on_command_invoked):
		EventBus.on_console_command_invoked.disconnect(_on_command_invoked)
	if EventBus.on_refuel_requested.is_connected(_on_refuel_requested):
		EventBus.on_refuel_requested.disconnect(_on_refuel_requested)
	if EventBus.on_repair_requested.is_connected(_on_repair_requested):
		EventBus.on_repair_requested.disconnect(_on_repair_requested)
	if EventBus.on_loan_borrow_requested.is_connected(_on_loan_borrow_requested):
		EventBus.on_loan_borrow_requested.disconnect(_on_loan_borrow_requested)
	if EventBus.on_loan_repay_requested.is_connected(_on_loan_repay_requested):
		EventBus.on_loan_repay_requested.disconnect(_on_loan_repay_requested)


func _on_refuel_requested() -> void:
	refuel_chunk()


func _on_repair_requested() -> void:
	repair_full()


func _on_loan_borrow_requested() -> void:
	borrow()


func _on_loan_repay_requested() -> void:
	try_repay()


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
	_upkeep_debt = 0.0
	_clear_debt_state()
	_set_credits(BalanceEconomy.STARTING_CREDITS)
	_set_fuel(BalanceEconomy.STARTING_FUEL)
	_set_condition(BalanceEconomy.STARTING_CONDITION)
	_emit_debt_changed()


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


## Life-support upkeep for scaled game time (E3.1 / D1).
## Undocked: burn BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * delta_scaled.
## Docked: no drain. Credits never go negative — stops at 0.
## Returns whole credits actually spent this call (0 when docked/broke/zero dt).
func tick_upkeep(delta_scaled: float, is_docked: bool) -> int:
	if is_docked or delta_scaled <= 0.0:
		return 0
	if _credits <= 0:
		_upkeep_debt = 0.0
		return 0
	if BalanceEconomy.UPKEEP_CREDITS_PER_SECOND <= 0.0:
		return 0
	_upkeep_debt += BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * delta_scaled
	var whole: int = int(floorf(_upkeep_debt))
	if whole <= 0:
		return 0
	_upkeep_debt -= float(whole)
	var paid: int = mini(whole, _credits)
	if paid > 0:
		_set_credits(_credits - paid)
	if paid < whole:
		# Broke mid-tick: floor at 0 and drop leftover fractional remainder.
		_upkeep_debt = 0.0
	return paid


# --- Emergency loan (E3.2 / D2) ---------------------------------------------


## Snapshot of emergency-loan state (E3.2). Keys: owed, lender_id, grace_docks_left.
func debt_state() -> Dictionary:
	return {
		&"owed": _debt_owed,
		&"lender_id": _debt_lender_id,
		&"grace_docks_left": _debt_grace_docks_left,
	}


## Take the Free Haulers emergency loan once while clear.
## Credits += LOAN_PRINCIPAL; debt owed = LOAN_REPAY_TOTAL; grace = GRACE_DOCKS.
## Returns principal received (0 if refused / already in debt).
func borrow() -> int:
	if _debt_owed > 0:
		return 0
	if BalanceEconomy.LOAN_PRINCIPAL <= 0 or BalanceEconomy.LOAN_REPAY_TOTAL <= 0:
		return 0
	_debt_owed = BalanceEconomy.LOAN_REPAY_TOTAL
	_debt_lender_id = BalanceEconomy.LOAN_LENDER_ENTITY_ID
	_debt_grace_docks_left = BalanceEconomy.GRACE_DOCKS
	_debt_grace_hit_applied = false
	_set_credits(_credits + BalanceEconomy.LOAN_PRINCIPAL)
	_emit_debt_changed()
	return BalanceEconomy.LOAN_PRINCIPAL


## Manual repay from wallet credits toward open debt.
## Pays min(credits, debt_owed). Returns amount applied (0 if broke/no debt).
func try_repay(amount: int = -1) -> int:
	if _debt_owed <= 0 or _credits <= 0:
		return 0
	var want: int = _debt_owed if amount < 0 else amount
	if want <= 0:
		return 0
	var paid: int = mini(want, mini(_credits, _debt_owed))
	if paid <= 0:
		return 0
	_set_credits(_credits - paid)
	_debt_owed -= paid
	if _debt_owed <= 0:
		_clear_debt_state()
	_emit_debt_changed()
	return paid


## Job pay with auto-garnish (E3.2). Seizes floor(gross * GARNISH_RATE) toward
## debt (capped by debt owed), pays remainder to the player.
## Returns net credits the player actually receives.
func apply_job_pay_with_garnish(gross: int) -> int:
	if gross <= 0:
		return 0
	var net: int = gross
	if _debt_owed > 0 and BalanceEconomy.GARNISH_RATE > 0.0:
		var garnish: int = int(floorf(float(gross) * BalanceEconomy.GARNISH_RATE))
		garnish = maxi(0, mini(garnish, mini(_debt_owed, gross)))
		net = gross - garnish
		if garnish > 0:
			_debt_owed -= garnish
			if _debt_owed <= 0:
				_clear_debt_state()
			_emit_debt_changed()
	if net > 0:
		_set_credits(_credits + net)
	return net


## Fee-charging dock event: burn one grace dock when debt is unpaid and the
## wallet is below MIN_PAYMENT_FLOOR. At exhaustion, Free Haulers standing hit
## only via StandingService (once per open loan). No dock ban, no ship loss.
## Invoked from charge_dock_fee (real docks only — not session restore).
func _note_dock_for_debt_grace() -> void:
	if _debt_owed <= 0 or _debt_grace_hit_applied:
		return
	if _credits >= BalanceEconomy.MIN_PAYMENT_FLOOR:
		return
	if _debt_grace_docks_left > 0:
		_debt_grace_docks_left -= 1
		_emit_debt_changed()
	if _debt_grace_docks_left <= 0 and not _debt_grace_hit_applied:
		_apply_grace_standing_hit()


func _apply_grace_standing_hit() -> void:
	if _debt_grace_hit_applied:
		return
	var lender: StringName = _debt_lender_id
	if String(lender).is_empty():
		lender = BalanceEconomy.LOAN_LENDER_ENTITY_ID
	_debt_grace_hit_applied = true
	_debt_grace_docks_left = 0
	StandingService.apply_entity_delta(
		lender,
		BalanceStanding.DEBT_GRACE_EXPIRED_DELTA,
		BalanceStanding.REASON_DEBT_GRACE_EXPIRED,
		false
	)
	_emit_debt_changed()


func _clear_debt_state() -> void:
	_debt_owed = 0
	_debt_lender_id = &""
	_debt_grace_docks_left = 0
	_debt_grace_hit_applied = false


func _emit_debt_changed() -> void:
	EventBus.on_debt_changed.emit(_debt_owed, _debt_lender_id, _debt_grace_docks_left)


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


## Docking fee for a system id: policing base × standing mult (E1.5).
## Prefer `station_id` so fee uses the station controller when present.
func dock_fee_for_system(system_id: StringName, station_id: StringName = &"") -> int:
	var base_fee: int = _base_dock_fee_for_system(system_id)
	if base_fee <= 0:
		return 0
	var mult: float = _dock_fee_standing_mult(system_id, station_id)
	if is_equal_approx(mult, BalanceEconomy.DOCK_FEE_STANDING_MULT_DEFAULT):
		return base_fee
	return _ceil_credits(float(base_fee) * mult)


## Charge docking fee (partial if broke — fee floors at remaining credits).
## Pass `station_id` from the dock charge path for controller standing.
## Also runs E3.2 debt grace (fee-charging docks only; session restore skips this).
func charge_dock_fee(system_id: StringName, station_id: StringName = &"") -> int:
	var fee: int = dock_fee_for_system(system_id, station_id)
	var paid: int = 0
	if fee > 0:
		paid = mini(fee, _credits)
		if paid > 0:
			_set_credits(_credits - paid)
	_note_dock_for_debt_grace()
	return paid


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


## Refuel one chunk (or remaining capacity). Returns fuel added (0 if broke/full).
## Applies standing service mult when docked at a controlled station (E1.5).
func refuel_chunk() -> float:
	var room: float = BalanceEconomy.FUEL_MAX - _fuel
	if room <= BalanceEconomy.FUEL_EMPTY_EPSILON:
		return 0.0
	var mult: float = _service_cost_mult_for_station()
	var unit_rate: float = BalanceEconomy.REFUEL_CREDITS_PER_UNIT * mult
	var units: float = minf(BalanceEconomy.REFUEL_CHUNK, room)
	var cost: int = _ceil_credits(units * unit_rate)
	if cost > 0 and not try_spend(cost):
		# Buy as much as credits allow.
		if _credits <= 0:
			return 0.0
		if unit_rate <= 0.0:
			return 0.0
		units = float(_credits) / unit_rate
		units = minf(units, room)
		if units <= BalanceEconomy.FUEL_EMPTY_EPSILON:
			return 0.0
		cost = _ceil_credits(units * unit_rate)
		if not try_spend(cost):
			return 0.0
	_set_fuel(minf(BalanceEconomy.FUEL_MAX, _fuel + units))
	return units


## Full repair toward CONDITION_MAX. Returns true if any repair applied.
## Hostile/Hated at docked controller station: refused (E1.5). Cost uses mult.
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


func _base_dock_fee_for_system(system_id: StringName) -> int:
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


func _dock_fee_standing_mult(system_id: StringName, station_id: StringName = &"") -> float:
	return BalanceEconomy.dock_fee_mult_for_tier(_standing_tier_for_place(system_id, station_id))


func _service_cost_mult_for_station(station_id: StringName = &"") -> float:
	var resolved: StringName = station_id
	if String(resolved).is_empty():
		resolved = _docked_station_id()
	if String(resolved).is_empty():
		return BalanceEconomy.SERVICE_COST_MULT_DEFAULT
	var system_id: StringName = _system_id_for_station(resolved)
	return BalanceEconomy.service_cost_mult_for_tier(_standing_tier_for_place(system_id, resolved))


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


## Optional save section dictionary.
func to_section() -> Dictionary:
	return {
		BalanceEconomy.SAVE_KEY_CREDITS: _credits,
		BalanceEconomy.SAVE_KEY_FUEL: _fuel,
		BalanceEconomy.SAVE_KEY_CONDITION: _condition,
		BalanceEconomy.SAVE_KEY_DEBT_OWED: _debt_owed,
		BalanceEconomy.SAVE_KEY_DEBT_LENDER_ID: String(_debt_lender_id),
		BalanceEconomy.SAVE_KEY_DEBT_GRACE_DOCKS_LEFT: _debt_grace_docks_left,
	}


## Apply optional wallet section (missing keys keep current / use defaults on reset).
## Missing debt keys → no debt (E3.2 / D5; no envelope version bump).
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
	_apply_debt_section(data)


func _apply_debt_section(data: Dictionary) -> void:
	# Missing any debt key → no debt (old saves / partial sections).
	if (
		not data.has(BalanceEconomy.SAVE_KEY_DEBT_OWED)
		and not data.has(BalanceEconomy.SAVE_KEY_DEBT_LENDER_ID)
		and not data.has(BalanceEconomy.SAVE_KEY_DEBT_GRACE_DOCKS_LEFT)
	):
		_clear_debt_state()
		_emit_debt_changed()
		return
	var owed: int = 0
	if data.has(BalanceEconomy.SAVE_KEY_DEBT_OWED):
		owed = maxi(0, _variant_to_int(data[BalanceEconomy.SAVE_KEY_DEBT_OWED]))
	var lender: StringName = &""
	if data.has(BalanceEconomy.SAVE_KEY_DEBT_LENDER_ID):
		lender = _variant_to_name(data[BalanceEconomy.SAVE_KEY_DEBT_LENDER_ID])
	var grace: int = 0
	if data.has(BalanceEconomy.SAVE_KEY_DEBT_GRACE_DOCKS_LEFT):
		grace = maxi(0, _variant_to_int(data[BalanceEconomy.SAVE_KEY_DEBT_GRACE_DOCKS_LEFT]))
	if owed <= 0:
		_clear_debt_state()
		_emit_debt_changed()
		return
	_debt_owed = owed
	if String(lender).is_empty():
		lender = BalanceEconomy.LOAN_LENDER_ENTITY_ID
	_debt_lender_id = lender
	_debt_grace_docks_left = grace
	# Grace already exhausted in the save → do not re-fire the standing hit on load.
	_debt_grace_hit_applied = grace <= 0
	_emit_debt_changed()


func _variant_to_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return StringName(str(value))


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
