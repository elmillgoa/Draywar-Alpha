extends GutTest

## REPAIR-22 — intercept submit/ignore must charge and report the same figure.
##
## Audit baseline ee17eab5 finding #12: submitting (or ignoring) a patrol
## intercept always set pay_credits to the full INTERCEPT_SUBMIT_PAY_LOSS and
## called the charge path without checking how much the wallet actually lost.
## A broke player was told they paid the full fee when they did not — either
## because try_spend refused the whole amount, or because a clamp-to-zero path
## took less than the nominal fee.
##
## Honest behaviour (this brief): take what the wallet can cover, report that
## amount in pay_credits, never go negative. Unpaid-debt / residual fine is a
## separate economy design change and is out of scope.

const SYSTEM_GAMMA: StringName = &"system_gamma"

## Wallet below the submit fee so the charge cannot be the full nominal loss.
const BROKE_CREDITS: int = 12

var _wallet: WalletService = null


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	IncidentService.reset()
	StandingService.reset_to_defaults()
	_wallet = WalletService.new()
	add_child_autofree(_wallet)
	_wallet.reset()


func after_each() -> void:
	IncidentService.reset()
	BoardService.reset()
	MarketService.reset()
	StandingService.reset_to_defaults()
	WorldClockHelpers.reset_clock()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()


## Definition of done: broke submit — pay_credits equals credits actually removed.
func test_broke_submit_reports_actual_wallet_loss() -> void:
	assert_lt(
		BROKE_CREDITS,
		BalanceIncident.INTERCEPT_SUBMIT_PAY_LOSS,
		"fixture must sit below the nominal submit fee"
	)
	_wallet.set_credits(BROKE_CREDITS)
	var before: int = _wallet.credits()

	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_INTERCEPT, SYSTEM_GAMMA)
	assert_false(String(id).is_empty(), "intercept must offer")

	var result: Dictionary = IncidentService.respond(id, BalanceIncident.CHOICE_SUBMIT)
	assert_true(_flag(result, &"ok"), "submit ok")
	assert_eq(_dict_name(result, &"outcome"), BalanceIncident.STATE_RESOLVED, "submit resolves")

	var after: int = _wallet.credits()
	var actual_removed: int = before - after
	var reported: int = _dict_int(result, &"pay_credits")

	assert_gte(after, 0, "wallet must not go negative")
	assert_eq(after, 0, "broke submit should take remaining credits")
	assert_eq(actual_removed, before, "all remaining credits should leave the wallet")
	assert_eq(
		reported,
		-actual_removed,
		"pay_credits must equal the credits actually removed, not the nominal fee"
	)
	assert_ne(
		reported,
		-BalanceIncident.INTERCEPT_SUBMIT_PAY_LOSS,
		"must not lie with the full nominal loss when the wallet could not cover it"
	)


## Ignore uses the same charge path as submit.
func test_broke_ignore_reports_actual_wallet_loss() -> void:
	_wallet.set_credits(BROKE_CREDITS)
	var before: int = _wallet.credits()

	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_INTERCEPT, SYSTEM_GAMMA)
	assert_false(String(id).is_empty())

	var result: Dictionary = IncidentService.respond(id, BalanceIncident.CHOICE_IGNORE)
	assert_true(_flag(result, &"ok"))

	var after: int = _wallet.credits()
	var actual_removed: int = before - after
	var reported: int = _dict_int(result, &"pay_credits")

	assert_gte(after, 0)
	assert_eq(reported, -actual_removed)
	assert_eq(actual_removed, before)


## Funded path still takes and reports the full fee (no accidental undercharge).
func test_funded_submit_still_charges_full_fee() -> void:
	var fee: int = BalanceIncident.INTERCEPT_SUBMIT_PAY_LOSS
	var starting: int = fee + 50
	_wallet.set_credits(starting)
	var before: int = _wallet.credits()

	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_INTERCEPT, SYSTEM_GAMMA)
	assert_false(String(id).is_empty())

	var result: Dictionary = IncidentService.respond(id, BalanceIncident.CHOICE_SUBMIT)
	assert_true(_flag(result, &"ok"))

	var after: int = _wallet.credits()
	assert_eq(before - after, fee)
	assert_eq(_dict_int(result, &"pay_credits"), -fee)
	assert_eq(after, starting - fee)


func _flag(data: Dictionary, key: StringName) -> bool:
	return data.get(key, false) == true


func _dict_int(data: Dictionary, key: StringName) -> int:
	if not data.has(key):
		return 0
	var raw: Variant = data[key]
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return int(as_float)
	return 0


func _dict_name(data: Dictionary, key: StringName) -> StringName:
	if not data.has(key):
		return &""
	return StringName(str(data[key]))
