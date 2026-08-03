class_name MarketNews
extends RefCounted

## Reason lines and the sector headline — Steam S2.
##
## Implements: docs/economy_sim.md §8 (readability contract)
##
## The captain has to answer "why is this price what it is?" at the dock,
## without a wiki. Every line here is built from real state — stock against
## target, an active shock, what the station makes or eats — never from a
## lookup table of flavour text.
##
## The headline rotates through the sharpest markets in the sector using the
## step counter, not a random number. Two saves that have run the same number
## of steps show the same headline, which is what lets the determinism test
## compare whole sessions.


## One line explaining this market's price, in priority order: an active shock
## beats a shortage or glut, which beats what the station makes or buys in.
static func price_reason(tables: MarketSeed.Tables, row: int, now_seconds: float) -> String:
	if row == MarketSeed.NO_ROW:
		return BalanceMarket.REASON_NO_MARKET

	var shock: StringName = MarketShocks.kind(tables, row, now_seconds)
	if shock == BalanceMarket.SHOCK_KIND_STRIP:
		return BalanceMarket.REASON_SHOCK_STRIP
	if shock == BalanceMarket.SHOCK_KIND_GLUT:
		return BalanceMarket.REASON_SHOCK_GLUT

	var stock: float = tables.row_stock[row]
	var target: float = tables.row_target[row]
	var shown: Array = [floori(stock), roundi(target)]
	if stock < target * BalanceMarket.REASON_SHORTAGE_FRACTION:
		return BalanceMarket.REASON_SHORTAGE_FORMAT % shown
	if stock > target * BalanceMarket.REASON_GLUT_FRACTION:
		return BalanceMarket.REASON_GLUT_FORMAT % shown
	if tables.row_produce[row] > 0.0:
		return BalanceMarket.REASON_PRODUCED_FORMAT % shown
	if tables.row_consume[row] > 0.0:
		return BalanceMarket.REASON_CONSUMED_FORMAT % shown
	return BalanceMarket.REASON_NEUTRAL_FORMAT % shown


## The current sector headline. Picks the markets furthest off target, then
## rotates through them with the step counter so a long session does not stare
## at one line forever. Deterministic: no RNG anywhere.
static func headline(tables: MarketSeed.Tables, steps_done: int) -> String:
	var pool: PackedInt32Array = _sharpest_rows(tables)
	if pool.is_empty():
		return BalanceMarket.NEWS_QUIET
	var pick: int = posmod(steps_done, pool.size())
	return _line_for(tables, pool[pick])


## Rows furthest off target, worst first, capped at NEWS_ROTATION_POOL.
## Selection rather than a sort: ties keep the lower row index, so the answer
## does not depend on a sort's stability.
static func _sharpest_rows(tables: MarketSeed.Tables) -> PackedInt32Array:
	var best_rows: PackedInt32Array = PackedInt32Array()
	var best_scores: PackedFloat64Array = PackedFloat64Array()
	for row: int in tables.row_count():
		var target: float = tables.row_target[row]
		if target <= 0.0:
			continue
		var deviation: float = absf(tables.row_stock[row] - target) / target
		if deviation < BalanceMarket.NEWS_DEVIATION_MIN_FRACTION:
			continue
		_insert_ranked(best_rows, best_scores, row, deviation)
	return best_rows


static func _insert_ranked(
	rows: PackedInt32Array, scores: PackedFloat64Array, row: int, score: float
) -> void:
	var slot: int = rows.size()
	for i: int in rows.size():
		if score > scores[i]:
			slot = i
			break
	if slot >= BalanceMarket.NEWS_ROTATION_POOL:
		return
	rows.insert(slot, row)
	scores.insert(slot, score)
	if rows.size() > BalanceMarket.NEWS_ROTATION_POOL:
		rows.remove_at(rows.size() - 1)
		scores.remove_at(scores.size() - 1)


static func _line_for(tables: MarketSeed.Tables, row: int) -> String:
	var station: String = tables.station_names[tables.row_station[row]]
	var commodity: String = tables.commodity_names[tables.row_commodity[row]]
	var named: Array = [commodity, station]
	if tables.row_stock[row] < tables.row_target[row]:
		return BalanceMarket.NEWS_SHORTAGE_FORMAT % named
	return BalanceMarket.NEWS_GLUT_FORMAT % named
