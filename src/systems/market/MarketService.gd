extends Node

## Single writer for station stock, prices and shocks — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2, docs/economy_sim.md §12
##
## Autoload named `MarketService`, deliberately with **no `class_name`**: a bare
## autoload name is the sanctioned way for one system to ask another something
## and get an answer back, and `scripts/check_boundaries.py` would flag a
## `class_name` reference reaching across a system boundary. The helper classes
## beside this file do carry `class_name` — that is one system talking to
## itself, which the boundary rule allows.
##
## Prices come from **stock at a station**, not from a table keyed by system.
## Two docks in one system quote different numbers for the same good, buying
## moves the price as you buy, and production, consumption and background
## freight move it back over world-clock time.
##
## **Steps are derived from the clock, never integrated from deltas.** The
## service asks WorldClock how much time has passed and runs
## `floor(elapsed / STEP_SECONDS)` steps, so a jump's compressed 8 hours run the
## identical 32 steps that flying them live would have run — same order, same
## arithmetic, no separate catch-up code path to get wrong. `catch_up()` also
## runs lazily at the top of every read, quote and commit, so a query is never
## answered from stale state. Both entry points are idempotent.
##
## There is **no randomness anywhere in this system**. Stock is a pure function
## of content, elapsed time and what the player did, which is what makes the
## byte-determinism criterion hold.

## Flattened market state: one row per traded (station, commodity) pair.
var _tables: MarketSeed.Tables = null
## Market steps applied since career start (couples the market to the clock).
var _steps_done: int = 0
## Last headline handed out, so `on_market_news` only fires on a real change.
var _news_line: String = ""
## True while a catch-up batch is running (re-entrancy guard).
var _catching_up: bool = false


func _ready() -> void:
	ServiceRegistry.register_resettable(reset)
	WorldClock.register_category_subscriber(BalanceWorldClock.CATEGORY_MARKET, _on_world_tick)
	_seed_from_content()


## Re-seed every market from station content and put the step counter back to
## zero. Registered with ServiceRegistry, so a new career resets the sector
## without Main knowing this service by name.
func reset() -> void:
	_seed_from_content()


## Run any simulation steps the world clock says are owed. Cheap and idempotent
## when there is nothing to do — one division and a comparison.
func catch_up() -> void:
	if _catching_up or _tables == null:
		return
	var elapsed: float = WorldClock.elapsed_seconds()
	if not is_finite(elapsed) or elapsed <= 0.0:
		return
	var wanted: int = floori(elapsed / BalanceMarket.STEP_SECONDS)
	if wanted <= _steps_done:
		return

	_catching_up = true
	var applied: int = wanted - _steps_done
	while _steps_done < wanted:
		MarketSim.step(_tables)
		_steps_done += 1
	MarketShocks.drop_expired(_tables, elapsed)
	_catching_up = false

	# One emit per batch, never per step: a 10,000-step advance fires once.
	EventBus.on_market_ticked.emit(applied, elapsed)
	_refresh_news()


## Market steps applied since career start.
func steps_done() -> int:
	catch_up()
	return _steps_done


## Whether this station keeps a market in this commodity at all.
func trades(station_id: StringName, commodity_id: StringName) -> bool:
	catch_up()
	return _row(station_id, commodity_id) != MarketSeed.NO_ROW


## Every commodity this station trades, in content id order.
func traded_commodity_ids(station_id: StringName) -> Array[StringName]:
	catch_up()
	var out: Array[StringName] = []
	if _tables == null:
		return out
	var station_index: int = _tables.station_index(station_id)
	if station_index < 0:
		return out
	for commodity_index: int in _tables.commodity_ids.size():
		if _tables.row_for(station_index, commodity_index) != MarketSeed.NO_ROW:
			out.append(_tables.commodity_ids[commodity_index])
	return out


## Whole units on the shelf, rounded down — the number the trade row shows.
func stock(station_id: StringName, commodity_id: StringName) -> int:
	return floori(stock_exact(station_id, commodity_id))


## Exact stock, fractions and all (the simulation's own number).
func stock_exact(station_id: StringName, commodity_id: StringName) -> float:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return 0.0
	return _tables.row_stock[row]


## The price-neutral stock level for this market (already market_scale-weighted).
func target_stock(station_id: StringName, commodity_id: StringName) -> float:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return 0.0
	return _tables.row_target[row]


## Stock at which local production has tapered to nothing.
func capacity_stock(station_id: StringName, commodity_id: StringName) -> float:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return 0.0
	return _tables.row_capacity[row]


## Credits for one unit bought here right now (floored at PRICE_FLOOR_CREDITS).
func unit_buy_price(station_id: StringName, commodity_id: StringName) -> int:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return 0
	return _display_buy(row)


## Credits paid for one unit sold here right now. Priced at the stock level the
## unit lands on, so the number on the row is the number the captain is paid.
func unit_sell_price(station_id: StringName, commodity_id: StringName) -> int:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return 0
	return MarketPricing.display_sell_price(
		_tables.row_stock[row],
		_tables.row_target[row],
		_tables.row_base_sell[row],
		_shock_multiplier(row)
	)


## Most units the player may buy here in one trade (docs/economy_sim.md §6).
func max_buy_units(station_id: StringName, commodity_id: StringName) -> int:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return 0
	return MarketPricing.max_buy_units(_tables.row_stock[row], _tables.row_floor[row])


## Most units the player may sell here in one trade.
func max_sell_units(station_id: StringName, commodity_id: StringName) -> int:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return 0
	return MarketPricing.max_sell_units(_tables.row_stock[row], _tables.row_hard_max[row])


## What buying `units` here would cost. Pure: calling it twice returns the same
## answer and moves nothing. Keys are the BalanceMarket.QUOTE_KEY_* constants.
func quote_buy(station_id: StringName, commodity_id: StringName, units: int) -> Dictionary:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return _quote(0, 0, false, BalanceMarket.QUOTE_REASON_NO_MARKET)
	if units <= 0:
		return _quote(0, 0, false, BalanceMarket.QUOTE_REASON_INVALID)
	var cap: int = MarketPricing.max_buy_units(_tables.row_stock[row], _tables.row_floor[row])
	if cap <= 0:
		return _quote(0, 0, true, BalanceMarket.QUOTE_REASON_NONE_AVAILABLE)
	var granted: int = mini(units, cap)
	var total: int = MarketPricing.buy_ladder_total(
		_tables.row_stock[row],
		_tables.row_target[row],
		_tables.row_base_buy[row],
		_shock_multiplier(row),
		granted
	)
	return _quote(granted, total, granted < units, _reason_for(granted, units))


## What selling `units` here would pay. Pure, same contract as `quote_buy`.
func quote_sell(station_id: StringName, commodity_id: StringName, units: int) -> Dictionary:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return _quote(0, 0, false, BalanceMarket.QUOTE_REASON_NO_MARKET)
	if units <= 0:
		return _quote(0, 0, false, BalanceMarket.QUOTE_REASON_INVALID)
	var cap: int = MarketPricing.max_sell_units(_tables.row_stock[row], _tables.row_hard_max[row])
	if cap <= 0:
		return _quote(0, 0, true, BalanceMarket.QUOTE_REASON_NONE_AVAILABLE)
	var granted: int = mini(units, cap)
	var total: int = MarketPricing.sell_ladder_total(
		_tables.row_stock[row],
		_tables.row_target[row],
		_tables.row_base_sell[row],
		_shock_multiplier(row),
		granted
	)
	return _quote(granted, total, granted < units, _reason_for(granted, units))


## Take `units` off this station's shelf and return the credits owed. The only
## path (with `commit_sell`) that moves stock. Emits `on_market_changed`.
func commit_buy(station_id: StringName, commodity_id: StringName, units: int) -> int:
	var quote: Dictionary = quote_buy(station_id, commodity_id, units)
	var granted: int = quote[BalanceMarket.QUOTE_KEY_UNITS]
	if granted <= 0:
		return 0
	var total: int = quote[BalanceMarket.QUOTE_KEY_TOTAL]
	var row: int = _row(station_id, commodity_id)
	_move_stock(row, -float(granted))
	MarketShocks.record_trade(_tables, row, granted, true, WorldClock.elapsed_seconds())
	_announce(row, station_id, commodity_id)
	return total


## Put `units` on this station's shelf and return the credits paid.
func commit_sell(station_id: StringName, commodity_id: StringName, units: int) -> int:
	var quote: Dictionary = quote_sell(station_id, commodity_id, units)
	var granted: int = quote[BalanceMarket.QUOTE_KEY_UNITS]
	if granted <= 0:
		return 0
	var total: int = quote[BalanceMarket.QUOTE_KEY_TOTAL]
	var row: int = _row(station_id, commodity_id)
	_move_stock(row, float(granted))
	MarketShocks.record_trade(_tables, row, granted, false, WorldClock.elapsed_seconds())
	_announce(row, station_id, commodity_id)
	return total


## One line saying why this price is what it is (docs/economy_sim.md §8).
func price_reason(station_id: StringName, commodity_id: StringName) -> String:
	catch_up()
	var row: int = _row(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return BalanceMarket.REASON_NO_MARKET
	return MarketNews.price_reason(_tables, row, WorldClock.elapsed_seconds())


## The current sector headline for the ticker.
func news_line() -> String:
	catch_up()
	if _news_line.is_empty() and _tables != null:
		_news_line = MarketNews.headline(_tables, _steps_done)
	return _news_line


## Optional `market` save section (docs/economy_sim.md §9). Always gathered.
func to_section() -> Dictionary:
	catch_up()
	var stocks: Dictionary = {}
	if _tables == null:
		return {
			BalanceMarket.SAVE_KEY_STEPS: 0,
			BalanceMarket.SAVE_KEY_STOCKS: stocks,
			BalanceMarket.SAVE_KEY_SHOCKS: [],
		}
	for row: int in _tables.row_count():
		var station_key: String = String(_tables.station_ids[_tables.row_station[row]])
		var commodity_key: String = String(_tables.commodity_ids[_tables.row_commodity[row]])
		if not stocks.has(station_key):
			stocks[station_key] = {}
		var per_station: Dictionary = stocks[station_key]
		per_station[commodity_key] = _finite_stock(row)
	return {
		BalanceMarket.SAVE_KEY_STEPS: _steps_done,
		BalanceMarket.SAVE_KEY_STOCKS: stocks,
		BalanceMarket.SAVE_KEY_SHOCKS: MarketShocks.to_array(_tables, WorldClock.elapsed_seconds()),
	}


## Restore from a save section. Seeds from content first, then overwrites the
## ids it recognises — unknown station or commodity ids are dropped rather than
## repaired, and a restored step count can never be ahead of its own clock.
func apply_section(raw: Variant) -> void:
	_seed_from_content()
	if typeof(raw) != TYPE_DICTIONARY or _tables == null:
		return
	var data: Dictionary = raw
	_steps_done = _restored_steps(data)
	if data.has(BalanceMarket.SAVE_KEY_STOCKS):
		_apply_stocks(data[BalanceMarket.SAVE_KEY_STOCKS])
	if data.has(BalanceMarket.SAVE_KEY_SHOCKS):
		MarketShocks.apply_array(
			_tables, data[BalanceMarket.SAVE_KEY_SHOCKS], WorldClock.elapsed_seconds()
		)


func _seed_from_content() -> void:
	_tables = MarketSeed.build()
	_steps_done = 0
	_news_line = ""


func _on_world_tick(_delta_seconds: float) -> void:
	catch_up()


func _row(station_id: StringName, commodity_id: StringName) -> int:
	if _tables == null:
		return MarketSeed.NO_ROW
	return _tables.row_for_ids(station_id, commodity_id)


func _shock_multiplier(row: int) -> float:
	return MarketShocks.multiplier(_tables, row, WorldClock.elapsed_seconds())


func _display_buy(row: int) -> int:
	return MarketPricing.display_buy_price(
		_tables.row_stock[row],
		_tables.row_target[row],
		_tables.row_base_buy[row],
		_shock_multiplier(row)
	)


func _move_stock(row: int, delta: float) -> void:
	var moved: float = _tables.row_stock[row] + delta
	_tables.row_stock[row] = clampf(moved, 0.0, _tables.row_hard_max[row])


func _announce(row: int, station_id: StringName, commodity_id: StringName) -> void:
	EventBus.on_market_changed.emit(
		station_id, commodity_id, floori(_tables.row_stock[row]), _display_buy(row)
	)
	_refresh_news()


func _refresh_news() -> void:
	if _tables == null:
		return
	var line: String = MarketNews.headline(_tables, _steps_done)
	if line == _news_line:
		return
	_news_line = line
	EventBus.on_market_news.emit(line)


func _quote(units: int, total: int, capped: bool, reason: StringName) -> Dictionary:
	var average: int = 0
	if units > 0:
		average = roundi(float(total) / float(units))
	return {
		BalanceMarket.QUOTE_KEY_UNITS: units,
		BalanceMarket.QUOTE_KEY_TOTAL: total,
		BalanceMarket.QUOTE_KEY_UNIT_AVG: average,
		BalanceMarket.QUOTE_KEY_CAPPED: capped,
		BalanceMarket.QUOTE_KEY_REASON: reason,
	}


func _reason_for(granted: int, asked: int) -> StringName:
	if granted < asked:
		return BalanceMarket.QUOTE_REASON_CAPPED
	return BalanceMarket.QUOTE_REASON_OK


## Stock as a finite, in-band float. The save layer refuses NaN and infinity,
## so nothing that could be either ever reaches it.
func _finite_stock(row: int) -> float:
	var value: float = _tables.row_stock[row]
	if not is_finite(value):
		return 0.0
	return clampf(value, 0.0, _tables.row_hard_max[row])


## Restored step count, never ahead of what the restored clock can justify.
func _restored_steps(data: Dictionary) -> int:
	if not data.has(BalanceMarket.SAVE_KEY_STEPS):
		return 0
	var raw: Variant = data[BalanceMarket.SAVE_KEY_STEPS]
	var saved: int = 0
	if typeof(raw) == TYPE_INT:
		saved = raw
	elif typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		if is_finite(as_float):
			saved = int(as_float)
	var elapsed: float = WorldClock.elapsed_seconds()
	var ceiling: int = 0
	if is_finite(elapsed) and elapsed > 0.0:
		ceiling = floori(elapsed / BalanceMarket.STEP_SECONDS)
	return clampi(saved, 0, ceiling)


func _apply_stocks(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var by_station: Dictionary = raw
	for station_key: Variant in by_station:
		var station_id: StringName = StringName(str(station_key))
		var per_station_raw: Variant = by_station[station_key]
		if typeof(per_station_raw) != TYPE_DICTIONARY:
			continue
		var per_station: Dictionary = per_station_raw
		for commodity_key: Variant in per_station:
			var commodity_id: StringName = StringName(str(commodity_key))
			var row: int = _row(station_id, commodity_id)
			if row == MarketSeed.NO_ROW:
				continue
			_write_restored_stock(row, per_station[commodity_key])


func _write_restored_stock(row: int, raw: Variant) -> void:
	var value: float = 0.0
	var kind_of: int = typeof(raw)
	if kind_of == TYPE_FLOAT:
		var as_float: float = raw
		value = as_float
	elif kind_of == TYPE_INT:
		var as_int: int = raw
		value = float(as_int)
	else:
		return
	if not is_finite(value):
		return
	_tables.row_stock[row] = clampf(value, 0.0, _tables.row_hard_max[row])
