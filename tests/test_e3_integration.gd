extends GutTest

## E3.5 economy integration / balance pass — pressure math + softlock escape.
##
## Implements: docs/BETA_E3_ECONOMY.md E3.5
## All scenario numbers come from named BalanceEconomy (and content) constants.

const StationLoanUiScript = preload("res://src/ui/station/StationLoanUi.gd")

const SYSTEM_ALPHA: StringName = &"system_alpha"
const STATION_ALPHA: StringName = &"station_alpha_port"
const CONTRACT_COURIER: StringName = &"contract_courier_alpha"
const CONTRACT_SMUGGLE: StringName = &"contract_smuggle_beta_to_gamma"
const CONTRACT_SMUGGLE_ALT: StringName = &"contract_smuggle_gamma_to_beta"


func after_each() -> void:
	StandingService.reset_to_defaults()


func _owed(wallet: WalletService) -> int:
	var state: Dictionary = wallet.debt_state()
	return _variant_to_int(state.get(&"owed", 0))


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _ceil_credits(amount: float) -> int:
	if amount <= 0.0:
		return 0
	return int(ceilf(amount))


## Fuel units → station refuel credit cost at base rate (no standing markup).
func _fuel_credit_cost(units: float) -> int:
	return _ceil_credits(units * BalanceEconomy.REFUEL_CREDITS_PER_UNIT)


## Courier pay used as pressure baseline (content override or mission default).
func _courier_pay() -> int:
	if ContentLibrary.has_item(CONTRACT_COURIER):
		var item: ContentItem = ContentLibrary.item(CONTRACT_COURIER)
		if item is ContractType:
			var contract: ContractType = item as ContractType
			return maxi(0, contract.pay_credits)
	return BalanceEconomy.MISSION_PAY_DEFAULT


func _smuggle_min_pay() -> int:
	var pays: Array[int] = []
	for id: StringName in [CONTRACT_SMUGGLE, CONTRACT_SMUGGLE_ALT]:
		if not ContentLibrary.has_item(id):
			continue
		var item: ContentItem = ContentLibrary.item(id)
		if item is ContractType:
			var contract: ContractType = item as ContractType
			pays.append(maxi(0, contract.pay_credits))
	if pays.is_empty():
		return 0
	var lowest: int = pays[0]
	for p: int in pays:
		lowest = mini(lowest, p)
	return lowest


func test_three_jumps_plus_free_fly_cost_more_than_one_courier() -> void:
	## Idle multi-system travel without earning must outspend one courier pay.
	var jump_fuel: float = (
		BalanceEconomy.JUMP_FUEL_COST * float(BalanceEconomy.SCENARIO_PRESSURE_JUMP_COUNT)
	)
	var jump_fuel_credits: int = _fuel_credit_cost(jump_fuel)

	var free_fly_s: float = BalanceEconomy.SCENARIO_FREE_FLY_SLICE_SECONDS
	var upkeep_credits: int = int(floorf(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * free_fly_s))
	var free_fly_fuel: float = BalanceEconomy.FUEL_BURN_PER_SECOND_AT_FULL * free_fly_s
	var free_fly_fuel_credits: int = _fuel_credit_cost(free_fly_fuel)

	var never_earn_cost: int = jump_fuel_credits + upkeep_credits + free_fly_fuel_credits
	var courier_pay: int = _courier_pay()

	assert_gt(BalanceEconomy.SCENARIO_PRESSURE_JUMP_COUNT, 0)
	assert_gt(free_fly_s, 0.0)
	assert_gt(jump_fuel_credits, 0, "three jumps must cost real refuel credits")
	assert_gt(upkeep_credits, 0, "free-fly slice must burn life-support credits")
	assert_gt(courier_pay, 0, "courier pay baseline must be positive")
	assert_gt(
		never_earn_cost,
		courier_pay,
		(
			(
				"never-earn slice (%d = jumps %d + upkeep %d + free-fly fuel %d) "
				+ "must exceed one courier (%d)"
			)
			% [
				never_earn_cost,
				jump_fuel_credits,
				upkeep_credits,
				free_fly_fuel_credits,
				courier_pay
			]
		)
	)
	# Also the simpler upkeep+jump-fuel form from the acceptance note.
	var upkeep_plus_jumps: int = upkeep_credits + jump_fuel_credits
	assert_gt(
		upkeep_plus_jumps,
		courier_pay,
		(
			"upkeep+three-jump fuel (%d) must exceed courier pay (%d)"
			% [upkeep_plus_jumps, courier_pay]
		)
	)


func test_smuggle_pay_covers_fine_risk_and_short_upkeep_with_margin() -> void:
	## Smuggle gross should clear Reach fine band + short bills and still leave cash.
	var pay: int = _smuggle_min_pay()
	assert_gt(pay, 0, "smuggle templates must load with pay")

	var fine_band: int = BalanceEconomy.CONTRABAND_FINE_BASE
	var short_upkeep: int = int(
		floorf(
			BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * BalanceEconomy.SCENARIO_SHORT_UPKEEP_SECONDS
		)
	)
	# One hop of fuel replace as the thin travel tax on a quiet run.
	var one_jump_fuel_credits: int = _fuel_credit_cost(BalanceEconomy.JUMP_FUEL_COST)

	var risk_and_bills: int = fine_band + short_upkeep + one_jump_fuel_credits
	var margin: int = pay - risk_and_bills

	assert_gt(fine_band, 0)
	assert_gt(short_upkeep, 0)
	assert_gt(
		margin,
		0,
		(
			(
				"smuggle min pay %d must cover fine %d + short upkeep %d + jump fuel %d "
				+ "(margin %d)"
			)
			% [pay, fine_band, short_upkeep, one_jump_fuel_credits, margin]
		)
	)
	# Rough band: pay at least fine + short upkeep even without the jump term.
	assert_gt(pay, fine_band + short_upkeep)


func test_starting_credits_do_not_softlock_before_first_job() -> void:
	## New career: short undock + first redock still leaves runway for a dock job.
	## Broke escape: Free Haulers loan unlocks dock fee + services cash.
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	assert_eq(wallet.credits(), BalanceEconomy.STARTING_CREDITS)
	assert_eq(_owed(wallet), 0)
	var fuel: FuelService = FuelService.new()
	add_child_autofree(fuel)
	fuel.reset()
	assert_true(fuel.has_fuel())
	assert_true(fuel.can_jump())

	# Brief free-fly before first re-dock (life-support only while undocked).
	var undock_s: float = BalanceEconomy.SCENARIO_FIRST_JOB_UNDOCK_SECONDS
	var spent_upkeep: int = wallet.tick_upkeep(undock_s, false)
	var expected_upkeep: int = int(floorf(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * undock_s))
	assert_eq(spent_upkeep, expected_upkeep)
	assert_eq(wallet.credits(), BalanceEconomy.STARTING_CREDITS - expected_upkeep)

	# Redock Alpha Port (patrolled fee). Must still be able to pay something
	# and keep credits for the job board path (jobs themselves are free to accept).
	var fee: int = wallet.dock_fee_for_system(SYSTEM_ALPHA, STATION_ALPHA)
	assert_gt(fee, 0, "Alpha dock fee must be a real sink")
	assert_true(
		wallet.can_afford(fee),
		"after short undock, starting wallet must still cover first dock fee"
	)
	var paid: int = wallet.charge_dock_fee(SYSTEM_ALPHA, STATION_ALPHA)
	assert_eq(paid, fee)
	assert_gt(wallet.credits(), 0, "post first-dock balance must remain positive for the job board")
	# Still above low-funds warn so the career does not open already panicked.
	assert_gt(wallet.credits(), BalanceEconomy.UPKEEP_LOW_FUNDS_THRESHOLD)

	# Softlock escape hatch: if wallet is emptied, loan restores runway.
	wallet.set_credits(0)
	assert_false(wallet.can_afford(fee))
	var principal: int = wallet.borrow()
	assert_eq(principal, BalanceEconomy.LOAN_PRINCIPAL)
	assert_eq(_owed(wallet), BalanceEconomy.LOAN_REPAY_TOTAL)
	assert_eq(wallet.credits(), BalanceEconomy.LOAN_PRINCIPAL)
	assert_true(wallet.can_afford(fee), "loan principal must cover a patrolled dock fee")
	assert_true(
		wallet.can_afford(BalanceEconomy.MIN_PAYMENT_FLOOR),
		"loan principal must clear the debt payment floor"
	)
	# One refuel chunk at base rate must also be affordable after borrow.
	var refuel_chunk_cost: int = _fuel_credit_cost(BalanceEconomy.REFUEL_CHUNK)
	assert_true(
		wallet.can_afford(refuel_chunk_cost),
		"loan must afford at least one refuel chunk (escape to fly again)"
	)


func test_service_simulation_upkeep_dock_job_garnish_repay() -> void:
	## End-to-end wallet path: pressure → earn with garnish → manual repay.
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	await get_tree().process_frame
	wallet.reset()
	mission.reset()

	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	var debt_before: int = _owed(wallet)
	assert_eq(debt_before, BalanceEconomy.LOAN_REPAY_TOTAL)

	# Undock pressure then dock (grace only burns when broke below floor).
	wallet.tick_upkeep(BalanceEconomy.SCENARIO_SHORT_UPKEEP_SECONDS, false)
	assert_eq(wallet.tick_upkeep(1.0, true), 0, "docked upkeep is off")
	wallet.charge_dock_fee(SYSTEM_ALPHA, STATION_ALPHA)
	assert_eq(_owed(wallet), debt_before, "dock fee must not clear debt")

	assert_true(mission.accept(CONTRACT_COURIER))
	var credits_before_pay: int = wallet.credits()
	var result: Dictionary = mission.complete()
	var attributed: bool = result.get(BalanceStanding.REPORT_KEY_ATTRIBUTED, false) == true
	assert_true(attributed)

	var template: ContractType = ContentLibrary.item(CONTRACT_COURIER) as ContractType
	assert_ne(template, null)
	var gross: int = maxi(0, template.pay_credits)
	var expected_garnish: int = int(floorf(float(gross) * BalanceEconomy.GARNISH_RATE))
	expected_garnish = mini(expected_garnish, debt_before)
	var expected_net: int = gross - expected_garnish
	assert_eq(_variant_to_int(result.get(&"pay_credits", 0)), expected_net)
	assert_eq(wallet.credits(), credits_before_pay + expected_net)
	assert_eq(_owed(wallet), debt_before - expected_garnish)

	# Manual repay clears remaining debt when funded.
	wallet.set_credits(BalanceEconomy.LOAN_REPAY_TOTAL)
	var paid: int = wallet.try_repay()
	assert_eq(paid, debt_before - expected_garnish)
	assert_eq(_owed(wallet), 0)
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL, "may borrow again after clear")


func test_captain_sheet_shows_credits_fuel_hull_debt_job() -> void:
	## Sheet formats + live debt/job lines after wallet + mission seed.
	assert_true(BalanceSession.SHEET_CREDITS_FORMAT.find("%d") >= 0)
	assert_true(BalanceSession.SHEET_FUEL_FORMAT.find("%d") >= 0)
	assert_true(BalanceSession.SHEET_HULL_FORMAT.find("%d") >= 0)
	assert_true(BalanceSession.SHEET_DEBT_FORMAT.find("%d") >= 0)
	assert_true(BalanceSession.SHEET_DEBT_NONE.find("none") >= 0)
	assert_true(BalanceSession.SHEET_JOB_FORMAT.find("%s") >= 0)
	assert_true(BalanceSession.SHEET_NO_JOB.find("none") >= 0)

	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	await get_tree().process_frame
	wallet.reset()
	mission.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	assert_true(mission.accept(CONTRACT_COURIER))

	var sheet: CaptainSheet = CaptainSheet.new()
	host.add_child(sheet)
	await get_tree().process_frame
	if sheet.has_method(&"_refresh"):
		sheet.call(&"_refresh")
	await get_tree().process_frame

	var credits_text: String = _label_text(sheet, "_credits_label")
	var debt_text: String = _label_text(sheet, "_debt_label")
	var fuel_text: String = _label_text(sheet, "_fuel_label")
	var hull_text: String = _label_text(sheet, "_hull_label")
	var job_text: String = _label_text(sheet, "_job_label")

	assert_false(credits_text.is_empty(), "credits line present")
	assert_true(
		credits_text.find(str(wallet.credits())) >= 0,
		"credits line shows balance: %s" % credits_text
	)
	assert_true(
		debt_text.find(str(BalanceEconomy.LOAN_REPAY_TOTAL)) >= 0 or debt_text.findn("Debt") >= 0,
		"debt line after borrow: %s" % debt_text
	)
	assert_true(fuel_text.findn("Fuel") >= 0 or fuel_text.find("%") >= 0, fuel_text)
	assert_true(hull_text.findn("Hull") >= 0 or hull_text.find("%") >= 0, hull_text)
	assert_false(job_text.is_empty(), "active job line present")
	assert_true(
		job_text.findn("Job") >= 0 or job_text.findn("Courier") >= 0 or job_text.find("→") >= 0,
		"job line readable: %s" % job_text
	)


func test_station_services_has_loan_repay_and_core_services() -> void:
	## Services desk: borrow + repay + refuel/repair labels exist and loan UI wires.
	assert_true(BalanceEconomy.STATION_REFUEL_LABEL.findn("Refuel") >= 0)
	assert_true(BalanceEconomy.STATION_REPAIR_LABEL.findn("Repair") >= 0)
	assert_true(BalanceEconomy.STATION_BORROW_FORMAT.find("%d") >= 0)
	assert_true(BalanceEconomy.STATION_REPAY_FORMAT.find("%d") >= 0)
	assert_eq(BalanceEconomy.STATION_SECTION_SERVICES, "Services")

	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	var host: Control = Control.new()
	add_child_autofree(host)
	var size: Vector2 = Vector2(200.0, 40.0)
	var loan_btns: Array[Button] = StationLoanUiScript.make_buttons(host, size)
	assert_eq(loan_btns.size(), 2)
	var borrow_btn: Button = loan_btns[0]
	var repay_btn: Button = loan_btns[1]

	StationLoanUiScript.refresh_buttons(borrow_btn, repay_btn, wallet, true)
	assert_true(borrow_btn.visible, "borrow visible when debt clear")
	assert_false(repay_btn.visible, "repay hidden when no debt")
	assert_true(
		borrow_btn.text.find(str(BalanceEconomy.LOAN_PRINCIPAL)) >= 0,
		"borrow label names principal: %s" % borrow_btn.text
	)

	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	StationLoanUiScript.refresh_buttons(borrow_btn, repay_btn, wallet, true)
	assert_false(borrow_btn.visible, "no second loan while open")
	assert_true(repay_btn.visible, "repay visible with debt")
	assert_true(
		repay_btn.text.find(str(BalanceEconomy.LOAN_REPAY_TOTAL)) >= 0,
		"repay label names owed: %s" % repay_btn.text
	)
	assert_false(repay_btn.disabled, "repay enabled when credits available")

	# Core services refresh keeps refuel/repair available beside loan controls.
	var refuel_btn: Button = Button.new()
	var repair_btn: Button = Button.new()
	var fee_label: Label = Label.new()
	host.add_child(refuel_btn)
	host.add_child(repair_btn)
	host.add_child(fee_label)
	StationLoanUiScript.refresh_core_services(
		refuel_btn, repair_btn, fee_label, borrow_btn, repay_btn, wallet, STATION_ALPHA, true
	)
	assert_true(refuel_btn.visible)
	assert_true(repair_btn.visible)
	assert_true(fee_label.visible)
	assert_true(fee_label.text.findn("Dock fee") >= 0 or fee_label.text.find("credits") >= 0)


func test_pressure_constants_are_sane_vs_start() -> void:
	## Guardrails so a future retune cannot softlock start or zero-out pressure.
	assert_gt(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND, 0.0)
	assert_gt(BalanceEconomy.FUEL_BURN_PER_SECOND_AT_FULL, 0.0)
	assert_gt(BalanceEconomy.JUMP_FUEL_COST, 0.0)
	assert_gt(BalanceEconomy.STARTING_CREDITS, 0)
	assert_gt(BalanceEconomy.LOAN_PRINCIPAL, 0)
	assert_gt(BalanceEconomy.LOAN_REPAY_TOTAL, BalanceEconomy.LOAN_PRINCIPAL)
	assert_gt(BalanceEconomy.GARNISH_RATE, 0.0)
	assert_lt(BalanceEconomy.GARNISH_RATE, 1.0)
	# Free-fly slice at start must bite but not wipe the wallet alone.
	var free_fly_bite: int = int(
		floorf(
			(
				BalanceEconomy.UPKEEP_CREDITS_PER_SECOND
				* BalanceEconomy.SCENARIO_FREE_FLY_SLICE_SECONDS
			)
		)
	)
	assert_gt(free_fly_bite, 0)
	assert_lt(free_fly_bite, BalanceEconomy.STARTING_CREDITS)
	# Loan principal outruns one patrolled dock fee (escape hatch usable).
	assert_gt(BalanceEconomy.LOAN_PRINCIPAL, BalanceEconomy.DOCK_FEE_PATROLLED)


func _label_text(sheet: CaptainSheet, prop: String) -> String:
	var raw: Variant = sheet.get(prop)
	if raw is Label:
		var label: Label = raw
		return label.text
	return ""
