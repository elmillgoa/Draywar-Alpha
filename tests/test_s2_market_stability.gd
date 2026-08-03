extends GutTest

## Phase S2 — the unattended sector: long-run stability and live routes.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2, docs/economy_sim.md §7, §11
##
## Ten thousand market steps with no player in the sector at all, driven the way
## the game drives them — through WorldClock and MarketService, not a private
## loop. Every traded market must finish at or above BAND_MIN_LIVE_FRACTION of
## its target and at or below its capacity, every number must stay finite, and
## every commodity must still have a profitable buy-here/sell-there pair when it
## is over.
##
## **A sector that is stable because everything equalised is a failed sector.**
## Background freight aims at each station's own target and stops at 45% of it,
## so an exporter stays above its target (cheap) and an importer below theirs
## (dear). The route margins are asserted *and printed*, so the shape can be
## eyeballed rather than taken on trust.
##
## The settle is expensive, so it runs once in `before_all` and every test in
## this file reads the same settled sector.

## Steps the unattended sector is run for (docs/economy_sim.md §11).
const SETTLE_STEPS: int = 10000
## Steps timed for the per-step tick budget measurement.
const TIMED_STEPS: int = 1000
const MICROSECONDS_PER_MS: float = 1000.0

## Markets that received nothing at all under one-hop freight, because what
## they eat is made three or four gates away and nothing relays.
const FAR_SPUR: StringName = &"station_zeta_spur"
const FAR_BELT: StringName = &"station_epsilon_belt"
const MEDICAL: StringName = &"commodity_medical"
const LUXURIES: StringName = &"commodity_luxuries"
const GRAIN: StringName = &"commodity_grain"

## Wall-clock milliseconds the shared 10,000-step settle took.
var _settle_ms: float = 0.0


func before_all() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	var hours: float = (
		float(SETTLE_STEPS) * BalanceMarket.STEP_SECONDS / BalanceWorldClock.SECONDS_PER_HOUR
	)
	# The clock's own tick subscriber drives the catch-up, so the advance is the
	# thing to time; the explicit catch_up() after it is a belt-and-braces no-op.
	var started: int = Time.get_ticks_usec()
	WorldClock.advance_hours(hours)
	MarketService.catch_up()
	_settle_ms = float(Time.get_ticks_usec() - started) / MICROSECONDS_PER_MS


func after_all() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()


func test_the_settle_really_ran_ten_thousand_unattended_steps() -> void:
	assert_eq(MarketService.steps_done(), SETTLE_STEPS, "the clock drove every step")
	print(
		(
			"[S2 stability] %d steps through MarketService in %.1f ms (%.4f ms/step)"
			% [SETTLE_STEPS, _settle_ms, _settle_ms / float(SETTLE_STEPS)]
		)
	)


func test_ten_thousand_unattended_steps_hold_the_liveness_band() -> void:
	var worst_fraction: float = INF
	var worst_label: String = ""
	var fullest_fraction: float = -INF
	var fullest_label: String = ""
	var markets: int = 0

	for station_id: StringName in ContentLibrary.ids_in(BalanceMarket.STATION_CONTENT_CATEGORY):
		for commodity_id: StringName in MarketService.traded_commodity_ids(station_id):
			markets += 1
			var label: String = "%s/%s" % [station_id, commodity_id]
			var stock: float = MarketService.stock_exact(station_id, commodity_id)
			var target: float = MarketService.target_stock(station_id, commodity_id)
			var capacity: float = MarketService.capacity_stock(station_id, commodity_id)
			assert_true(is_finite(stock), "%s stock is finite" % label)
			assert_gte(stock, 0.0, "%s stock is never negative" % label)
			assert_gt(target, 0.0, "%s has a real target" % label)
			assert_gt(capacity, 0.0, "%s has a real capacity" % label)

			var live: float = stock / target
			assert_gte(live, BalanceMarket.BAND_MIN_LIVE_FRACTION, _starved(label, live))
			var full: float = stock / capacity
			assert_lte(full, _ceiling(), _ran_away(label, full))

			if live < worst_fraction:
				worst_fraction = live
				worst_label = label
			if full > fullest_fraction:
				fullest_fraction = full
				fullest_label = label

	assert_gt(markets, 0, "the sector has markets to keep alive")
	print(
		(
			"[S2 stability] %d markets | thinnest %.3f x target (%s) | fullest %.3f x capacity (%s)"
			% [markets, worst_fraction, worst_label, fullest_fraction, fullest_label]
		)
	)


func test_freight_reaches_the_systems_that_produce_none_of_what_they_eat() -> void:
	## The kill-shot for the producer-cluster fault. Grain is made only in Delta
	## and medical and luxuries only in Alpha; Zeta is four gates from both and
	## Epsilon three. Under one-hop freight these markets received nothing, ever,
	## and flatlined at exactly zero with no formula anywhere looking wrong.
	for pair: Array in [
		[FAR_SPUR, MEDICAL], [FAR_SPUR, LUXURIES], [FAR_SPUR, GRAIN], [FAR_BELT, LUXURIES]
	]:
		var station_id: StringName = pair[0]
		var commodity_id: StringName = pair[1]
		assert_true(MarketService.trades(station_id, commodity_id), "%s trades it" % station_id)
		var stock: float = MarketService.stock_exact(station_id, commodity_id)
		var target: float = MarketService.target_stock(station_id, commodity_id)
		assert_gt(stock, 0.0, "%s/%s is not dead" % [station_id, commodity_id])
		assert_gte(
			stock / target,
			BalanceMarket.BAND_MIN_LIVE_FRACTION,
			"%s/%s at %.3f x target" % [station_id, commodity_id, stock / target]
		)


func test_every_commodity_still_has_a_profitable_route_after_the_settle() -> void:
	var station_ids: Array[StringName] = ContentLibrary.ids_in(
		BalanceMarket.STATION_CONTENT_CATEGORY
	)
	for commodity_id: StringName in ContentLibrary.ids_in(
		BalanceEconomy.COMMODITY_CONTENT_CATEGORY
	):
		var best_margin: int = 0
		var best_route: String = "none"
		var found: bool = false
		for buy_at: StringName in station_ids:
			if not MarketService.trades(buy_at, commodity_id):
				continue
			var cost: int = MarketService.unit_buy_price(buy_at, commodity_id)
			for sell_at: StringName in station_ids:
				if sell_at == buy_at or not MarketService.trades(sell_at, commodity_id):
					continue
				var paid: int = MarketService.unit_sell_price(sell_at, commodity_id)
				if found and paid - cost <= best_margin:
					continue
				found = true
				best_margin = paid - cost
				best_route = "%s -> %s" % [buy_at, sell_at]
		assert_true(found, "%s is traded in at least two places" % commodity_id)
		assert_gt(
			best_margin, 0, "%s has no profitable route left: %s" % [commodity_id, best_route]
		)
		print(
			(
				"[S2 route] %-24s +%d credits/unit  %s"
				% [String(commodity_id), best_margin, best_route]
			)
		)


func test_one_full_sector_step_stays_inside_the_tick_budget() -> void:
	## Measured on the settled sector, not the transient: the link list is at its
	## full size and every row is doing real arithmetic.
	var tables: MarketSeed.Tables = MarketSeed.build()
	for _warm: int in TIMED_STEPS:
		MarketSim.step(tables)

	var started: int = Time.get_ticks_usec()
	for _step: int in TIMED_STEPS:
		MarketSim.step(tables)
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / MICROSECONDS_PER_MS
	var per_step_ms: float = elapsed_ms / float(TIMED_STEPS)

	print(
		(
			"[S2 perf] %d rows, %d freight links | %.4f ms/step (budget %.2f ms)"
			% [
				tables.row_count(),
				tables.link_rate.size(),
				per_step_ms,
				BalanceMarket.TICK_BUDGET_MS
			]
		)
	)
	assert_lt(
		per_step_ms, BalanceMarket.TICK_BUDGET_MS, "a full sector step took %.4f ms" % per_step_ms
	)


# --- helpers ----------------------------------------------------------------


## Ceiling the unattended steady state is held to: capacity itself, plus the
## floating-point slack 10,000 steps of accumulation earns.
func _ceiling() -> float:
	return BalanceMarket.BAND_MAX_LIVE_FRACTION + BalanceMarket.BAND_CEILING_EPSILON


func _starved(label: String, live: float) -> String:
	return (
		"%s starved to %.4f x target (floor %.2f)"
		% [label, live, BalanceMarket.BAND_MIN_LIVE_FRACTION]
	)


func _ran_away(label: String, full: float) -> String:
	return "%s ran away to %.4f x capacity (ceiling %.2f)" % [label, full, _ceiling()]
