class_name MarketShocks
extends RefCounted

## Temporary price modifiers left behind by player trades — Steam S2.
##
## Implements: docs/economy_sim.md §7 (shocks), §9 (save)
##
## A trade big enough to matter marks the market for a while: `strip` after
## heavy buying (price up), `glut` after a dump (price down). The mark decays
## linearly to nothing over SHOCK_DURATION_HOURS of world-clock time, so a
## shock is a pure function of stored magnitude, stored expiry and the clock —
## no per-frame bookkeeping, and no drift between live play and away-time.
##
## The multiplier is returned once and applied to **both** sides of the trade.
## A shock that touched only the buy price would be a same-station money pump.
##
## Magnitude is stored signed: positive is a strip, negative is a glut. Both are
## clamped to SHOCK_MAGNITUDE_MAX **and** to what this commodity's own buy/sell
## spread can carry (BalanceMarket.shock_magnitude_ceiling), so repeated dumping
## cannot stack a market into free goods and a dump followed by a buy-back can
## never come out ahead.


## Live multiplier for one row. 1.0 when there is no shock or it has expired.
static func multiplier(tables: MarketSeed.Tables, row: int, now_seconds: float) -> float:
	return 1.0 + _remaining_magnitude(tables, row, now_seconds)


## Shock kind currently in force on a row, or empty.
static func kind(tables: MarketSeed.Tables, row: int, now_seconds: float) -> StringName:
	if is_zero_approx(_remaining_magnitude(tables, row, now_seconds)):
		return &""
	return tables.row_shock_kind[row]


## Record a player trade against a row. `units` is what actually moved; a buy
## raises a strip, a sell raises a glut. Small trades leave no mark at all.
## Returns true when a shock was raised or deepened.
static func record_trade(
	tables: MarketSeed.Tables, row: int, units: int, is_buy: bool, now_seconds: float
) -> bool:
	var target: float = tables.row_target[row]
	if units <= 0 or target <= 0.0:
		return false
	var moved_fraction: float = float(units) / target
	if moved_fraction < BalanceMarket.SHOCK_TRIGGER_FRACTION:
		return false

	# The step a trade moves the shock by is capped at the same ceiling the stored
	# magnitude is. Sizing the step off the global maximum and only capping the
	# result leaves an asymmetric residue: the opposite leg of a round trip
	# overshoots, gets clamped, and every further cycle then sells into a standing
	# strip and buys out of a standing glut. Measured before this line existed,
	# ten dump-and-buy-back cycles on Beta Hub fuel cells netted +449 credits with
	# the shelf back at its opening stock.
	var ceiling: float = BalanceMarket.shock_magnitude_ceiling(
		tables.row_base_buy[row], tables.row_base_sell[row]
	)
	if ceiling <= 0.0:
		return false
	var size: float = minf(moved_fraction * BalanceMarket.SHOCK_MAGNITUDE_PER_TARGET, ceiling)
	var signed_size: float = size if is_buy else -size
	var standing: float = _remaining_magnitude(tables, row, now_seconds)
	var combined: float = clampf(standing + signed_size, -ceiling, ceiling)
	_write(tables, row, combined, now_seconds + BalanceMarket.shock_duration_seconds())
	return true


## Clear every shock whose expiry has passed. Called once per catch-up batch.
static func drop_expired(tables: MarketSeed.Tables, now_seconds: float) -> void:
	for row: int in tables.row_count():
		if is_zero_approx(tables.row_shock_magnitude[row]):
			continue
		if tables.row_shock_expiry[row] > now_seconds:
			continue
		_clear(tables, row)


## Active shocks as save rows (docs/economy_sim.md §9). Expired shocks are not
## written; neither is anything non-finite.
static func to_array(tables: MarketSeed.Tables, now_seconds: float) -> Array:
	var out: Array = []
	for row: int in tables.row_count():
		var magnitude: float = tables.row_shock_magnitude[row]
		var expiry: float = tables.row_shock_expiry[row]
		if is_zero_approx(magnitude) or expiry <= now_seconds:
			continue
		if not is_finite(magnitude) or not is_finite(expiry):
			continue
		var station_index: int = tables.row_station[row]
		var commodity_index: int = tables.row_commodity[row]
		(
			out
			. append(
				{
					BalanceMarket.SHOCK_KEY_STATION: String(tables.station_ids[station_index]),
					BalanceMarket.SHOCK_KEY_COMMODITY:
					String(tables.commodity_ids[commodity_index]),
					BalanceMarket.SHOCK_KEY_KIND: String(tables.row_shock_kind[row]),
					BalanceMarket.SHOCK_KEY_MAGNITUDE: magnitude,
					BalanceMarket.SHOCK_KEY_EXPIRY: expiry,
				}
			)
		)
	return out


## Restore shocks from a save array. Unknown ids and already-expired entries
## are dropped rather than repaired.
static func apply_array(tables: MarketSeed.Tables, raw: Variant, now_seconds: float) -> void:
	tables.clear_shocks()
	if typeof(raw) != TYPE_ARRAY:
		return
	var entries: Array = raw
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var fields: Dictionary = entry
		_apply_entry(tables, fields, now_seconds)


static func _apply_entry(tables: MarketSeed.Tables, entry: Dictionary, now_seconds: float) -> void:
	if not entry.has(BalanceMarket.SHOCK_KEY_STATION):
		return
	if not entry.has(BalanceMarket.SHOCK_KEY_COMMODITY):
		return
	var station_id: StringName = StringName(str(entry[BalanceMarket.SHOCK_KEY_STATION]))
	var commodity_id: StringName = StringName(str(entry[BalanceMarket.SHOCK_KEY_COMMODITY]))
	var row: int = tables.row_for_ids(station_id, commodity_id)
	if row == MarketSeed.NO_ROW:
		return
	var magnitude: float = _as_float(entry.get(BalanceMarket.SHOCK_KEY_MAGNITUDE))
	var expiry: float = _as_float(entry.get(BalanceMarket.SHOCK_KEY_EXPIRY))
	if is_zero_approx(magnitude) or expiry <= now_seconds:
		return
	magnitude = clampf(
		magnitude, -BalanceMarket.SHOCK_MAGNITUDE_MAX, BalanceMarket.SHOCK_MAGNITUDE_MAX
	)
	var longest: float = now_seconds + BalanceMarket.shock_duration_seconds()
	_write(tables, row, magnitude, minf(expiry, longest))


## Signed magnitude still in force after linear decay. 0.0 once expired.
static func _remaining_magnitude(tables: MarketSeed.Tables, row: int, now_seconds: float) -> float:
	var magnitude: float = tables.row_shock_magnitude[row]
	if is_zero_approx(magnitude):
		return 0.0
	var duration: float = BalanceMarket.shock_duration_seconds()
	if duration <= 0.0:
		return 0.0
	var left: float = clampf((tables.row_shock_expiry[row] - now_seconds) / duration, 0.0, 1.0)
	return magnitude * left


## The single writer for a row's shock. Every magnitude that reaches storage —
## a fresh trade, a restored save row — is clamped to this commodity's own
## spread ceiling here, so no caller can open the round-trip hole by forgetting
## to (docs/economy_sim.md §7, BalanceMarket.shock_magnitude_ceiling).
static func _write(tables: MarketSeed.Tables, row: int, magnitude: float, expiry: float) -> void:
	if not is_finite(magnitude) or not is_finite(expiry):
		_clear(tables, row)
		return
	var ceiling: float = BalanceMarket.shock_magnitude_ceiling(
		tables.row_base_buy[row], tables.row_base_sell[row]
	)
	var capped: float = clampf(magnitude, -ceiling, ceiling)
	if is_zero_approx(capped):
		_clear(tables, row)
		return
	tables.row_shock_magnitude[row] = capped
	tables.row_shock_expiry[row] = expiry
	if capped > 0.0:
		tables.row_shock_kind[row] = BalanceMarket.SHOCK_KIND_STRIP
	else:
		tables.row_shock_kind[row] = BalanceMarket.SHOCK_KIND_GLUT


static func _clear(tables: MarketSeed.Tables, row: int) -> void:
	tables.row_shock_magnitude[row] = 0.0
	tables.row_shock_expiry[row] = 0.0
	tables.row_shock_kind[row] = &""


static func _as_float(value: Variant) -> float:
	var kind_of: int = typeof(value)
	if kind_of == TYPE_FLOAT:
		var as_float: float = value
		return as_float if is_finite(as_float) else 0.0
	if kind_of == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	return 0.0
