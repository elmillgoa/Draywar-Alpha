extends GutTest

## Market simulation core — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2, docs/economy_sim.md §4–§9
##
## The maths, not the acceptance criteria: the price curve, the marginal
## ladder, the weight caps, one simulation step, seeding, and the save
## round-trip. §5.6's sector-wide criteria live in their own suite.

const TOLERANCE: float = 0.0001
const PORT: StringName = &"station_alpha_port"
const YARD: StringName = &"station_alpha_yard"
const BETA_HUB: StringName = &"station_beta_hub"
const GAMMA_RIM: StringName = &"station_gamma_rim"
const ZETA_SPUR: StringName = &"station_zeta_spur"
const ORE: StringName = &"commodity_ore"
const MEDICAL: StringName = &"commodity_medical"
const SCRAP: StringName = &"commodity_scrap"
const GRAIN: StringName = &"commodity_grain"

## Stock levels the curve is probed at (deliberately spans both sides of target).
const PROBE_STOCKS: Array[float] = [
	0.0, 0.5, 1.0, 7.0, 40.0, 99.0, 100.0, 101.0, 250.0, 1000.0, 100000.0
]
## A target big enough that fractional stock still reads as a real market.
const PROBE_TARGET: float = 100.0


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()


func test_autoload_is_registered_after_standing_service() -> void:
	var raw: Variant = ProjectSettings.get_setting("autoload/MarketService", "")
	var value: String = str(raw)
	assert_gt(value.length(), 0, "project.godot must declare autoload/MarketService")
	assert_eq(MarketService.get_path(), NodePath("/root/MarketService"))


func test_multiplier_is_exactly_one_at_target() -> void:
	## The constants are chosen symmetric so a station sitting on target quotes
	## the commodity's unmodified base price — not "about" it.
	for target: float in [1.0, 40.0, 100.0, 360.0, 12345.0]:
		var mul: float = MarketPricing.stock_multiplier(target, target)
		assert_eq(mul, 1.0, "mul at stock == target %f" % target)


func test_multiplier_is_max_at_empty_and_never_nan() -> void:
	assert_eq(MarketPricing.stock_multiplier(0.0, PROBE_TARGET), BalanceMarket.MUL_MAX)
	assert_eq(MarketPricing.stock_multiplier(-5.0, PROBE_TARGET), BalanceMarket.MUL_MAX)
	assert_false(is_nan(MarketPricing.stock_multiplier(0.0, PROBE_TARGET)))
	# A pathological target must still answer a finite number, not NaN.
	assert_false(is_nan(MarketPricing.stock_multiplier(0.0, 0.0)))
	assert_false(is_nan(MarketPricing.stock_multiplier(10.0, 0.0)))


func test_multiplier_is_bounded_and_strictly_decreasing() -> void:
	var previous: float = BalanceMarket.MUL_MAX + 1.0
	for level: float in PROBE_STOCKS:
		var mul: float = MarketPricing.stock_multiplier(level, PROBE_TARGET)
		assert_true(is_finite(mul), "mul finite at stock %f" % level)
		assert_lte(mul, BalanceMarket.MUL_MAX, "mul under ceiling at %f" % level)
		assert_gt(mul, BalanceMarket.MUL_MIN, "mul above floor at %f" % level)
		assert_lt(mul, previous, "mul strictly decreasing at %f" % level)
		previous = mul
	# Far above target the curve is pinned near the floor but never reaches it.
	var enormous: float = MarketPricing.stock_multiplier(1.0e9, PROBE_TARGET)
	assert_almost_eq(enormous, BalanceMarket.MUL_MIN, 0.001)
	assert_gt(enormous, BalanceMarket.MUL_MIN)


func test_buy_ladder_prices_each_unit_before_it_leaves_the_shelf() -> void:
	var stock: float = 50.0
	var units: int = 4
	var expected: float = 0.0
	for i: int in units:
		expected += MarketPricing.unit_buy_at(stock - float(i), PROBE_TARGET, 40, 1.0)
	var total: int = MarketPricing.buy_ladder_total(stock, PROBE_TARGET, 40, 1.0, units)
	assert_eq(total, ceili(expected), "buy walks 50, 49, 48, 47 and rounds up")
	assert_eq(MarketPricing.buy_ladder_total(stock, PROBE_TARGET, 40, 1.0, 0), 0)


func test_sell_ladder_prices_each_unit_after_it_lands() -> void:
	var stock: float = 50.0
	var units: int = 4
	var expected: float = 0.0
	for i: int in units:
		expected += MarketPricing.unit_sell_at(stock + float(i + 1), PROBE_TARGET, 28, 1.0)
	var total: int = MarketPricing.sell_ladder_total(stock, PROBE_TARGET, 28, 1.0, units)
	assert_eq(total, floori(expected), "sell walks 51, 52, 53, 54 and rounds down")
	assert_eq(MarketPricing.sell_ladder_total(stock, PROBE_TARGET, 28, 1.0, 0), 0)


func test_ladders_walk_the_same_levels_so_a_round_trip_cannot_profit() -> void:
	## Buying q from s then selling them back into s-q walks exactly the same
	## set of stock levels in the opposite direction. With base_sell below
	## base_buy that is a loss by construction, at every shock level, in both
	## directions — not a tuning accident.
	for shock: float in [0.65, 1.0, 1.35]:
		for stock: float in [12.0, 100.0, 640.0]:
			for units: int in [1, 5, 37]:
				var spent: int = MarketPricing.buy_ladder_total(
					stock, PROBE_TARGET, 40, shock, units
				)
				var earned: int = MarketPricing.sell_ladder_total(
					stock - float(units), PROBE_TARGET, 28, shock, units
				)
				assert_lt(
					earned, spent, "round trip of %d at stock %f, shock %f" % [units, stock, shock]
				)


func test_max_buy_units_honours_the_fraction_and_the_local_floor() -> void:
	# 200 * 0.35 = 70, well above the 10-unit floor gap, so the fraction bites.
	assert_eq(MarketPricing.max_buy_units(200.0, 10.0), 70)
	# Floor bites first: only 4 units sit above it.
	assert_eq(MarketPricing.max_buy_units(200.0, 196.0), 4)
	# Already under the floor: nothing may be taken.
	assert_eq(MarketPricing.max_buy_units(10.0, 40.0), 0)
	# Empty shelf.
	assert_eq(MarketPricing.max_buy_units(0.0, 0.0), 0)
	# A thin shelf offers one unit rather than a buy button that cannot work:
	# floor(2 * 0.35) is 0, and a dead button reads as a bug, not as scarcity.
	assert_eq(MarketPricing.max_buy_units(2.0, 0.0), 1)
	assert_eq(MarketPricing.max_buy_units(1.0, 0.0), 1)
	assert_eq(MarketPricing.max_buy_units(2.9, 0.0), 1)
	# Unless that one unit would take the locals below their floor.
	assert_eq(MarketPricing.max_buy_units(2.0, 1.5), 0)
	assert_eq(MarketPricing.max_buy_units(0.5, 0.0), 0, "half a unit is not a unit")
	# Huge shelf still stops at the per-trade ceiling.
	assert_eq(MarketPricing.max_buy_units(100000.0, 0.0), BalanceMarket.MAX_UNITS_PER_TRADE)


func test_max_sell_units_honours_the_overfill_headroom() -> void:
	assert_eq(MarketPricing.max_sell_units(100.0, 120.0), 20)
	assert_eq(MarketPricing.max_sell_units(120.0, 120.0), 0)
	assert_eq(MarketPricing.max_sell_units(500.0, 120.0), 0)
	assert_eq(MarketPricing.max_sell_units(0.0, 100000.0), BalanceMarket.MAX_UNITS_PER_TRADE)


func test_production_runs_flat_out_until_the_band_and_consumption_needs_stock() -> void:
	## The kill-shot for the structural famine: a producer parked on its freight
	## keep line sits at 1.3/3.0 = 43% of capacity, and must still run at its
	## full nameplate rate. A straight-line taper gave it 0.567 of that for ever.
	var tables: MarketSeed.Tables = _synthetic_tables(4)
	var keep_line: float = 100.0 * BalanceMarket.FLOW_SOURCE_KEEP_FRACTION
	_write_row(tables, 0, 100.0, 2.0, 0.0, keep_line)
	_write_row(tables, 1, 100.0, 2.0, 0.0, 255.0)
	_write_row(tables, 2, 100.0, 2.0, 0.0, 300.0)
	_write_row(tables, 3, 100.0, 0.0, 3.0, 2.0)

	MarketSim.step(tables)

	assert_almost_eq(
		tables.row_stock[0], keep_line + 2.0, TOLERANCE, "keep-line producer runs flat out"
	)
	# 255 of 300 is inside the band: (1 - 0.85) / 0.35 of the nameplate rate.
	var band_taper: float = (1.0 - 255.0 / 300.0) / BalanceMarket.PRODUCTION_TAPER_BAND
	assert_lt(band_taper, 1.0, "255 of 300 really is inside the ramp")
	assert_almost_eq(tables.row_stock[1], 255.0 + 2.0 * band_taper, TOLERANCE)
	assert_almost_eq(tables.row_stock[2], 300.0, TOLERANCE, "nothing is made at capacity")
	# Wanted 3.0, only 2.0 on the shelf: a station cannot eat what is not there.
	assert_almost_eq(tables.row_stock[3], 0.0, TOLERANCE)


func test_step_moves_freight_from_a_surplus_to_a_deficit() -> void:
	var tables: MarketSeed.Tables = _synthetic_tables(2)
	_write_row(tables, 0, 100.0, 0.0, 0.0, 200.0)
	_write_row(tables, 1, 100.0, 0.0, 0.0, 5.0)
	_add_link(tables, 0, 1, BalanceMarket.FLOW_RATE_INTRA_SYSTEM)

	MarketSim.step(tables)

	# surplus = 200 - 130 = 70; deficit = 45 - 5 = 40; 0.10 * 40 = 4.0,
	# which is exactly the per-link per-step ceiling.
	assert_almost_eq(tables.row_stock[0], 196.0, TOLERANCE)
	assert_almost_eq(tables.row_stock[1], 9.0, TOLERANCE)


func test_step_scales_outflows_when_one_source_is_oversubscribed() -> void:
	var tables: MarketSeed.Tables = _synthetic_tables(3)
	_write_row(tables, 0, 10.0, 0.0, 0.0, 18.0)
	_write_row(tables, 1, 100.0, 0.0, 0.0, 0.0)
	_write_row(tables, 2, 100.0, 0.0, 0.0, 0.0)
	# A rate high enough that two destinations together ask for more than the
	# source holds above its keep line.
	_add_link(tables, 0, 1, 0.6)
	_add_link(tables, 0, 2, 0.6)

	MarketSim.step(tables)

	# surplus = 18 - 13 = 5; each link wants 0.6 * 5 = 3.0, total 6.0 > 5.0,
	# so both scale by 5/6 and ship 2.5. The source lands exactly on its keep
	# line and never ships surplus it does not have.
	assert_almost_eq(tables.row_stock[0], 13.0, TOLERANCE)
	assert_almost_eq(tables.row_stock[1], 2.5, TOLERANCE)
	assert_almost_eq(tables.row_stock[2], 2.5, TOLERANCE)


func test_step_clamps_stock_into_the_legal_band() -> void:
	var tables: MarketSeed.Tables = _synthetic_tables(2)
	_write_row(tables, 0, 100.0, 0.0, 0.0, 5000.0)
	_write_row(tables, 1, 100.0, 0.0, 99999.0, 10.0)

	MarketSim.step(tables)

	assert_almost_eq(tables.row_stock[0], 600.0, TOLERANCE, "clamped to hard_max")
	assert_almost_eq(tables.row_stock[1], 0.0, TOLERANCE, "never below zero")


func test_seed_uses_content_factors_capacity_and_hard_max() -> void:
	assert_eq(BalanceMarket.seed_factor_for(true, false), BalanceMarket.SEED_PRODUCER_FACTOR)
	assert_eq(BalanceMarket.seed_factor_for(false, true), BalanceMarket.SEED_CONSUMER_FACTOR)
	assert_eq(BalanceMarket.seed_factor_for(false, false), BalanceMarket.SEED_NEUTRAL_FACTOR)
	assert_eq(BalanceMarket.seed_factor_for(true, true), BalanceMarket.SEED_NEUTRAL_FACTOR)

	# Alpha Port has market_scale 2.0: ore target 180 -> 360, medical 50 -> 100.
	var ore_target: float = MarketService.target_stock(PORT, ORE)
	assert_almost_eq(ore_target, 360.0, TOLERANCE)
	assert_almost_eq(MarketService.capacity_stock(PORT, ORE), 1080.0, TOLERANCE)
	# Consumed here, so it opens drawn down; produced medical opens stocked up.
	assert_almost_eq(
		MarketService.stock_exact(PORT, ORE),
		ore_target * BalanceMarket.SEED_CONSUMER_FACTOR,
		TOLERANCE
	)
	assert_almost_eq(
		MarketService.stock_exact(PORT, MEDICAL),
		MarketService.target_stock(PORT, MEDICAL) * BalanceMarket.SEED_PRODUCER_FACTOR,
		TOLERANCE
	)
	# Nothing may be sold past capacity * SELL_OVERFILL_LIMIT.
	var hard_max: float = BalanceMarket.hard_max_for(ore_target)
	assert_almost_eq(hard_max, 2160.0, TOLERANCE)
	assert_eq(
		MarketService.max_sell_units(PORT, ORE),
		MarketPricing.max_sell_units(MarketService.stock_exact(PORT, ORE), hard_max)
	)


func test_freight_rate_decays_per_gate_and_stops_past_the_hop_limit() -> void:
	## The ladder itself, independent of content: same system fastest, one gate
	## slower, each extra gate decayed, nothing at all past FLOW_MAX_HOPS.
	assert_eq(BalanceMarket.freight_rate_for_hops(0), BalanceMarket.FLOW_RATE_INTRA_SYSTEM)
	assert_eq(BalanceMarket.freight_rate_for_hops(1), BalanceMarket.FLOW_RATE_INTER_SYSTEM)
	var previous: float = BalanceMarket.freight_rate_for_hops(1)
	for hops: int in range(2, BalanceMarket.FLOW_MAX_HOPS + 1):
		var rate: float = BalanceMarket.freight_rate_for_hops(hops)
		assert_gt(rate, 0.0, "%d gates is still served" % hops)
		assert_lt(rate, previous, "%d gates is slower than %d" % [hops, hops - 1])
		assert_almost_eq(rate, previous * BalanceMarket.FLOW_HOP_DECAY, TOLERANCE)
		previous = rate
	assert_eq(BalanceMarket.freight_rate_for_hops(BalanceMarket.FLOW_MAX_HOPS + 1), 0.0)
	# Unreachable (SectorGraph.hop_distance answers -1) is not a link.
	assert_eq(BalanceMarket.freight_rate_for_hops(-1), 0.0)


func test_freight_links_are_precomputed_and_reach_across_the_gate_graph() -> void:
	var tables: MarketSeed.Tables = MarketSeed.build()
	assert_gt(tables.link_rate.size(), 0, "links exist")

	# Two docks in one system: the fast local rate, both ways.
	assert_almost_eq(
		_link_rate(tables, PORT, YARD, SCRAP), BalanceMarket.FLOW_RATE_INTRA_SYSTEM, TOLERANCE
	)
	assert_almost_eq(
		_link_rate(tables, YARD, PORT, SCRAP), BalanceMarket.FLOW_RATE_INTRA_SYSTEM, TOLERANCE
	)
	# One gate away (system_alpha <-> system_beta): the slower rate, both ways.
	assert_almost_eq(
		_link_rate(tables, YARD, BETA_HUB, GRAIN), BalanceMarket.FLOW_RATE_INTER_SYSTEM, TOLERANCE
	)
	assert_almost_eq(
		_link_rate(tables, BETA_HUB, YARD, GRAIN), BalanceMarket.FLOW_RATE_INTER_SYSTEM, TOLERANCE
	)
	# Two gates away (alpha -> beta -> gamma): served, one decay step down.
	assert_almost_eq(
		_link_rate(tables, YARD, GAMMA_RIM, GRAIN),
		BalanceMarket.freight_rate_for_hops(2),
		TOLERANCE
	)
	# Four gates away (alpha -> beta -> gamma -> epsilon -> zeta). Medical is
	# made only at Alpha Port, so without this link the far spur never sees any.
	var far: float = _link_rate(tables, PORT, ZETA_SPUR, MEDICAL)
	assert_almost_eq(far, BalanceMarket.freight_rate_for_hops(4), TOLERANCE)
	assert_gt(far, 0.0, "the far spur is barely served, but it IS served")
	assert_lt(far, BalanceMarket.FLOW_RATE_INTER_SYSTEM, "and it is the slowest run in the sector")
	# A commodity only one of the pair trades is never linked.
	assert_almost_eq(_link_rate(tables, PORT, YARD, GRAIN), 0.0, TOLERANCE)


func test_steps_are_derived_from_the_clock_not_integrated() -> void:
	assert_eq(MarketService.steps_done(), 0)
	WorldClock.advance_seconds(BalanceMarket.STEP_SECONDS - 1.0)
	assert_eq(MarketService.steps_done(), 0, "a part-step is not a step")
	WorldClock.advance_seconds(1.0)
	assert_eq(MarketService.steps_done(), 1)
	WorldClock.advance_seconds(BalanceMarket.STEP_SECONDS * 2.0)
	assert_eq(MarketService.steps_done(), 3)
	# Idempotent: catching up twice with no clock movement changes nothing.
	var before: float = MarketService.stock_exact(PORT, ORE)
	MarketService.catch_up()
	MarketService.catch_up()
	assert_eq(MarketService.steps_done(), 3)
	assert_eq(MarketService.stock_exact(PORT, ORE), before)


func test_away_time_runs_the_identical_arithmetic_to_live_time() -> void:
	## A jump's compressed 8 hours must be the same 32 steps that flying them
	## would have run — identical, not merely close.
	var jump_hours: float = BalanceWorldClock.JUMP_AWAY_HOURS
	var steps: int = int(
		jump_hours * BalanceWorldClock.SECONDS_PER_HOUR / BalanceMarket.STEP_SECONDS
	)
	WorldClock.advance_hours(jump_hours)
	assert_eq(MarketService.steps_done(), steps)
	var compressed: Dictionary[String, float] = _stock_snapshot()

	WorldClockHelpers.reset_clock()
	MarketService.reset()
	for _i: int in steps:
		WorldClock.advance_seconds(BalanceMarket.STEP_SECONDS)
	assert_eq(MarketService.steps_done(), steps)
	var live: Dictionary[String, float] = _stock_snapshot()

	assert_eq(live.size(), compressed.size())
	for key: String in compressed:
		var live_value: float = live[key]
		var compressed_value: float = compressed[key]
		assert_eq(live_value, compressed_value, "away-time differs at %s" % key)


func test_market_ticked_fires_once_per_batch_never_per_step() -> void:
	var probe: _TickProbe = _TickProbe.new()
	probe.listen()
	WorldClock.advance_hours(BalanceWorldClock.HOURS_PER_DAY * 10.0)
	MarketService.catch_up()
	probe.stop()
	assert_eq(probe.batches, 1, "one emit for the whole advance")
	assert_gt(probe.last_steps, 900, "the batch really did run hundreds of steps")
	assert_eq(probe.last_steps, MarketService.steps_done())


func test_quotes_are_pure_and_commits_are_the_only_writers() -> void:
	var before: float = MarketService.stock_exact(PORT, ORE)
	var first: Dictionary = MarketService.quote_buy(PORT, ORE, 12)
	var second: Dictionary = MarketService.quote_buy(PORT, ORE, 12)
	assert_eq(first, second, "quote_buy is a pure function of state")
	assert_eq(MarketService.stock_exact(PORT, ORE), before, "quoting moves nothing")

	var units: int = first[BalanceMarket.QUOTE_KEY_UNITS]
	var total: int = first[BalanceMarket.QUOTE_KEY_TOTAL]
	assert_eq(units, 12)
	assert_gt(total, 0)
	var charged: int = MarketService.commit_buy(PORT, ORE, 12)
	assert_eq(charged, total, "the commit charges what the quote said")
	assert_almost_eq(MarketService.stock_exact(PORT, ORE), before - 12.0, TOLERANCE)

	var refused: Dictionary = MarketService.quote_buy(PORT, GRAIN, 5)
	var refusal: StringName = refused[BalanceMarket.QUOTE_KEY_REASON]
	assert_eq(refusal, BalanceMarket.QUOTE_REASON_NO_MARKET)
	assert_eq(MarketService.commit_buy(PORT, GRAIN, 5), 0)


func test_a_same_station_round_trip_through_the_service_always_loses() -> void:
	for pair: Array in [[PORT, ORE], [PORT, MEDICAL], [YARD, SCRAP]]:
		var station: StringName = pair[0]
		var commodity: StringName = pair[1]
		for units: int in [1, 5, 20]:
			MarketService.reset()
			var spent: int = MarketService.commit_buy(station, commodity, units)
			var earned: int = MarketService.commit_sell(station, commodity, units)
			assert_gt(spent, 0, "%s %s buy priced" % [station, commodity])
			assert_lt(earned, spent, "%s %s round trip of %d" % [station, commodity, units])


func test_a_shock_moves_both_sides_together_and_decays() -> void:
	var target: float = MarketService.target_stock(PORT, ORE)
	var big: int = int(target * BalanceMarket.SHOCK_TRIGGER_FRACTION) + 1
	var plain_buy: int = MarketService.unit_buy_price(PORT, ORE)
	var plain_sell: int = MarketService.unit_sell_price(PORT, ORE)

	MarketService.commit_buy(PORT, ORE, big)
	assert_eq(
		MarketService.price_reason(PORT, ORE),
		BalanceMarket.REASON_SHOCK_STRIP,
		"a heavy buy leaves a mark the dock remembers"
	)
	assert_gt(MarketService.unit_buy_price(PORT, ORE), plain_buy)
	assert_gt(MarketService.unit_sell_price(PORT, ORE), plain_sell)
	# Both sides moved, so the round trip is still a loss under the shock.
	var spent: int = MarketService.commit_buy(PORT, ORE, 5)
	var earned: int = MarketService.commit_sell(PORT, ORE, 5)
	assert_lt(earned, spent, "shocked round trip still loses")

	WorldClock.advance_hours(BalanceMarket.SHOCK_DURATION_HOURS + 1.0)
	assert_ne(
		MarketService.price_reason(PORT, ORE),
		BalanceMarket.REASON_SHOCK_STRIP,
		"shocks expire instead of stacking forever"
	)


func test_save_round_trip_restores_stock_shocks_and_step_count() -> void:
	WorldClock.advance_hours(10.0)
	MarketService.commit_buy(PORT, ORE, 60)
	var expected_steps: int = MarketService.steps_done()
	var expected: Dictionary[String, float] = _stock_snapshot()
	var section: Dictionary = MarketService.to_section()
	assert_true(section.has(BalanceMarket.SAVE_KEY_STEPS))
	assert_true(section.has(BalanceMarket.SAVE_KEY_STOCKS))
	var shock_rows: Array = section[BalanceMarket.SAVE_KEY_SHOCKS]
	assert_gt(shock_rows.size(), 0, "shock persisted")

	WorldClockHelpers.reset_clock()
	MarketService.reset()
	assert_eq(MarketService.steps_done(), 0)
	var saved_ore: float = expected["%s|%s" % [PORT, ORE]]
	assert_ne(MarketService.stock_exact(PORT, ORE), saved_ore)

	WorldClock.advance_hours(10.0)
	MarketService.apply_section(section)
	assert_eq(MarketService.steps_done(), expected_steps)
	var restored: Dictionary[String, float] = _stock_snapshot()
	for key: String in expected:
		var restored_value: float = restored[key]
		var expected_value: float = expected[key]
		assert_eq(restored_value, expected_value, "stock differs at %s" % key)
	assert_eq(MarketService.price_reason(PORT, ORE), BalanceMarket.REASON_SHOCK_STRIP)


func test_apply_section_drops_unknown_ids_and_clamps_what_it_keeps() -> void:
	WorldClock.advance_seconds(BalanceMarket.STEP_SECONDS * 4.0)
	var hard_max: float = BalanceMarket.hard_max_for(MarketService.target_stock(PORT, ORE))
	(
		MarketService
		. apply_section(
			{
				BalanceMarket.SAVE_KEY_STEPS: 999999,
				BalanceMarket.SAVE_KEY_STOCKS:
				{
					"station_does_not_exist": {"commodity_ore": 5.0},
					String(PORT): {"commodity_does_not_exist": 5.0, String(ORE): 1.0e9},
					String(YARD): {String(SCRAP): -50.0},
				},
				BalanceMarket.SAVE_KEY_SHOCKS:
				[
					{
						BalanceMarket.SHOCK_KEY_STATION: "station_does_not_exist",
						BalanceMarket.SHOCK_KEY_COMMODITY: String(ORE),
						BalanceMarket.SHOCK_KEY_KIND: String(BalanceMarket.SHOCK_KIND_STRIP),
						BalanceMarket.SHOCK_KEY_MAGNITUDE: 0.2,
						BalanceMarket.SHOCK_KEY_EXPIRY: 1.0e9,
					}
				],
			}
		)
	)
	assert_eq(MarketService.steps_done(), 4, "restored steps cannot outrun the clock")
	assert_almost_eq(MarketService.stock_exact(PORT, ORE), hard_max, TOLERANCE)
	assert_almost_eq(MarketService.stock_exact(YARD, SCRAP), 0.0, TOLERANCE)
	# Garbage in place of a section leaves a freshly seeded sector, not a crash.
	MarketService.apply_section("not a dictionary")
	assert_eq(MarketService.steps_done(), 4, "a bare re-seed still catches up to the clock")


func test_career_save_gathers_and_applies_the_market_section() -> void:
	WorldClock.advance_hours(6.0)
	MarketService.commit_buy(PORT, ORE, 25)
	var expected: float = MarketService.stock_exact(PORT, ORE)
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceMarket.SAVE_SECTION_KEY), "market always gathered")

	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_almost_eq(MarketService.stock_exact(PORT, ORE), expected, TOLERANCE)

	# A save with no market section re-seeds rather than leaving stale stock.
	CareerSave.apply_meta_sections(get_tree(), {})
	assert_eq(MarketService.steps_done(), 0, "no world clock section means no elapsed time")
	assert_almost_eq(
		MarketService.stock_exact(PORT, ORE),
		MarketService.target_stock(PORT, ORE) * BalanceMarket.SEED_CONSUMER_FACTOR,
		TOLERANCE
	)


func test_commodity_content_forbids_paying_more_than_it_charges() -> void:
	var pump: Commodity = Commodity.new()
	pump.id = &"commodity_pump_probe"
	pump.display_name = "Pump Probe"
	pump.base_buy_price = 10
	pump.base_sell_price = 10
	var problems: PackedStringArray = pump.validation_errors()
	assert_gt(problems.size(), 0, "sell == buy is refused")
	assert_true(", ".join(problems).contains("base_sell_price"), "the complaint names the field")

	pump.base_sell_price = 9
	assert_eq(pump.validation_errors().size(), 0, "sell below buy is fine")

	for id: StringName in ContentLibrary.ids_in(BalanceEconomy.COMMODITY_CONTENT_CATEGORY):
		var commodity: Commodity = ContentLibrary.item(id) as Commodity
		assert_lt(
			commodity.base_sell_price,
			commodity.base_buy_price,
			"%s must not pay more than it charges" % id
		)


func test_reason_lines_and_headline_are_deterministic() -> void:
	var line: String = MarketService.price_reason(PORT, ORE)
	assert_false(line.is_empty())
	assert_eq(line, MarketService.price_reason(PORT, ORE), "the same state reads the same")
	assert_eq(MarketService.price_reason(PORT, GRAIN), BalanceMarket.REASON_NO_MARKET)

	var headline: String = MarketService.news_line()
	assert_false(headline.is_empty())
	assert_eq(headline, MarketService.news_line(), "no RNG in the ticker")

	# Same elapsed time from the same seed reproduces the same headline.
	WorldClock.advance_hours(30.0)
	var after: String = MarketService.news_line()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	WorldClock.advance_hours(30.0)
	assert_eq(MarketService.news_line(), after)


func test_traded_commodity_ids_lists_only_real_markets() -> void:
	var traded: Array[StringName] = MarketService.traded_commodity_ids(PORT)
	assert_gt(traded.size(), 0)
	var station: Station = ContentLibrary.item(PORT) as Station
	assert_eq(traded.size(), station.stock_targets.size())
	for id: StringName in traded:
		assert_true(station.stock_targets.has(id), "%s has a market row" % id)
		assert_true(MarketService.trades(PORT, id))
	assert_false(MarketService.trades(PORT, GRAIN))
	assert_eq(MarketService.traded_commodity_ids(&"station_does_not_exist").size(), 0)


# --- helpers ----------------------------------------------------------------


## A bare Tables with `count` rows, no links, ready to have rows written.
func _synthetic_tables(count: int) -> MarketSeed.Tables:
	var tables: MarketSeed.Tables = MarketSeed.Tables.new()
	for i: int in count:
		tables.row_station.append(0)
		tables.row_commodity.append(i)
		tables.row_target.append(1.0)
		tables.row_capacity.append(1.0)
		tables.row_hard_max.append(1.0)
		tables.row_produce.append(0.0)
		tables.row_consume.append(0.0)
		tables.row_floor.append(0.0)
		tables.row_base_buy.append(1)
		tables.row_base_sell.append(1)
		tables.row_stock.append(0.0)
	tables.clear_shocks()
	tables.scratch_delta.resize(count)
	tables.scratch_surplus.resize(count)
	tables.scratch_deficit.resize(count)
	tables.scratch_outflow.resize(count)
	return tables


## Fill one synthetic row. Capacity and hard_max follow the balance ratios so
## the hand-computed expectations in the tests match the shipped constants.
func _write_row(
	tables: MarketSeed.Tables, row: int, target: float, produce: float, consume: float, stock: float
) -> void:
	tables.row_target[row] = target
	tables.row_capacity[row] = BalanceMarket.capacity_for(target)
	tables.row_hard_max[row] = BalanceMarket.hard_max_for(target)
	tables.row_produce[row] = produce
	tables.row_consume[row] = consume
	tables.row_stock[row] = stock


func _add_link(tables: MarketSeed.Tables, from_row: int, to_row: int, rate: float) -> void:
	tables.link_from.append(from_row)
	tables.link_to.append(to_row)
	tables.link_rate.append(rate)
	tables.scratch_move.resize(tables.link_rate.size())


## Rate of the freight link between two stations for one commodity, or 0.0.
func _link_rate(
	tables: MarketSeed.Tables,
	from_station: StringName,
	to_station: StringName,
	commodity: StringName
) -> float:
	var from_row: int = tables.row_for_ids(from_station, commodity)
	var to_row: int = tables.row_for_ids(to_station, commodity)
	if from_row == MarketSeed.NO_ROW or to_row == MarketSeed.NO_ROW:
		return 0.0
	for link: int in tables.link_rate.size():
		if tables.link_from[link] == from_row and tables.link_to[link] == to_row:
			return tables.link_rate[link]
	return 0.0


## Every live stock in the sector, keyed "station|commodity".
func _stock_snapshot() -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	for station_id: StringName in ContentLibrary.ids_in(BalanceMarket.STATION_CONTENT_CATEGORY):
		for commodity_id: StringName in MarketService.traded_commodity_ids(station_id):
			out["%s|%s" % [station_id, commodity_id]] = MarketService.stock_exact(
				station_id, commodity_id
			)
	return out


## Counts on_market_ticked emissions without leaving a listener behind.
class _TickProbe:
	extends RefCounted

	var batches: int = 0
	var last_steps: int = 0

	func listen() -> void:
		EventBus.on_market_ticked.connect(_on_ticked)

	func stop() -> void:
		if EventBus.on_market_ticked.is_connected(_on_ticked):
			EventBus.on_market_ticked.disconnect(_on_ticked)

	func _on_ticked(steps_applied: int, _elapsed_seconds: float) -> void:
		batches += 1
		last_steps = steps_applied
