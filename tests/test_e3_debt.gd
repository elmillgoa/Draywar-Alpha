extends GutTest

## E3.2 debt seed — Free Haulers thin loan, garnish, repay, save, grace standing.
##
## Implements: docs/BETA_E3_ECONOMY.md E3.2 / locked D2

const ENTITY_HAULERS: StringName = BalanceEconomy.LOAN_LENDER_ENTITY_ID
const ENTITY_REACH: StringName = &"entity_reach_authority"
const CONTRACT_ALPHA: StringName = &"contract_courier_alpha"
const SYSTEM_ALPHA: StringName = &"system_alpha"


func after_each() -> void:
	StandingService.reset_to_defaults()


func _owed(wallet: WalletService) -> int:
	var state: Dictionary = wallet.debt_state()
	return _variant_to_int(state.get(&"owed", 0))


func _lender(wallet: WalletService) -> StringName:
	var state: Dictionary = wallet.debt_state()
	return _variant_to_name(state.get(&"lender_id", &""))


func _grace(wallet: WalletService) -> int:
	var state: Dictionary = wallet.debt_state()
	return _variant_to_int(state.get(&"grace_docks_left", 0))


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _variant_to_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""


func _dict_bool(data: Dictionary, key: StringName) -> bool:
	var raw: Variant = data.get(key, false)
	return raw == true


func _dict_int(data: Dictionary, key: StringName) -> int:
	return _variant_to_int(data.get(key, 0))


func test_borrow_once_to_cap_cannot_stack() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start: int = wallet.credits()

	assert_eq(_owed(wallet), 0)
	var received: int = wallet.borrow()
	assert_eq(received, BalanceEconomy.LOAN_PRINCIPAL)
	assert_eq(wallet.credits(), start + BalanceEconomy.LOAN_PRINCIPAL)
	assert_eq(_owed(wallet), BalanceEconomy.LOAN_REPAY_TOTAL)
	assert_eq(_lender(wallet), ENTITY_HAULERS)
	assert_eq(_grace(wallet), BalanceEconomy.GRACE_DOCKS)

	var second: int = wallet.borrow()
	assert_eq(second, 0)
	assert_eq(_owed(wallet), BalanceEconomy.LOAN_REPAY_TOTAL)
	assert_eq(wallet.credits(), start + BalanceEconomy.LOAN_PRINCIPAL)


func test_job_pay_garnish_reduces_debt_player_gets_remainder() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	var credits_before: int = wallet.credits()
	var debt_before: int = _owed(wallet)
	var gross: int = BalanceEconomy.MISSION_PAY_DEFAULT
	var expected_garnish: int = int(floorf(float(gross) * BalanceEconomy.GARNISH_RATE))
	expected_garnish = mini(expected_garnish, debt_before)
	var expected_net: int = gross - expected_garnish

	var net: int = wallet.apply_job_pay_with_garnish(gross)
	assert_eq(net, expected_net)
	assert_eq(wallet.credits(), credits_before + expected_net)
	assert_eq(_owed(wallet), debt_before - expected_garnish)
	assert_gt(expected_garnish, 0, "balance garnish must seize some of default job pay")
	assert_gt(expected_net, 0, "player must still receive remainder")


func test_mission_complete_uses_garnish_path() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	await get_tree().process_frame
	wallet.reset()
	mission.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	var credits_before: int = wallet.credits()
	var debt_before: int = _owed(wallet)

	assert_true(mission.accept(CONTRACT_ALPHA))
	var result: Dictionary = mission.complete()
	assert_true(_dict_bool(result, BalanceStanding.REPORT_KEY_ATTRIBUTED))

	var template: ContractType = ContentLibrary.item(CONTRACT_ALPHA) as ContractType
	assert_ne(template, null)
	var gross: int = maxi(0, template.pay_credits)
	var expected_garnish: int = int(floorf(float(gross) * BalanceEconomy.GARNISH_RATE))
	expected_garnish = mini(expected_garnish, debt_before)
	var expected_net: int = gross - expected_garnish
	assert_eq(_dict_int(result, &"pay_credits"), expected_net)
	assert_eq(wallet.credits(), credits_before + expected_net)
	assert_eq(_owed(wallet), debt_before - expected_garnish)


func test_manual_repay_reduces_and_clears_debt() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	wallet.set_credits(100)
	var paid: int = wallet.try_repay()
	assert_eq(paid, 100)
	assert_eq(_owed(wallet), BalanceEconomy.LOAN_REPAY_TOTAL - 100)
	assert_eq(wallet.credits(), 0)
	assert_gt(_owed(wallet), 0)

	wallet.set_credits(1000)
	paid = wallet.try_repay()
	assert_eq(paid, BalanceEconomy.LOAN_REPAY_TOTAL - 100)
	assert_eq(_owed(wallet), 0)
	assert_eq(_lender(wallet), &"")
	# After clear, may borrow again (no stack while open).
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)


func test_save_round_trips_debt_fields() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	# Burn one grace dock via fee-charging dock while broke.
	wallet.set_credits(0)
	wallet.charge_dock_fee(SYSTEM_ALPHA)
	assert_eq(_grace(wallet), BalanceEconomy.GRACE_DOCKS - 1)
	wallet.set_credits(222)

	var section: Dictionary = wallet.to_section()
	assert_true(section.has(BalanceEconomy.SAVE_KEY_DEBT_OWED))
	assert_true(section.has(BalanceEconomy.SAVE_KEY_DEBT_LENDER_ID))
	assert_true(section.has(BalanceEconomy.SAVE_KEY_DEBT_GRACE_DOCKS_LEFT))

	var other: WalletService = WalletService.new()
	add_child_autofree(other)
	other.apply_section(section)
	assert_eq(other.credits(), 222)
	assert_eq(_owed(other), BalanceEconomy.LOAN_REPAY_TOTAL)
	assert_eq(_lender(other), ENTITY_HAULERS)
	assert_eq(_grace(other), BalanceEconomy.GRACE_DOCKS - 1)


func test_missing_wallet_debt_keys_means_no_debt() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	assert_gt(_owed(wallet), 0)

	# Old A5 wallet section shape: credits/fuel/condition only.
	(
		wallet
		. apply_section(
			{
				BalanceEconomy.SAVE_KEY_CREDITS: 50,
				BalanceEconomy.SAVE_KEY_FUEL: 80.0,
				BalanceEconomy.SAVE_KEY_CONDITION: 90.0,
			}
		)
	)
	assert_eq(wallet.credits(), 50)
	assert_eq(_owed(wallet), 0)
	assert_eq(_lender(wallet), &"")
	assert_eq(_grace(wallet), 0)


func test_grace_expiry_hits_free_haulers_only_via_standing_service() -> void:
	StandingService.reset_to_defaults()
	StandingService.set_entity_standing(ENTITY_HAULERS, 0.0)
	StandingService.set_entity_standing(ENTITY_REACH, 5.0)
	var before_haulers: float = StandingService.get_entity_standing(ENTITY_HAULERS)
	var before_reach: float = StandingService.get_entity_standing(ENTITY_REACH)

	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	wallet.set_credits(0)

	# Burn all grace docks while broke (fee path; partial fee when broke is OK).
	for _i: int in BalanceEconomy.GRACE_DOCKS:
		wallet.charge_dock_fee(SYSTEM_ALPHA)
	assert_eq(_grace(wallet), 0)
	assert_eq(_owed(wallet), BalanceEconomy.LOAN_REPAY_TOTAL, "grace must not clear debt")

	var after_haulers: float = StandingService.get_entity_standing(ENTITY_HAULERS)
	var after_reach: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(
		after_haulers, before_haulers + BalanceStanding.DEBT_GRACE_EXPIRED_DELTA, 0.0001
	)
	assert_almost_eq(after_reach, before_reach, 0.0001)
	assert_eq(StandingService.last_delta_reason, BalanceStanding.REASON_DEBT_GRACE_EXPIRED)

	# Extra docks after expiry must not re-hit standing.
	wallet.charge_dock_fee(SYSTEM_ALPHA)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_HAULERS), after_haulers, 0.0001)


func test_grace_does_not_burn_when_credits_meet_floor() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	# After dock fee, credits must still meet floor so grace does not burn.
	# Patrolled fee is 30; start with floor + fee so post-fee balance == floor.
	var fee: int = wallet.dock_fee_for_system(SYSTEM_ALPHA)
	wallet.set_credits(BalanceEconomy.MIN_PAYMENT_FLOOR + fee)
	wallet.charge_dock_fee(SYSTEM_ALPHA)
	assert_eq(wallet.credits(), BalanceEconomy.MIN_PAYMENT_FLOOR)
	assert_eq(_grace(wallet), BalanceEconomy.GRACE_DOCKS)

	wallet.set_credits(BalanceEconomy.MIN_PAYMENT_FLOOR - 1)
	wallet.charge_dock_fee(SYSTEM_ALPHA)
	assert_eq(_grace(wallet), BalanceEconomy.GRACE_DOCKS - 1)


func test_broke_with_debt_still_can_fly_when_fuel_and_hull_allow() -> void:
	## Debt ≠ cripple / repossession / undock ban (D2 / D7).
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	wallet.set_credits(0)
	assert_gt(_owed(wallet), 0)
	assert_true(wallet.has_fuel())
	assert_true(wallet.can_fly())
	assert_true(wallet.can_jump())
	assert_gte(wallet.credits(), 0)


func test_loan_balance_constants_match_d2() -> void:
	assert_eq(BalanceEconomy.LOAN_PRINCIPAL, 400)
	assert_eq(BalanceEconomy.LOAN_REPAY_TOTAL, 480)
	assert_almost_eq(BalanceEconomy.GARNISH_RATE, 0.25, 0.0001)
	assert_eq(BalanceEconomy.GRACE_DOCKS, 3)
	assert_eq(BalanceEconomy.LOAN_LENDER_ENTITY_ID, &"entity_free_haulers")
	assert_true(ContentLibrary.has_item(BalanceEconomy.LOAN_LENDER_ENTITY_ID))
	assert_lt(BalanceStanding.DEBT_GRACE_EXPIRED_DELTA, 0.0)
	assert_eq(BalanceStanding.REASON_DEBT_GRACE_EXPIRED, &"debt_grace_expired")


func test_garnish_clears_small_remaining_debt() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	wallet.set_credits(BalanceEconomy.LOAN_REPAY_TOTAL - 10)
	assert_eq(wallet.try_repay(), BalanceEconomy.LOAN_REPAY_TOTAL - 10)
	assert_eq(_owed(wallet), 10)
	wallet.set_credits(0)
	var net: int = wallet.apply_job_pay_with_garnish(100)
	# 25% of 100 = 25, capped to 10 debt → net 90.
	assert_eq(net, 90)
	assert_eq(_owed(wallet), 0)
	assert_eq(wallet.credits(), 90)
