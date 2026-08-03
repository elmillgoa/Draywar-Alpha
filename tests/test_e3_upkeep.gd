extends GutTest

## E3.1 career pressure — undocked life-support upkeep + fuel still gates motion.
##
## Implements: docs/BETA_E3_ECONOMY.md E3.1

## Fixed scaled seconds for headless delta checks (whole product with rate).
const FIXED_SCALED_SECONDS: float = 10.0


func test_upkeep_undocked_burns_at_balance_rate() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start: int = wallet.credits()
	assert_eq(start, BalanceEconomy.STARTING_CREDITS)

	var expected: int = int(floorf(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * FIXED_SCALED_SECONDS))
	assert_gt(expected, 0, "balance rate × fixed seconds must produce a whole credit")

	var spent: int = wallet.tick_upkeep(FIXED_SCALED_SECONDS, false)
	assert_eq(spent, expected)
	assert_eq(wallet.credits(), start - expected)


func test_upkeep_docked_does_not_burn() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start: int = wallet.credits()

	var spent: int = wallet.tick_upkeep(FIXED_SCALED_SECONDS, true)
	assert_eq(spent, 0)
	assert_eq(wallet.credits(), start)


func test_upkeep_credits_never_go_negative() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	wallet.set_credits(3)

	var spent: int = wallet.tick_upkeep(100.0, false)
	assert_eq(spent, 3)
	assert_eq(wallet.credits(), 0)

	# Already broke: further undocked time spends nothing and stays at 0.
	spent = wallet.tick_upkeep(FIXED_SCALED_SECONDS, false)
	assert_eq(spent, 0)
	assert_eq(wallet.credits(), 0)
	assert_gte(wallet.credits(), 0)


func test_upkeep_multi_frame_matches_single_chunk() -> void:
	## Fractional debt must land the same whole credits as one big tick.
	var a: WalletService = WalletService.new()
	var b: WalletService = WalletService.new()
	add_child_autofree(a)
	add_child_autofree(b)
	a.reset()
	b.reset()

	var frame: float = 0.25
	var frames: int = 40
	var total: float = frame * float(frames)
	for _i: int in frames:
		a.tick_upkeep(frame, false)
	b.tick_upkeep(total, false)
	assert_eq(a.credits(), b.credits())


func test_upkeep_zero_delta_and_zero_rate_safe() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start: int = wallet.credits()
	assert_eq(wallet.tick_upkeep(0.0, false), 0)
	assert_eq(wallet.tick_upkeep(-1.0, false), 0)
	assert_eq(wallet.credits(), start)


func test_fuel_still_gates_thrust_and_jumps() -> void:
	var fuel: FuelService = FuelService.new()
	add_child_autofree(fuel)
	fuel.reset()
	assert_true(fuel.has_fuel())
	assert_true(fuel.can_jump())

	# Drain tank via burn + jumps until empty of jump fuel.
	while fuel.can_jump():
		assert_true(fuel.try_spend_jump_fuel())
	assert_false(fuel.can_jump())

	# Burn remaining fuel with full throttle.
	var guard: int = 0
	while fuel.has_fuel() and guard < 10000:
		fuel.burn_fuel(1.0, 1.0, true)
		guard += 1
	assert_false(fuel.has_fuel())
	assert_false(fuel.can_jump())
	assert_false(fuel.try_spend_jump_fuel())


func test_upkeep_rate_is_noticeable_vs_start() -> void:
	## Guidance: ~30–60s free-fly should bite starting credits.
	var bite_at_sixty: int = int(floorf(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * 60.0))
	assert_gte(bite_at_sixty, 30, "60s free-fly should cost at least ~30 credits")
	assert_lt(
		bite_at_sixty,
		BalanceEconomy.STARTING_CREDITS,
		"60s free-fly must not softlock a new career"
	)
	assert_gt(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND, 0.0)
