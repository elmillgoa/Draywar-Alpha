extends GutTest

## Job 8 (audit PT-2, and the pre-career half of PT-10) — making a captain must
## not cost the captain money.
##
## External audit baseline ee17eab5: the world clock ran behind the
## character-creation screen and life support billed 1 credit per second of it,
## measured at 0.99 credits/s on the shipping 1152x648 window. A player who read
## the three cards was poorer for reading them, and Confirm restored nothing —
## careers were observed starting at 0 credits.
##
## Implements Elliot's written decision (2026-08-07,
## `Draywar Review/DECISION_creation-screen-clock.md`):
##   Q1 option B — Confirm tops credits up to BalanceEconomy.STARTING_CREDITS
##     only when below it, and never subtracts, so it cannot wipe the debt
##     mark's +400 whatever order it runs in.
##   Q2 option B — the clock keeps running (market, board and security still
##     age behind the dialog) but the wallet is exempt from upkeep until the
##     career exists.
## The pause-menu half of PT-10 (#46) is deliberately NOT touched here.
##
## Simulated screen time uses WorldClock.advance_seconds: the same
## _tick_wallet_upkeep path a live frame takes, and a stricter one — the bulk
## path skips the "is a player ship in the tree" guard that the live path
## applies, so nothing here can pass by accident of an empty scene.

## A minute spent reading the three cards.
const CREATION_SCREEN_SECONDS: float = 60.0
## Short run used to prove upkeep is billing again after the opening ends.
const RESUMED_SECONDS: float = 10.0
## The drain the audit measured before Confirm (~90 credits at 1 credit/s).
## Applied through the wallet's own upkeep API because the clock no longer
## produces it — the floor must still catch a wallet that arrives low by any
## route, including the pause-menu drain that is still someone else's job.
const MEASURED_PRE_CAREER_DRAIN_SECONDS: float = 90.0
## A wallet that reaches Confirm richer than the floor. Must be left alone.
const RICH_WALLET_CREDITS: int = 1200

var _category_seconds: float = 0.0


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()
	CareerStart.reset()
	_category_seconds = 0.0


func after_each() -> void:
	# Never leave the exemption standing: it is an autoload flag, so a test that
	# opened the creation screen and did not close it would hand every later
	# upkeep test free life support.
	EventBus.on_annexation_continue_requested.emit()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()
	CareerStart.reset()


## Q2: a minute on the creation screen costs nothing.
func test_reading_the_life_path_cards_costs_no_credits() -> void:
	var wallet: WalletService = _fresh_wallet()
	EventBus.on_new_game_requested.emit()

	WorldClock.advance_seconds(CREATION_SCREEN_SECONDS)

	assert_eq(
		wallet.credits(),
		BalanceEconomy.STARTING_CREDITS,
		"life support may not bill a career that does not exist yet"
	)


## Q2: exempt the wallet, not the world. The clock is not frozen.
func test_the_world_still_ages_behind_the_creation_screen() -> void:
	var wallet: WalletService = _fresh_wallet()
	EventBus.on_new_game_requested.emit()
	WorldClock.register_category_subscriber(BalanceWorldClock.CATEGORY_MARKET, _count_category)

	WorldClock.advance_seconds(CREATION_SCREEN_SECONDS)
	WorldClock.unregister_category_subscriber(BalanceWorldClock.CATEGORY_MARKET, _count_category)

	assert_almost_eq(
		WorldClock.elapsed_seconds(), CREATION_SCREEN_SECONDS, 0.001, "world time must keep running"
	)
	assert_almost_eq(
		_category_seconds,
		CREATION_SCREEN_SECONDS,
		0.001,
		"market/board/security subscribers must still tick during the opening"
	)
	assert_eq(wallet.credits(), BalanceEconomy.STARTING_CREDITS)


## Definition of done, test 1: sit on the creation screen for a simulated
## minute, press Confirm, and hold the guaranteed balance.
func test_confirm_after_a_minute_on_the_creation_screen_starts_at_the_floor() -> void:
	var wallet: WalletService = _fresh_wallet()
	EventBus.on_new_game_requested.emit()
	WorldClock.advance_seconds(CREATION_SCREEN_SECONDS)

	CareerStart.apply_default(wallet)

	assert_eq(
		wallet.credits(),
		BalanceEconomy.STARTING_CREDITS,
		"Confirm must guarantee the starting balance"
	)
	assert_eq(_owed(wallet), 0, "a clean mark opens no debt")


## Definition of done, test 2 — the ordering test. The debt mark is the only
## card in the game that promises a credit figure ("+400 credits, owe 480"). A
## floor applied as a hard set, or applied after the loan, would swallow it.
func test_debt_mark_confirm_pays_the_floor_plus_the_full_loan() -> void:
	var wallet: WalletService = _fresh_wallet()
	EventBus.on_new_game_requested.emit()
	# Arrive at Confirm poor, the way the audit found the player arriving.
	wallet.tick_upkeep(MEASURED_PRE_CAREER_DRAIN_SECONDS, false)
	assert_lt(
		wallet.credits(),
		BalanceEconomy.STARTING_CREDITS,
		"setup: wallet must start below the floor"
	)

	CareerStart.apply(
		BalanceStanding.LIFE_PATH_DEFAULT_ORIGIN,
		BalanceStanding.LIFE_PATH_DEFAULT_TRADE,
		&"mark_debt",
		wallet
	)

	assert_eq(
		wallet.credits(),
		BalanceEconomy.STARTING_CREDITS + BalanceEconomy.LOAN_PRINCIPAL,
		"the loan's +400 must land on top of the floor, not instead of it"
	)
	assert_eq(_owed(wallet), BalanceEconomy.LOAN_REPAY_TOTAL, "the 480 is still owed")


## Q1: a floor, not a set. A wallet above STARTING_CREDITS keeps what it has.
func test_confirm_never_subtracts_from_a_wallet_above_the_floor() -> void:
	var wallet: WalletService = _fresh_wallet()
	wallet.set_credits(RICH_WALLET_CREDITS)
	EventBus.on_new_game_requested.emit()
	WorldClock.advance_seconds(CREATION_SCREEN_SECONDS)

	CareerStart.apply_default(wallet)

	assert_eq(wallet.credits(), RICH_WALLET_CREDITS, "the floor may only ever raise the balance")


## The floor is a grant, so the money log must see it (S2 telemetry).
func test_floor_top_up_reports_the_credits_it_granted() -> void:
	var wallet: WalletService = _fresh_wallet()
	wallet.set_credits(0)

	var granted: int = wallet.top_up_to_starting_floor()

	assert_eq(granted, BalanceEconomy.STARTING_CREDITS)
	assert_eq(wallet.credits(), BalanceEconomy.STARTING_CREDITS)
	assert_eq(wallet.top_up_to_starting_floor(), 0, "a second call is a no-op")


## The exemption is not sticky: once the opening beat is dismissed, life support
## bills again exactly as before.
func test_upkeep_resumes_once_the_opening_beat_is_over() -> void:
	var wallet: WalletService = _fresh_wallet()
	EventBus.on_new_game_requested.emit()
	EventBus.on_annexation_continue_requested.emit()

	WorldClock.advance_seconds(RESUMED_SECONDS)

	assert_eq(wallet.credits(), BalanceEconomy.STARTING_CREDITS - _upkeep_for(RESUMED_SECONDS))


## Cancelling out of creation ends the exemption too — otherwise New Game then
## Back would leave life support switched off for the rest of the session.
func test_cancelling_creation_ends_the_exemption() -> void:
	var wallet: WalletService = _fresh_wallet()
	EventBus.on_new_game_requested.emit()
	EventBus.on_life_path_cancel_requested.emit()

	WorldClock.advance_seconds(RESUMED_SECONDS)

	assert_eq(wallet.credits(), BalanceEconomy.STARTING_CREDITS - _upkeep_for(RESUMED_SECONDS))


## Continue loads a career that already exists, so it is never exempt.
func test_continuing_a_saved_career_ends_the_exemption() -> void:
	var wallet: WalletService = _fresh_wallet()
	EventBus.on_new_game_requested.emit()
	EventBus.on_continue_requested.emit()

	WorldClock.advance_seconds(RESUMED_SECONDS)

	assert_eq(wallet.credits(), BalanceEconomy.STARTING_CREDITS - _upkeep_for(RESUMED_SECONDS))


func _fresh_wallet() -> WalletService:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	return wallet


func _count_category(delta_seconds: float) -> void:
	_category_seconds += delta_seconds


func _upkeep_for(seconds: float) -> int:
	return int(floorf(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * seconds))


func _owed(wallet: WalletService) -> int:
	var state: Dictionary = wallet.debt_state()
	var raw: Variant = state[&"owed"]
	if typeof(raw) != TYPE_INT:
		return 0
	var owed: int = raw
	return owed
