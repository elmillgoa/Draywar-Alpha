extends GutTest

## S5 Session B — WalletService split into money / fuel / hull.
##
## Proves: WalletService.to_section is money-only; CareerSave merges all three
## under the single optional `wallet` key; fuel and hull apply independently
## from a combined section. No envelope version bump.

const TOLERANCE: float = 0.001


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _as_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return as_float
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	return 0.0


func test_wallet_to_section_is_money_only() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	wallet.set_credits(777)
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)

	var section: Dictionary = wallet.to_section()
	assert_true(section.has(BalanceEconomy.SAVE_KEY_CREDITS))
	assert_true(section.has(BalanceEconomy.SAVE_KEY_DEBT_OWED))
	assert_true(section.has(BalanceEconomy.SAVE_KEY_DEBT_LENDER_ID))
	assert_true(section.has(BalanceEconomy.SAVE_KEY_DEBT_GRACE_DOCKS_LEFT))
	assert_false(
		section.has(BalanceEconomy.SAVE_KEY_FUEL),
		"WalletService.to_section must not write fuel (FuelService owns it)"
	)
	assert_false(
		section.has(BalanceEconomy.SAVE_KEY_CONDITION),
		"WalletService.to_section must not write condition (HullConditionService owns it)"
	)
	assert_eq(_as_int(section[BalanceEconomy.SAVE_KEY_CREDITS]), wallet.credits())


func test_fuel_and_hull_to_section_are_key_only() -> void:
	var fuel: FuelService = FuelService.new()
	var hull: HullConditionService = HullConditionService.new()
	add_child_autofree(fuel)
	add_child_autofree(hull)
	fuel.reset()
	hull.reset()
	fuel.burn_fuel(1.0, 1.0, false)
	hull.wear_condition(3.0, true)

	var fuel_section: Dictionary = fuel.to_section()
	assert_eq(fuel_section.size(), 1)
	assert_true(fuel_section.has(BalanceEconomy.SAVE_KEY_FUEL))
	assert_almost_eq(_as_float(fuel_section[BalanceEconomy.SAVE_KEY_FUEL]), fuel.fuel(), TOLERANCE)

	var hull_section: Dictionary = hull.to_section()
	assert_eq(hull_section.size(), 1)
	assert_true(hull_section.has(BalanceEconomy.SAVE_KEY_CONDITION))
	assert_almost_eq(
		_as_float(hull_section[BalanceEconomy.SAVE_KEY_CONDITION]), hull.condition(), TOLERANCE
	)


func test_career_save_combined_wallet_section_has_all_three() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	var fuel: FuelService = FuelService.new()
	var hull: HullConditionService = HullConditionService.new()
	host.add_child(wallet)
	host.add_child(fuel)
	host.add_child(hull)
	await get_tree().process_frame

	wallet.reset()
	fuel.reset()
	hull.reset()
	wallet.set_credits(250)
	fuel.burn_fuel(2.0, 1.0, false)
	hull.apply_damage(15.0)

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceEconomy.SAVE_SECTION_KEY), "wallet section must be gathered")
	var combined: Dictionary = sections[BalanceEconomy.SAVE_SECTION_KEY]
	assert_true(combined.has(BalanceEconomy.SAVE_KEY_CREDITS))
	assert_true(combined.has(BalanceEconomy.SAVE_KEY_FUEL))
	assert_true(combined.has(BalanceEconomy.SAVE_KEY_CONDITION))
	assert_eq(_as_int(combined[BalanceEconomy.SAVE_KEY_CREDITS]), 250)
	assert_almost_eq(_as_float(combined[BalanceEconomy.SAVE_KEY_FUEL]), fuel.fuel(), TOLERANCE)
	assert_almost_eq(
		_as_float(combined[BalanceEconomy.SAVE_KEY_CONDITION]), hull.condition(), TOLERANCE
	)


func test_fuel_and_hull_apply_independently_from_full_section() -> void:
	## Old combined wallet shape (credits + fuel + condition + debt) loads into
	## the three services; each keeps only its keys.
	var full: Dictionary = {
		BalanceEconomy.SAVE_KEY_CREDITS: 111,
		BalanceEconomy.SAVE_KEY_FUEL: 42.5,
		BalanceEconomy.SAVE_KEY_CONDITION: 77.0,
		BalanceEconomy.SAVE_KEY_DEBT_OWED: 0,
		BalanceEconomy.SAVE_KEY_DEBT_LENDER_ID: "",
		BalanceEconomy.SAVE_KEY_DEBT_GRACE_DOCKS_LEFT: 0,
	}

	var wallet: WalletService = WalletService.new()
	var fuel: FuelService = FuelService.new()
	var hull: HullConditionService = HullConditionService.new()
	add_child_autofree(wallet)
	add_child_autofree(fuel)
	add_child_autofree(hull)
	wallet.reset()
	fuel.reset()
	hull.reset()

	wallet.apply_section(full)
	fuel.apply_section(full)
	hull.apply_section(full)

	assert_eq(wallet.credits(), 111)
	assert_almost_eq(fuel.fuel(), 42.5, TOLERANCE)
	assert_almost_eq(hull.condition(), 77.0, TOLERANCE)

	# Money-only re-apply must not wipe fuel/condition on those services.
	var money_only: Dictionary = wallet.to_section()
	assert_false(money_only.has(BalanceEconomy.SAVE_KEY_FUEL))
	fuel.apply_section(money_only)
	hull.apply_section(money_only)
	assert_almost_eq(fuel.fuel(), 42.5, TOLERANCE, "missing fuel key leaves fuel alone")
	assert_almost_eq(hull.condition(), 77.0, TOLERANCE, "missing condition key leaves hull alone")


func test_missing_wallet_section_resets_all_three_via_career_save() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	var fuel: FuelService = FuelService.new()
	var hull: HullConditionService = HullConditionService.new()
	host.add_child(wallet)
	host.add_child(fuel)
	host.add_child(hull)
	await get_tree().process_frame

	wallet.set_credits(9)
	fuel.burn_fuel(3.0, 1.0, true)
	hull.apply_damage(20.0)
	assert_ne(wallet.credits(), BalanceEconomy.STARTING_CREDITS)
	assert_lt(fuel.fuel(), BalanceEconomy.STARTING_FUEL)
	assert_lt(hull.condition(), BalanceEconomy.STARTING_CONDITION)

	# Missing `wallet` key only — other meta sections left alone.
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	sections.erase(BalanceEconomy.SAVE_SECTION_KEY)
	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_eq(wallet.credits(), BalanceEconomy.STARTING_CREDITS)
	assert_almost_eq(fuel.fuel(), BalanceEconomy.STARTING_FUEL, TOLERANCE)
	assert_almost_eq(hull.condition(), BalanceEconomy.STARTING_CONDITION, TOLERANCE)


func test_refuel_spends_via_wallet_group() -> void:
	var wallet: WalletService = WalletService.new()
	var fuel: FuelService = FuelService.new()
	add_child_autofree(wallet)
	add_child_autofree(fuel)
	wallet.reset()
	fuel.reset()
	wallet.set_credits(500)
	while fuel.fuel() > 1.0:
		fuel.burn_fuel(1.0, 1.0, true)
	var before: int = wallet.credits()
	var added: float = fuel.refuel_chunk()
	assert_gt(added, 0.0)
	assert_lt(wallet.credits(), before)


func test_repair_spends_via_wallet_group() -> void:
	var wallet: WalletService = WalletService.new()
	var hull: HullConditionService = HullConditionService.new()
	add_child_autofree(wallet)
	add_child_autofree(hull)
	wallet.reset()
	hull.reset()
	wallet.set_credits(2000)
	hull.apply_damage(50.0)
	var before: int = wallet.credits()
	assert_true(hull.repair_full())
	assert_lt(wallet.credits(), before)
	assert_almost_eq(hull.condition(), BalanceEconomy.CONDITION_MAX, TOLERANCE)
