class_name MarketPricing
extends RefCounted

## Pure price maths for the market sim — Steam S2.
##
## Implements: docs/economy_sim.md §4 (price model), §5 (marginal ladder),
## §6 (player weight caps)
##
## Every function here is static, side-effect free and a pure function of its
## arguments. Nothing in this file reads world state, and nothing in it is
## random: that is what makes the same actions on the same save produce the
## same credits, every run, on every machine.
##
## The one rule the whole economy rests on: the shock multiplier is passed in
## and applied **identically** to the buy and the sell side. Apply it to one
## side only and a shocked station becomes a money pump.


## Price multiplier for a stock level against its price-neutral target.
##
## `t = s^K / (s^K + target^K)`, `mul = MUL_MAX - (MUL_MAX - MUL_MIN) * t`.
## Empty shelf → MUL_MAX; exactly on target → exactly 1.0; drowning in stock →
## MUL_MIN. Strictly decreasing, bounded at both ends, never NaN.
##
## `stock <= 0` is answered before any `pow` runs — `pow(0.0, K)` is a special
## case nobody should have to reason about at a price.
static func stock_multiplier(stock: float, target: float) -> float:
	var span: float = BalanceMarket.MUL_MAX - BalanceMarket.MUL_MIN
	if stock <= 0.0 or target <= 0.0:
		return BalanceMarket.MUL_MAX
	var stock_pow: float = pow(stock, BalanceMarket.PRICE_ELASTICITY)
	var target_pow: float = pow(target, BalanceMarket.PRICE_ELASTICITY)
	var denominator: float = stock_pow + target_pow
	if denominator <= 0.0 or not is_finite(denominator):
		return BalanceMarket.MUL_MAX
	var share: float = stock_pow / denominator
	return BalanceMarket.MUL_MAX - span * share


## What one unit costs the player at an arbitrary stock level (raw credits,
## unrounded and unfloored — the ladder sums these).
static func unit_buy_at(stock: float, target: float, base_buy: int, shock_mul: float) -> float:
	return float(base_buy) * stock_multiplier(stock, target) * shock_mul


## What one unit pays the player at an arbitrary stock level (raw credits).
## Same multiplier, same shock, different base price. That is the whole reason
## a same-station round trip loses.
static func unit_sell_at(stock: float, target: float, base_sell: int, shock_mul: float) -> float:
	return float(base_sell) * stock_multiplier(stock, target) * shock_mul


## Credits charged for buying `units` out of `stock` (docs/economy_sim.md §5).
##
## Each unit is priced at the stock level **before** it is removed, so the walk
## is `stock, stock-1, … stock-units+1` and the price climbs as the shelf
## empties. The total rounds up; individual rungs are never floored, because
## flooring both sides at one credit would let a cheap round trip break even.
static func buy_ladder_total(
	stock: float, target: float, base_buy: int, shock_mul: float, units: int
) -> int:
	if units <= 0:
		return 0
	var raw: float = 0.0
	for i: int in units:
		raw += unit_buy_at(stock - float(i), target, base_buy, shock_mul)
	return ceili(raw)


## Credits paid for selling `units` into `stock` (docs/economy_sim.md §5).
##
## Each unit is priced at the stock level **after** it lands, so the walk is
## `stock+1, stock+2, … stock+units` and the price falls as the shelf fills.
## The total rounds down. Buying q from s and selling them back walks the
## identical set of stock levels in the opposite direction — that is what makes
## the round-trip loss a theorem rather than a tuning accident.
static func sell_ladder_total(
	stock: float, target: float, base_sell: int, shock_mul: float, units: int
) -> int:
	if units <= 0:
		return 0
	var raw: float = 0.0
	for i: int in units:
		raw += unit_sell_at(stock + float(i + 1), target, base_sell, shock_mul)
	return floori(raw)


## The single-unit buy price to show the captain. This is the only place
## PRICE_FLOOR_CREDITS applies: it keeps a displayed price off zero without
## touching the ladder the invariants depend on.
static func display_buy_price(stock: float, target: float, base_buy: int, shock_mul: float) -> int:
	var one: int = buy_ladder_total(stock, target, base_buy, shock_mul, 1)
	return maxi(BalanceMarket.PRICE_FLOOR_CREDITS, one)


## The single-unit sell price to show the captain — priced at `stock + 1`, the
## level the first sold unit actually lands on, so the number on the row is the
## number the player is paid.
static func display_sell_price(
	stock: float, target: float, base_sell: int, shock_mul: float
) -> int:
	var one: int = sell_ladder_total(stock, target, base_sell, shock_mul, 1)
	return maxi(BalanceMarket.PRICE_FLOOR_CREDITS, one)


## Most units the player may buy here in one trade (docs/economy_sim.md §6).
##
## The per-trade ceiling, the per-trade stock fraction, and the local stock
## floor, whichever bites first. `floor_stock` is zero at a station that does
## not consume the good — the "locals eat first" rule only protects a market
## the station actually eats out of.
##
## **One unit is always allowed when there is genuinely one unit to sell**: at
## stock 2 the fraction alone rounds to `floor(2 * 0.35)` = 0 and the trade row
## would show a buy button that can never work, which reads as a bug rather than
## as scarcity. The floor still wins — taking the unit has to leave the station
## at or above it — and below the floor zero is the right answer, with the UI
## saying why (docs/economy_sim.md §6).
##
## Both limits carry BalanceMarket.UNIT_CAP_EPSILON, because whole units are
## being read off a float shelf: without it a shelf holding 125.99999999999999
## of an intended 126 strands its last legal unit for ever.
static func max_buy_units(stock: float, floor_stock: float) -> int:
	var epsilon: float = BalanceMarket.UNIT_CAP_EPSILON
	var by_fraction: float = stock * BalanceMarket.MAX_STOCK_FRACTION_PER_TRADE + epsilon
	var above_floor: float = stock - floor_stock + epsilon
	var allowed: int = floori(minf(by_fraction, above_floor))
	if allowed < 1 and stock >= 1.0 and above_floor >= 1.0:
		allowed = 1
	return maxi(0, mini(BalanceMarket.MAX_UNITS_PER_TRADE, allowed))


## Most units the player may sell here in one trade — the per-trade ceiling or
## the headroom left under the station's overfill limit, whichever is smaller.
static func max_sell_units(stock: float, hard_max: float) -> int:
	var headroom: int = floori(hard_max - stock)
	return maxi(0, mini(BalanceMarket.MAX_UNITS_PER_TRADE, headroom))
