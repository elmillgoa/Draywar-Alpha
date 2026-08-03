extends GutTest

## Upkeep via WorldClock (not PlayerShip) — Steam S1.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S1, docs/BETA_E3_ECONOMY.md E3.1

const FRAME_SECONDS: float = 0.25
const FRAME_COUNT: int = 40
const FIXED_SCALED_SECONDS: float = 10.0


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()


func test_upkeep_via_clock_bulk_burns_undocked() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start: int = wallet.credits()
	var expected: int = int(floorf(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * FIXED_SCALED_SECONDS))
	assert_gt(expected, 0)

	WorldClock.advance_seconds(FIXED_SCALED_SECONDS)
	assert_eq(wallet.credits(), start - expected)


func test_upkeep_multi_frame_matches_chunk_via_world_clock() -> void:
	var a: WalletService = WalletService.new()
	var b: WalletService = WalletService.new()
	add_child_autofree(a)
	add_child_autofree(b)
	a.reset()
	b.reset()

	# Only one wallet may sit in the group at a time for clock lookups.
	# Run multi-frame on `a` alone, then chunk on `b` alone.
	b.remove_from_group(&"wallet_service")
	var frame: float = FRAME_SECONDS
	var frames: int = FRAME_COUNT
	var total: float = frame * float(frames)
	for _i: int in frames:
		WorldClock.advance_seconds(frame)
	var multi_credits: int = a.credits()

	a.remove_from_group(&"wallet_service")
	b.add_to_group(&"wallet_service")
	WorldClockHelpers.reset_clock()
	WorldClock.advance_seconds(total)
	var chunk_credits: int = b.credits()

	assert_eq(multi_credits, chunk_credits)


func test_direct_tick_upkeep_still_works() -> void:
	## Existing E3 API remains for unit tests and callers.
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start: int = wallet.credits()
	var spent: int = wallet.tick_upkeep(FIXED_SCALED_SECONDS, false)
	var expected: int = int(floorf(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * FIXED_SCALED_SECONDS))
	assert_eq(spent, expected)
	assert_eq(wallet.credits(), start - expected)


func test_docked_skips_upkeep_via_clock() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start: int = wallet.credits()

	var docking: _FakeDockingDocked = _FakeDockingDocked.new()
	add_child_autofree(docking)

	WorldClock.advance_seconds(FIXED_SCALED_SECONDS)
	assert_eq(wallet.credits(), start, "docked station id must skip upkeep")


func test_player_ship_no_longer_owns_wallet_tick_upkeep() -> void:
	## Regression: ship must not keep a private upkeep heartbeat method.
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	assert_false(
		ship.has_method(&"_wallet_tick_upkeep"),
		"PlayerShip must not call wallet upkeep from physics after S1"
	)


func test_advance_hours_burns_same_accumulators_as_seconds() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start: int = wallet.credits()
	# 1 second of upkeep via hours path (1/3600 hour).
	var hours: float = 1.0 / BalanceWorldClock.SECONDS_PER_HOUR
	WorldClock.advance_hours(hours)
	var expected: int = int(floorf(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * 1.0))
	# At 1.0 credits/s, 1s → 1 credit if rate is whole; floor may be 0 if rate < 1.
	var spent: int = start - wallet.credits()
	assert_eq(spent, expected)


## Minimal docking_service stand-in reporting a docked station.
class _FakeDockingDocked:
	extends Node

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return &"station_alpha_port"
