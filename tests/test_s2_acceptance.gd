extends GutTest

## Phase S2 acceptance criteria the rest of the suite leaves open.
##
## Implements: docs/STEAM_PHASE_PLAN.md §5.6, docs/economy_sim.md §7, §9, §11
##
## Four claims nothing else proved. The `market` save section is **byte**
## identical from the same seed and the same actions — the actual
## PackedByteArray a save file would hold, not a dictionary that merely looks
## equal. No sequence of trades at one dock leaves the captain richer than they
## started, in either order, at any stock level, with or without a shock
## running. A hand-corrupted market section cannot crash a load or leave behind
## a stock that is negative, NaN or past the station's ceiling. And a career
## reloaded after a long absence resumes the sim instead of replaying it.

const PORT: StringName = &"station_alpha_port"
const YARD: StringName = &"station_alpha_yard"
const HUB: StringName = &"station_beta_hub"
const ORE: StringName = &"commodity_ore"
const SCRAP: StringName = &"commodity_scrap"
const GRAIN: StringName = &"commodity_grain"
const FUEL_CELLS: StringName = &"commodity_fuel_cells"
const LUXURIES: StringName = &"commodity_luxuries"
const MISSING_STATION: StringName = &"station_does_not_exist"
const MISSING_COMMODITY: StringName = &"commodity_does_not_exist"

const TOLERANCE: float = 0.0001

## Stock levels, as a fraction of target, the money-pump scan is run at:
## a nearly bare shelf, below target, on target, above capacity, and one
## stuffed almost to the overfill ceiling.
const PUMP_STOCK_FRACTIONS: Array[float] = [0.02, 0.5, 1.0, 3.5, 5.9]

## Trade sizes, as a fraction of target. The largest clears
## SHOCK_TRIGGER_FRACTION comfortably, so half the scan runs with a fresh shock.
const PUMP_TRADE_FRACTIONS: Array[float] = [0.02, 0.12, 0.4]

## Stock levels the shocked scan runs at: a bare shelf, on target, and one
## stuffed almost to the overfill ceiling.
const SHOCKED_STOCK_FRACTIONS: Array[float] = [0.02, 1.0, 5.9]

## Hours waited between the two legs of the delayed round trip. The last one is
## past SHOCK_DURATION_HOURS, so the shock the first leg raised has fully gone.
const PUMP_WAIT_HOURS: Array[float] = [0.25, 4.0, 13.0]

## Cycles the repeat scan runs. One cycle can look like a rounding artefact;
## twelve that each end with the shelf where it started cannot.
const PUMP_CYCLES: int = 12

## Hours of unattended sim the price-movement check runs for.
const UNATTENDED_HOURS: float = 120.0

## Least the last unit off a bare shelf must cost against the first one off a
## full one. The curve spans MUL_MIN..MUL_MAX = 0.4..1.6, so 4x is the ceiling;
## 2x leaves room for an honest rebalance without letting the cap go soft.
const STRIP_PRICE_MULTIPLE: float = 2.0


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


# --- Determinism: byte-identical market save section (§5.6) ------------------


func test_the_same_seed_and_the_same_actions_write_identical_market_bytes() -> void:
	## The criterion says *byte* identical, so this compares the bytes a save
	## file would carry — not two dictionaries that print the same. A double
	## that differs in its last bit survives `assert_eq` on a float snapshot and
	## does not survive this.
	_replay_the_same_career()
	var first: PackedByteArray = _market_bytes()
	assert_gt(first.size(), 0, "the market section encodes to real bytes")

	_replay_the_same_career()
	_assert_same_bytes(_market_bytes(), first, "the same seed and the same actions")

	# A third run through a *different* clock path that lands on the same elapsed
	# time: away-time compression must not change a single byte either.
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	_replay_the_same_career_in_small_steps()
	_assert_same_bytes(_market_bytes(), first, "compressed against step-by-step time")


func test_different_actions_write_different_market_bytes() -> void:
	## Guards the test above from being vacuous: if the encoder flattened state
	## away, every run would match and the determinism check would prove nothing.
	_replay_the_same_career()
	var baseline: String = _digest(_market_bytes())

	_replay_the_same_career()
	MarketService.commit_buy(PORT, ORE, 1)
	assert_ne(_digest(_market_bytes()), baseline, "one extra unit bought must move the bytes")

	_replay_the_same_career()
	WorldClock.advance_seconds(BalanceMarket.STEP_SECONDS)
	assert_ne(_digest(_market_bytes()), baseline, "one more sim step must move the bytes")


func test_a_load_then_save_reproduces_the_original_market_bytes() -> void:
	## The round trip the criterion actually protects: what came out of a file
	## has to go back into one unchanged, or two saves of the same career drift.
	_replay_the_same_career()
	var original: PackedByteArray = _market_bytes()
	var section: Dictionary = MarketService.to_section()
	var elapsed: float = WorldClock.elapsed_seconds()

	WorldClockHelpers.reset_clock()
	MarketService.reset()
	WorldClock.advance_seconds(elapsed)
	MarketService.apply_section(section)
	_assert_same_bytes(_market_bytes(), original, "load then save")

	# And again, so a second load off the reloaded state is still stable.
	var reloaded: Dictionary = MarketService.to_section()
	MarketService.apply_section(reloaded)
	_assert_same_bytes(_market_bytes(), original, "a second load off the reloaded state")


func test_a_real_save_file_round_trips_the_market_section_byte_for_byte() -> void:
	## Through the actual writer and reader, not just the encoder: bytes on disk,
	## read back, applied, re-gathered, re-encoded.
	_replay_the_same_career()
	var original: PackedByteArray = _market_bytes()
	var elapsed: float = WorldClock.elapsed_seconds()

	var service: SaveService = SaveService.new()
	var path: String = SaveService.path_for("s2_determinism_probe")
	var written: SaveResult = service.save_to(path, _market_envelope())
	assert_true(written.ok(), "the save must write: %s" % written.summary())
	_assert_same_bytes(written.bytes, original, "the file against the encoder")

	WorldClockHelpers.reset_clock()
	MarketService.reset()
	WorldClock.advance_seconds(elapsed)

	var read_back: SaveResult = service.load_from(path)
	assert_true(read_back.ok(), "the save must load: %s" % read_back.summary())
	var envelope: Dictionary = read_back.envelope
	var sections: Dictionary = envelope[SaveService.KEY_SECTIONS]
	MarketService.apply_section(sections[BalanceMarket.SAVE_SECTION_KEY])
	_assert_same_bytes(_market_bytes(), original, "a real file round trip")
	DirAccess.remove_absolute(path)


# --- No same-station money pump (§5.6) ---------------------------------------


func test_no_money_pump_in_either_direction_at_any_stock_level() -> void:
	## Every market in the sector, from a nearly bare shelf to one stuffed past
	## capacity, at three trade sizes, both orders. A round trip counts as a pump
	## only when the captain ends up with more credits *and* no fewer goods —
	## selling a hold and walking away is trading, not an exploit.
	var worst: int = 0
	var worst_label: String = ""
	var scanned: int = 0
	for row: Array in _every_market():
		var station_id: StringName = row[0]
		var commodity_id: StringName = row[1]
		for stock_fraction: float in PUMP_STOCK_FRACTIONS:
			for trade_fraction: float in PUMP_TRADE_FRACTIONS:
				for sell_first: bool in [true, false]:
					var outcome: Array = _round_trip(
						station_id, commodity_id, stock_fraction, trade_fraction, sell_first, 0.0
					)
					var credits: int = outcome[0]
					var goods: int = outcome[1]
					if goods < 0 or credits <= worst:
						continue
					scanned += 1
					worst = credits
					worst_label = (
						"%s/%s stock %.2fx target, trade %.2fx target, sell_first=%s"
						% [station_id, commodity_id, stock_fraction, trade_fraction, sell_first]
					)
	assert_lte(worst, 0, "a same-station round trip made %d credits: %s" % [worst, worst_label])
	assert_eq(scanned, 0, "no configuration may end richer with the same goods")


func test_no_money_pump_while_a_shock_is_running() -> void:
	## The dangerous case, and the one that was broken. A trade is priced from a
	## quote taken *before* it records its own shock, so the second leg is
	## charged under a modifier the first leg never paid. Both signs are seeded
	## here, at full strength, so the round trip runs entirely inside a shock as
	## well as into one it created itself.
	var worst: int = 0
	var worst_label: String = ""
	for row: Array in _every_market():
		var station_id: StringName = row[0]
		var commodity_id: StringName = row[1]
		for magnitude: float in [
			-BalanceMarket.SHOCK_MAGNITUDE_MAX, BalanceMarket.SHOCK_MAGNITUDE_MAX
		]:
			for stock_fraction: float in SHOCKED_STOCK_FRACTIONS:
				for sell_first: bool in [true, false]:
					var outcome: Array = _round_trip(
						station_id, commodity_id, stock_fraction, 0.4, sell_first, magnitude
					)
					var credits: int = outcome[0]
					var goods: int = outcome[1]
					if goods < 0 or credits <= worst:
						continue
					worst = credits
					worst_label = (
						"%s/%s shock %.2f stock %.2fx sell_first=%s"
						% [station_id, commodity_id, magnitude, stock_fraction, sell_first]
					)
	assert_lte(worst, 0, "a shocked round trip made %d credits: %s" % [worst, worst_label])


func test_no_money_pump_when_the_shock_decays_between_the_two_legs() -> void:
	var worst: int = 0
	var worst_label: String = ""
	for row: Array in _every_market():
		var station_id: StringName = row[0]
		var commodity_id: StringName = row[1]
		for wait_hours: float in PUMP_WAIT_HOURS:
			for sell_first: bool in [true, false]:
				var outcome: Array = _delayed_round_trip(
					station_id, commodity_id, sell_first, wait_hours
				)
				var credits: int = outcome[0]
				var goods: int = outcome[1]
				if goods < 0 or credits <= worst:
					continue
				worst = credits
				worst_label = (
					"%s/%s waited %.2f h sell_first=%s"
					% [station_id, commodity_id, wait_hours, sell_first]
				)
	assert_lte(worst, 0, "a delayed round trip made %d credits: %s" % [worst, worst_label])


func test_repeating_the_cycle_never_turns_a_rounding_edge_into_an_income() -> void:
	## One cycle can be lost in integer rounding. Twelve, each ending with the
	## shelf exactly where it started, cannot be. This is the shape the shipped
	## defect took: Beta Hub fuel cells returned +89 credits a cycle for ever.
	for row: Array in _every_market():
		var station_id: StringName = row[0]
		var commodity_id: StringName = row[1]
		for sell_first: bool in [true, false]:
			MarketService.reset()
			var target: float = MarketService.target_stock(station_id, commodity_id)
			var quantity: int = int(target * 0.45)
			if quantity <= 0:
				continue
			var opening: float = MarketService.stock_exact(station_id, commodity_id)
			var purse: int = 0
			var goods: int = 0
			for _cycle_index: int in PUMP_CYCLES:
				var outcome: Array = _one_cycle(station_id, commodity_id, quantity, sell_first)
				purse += outcome[0]
				goods += outcome[1]
			var closing: float = MarketService.stock_exact(station_id, commodity_id)
			if goods < 0:
				continue
			assert_lte(
				purse,
				0,
				(
					"%d cycles at %s/%s made %d credits (shelf %.3f -> %.3f)"
					% [PUMP_CYCLES, station_id, commodity_id, purse, opening, closing]
				)
			)


func test_a_shock_can_never_cross_the_commoditys_own_buy_sell_spread() -> void:
	## The algebra the whole no-pump result rests on. A glut prices the buy-back
	## at `1 - magnitude`, so the dump only comes out ahead when the magnitude
	## exceeds `1 - base_sell / base_buy`. Capping every shock below that spread
	## makes the loss hold for any content, not for these ten numbers.
	for commodity_id: StringName in ContentLibrary.ids_in(
		BalanceEconomy.COMMODITY_CONTENT_CATEGORY
	):
		var commodity: Commodity = ContentLibrary.item(commodity_id) as Commodity
		var ceiling: float = BalanceMarket.shock_magnitude_ceiling(
			commodity.base_buy_price, commodity.base_sell_price
		)
		assert_gt(ceiling, 0.0, "%s can still carry a shock" % commodity_id)
		assert_lte(
			ceiling, BalanceMarket.SHOCK_MAGNITUDE_MAX, "%s obeys the flat cap" % commodity_id
		)
		assert_lt(
			float(commodity.base_sell_price),
			(1.0 - ceiling) * float(commodity.base_buy_price),
			(
				"a full glut on %s must still leave the buy-back dearer than the dump paid"
				% commodity_id
			)
		)

	# Degenerate content cannot produce a shock at all rather than a wild one.
	assert_eq(BalanceMarket.shock_magnitude_ceiling(0, 0), 0.0)
	assert_eq(BalanceMarket.shock_magnitude_ceiling(10, 10), 0.0)
	assert_eq(BalanceMarket.shock_magnitude_ceiling(10, 12), 0.0)


func test_the_market_never_stores_a_shock_past_that_ceiling() -> void:
	var tables: MarketSeed.Tables = MarketSeed.build()
	var row: int = tables.row_for_ids(HUB, FUEL_CELLS)
	assert_ne(row, MarketSeed.NO_ROW, "the probe row exists")
	var ceiling: float = BalanceMarket.shock_magnitude_ceiling(
		tables.row_base_buy[row], tables.row_base_sell[row]
	)
	assert_lt(ceiling, BalanceMarket.SHOCK_MAGNITUDE_MAX, "fuel cells are the tight commodity")

	# A dump four times the market's target still cannot push past the ceiling.
	var huge: int = int(tables.row_target[row] * 4.0)
	assert_true(MarketShocks.record_trade(tables, row, huge, false, 0.0))
	assert_almost_eq(MarketShocks.multiplier(tables, row, 0.0), 1.0 - ceiling, TOLERANCE)

	# Nor can a save row that claims one.
	(
		MarketShocks
		. apply_array(
			tables,
			[
				{
					BalanceMarket.SHOCK_KEY_STATION: String(HUB),
					BalanceMarket.SHOCK_KEY_COMMODITY: String(FUEL_CELLS),
					BalanceMarket.SHOCK_KEY_KIND: String(BalanceMarket.SHOCK_KIND_GLUT),
					BalanceMarket.SHOCK_KEY_MAGNITUDE: -0.95,
					BalanceMarket.SHOCK_KEY_EXPIRY: 1.0e9,
				}
			],
			0.0
		)
	)
	assert_almost_eq(MarketShocks.multiplier(tables, row, 0.0), 1.0 - ceiling, TOLERANCE)


# --- Corrupt save sections (§5.6 save/load) ----------------------------------


func test_a_corrupt_market_section_never_crashes_or_leaves_a_bad_number() -> void:
	## `apply_section` is public and takes a Variant, so every one of these is
	## reachable from a hand-edited file. None of them may leave a stock that is
	## negative, NaN, past hard_max, or a price of zero — and whatever state they
	## do leave has to be encodable, or the next save is the one that explodes.
	for poison: Variant in _poisoned_sections():
		WorldClockHelpers.reset_clock()
		WorldClock.advance_seconds(BalanceMarket.STEP_SECONDS * 4.0)
		MarketService.apply_section(poison)
		_assert_market_is_sane(str(poison))


func test_every_poisoned_section_still_encodes_into_a_save() -> void:
	for poison: Variant in _poisoned_sections():
		WorldClockHelpers.reset_clock()
		WorldClock.advance_seconds(BalanceMarket.STEP_SECONDS * 4.0)
		MarketService.apply_section(poison)
		var service: SaveService = SaveService.new()
		var result: SaveResult = service.encode_bytes(_market_envelope())
		assert_true(result.ok(), "after %s the save refused: %s" % [str(poison), result.summary()])


func test_a_restored_step_count_can_never_outrun_or_lag_its_own_clock() -> void:
	WorldClock.advance_seconds(BalanceMarket.STEP_SECONDS * 6.0)
	(
		MarketService
		. apply_section(
			{
				BalanceMarket.SAVE_KEY_STEPS: 999999999,
				BalanceMarket.SAVE_KEY_STOCKS: {},
				BalanceMarket.SAVE_KEY_SHOCKS: [],
			}
		)
	)
	assert_eq(MarketService.steps_done(), 6, "a save from the future is pulled back to the clock")

	(
		MarketService
		. apply_section(
			{
				BalanceMarket.SAVE_KEY_STEPS: -50,
				BalanceMarket.SAVE_KEY_STOCKS: {},
				BalanceMarket.SAVE_KEY_SHOCKS: [],
			}
		)
	)
	assert_eq(MarketService.steps_done(), 6, "a negative count catches up rather than going back")


# --- Clock coupling ----------------------------------------------------------


func test_a_load_after_a_long_absence_resumes_the_market_instead_of_replaying_it() -> void:
	## Saving nine hours in and coming back ten days later has to leave the sector
	## exactly where playing straight through would have. Replaying the timeline
	## from the saved stock, or skipping the missing days, both fail here.
	var early_hours: float = 9.0
	var late_hours: float = 240.0

	WorldClock.advance_hours(early_hours)
	MarketService.commit_buy(PORT, ORE, 40)
	var section: Dictionary = MarketService.to_section()
	WorldClock.advance_hours(late_hours - early_hours)
	var expected: Dictionary[String, float] = _stock_snapshot()
	var expected_steps: int = MarketService.steps_done()

	WorldClockHelpers.reset_clock()
	MarketService.reset()
	WorldClock.advance_hours(late_hours)
	MarketService.apply_section(section)

	assert_eq(MarketService.steps_done(), expected_steps, "the sim resumed, it did not restart")
	assert_eq(
		MarketService.steps_done(),
		floori(WorldClock.elapsed_seconds() / BalanceMarket.STEP_SECONDS),
		"the step count still agrees with elapsed time"
	)
	var resumed: Dictionary[String, float] = _stock_snapshot()
	assert_eq(resumed.size(), expected.size())
	for key: String in expected:
		var got: float = resumed[key]
		var want: float = expected[key]
		assert_eq(got, want, "the absence was resumed, not replayed, at %s" % key)


# --- Unattended movement (§5.6 "production/consumption + NPC flow") ----------


func test_unattended_time_moves_prices_and_not_only_stock() -> void:
	## Criterion three names prices, not stock. Nothing here trades: the sector
	## is left alone for five days and the quoted numbers have to move on their
	## own, each in the direction its own shelf went.
	var stock_before: Dictionary[String, float] = _stock_snapshot()
	var price_before: Dictionary[String, int] = _price_snapshot()

	WorldClock.advance_hours(UNATTENDED_HOURS)

	var stock_after: Dictionary[String, float] = _stock_snapshot()
	var price_after: Dictionary[String, int] = _price_snapshot()
	var moved: int = 0
	for key: String in price_before:
		var was_price: int = price_before[key]
		var now_price: int = price_after[key]
		var was_stock: float = stock_before[key]
		var now_stock: float = stock_after[key]
		if now_price != was_price:
			moved += 1
		if absf(now_stock - was_stock) < 1.0:
			continue
		if now_stock > was_stock:
			assert_lte(now_price, was_price, "%s filled up but got dearer" % key)
		else:
			assert_gte(now_price, was_price, "%s drained but got cheaper" % key)
	assert_gt(moved, 0, "no price in the sector moved in %.0f unattended hours" % UNATTENDED_HOURS)
	print("[S2 acceptance] %d of %d markets repriced unattended" % [moved, price_before.size()])


# --- No dead commodities, at boot (§5.6) ------------------------------------


func test_every_commodity_has_a_profitable_route_at_boot() -> void:
	## §5.6's "no dead commodities", measured where a captain actually meets it:
	## the **displayed whole-credit prices** on the trade board of a fresh career,
	## not the decimals underneath them. A row quoting "buy 6" here and "sell 6"
	## there is a dead route however healthy the underlying floats are.
	##
	## This was `pending()` until the seed factors were fixed, because grain and
	## scrap both topped out at a margin of exactly **0** credits a unit. At the
	## old seeds — a producer at 1.8x target (multiplier 0.7370) and a consumer at
	## 0.45x (1.3385) — grain (10/6) was `ceil(10 x 0.7370)` = 8 against
	## `floor(6 x 1.3385)` = 8, and scrap (8/5) was 6 against 6. The seeds are now
	## 2.0 / 0.35 and every commodity clears by at least a credit; see
	## BalanceMarket.SEED_PRODUCER_FACTOR for why the seeds are the safe lever.
	##
	## The whole table prints on every run, pass or fail, the way the settled one
	## does in test_s2_market_stability.gd — a route thinning toward zero should be
	## visible in the log before it becomes a failure.
	var station_ids: Array[StringName] = ContentLibrary.ids_in(
		BalanceMarket.STATION_CONTENT_CATEGORY
	)
	var checked: int = 0
	var paying: int = 0
	var thinnest: int = 0
	var thinnest_label: String = ""
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
		print(
			(
				"[S2 boot route] %-24s %+d cr/unit  %s"
				% [String(commodity_id), best_margin, best_route]
			)
		)
		# The margin itself, not a constant that would move with it (traps #20).
		assert_gt(
			best_margin,
			0,
			"%s has no profitable route at boot (best %s)" % [commodity_id, best_route]
		)
		if checked == 0 or best_margin < thinnest:
			thinnest = best_margin
			thinnest_label = String(commodity_id)
		if best_margin > 0:
			paying += 1
		checked += 1

	assert_gt(checked, 0, "the commodity library is not empty")
	print(
		(
			"[S2 boot route] %d of %d commodities pay at boot | thinnest %+d cr/unit (%s)"
			% [paying, checked, thinnest, thinnest_label]
		)
	)


# --- Weight caps -------------------------------------------------------------


func test_repeated_maximum_buys_stop_at_the_local_floor_on_a_consumed_good() -> void:
	## The cap is per trade, so clicking again is always allowed. What stops the
	## shelf going to nothing is the floor, and it only exists where the station
	## eats the good itself (docs/economy_sim.md §6).
	var target: float = MarketService.target_stock(PORT, ORE)
	var clicks: int = _drain(PORT, ORE)
	var left: float = MarketService.stock_exact(PORT, ORE)
	assert_gt(clicks, 1, "the shelf took more than one trade to empty")
	# Asserted as a real quantity first. Comparing only against the constant
	# would let the constant go to zero and still read green — the floor would be
	# gone and the test would agree with it.
	assert_gt(left, 0.0, "a good the station eats is never bought down to nothing")
	assert_gt(BalanceMarket.STOCK_FLOOR_FRACTION, 0.0, "the locals-eat-first floor still exists")
	assert_almost_eq(
		left, target * BalanceMarket.STOCK_FLOOR_FRACTION, TOLERANCE, "the locals still eat"
	)
	assert_eq(MarketService.max_buy_units(PORT, ORE), 0, "and the next click is refused")


func test_a_shelf_the_station_does_not_eat_can_be_emptied_but_never_cheaply() -> void:
	## Honest report of what the caps actually do: a good the station only makes
	## has no floor, so enough clicks do take it to zero. The defence is the
	## price, and this pins how hard it has to bite.
	var first_price: int = MarketService.unit_buy_price(PORT, LUXURIES)
	var clicks: int = _drain(PORT, LUXURIES)
	assert_almost_eq(MarketService.stock_exact(PORT, LUXURIES), 0.0, TOLERANCE)
	var last_price: int = MarketService.unit_buy_price(PORT, LUXURIES)
	assert_gte(
		float(last_price),
		float(first_price) * STRIP_PRICE_MULTIPLE,
		"stripping the shelf must cost at least %.1fx the opening price" % STRIP_PRICE_MULTIPLE
	)
	print(
		(
			"[S2 acceptance] %s/%s emptied in %d trades, %d cr -> %d cr a unit"
			% [PORT, LUXURIES, clicks, first_price, last_price]
		)
	)


# --- helpers ----------------------------------------------------------------


## Every live (station, commodity) market in the sector, as [station, commodity].
func _every_market() -> Array:
	var out: Array = []
	for station_id: StringName in ContentLibrary.ids_in(BalanceMarket.STATION_CONTENT_CATEGORY):
		for commodity_id: StringName in MarketService.traded_commodity_ids(station_id):
			out.append([station_id, commodity_id])
	return out


## A save envelope carrying only the market section.
func _market_envelope() -> Dictionary:
	return SaveService.envelope({BalanceMarket.SAVE_SECTION_KEY: MarketService.to_section()})


## Two byte arrays are the same run of bytes.
##
## Asserted through a SHA-256 digest rather than by handing the arrays to
## `assert_eq`: the section is about twenty kilobytes, and GUT prints both sides
## of a failed comparison, so a real failure would arrive as forty kilobytes of
## decimal byte values with the one that differs somewhere inside it. The length
## is checked separately so the common failure names itself in one line.
func _assert_same_bytes(got: PackedByteArray, want: PackedByteArray, what: String) -> void:
	assert_eq(got.size(), want.size(), "%s: the encoded section changed length" % what)
	assert_eq(_digest(got), _digest(want), "%s: the market bytes are not identical" % what)


## SHA-256 of a byte run, as hex.
func _digest(bytes: PackedByteArray) -> String:
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


## The exact bytes a save file would hold for the market as it stands.
func _market_bytes() -> PackedByteArray:
	var service: SaveService = SaveService.new()
	var result: SaveResult = service.encode_bytes(_market_envelope())
	assert_true(result.ok(), "the market section must encode: %s" % result.summary())
	return result.bytes


## The fixed career both determinism runs replay: elapsed time, a heavy buy that
## raises a shock, a dump at another dock, and a trade the caps will trim.
func _replay_the_same_career() -> void:
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	WorldClock.advance_hours(7.0)
	MarketService.commit_buy(PORT, ORE, 40)
	WorldClock.advance_hours(1.5)
	MarketService.commit_sell(YARD, SCRAP, 30)
	WorldClock.advance_hours(0.25)
	MarketService.commit_buy(HUB, FUEL_CELLS, 61)
	MarketService.commit_sell(HUB, GRAIN, 12)
	MarketService.commit_buy(PORT, LUXURIES, 999999)
	WorldClock.advance_hours(3.0)


## The same career again, with the waits walked one step at a time instead of
## compressed. Same elapsed time, same order, different clock path.
func _replay_the_same_career_in_small_steps() -> void:
	_advance_in_steps(7.0)
	MarketService.commit_buy(PORT, ORE, 40)
	_advance_in_steps(1.5)
	MarketService.commit_sell(YARD, SCRAP, 30)
	_advance_in_steps(0.25)
	MarketService.commit_buy(HUB, FUEL_CELLS, 61)
	MarketService.commit_sell(HUB, GRAIN, 12)
	MarketService.commit_buy(PORT, LUXURIES, 999999)
	_advance_in_steps(3.0)


func _advance_in_steps(hours: float) -> void:
	var seconds: float = hours * BalanceWorldClock.SECONDS_PER_HOUR
	var whole: int = floori(seconds / BalanceMarket.STEP_SECONDS)
	for _i: int in whole:
		WorldClock.advance_seconds(BalanceMarket.STEP_SECONDS)
	var remainder: float = seconds - float(whole) * BalanceMarket.STEP_SECONDS
	if remainder > 0.0:
		WorldClock.advance_seconds(remainder)


## Put one market at `stock_fraction` of its target with an optional shock in
## force, then run a same-station round trip. Returns
## [credits gained, units the captain still holds].
func _round_trip(
	station_id: StringName,
	commodity_id: StringName,
	stock_fraction: float,
	trade_fraction: float,
	sell_first: bool,
	shock_magnitude: float
) -> Array:
	_place(station_id, commodity_id, stock_fraction, shock_magnitude)
	var target: float = MarketService.target_stock(station_id, commodity_id)
	var quantity: int = int(target * trade_fraction)
	if quantity <= 0:
		return [0, 0]
	return _one_cycle(station_id, commodity_id, quantity, sell_first)


## A round trip with world-clock time running between the two legs.
func _delayed_round_trip(
	station_id: StringName, commodity_id: StringName, sell_first: bool, wait_hours: float
) -> Array:
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	var target: float = MarketService.target_stock(station_id, commodity_id)
	var quantity: int = int(target * 0.4)
	if quantity <= 0:
		return [0, 0]
	var first: Array = _leg(station_id, commodity_id, quantity, sell_first)
	WorldClock.advance_hours(wait_hours)
	var second: Array = _leg(station_id, commodity_id, quantity, not sell_first)
	return [first[0] + second[0], first[1] + second[1]]


## One sell-then-buy (or buy-then-sell) pair at the quantity the caps allow.
func _one_cycle(
	station_id: StringName, commodity_id: StringName, quantity: int, sell_first: bool
) -> Array:
	var first: Array = _leg(station_id, commodity_id, quantity, sell_first)
	var second: Array = _leg(station_id, commodity_id, quantity, not sell_first)
	return [first[0] + second[0], first[1] + second[1]]


## One leg of a round trip. Returns [credits gained, units gained].
func _leg(station_id: StringName, commodity_id: StringName, quantity: int, selling: bool) -> Array:
	if selling:
		var sell_cap: int = mini(quantity, MarketService.max_sell_units(station_id, commodity_id))
		if sell_cap <= 0:
			return [0, 0]
		return [MarketService.commit_sell(station_id, commodity_id, sell_cap), -sell_cap]
	var buy_cap: int = mini(quantity, MarketService.max_buy_units(station_id, commodity_id))
	if buy_cap <= 0:
		return [0, 0]
	return [-MarketService.commit_buy(station_id, commodity_id, buy_cap), buy_cap]


## Re-seed the sector, then set one market's stock and shock by hand through the
## save path — the same door a loaded career comes through.
func _place(
	station_id: StringName, commodity_id: StringName, stock_fraction: float, shock_magnitude: float
) -> void:
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	var target: float = MarketService.target_stock(station_id, commodity_id)
	var shocks: Array = []
	if not is_zero_approx(shock_magnitude):
		(
			shocks
			. append(
				{
					BalanceMarket.SHOCK_KEY_STATION: String(station_id),
					BalanceMarket.SHOCK_KEY_COMMODITY: String(commodity_id),
					BalanceMarket.SHOCK_KEY_KIND: String(BalanceMarket.SHOCK_KIND_STRIP),
					BalanceMarket.SHOCK_KEY_MAGNITUDE: shock_magnitude,
					BalanceMarket.SHOCK_KEY_EXPIRY: BalanceMarket.shock_duration_seconds(),
				}
			)
		)
	(
		MarketService
		. apply_section(
			{
				BalanceMarket.SAVE_KEY_STEPS: 0,
				BalanceMarket.SAVE_KEY_STOCKS:
				{String(station_id): {String(commodity_id): target * stock_fraction}},
				BalanceMarket.SAVE_KEY_SHOCKS: shocks,
			}
		)
	)


## Buy the most this station will release, over and over, until it refuses.
## Returns how many trades that took.
func _drain(station_id: StringName, commodity_id: StringName) -> int:
	var clicks: int = 0
	while clicks < 5000:
		var cap: int = MarketService.max_buy_units(station_id, commodity_id)
		if cap <= 0:
			break
		MarketService.commit_buy(station_id, commodity_id, cap)
		clicks += 1
	return clicks


## Every shape of damaged `market` section a hand-edited save could hold.
func _poisoned_sections() -> Array:
	var station: String = String(PORT)
	var commodity: String = String(ORE)
	return [
		null,
		{},
		[],
		"not a section",
		42,
		{BalanceMarket.SAVE_KEY_STEPS: "later"},
		{BalanceMarket.SAVE_KEY_STEPS: NAN},
		{BalanceMarket.SAVE_KEY_STEPS: INF},
		{BalanceMarket.SAVE_KEY_STOCKS: "no"},
		{BalanceMarket.SAVE_KEY_STOCKS: []},
		{BalanceMarket.SAVE_KEY_STOCKS: {station: "no"}},
		{BalanceMarket.SAVE_KEY_STOCKS: {station: {commodity: NAN}}},
		{BalanceMarket.SAVE_KEY_STOCKS: {station: {commodity: INF}}},
		{BalanceMarket.SAVE_KEY_STOCKS: {station: {commodity: -INF}}},
		{BalanceMarket.SAVE_KEY_STOCKS: {station: {commodity: -5000.0}}},
		{BalanceMarket.SAVE_KEY_STOCKS: {station: {commodity: 1.0e300}}},
		{BalanceMarket.SAVE_KEY_STOCKS: {station: {commodity: "lots"}}},
		{BalanceMarket.SAVE_KEY_STOCKS: {station: {commodity: null}}},
		{BalanceMarket.SAVE_KEY_STOCKS: {String(MISSING_STATION): {commodity: 5.0}}},
		{BalanceMarket.SAVE_KEY_STOCKS: {station: {String(MISSING_COMMODITY): 5.0}}},
		{BalanceMarket.SAVE_KEY_SHOCKS: "no"},
		{BalanceMarket.SAVE_KEY_SHOCKS: {}},
		{BalanceMarket.SAVE_KEY_SHOCKS: [null, 5, {}, {BalanceMarket.SHOCK_KEY_STATION: station}]},
		{
			BalanceMarket.SAVE_KEY_SHOCKS:
			[
				{
					BalanceMarket.SHOCK_KEY_STATION: station,
					BalanceMarket.SHOCK_KEY_COMMODITY: commodity,
					BalanceMarket.SHOCK_KEY_KIND: "nonsense",
					BalanceMarket.SHOCK_KEY_MAGNITUDE: NAN,
					BalanceMarket.SHOCK_KEY_EXPIRY: INF,
				}
			]
		},
		{
			BalanceMarket.SAVE_KEY_SHOCKS:
			[
				{
					BalanceMarket.SHOCK_KEY_STATION: station,
					BalanceMarket.SHOCK_KEY_COMMODITY: commodity,
					BalanceMarket.SHOCK_KEY_KIND: String(BalanceMarket.SHOCK_KIND_GLUT),
					BalanceMarket.SHOCK_KEY_MAGNITUDE: -99.0,
					BalanceMarket.SHOCK_KEY_EXPIRY: 1.0e18,
				}
			]
		},
	]


## Every market in the sector holds a number a price can be built from.
func _assert_market_is_sane(what: String) -> void:
	assert_gte(MarketService.steps_done(), 0, "%s left a negative step count" % what)
	assert_lte(
		MarketService.steps_done(),
		floori(WorldClock.elapsed_seconds() / BalanceMarket.STEP_SECONDS),
		"%s left the step count ahead of the clock" % what
	)
	for row: Array in _every_market():
		var station_id: StringName = row[0]
		var commodity_id: StringName = row[1]
		var label: String = "%s after %s" % [station_id, what]
		var stock: float = MarketService.stock_exact(station_id, commodity_id)
		assert_true(is_finite(stock), "%s: stock is not finite" % label)
		assert_gte(stock, 0.0, "%s: stock went negative" % label)
		assert_lte(
			stock,
			BalanceMarket.hard_max_for(MarketService.target_stock(station_id, commodity_id)),
			"%s: stock passed the ceiling" % label
		)
		var buy: int = MarketService.unit_buy_price(station_id, commodity_id)
		var sell: int = MarketService.unit_sell_price(station_id, commodity_id)
		assert_gte(buy, BalanceMarket.PRICE_FLOOR_CREDITS, "%s: buy price fell to zero" % label)
		assert_gte(sell, BalanceMarket.PRICE_FLOOR_CREDITS, "%s: sell price fell to zero" % label)
		assert_lte(sell, buy, "%s: the dock paid more than it charged" % label)


## Every live stock in the sector, keyed "station|commodity".
func _stock_snapshot() -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	for row: Array in _every_market():
		var station_id: StringName = row[0]
		var commodity_id: StringName = row[1]
		out["%s|%s" % [station_id, commodity_id]] = MarketService.stock_exact(
			station_id, commodity_id
		)
	return out


## Every quoted unit buy price in the sector, keyed the same way.
func _price_snapshot() -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	for row: Array in _every_market():
		var station_id: StringName = row[0]
		var commodity_id: StringName = row[1]
		out["%s|%s" % [station_id, commodity_id]] = MarketService.unit_buy_price(
			station_id, commodity_id
		)
	return out
