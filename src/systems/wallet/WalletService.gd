class_name WalletService
extends Node

## Credits, upkeep, and thin emergency debt — money only (S5 Session B split).
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5, docs/BETA_E3_ECONOMY.md E3.1–E3.2,
## docs/STEAM_PHASE_PLAN.md S5 Session B (money half of former god wallet).
##
## Single writer for credits/debt. Child of Main (not an autoload).
## Fuel lives on FuelService; hull on HullConditionService.
## Optional save section `wallet` is gathered by CareerSave from all three
## (this service writes credits + debt keys only). No envelope version bump.
## Console: `credits` / `credits set <n>`.
## Undocked life-support upkeep drains credits via tick_upkeep (never negative).
## Free Haulers loan: borrow once while clear; job garnish; manual repay; grace
## dock standing hit only (no repossession, no game-over).
## Emits EventBus.on_money_event on every real credit movement for the S2
## telemetry log (docs/STEAM_PHASE_PLAN.md Phase S2).

const CREDITS: StringName = BalanceEconomy.CREDITS_COMMAND
const ACTION_SET: String = "set"

var _credits: int = BalanceEconomy.STARTING_CREDITS
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
	EventBus.on_loan_borrow_requested.connect(_on_loan_borrow_requested)
	EventBus.on_loan_repay_requested.connect(_on_loan_repay_requested)
	# Seed HUD listeners.
	EventBus.on_credits_changed.emit(_credits)
	EventBus.on_debt_changed.emit(_debt_owed, _debt_lender_id, _debt_grace_docks_left)


func _exit_tree() -> void:
	if EventBus.on_console_commands_requested.is_connected(_on_commands_requested):
		EventBus.on_console_commands_requested.disconnect(_on_commands_requested)
	if EventBus.on_console_command_invoked.is_connected(_on_command_invoked):
		EventBus.on_console_command_invoked.disconnect(_on_command_invoked)
	if EventBus.on_loan_borrow_requested.is_connected(_on_loan_borrow_requested):
		EventBus.on_loan_borrow_requested.disconnect(_on_loan_borrow_requested)
	if EventBus.on_loan_repay_requested.is_connected(_on_loan_repay_requested):
		EventBus.on_loan_repay_requested.disconnect(_on_loan_repay_requested)


func _on_loan_borrow_requested() -> void:
	borrow()


func _on_loan_repay_requested() -> void:
	try_repay()


func credits() -> int:
	return _credits


## Reset to boot defaults (tests / new session). Money only.
func reset() -> void:
	_upkeep_debt = 0.0
	_clear_debt_state()
	_set_credits(BalanceEconomy.STARTING_CREDITS)
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
		_emit_money(BalanceTelemetry.REASON_UPKEEP, -paid)
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
	_emit_money(BalanceEconomy.REASON_LOAN_BORROW, BalanceEconomy.LOAN_PRINCIPAL)
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
	_emit_money(BalanceEconomy.REASON_LOAN_REPAY, -paid)
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
			_emit_money(BalanceEconomy.REASON_LOAN_GARNISH, -garnish)
	if net > 0:
		_set_credits(_credits + net)
		_emit_money(BalanceTelemetry.REASON_JOB_PAY, net)
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
			_emit_money(
				BalanceTelemetry.REASON_DOCK_FEE,
				-paid,
				{
					BalanceTelemetry.DETAIL_KEY_STATION_ID: station_id,
					BalanceTelemetry.DETAIL_KEY_SYSTEM_ID: system_id,
				}
			)
	_note_dock_for_debt_grace()
	return paid


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


## Optional save section dictionary — credits + debt only (S5 Session B).
func to_section() -> Dictionary:
	var carried_upkeep: float = _upkeep_debt
	if not is_finite(carried_upkeep) or carried_upkeep < 0.0:
		carried_upkeep = 0.0
	return {
		BalanceEconomy.SAVE_KEY_CREDITS: _credits,
		BalanceEconomy.SAVE_KEY_DEBT_OWED: _debt_owed,
		BalanceEconomy.SAVE_KEY_DEBT_LENDER_ID: String(_debt_lender_id),
		BalanceEconomy.SAVE_KEY_DEBT_GRACE_DOCKS_LEFT: _debt_grace_docks_left,
		BalanceEconomy.SAVE_KEY_UPKEEP_DEBT: carried_upkeep,
	}


## Apply optional wallet section keys owned by money (credits + debt).
## Ignores fuel/condition keys (FuelService / HullConditionService own those).
## Missing debt keys → no debt (E3.2 / D5; no envelope version bump).
func apply_section(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		reset()
		return
	var data: Dictionary = raw
	if data.has(BalanceEconomy.SAVE_KEY_CREDITS):
		_set_credits(maxi(0, _variant_to_int(data[BalanceEconomy.SAVE_KEY_CREDITS])))
	_apply_upkeep_debt(data)
	_apply_debt_section(data)


## Restore the part-credit of upkeep already run up. Missing key (a save from
## before this was kept) means none owed — the old, forgiving behaviour.
func _apply_upkeep_debt(data: Dictionary) -> void:
	if not data.has(BalanceEconomy.SAVE_KEY_UPKEEP_DEBT):
		_upkeep_debt = 0.0
		return
	var carried: float = _variant_to_float(data[BalanceEconomy.SAVE_KEY_UPKEEP_DEBT])
	if not is_finite(carried) or carried < 0.0:
		carried = 0.0
	_upkeep_debt = carried


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


func _set_credits(value: int) -> void:
	var next: int = maxi(0, value)
	if next == _credits:
		return
	_credits = next
	EventBus.on_credits_changed.emit(_credits)


## Tags a real credit movement for the S2 telemetry log. Reads `_credits`
## after the mutation, so callers must apply the change first. Never call
## this from `_set_credits` itself — that would double-log every path.
func _emit_money(reason: StringName, delta: int, detail: Dictionary = {}) -> void:
	if delta == 0:
		return
	EventBus.on_money_event.emit(reason, delta, _credits, detail)


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
		var before: int = _credits
		set_credits(int(raw))
		var delta: int = _credits - before
		if delta != 0:
			_emit_money(BalanceTelemetry.REASON_DEBUG_CREDITS_SET, delta)
		_say(BalanceEconomy.CONSOLE_CREDITS_SET_FORMAT % _credits)
		return
	_say("Usage: %s" % usage())


func _say_status() -> void:
	var fuel_units: float = 0.0
	var fuel_cap: float = BalanceEconomy.FUEL_MAX
	var condition_units: float = 0.0
	var condition_cap: float = BalanceEconomy.CONDITION_MAX
	var tree: SceneTree = get_tree()
	if tree != null:
		var fuel_node: Node = tree.get_first_node_in_group(&"fuel_service")
		if fuel_node != null:
			if fuel_node.has_method(&"fuel"):
				fuel_units = _variant_to_float(fuel_node.call(&"fuel"))
			if fuel_node.has_method(&"fuel_max"):
				fuel_cap = _variant_to_float(fuel_node.call(&"fuel_max"))
		var hull_node: Node = tree.get_first_node_in_group(&"hull_condition_service")
		if hull_node != null:
			if hull_node.has_method(&"condition"):
				condition_units = _variant_to_float(hull_node.call(&"condition"))
			if hull_node.has_method(&"condition_max"):
				condition_cap = _variant_to_float(hull_node.call(&"condition_max"))
	var fuel_pct: int = 0
	if fuel_cap > 0.0:
		fuel_pct = int(roundf((fuel_units / fuel_cap) * BalanceEconomy.PERCENT_SCALE))
	var hull_pct: int = 0
	if condition_cap > 0.0:
		hull_pct = int(roundf((condition_units / condition_cap) * BalanceEconomy.PERCENT_SCALE))
	_say(
		(
			BalanceEconomy.CONSOLE_CREDITS_SHOW_FORMAT
			% [_credits, str(fuel_pct) + "%", str(hull_pct) + "%"]
		)
	)


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


static func _say(line: String) -> void:
	EventBus.on_console_output.emit(line)
