class_name CargoTrade
extends RefCounted

## Market-facing half of CargoService — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2, docs/economy_sim.md §5–§6, §12
##
## Same system as CargoService (both live under `src/systems/cargo/`), split out
## only so the service stays inside the file-length gate. Everything here is
## static and side-effect free: it reads quotes, never commits.
##
## MarketService is reached by **bare autoload name**. That is the sanctioned
## way for one system to ask another something and get an answer back — it has
## no `class_name`, so nothing here is a static cross-system reference.
##
## The reason a "max affordable" search exists at all is the marginal ladder
## (docs/economy_sim.md §5): a trade of q units is not q × the unit price, so
## `credits / unit_price` is the wrong answer and gets more wrong the bigger the
## trade. The only honest way to find the largest affordable quantity is to ask
## the market what quantities actually cost.


## Units a quote actually covers, after the station's own weight caps.
static func quote_units(quote: Dictionary) -> int:
	return _quote_int(quote, BalanceMarket.QUOTE_KEY_UNITS)


## Whole credits for a whole quote (buy rounds up, sell rounds down).
static func quote_total(quote: Dictionary) -> int:
	return _quote_int(quote, BalanceMarket.QUOTE_KEY_TOTAL)


## Rounded credits per unit across a quote — the telemetry log's unit price.
static func quote_unit_avg(quote: Dictionary) -> int:
	return _quote_int(quote, BalanceMarket.QUOTE_KEY_UNIT_AVG)


## Largest quantity up to `ceiling` whose buy quote fits inside `credits`.
##
## Binary search rather than division, because the ladder makes each extra unit
## dearer than the last. `ceiling` is already the market-and-hold cap, so the
## answer is the wallet's own limit and nothing else.
static func affordable_units(
	station_id: StringName, commodity_id: StringName, credits: int, ceiling: int
) -> int:
	if ceiling <= 0 or credits <= 0:
		return 0
	if _buy_total(station_id, commodity_id, ceiling) <= credits:
		return ceiling
	var low: int = 0
	var high: int = ceiling
	while low < high:
		# Halve the remaining span, rounding up so the loop always advances.
		var middle: int = low + ((high - low + 1) >> 1)
		if _buy_total(station_id, commodity_id, middle) <= credits:
			low = middle
		else:
			high = middle - 1
	return low


## Everything one station trade row displays, plus the caps that decide what its
## buttons may do (docs/economy_sim.md §8). `fit_units` is how many units still
## fit in the hold; `held` is how many are already aboard.
static func row(
	station_id: StringName, commodity_id: StringName, held: int, fit_units: int, credits: int
) -> Dictionary:
	if String(station_id).is_empty() or not MarketService.trades(station_id, commodity_id):
		return _dead_row(station_id, commodity_id)
	var buy_cap: int = MarketService.max_buy_units(station_id, commodity_id)
	var ceiling: int = mini(buy_cap, maxi(0, fit_units))
	var max_buy: int = affordable_units(station_id, commodity_id, credits, ceiling)
	var sell_cap: int = MarketService.max_sell_units(station_id, commodity_id)
	var max_sell: int = mini(sell_cap, maxi(0, held))
	return {
		BalanceEconomy.TRADE_ROW_KEY_TRADED: true,
		BalanceEconomy.TRADE_ROW_KEY_STOCK: MarketService.stock(station_id, commodity_id),
		BalanceEconomy.TRADE_ROW_KEY_UNIT_BUY:
		MarketService.unit_buy_price(station_id, commodity_id),
		BalanceEconomy.TRADE_ROW_KEY_UNIT_SELL:
		MarketService.unit_sell_price(station_id, commodity_id),
		BalanceEconomy.TRADE_ROW_KEY_REASON: MarketService.price_reason(station_id, commodity_id),
		BalanceEconomy.TRADE_ROW_KEY_MAX_BUY: max_buy,
		BalanceEconomy.TRADE_ROW_KEY_MAX_SELL: max_sell,
		BalanceEconomy.TRADE_ROW_KEY_BUY_LIMIT: _buy_limit(max_buy, ceiling, fit_units, buy_cap),
		BalanceEconomy.TRADE_ROW_KEY_SELL_LIMIT: _sell_limit(held, sell_cap),
	}


## Detail fields the money-event telemetry row carries for a trade
## (docs/economy_sim.md §10).
static func money_detail(
	commodity_id: StringName,
	units: int,
	unit_price: int,
	station_id: StringName,
	system_id: StringName
) -> Dictionary:
	return {
		BalanceTelemetry.DETAIL_KEY_COMMODITY_ID: commodity_id,
		BalanceTelemetry.DETAIL_KEY_UNITS: units,
		BalanceTelemetry.DETAIL_KEY_UNIT_PRICE: unit_price,
		BalanceTelemetry.DETAIL_KEY_STATION_ID: station_id,
		BalanceTelemetry.DETAIL_KEY_SYSTEM_ID: system_id,
	}


## The row for a good this dock keeps no market in: readable, never tradable.
static func _dead_row(station_id: StringName, commodity_id: StringName) -> Dictionary:
	var line: String = BalanceMarket.REASON_NO_MARKET
	if not String(station_id).is_empty():
		line = MarketService.price_reason(station_id, commodity_id)
	return {
		BalanceEconomy.TRADE_ROW_KEY_TRADED: false,
		BalanceEconomy.TRADE_ROW_KEY_STOCK: 0,
		BalanceEconomy.TRADE_ROW_KEY_UNIT_BUY: 0,
		BalanceEconomy.TRADE_ROW_KEY_UNIT_SELL: 0,
		BalanceEconomy.TRADE_ROW_KEY_REASON: line,
		BalanceEconomy.TRADE_ROW_KEY_MAX_BUY: 0,
		BalanceEconomy.TRADE_ROW_KEY_MAX_SELL: 0,
		BalanceEconomy.TRADE_ROW_KEY_BUY_LIMIT: BalanceEconomy.TRADE_LIMIT_MARKET,
		BalanceEconomy.TRADE_ROW_KEY_SELL_LIMIT: BalanceEconomy.TRADE_LIMIT_MARKET,
	}


## Which of the three limits actually bit, tightest first. "The shelf only has
## 14" and "you cannot carry more" are different sentences and the captain is
## owed the right one.
static func _buy_limit(max_buy: int, ceiling: int, fit_units: int, buy_cap: int) -> StringName:
	if max_buy < ceiling:
		return BalanceEconomy.TRADE_LIMIT_CREDITS
	if fit_units < buy_cap:
		return BalanceEconomy.TRADE_LIMIT_HOLD
	return BalanceEconomy.TRADE_LIMIT_MARKET


static func _sell_limit(held: int, sell_cap: int) -> StringName:
	if held < sell_cap:
		return BalanceEconomy.TRADE_LIMIT_HOLD
	return BalanceEconomy.TRADE_LIMIT_MARKET


static func _buy_total(station_id: StringName, commodity_id: StringName, units: int) -> int:
	return quote_total(MarketService.quote_buy(station_id, commodity_id, units))


## A Dictionary value cannot be handed straight to arithmetic or an assert under
## this project's warning settings (docs/traps.md #17) — it lands in a typed
## local here, once, so no caller has to remember.
static func _quote_int(quote: Dictionary, key: StringName) -> int:
	if not quote.has(key):
		return 0
	var raw: Variant = quote[key]
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return int(as_float)
	return 0
