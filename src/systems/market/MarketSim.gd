class_name MarketSim
extends RefCounted

## One market simulation step — Steam S2.
##
## Implements: docs/economy_sim.md §7 (the tick)
##
## Production, consumption and background freight for the whole sector, once.
## The step is a pure function of the stock it starts with: every delta is
## computed from the stock levels as they were **before** anything moved, and
## only written back at the end. Nothing here reads a clock, a random number or
## a content file, so running 32 steps in a compressed jump gives byte-identical
## results to flying those 8 hours live.
##
## Freight is a surplus→deficit model, not diffusion toward equal stock levels.
## Diffusion would drag an importer up to its supplier's relative stock level,
## flatten the price gap between them and kill the route. Aiming at each
## station's own target leaves exporters above target (cheap) and importers
## below theirs (dear) — a gap that persists because it comes from what the
## stations *are*.


## Advance the whole sector by one step, in place.
static func step(tables: MarketSeed.Tables) -> void:
	_local_flows(tables)
	_freight(tables)
	_settle(tables)


## Production (flat out until the silos are nearly full, then ramping to
## nothing at capacity) and consumption (limited by what is actually on the
## shelf), plus the surplus/deficit each row offers freight.
##
## The taper is a **band**, not a straight line from empty to full: a producer
## parked on its freight keep line sits at 43% of capacity, so a straight-line
## taper would multiply its stated output by 0.567 for ever and starve the
## sector (docs/economy_sim.md §7, BalanceMarket.PRODUCTION_TAPER_BAND).
static func _local_flows(tables: MarketSeed.Tables) -> void:
	for row: int in tables.row_count():
		var stock: float = tables.row_stock[row]
		var capacity: float = tables.row_capacity[row]
		var taper: float = 1.0
		if capacity > 0.0:
			var fill: float = 1.0 - stock / capacity
			taper = clampf(fill / BalanceMarket.PRODUCTION_TAPER_BAND, 0.0, 1.0)
		var produced: float = tables.row_produce[row] * taper
		var consumed: float = minf(tables.row_consume[row], stock)
		tables.scratch_delta[row] = produced - consumed

		var target: float = tables.row_target[row]
		tables.scratch_surplus[row] = stock - target * BalanceMarket.FLOW_SOURCE_KEEP_FRACTION
		tables.scratch_deficit[row] = (target * BalanceMarket.FLOW_TARGET_FILL_FRACTION - stock)
		tables.scratch_outflow[row] = 0.0


## Background haulers: every link asks for what it would move, then every
## source scales its outgoing links down proportionally so it can never ship
## more than the surplus it actually holds.
static func _freight(tables: MarketSeed.Tables) -> void:
	var link_count: int = tables.link_rate.size()
	for link: int in link_count:
		var source: int = tables.link_from[link]
		var destination: int = tables.link_to[link]
		var supply: float = maxf(tables.scratch_surplus[source], 0.0)
		var demand: float = maxf(tables.scratch_deficit[destination], 0.0)
		var move: float = tables.link_rate[link] * minf(supply, demand)
		move = minf(move, BalanceMarket.FLOW_MAX_UNITS_PER_STEP)
		tables.scratch_move[link] = move
		tables.scratch_outflow[source] += move

	for link: int in link_count:
		var source: int = tables.link_from[link]
		var move: float = tables.scratch_move[link] * _outflow_scale(tables, source)
		if move <= 0.0:
			continue
		tables.scratch_delta[source] -= move
		tables.scratch_delta[tables.link_to[link]] += move


## 1.0 unless this source promised more than its surplus, in which case the
## fraction that fits.
static func _outflow_scale(tables: MarketSeed.Tables, source: int) -> float:
	var promised: float = tables.scratch_outflow[source]
	if promised <= 0.0:
		return 1.0
	var available: float = maxf(tables.scratch_surplus[source], 0.0)
	if promised <= available:
		return 1.0
	return available / promised


## Apply every delta at once and clamp into the legal band.
static func _settle(tables: MarketSeed.Tables) -> void:
	for row: int in tables.row_count():
		var moved: float = tables.row_stock[row] + tables.scratch_delta[row]
		tables.row_stock[row] = clampf(moved, 0.0, tables.row_hard_max[row])
