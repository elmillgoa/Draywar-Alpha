class_name MarketSeed
extends RefCounted

## Opening market state built from station content — Steam S2.
##
## Implements: docs/economy_sim.md §3 (station economic identity), §7 (freight)
##
## Reads every station and commodity out of ContentLibrary once and flattens
## them into `Tables`: parallel arrays, one entry per traded
## (station, commodity) pair, plus the freight link list.
##
## **The flattening is the performance story.** A simulation step touches only
## packed arrays of numbers — no dictionary lookups, no ContentLibrary calls,
## no gate-graph walks. The link list in particular is built here exactly once:
## rebuilding station pairs inside the step would turn a 10,000-step catch-up
## into a crawl.
##
## Rows are ordered by sorted station id then sorted commodity id, and the step
## walks them in that order, so the arithmetic of a sector step never depends on
## dictionary iteration order.

## Marks a (station, commodity) pair this station keeps no market in.
const NO_ROW: int = -1


## Flattened market state. Everything MarketSim and MarketService touch.
class Tables:
	extends RefCounted

	## Sorted station content ids; the index into this array is a station index.
	var station_ids: Array[StringName] = []
	## Station display names, parallel to `station_ids` (news lines).
	var station_names: PackedStringArray = PackedStringArray()
	## Sorted commodity content ids; the index is a commodity index.
	var commodity_ids: Array[StringName] = []
	## Commodity display names, parallel to `commodity_ids` (news lines).
	var commodity_names: PackedStringArray = PackedStringArray()

	## station_index * commodity_ids.size() + commodity_index -> row, or NO_ROW.
	var row_lookup: PackedInt32Array = PackedInt32Array()

	## Per row: which station and which commodity it belongs to.
	var row_station: PackedInt32Array = PackedInt32Array()
	var row_commodity: PackedInt32Array = PackedInt32Array()
	## Per row: price-neutral stock, already weighted by market_scale.
	var row_target: PackedFloat64Array = PackedFloat64Array()
	## Per row: target * CAPACITY_TO_TARGET (production tapers against this).
	var row_capacity: PackedFloat64Array = PackedFloat64Array()
	## Per row: capacity * SELL_OVERFILL_LIMIT (the absolute clamp).
	var row_hard_max: PackedFloat64Array = PackedFloat64Array()
	## Per row: units produced in one step at an empty shelf.
	var row_produce: PackedFloat64Array = PackedFloat64Array()
	## Per row: units consumed in one step when the stock is there.
	var row_consume: PackedFloat64Array = PackedFloat64Array()
	## Per row: stock a player buy may not take this market below.
	var row_floor: PackedFloat64Array = PackedFloat64Array()
	## Per row: the commodity's content prices.
	var row_base_buy: PackedInt32Array = PackedInt32Array()
	var row_base_sell: PackedInt32Array = PackedInt32Array()

	## Per row: live stock. The only thing a simulation step writes.
	var row_stock: PackedFloat64Array = PackedFloat64Array()

	## Per row: signed peak shock offset (0.0 = no shock).
	var row_shock_magnitude: PackedFloat64Array = PackedFloat64Array()
	## Per row: world-clock second the shock decays to nothing.
	var row_shock_expiry: PackedFloat64Array = PackedFloat64Array()
	## Per row: SHOCK_KIND_STRIP / SHOCK_KIND_GLUT, or empty.
	var row_shock_kind: Array[StringName] = []

	## Freight links, directed. A surplus at `link_from` feeds a deficit at
	## `link_to` at `link_rate` per step, which decays with gate distance.
	## Built in a fixed source-station / destination-station / commodity order.
	var link_from: PackedInt32Array = PackedInt32Array()
	var link_to: PackedInt32Array = PackedInt32Array()
	var link_rate: PackedFloat64Array = PackedFloat64Array()

	## Step scratch, allocated once and reused so a step never allocates.
	var scratch_delta: PackedFloat64Array = PackedFloat64Array()
	var scratch_surplus: PackedFloat64Array = PackedFloat64Array()
	var scratch_deficit: PackedFloat64Array = PackedFloat64Array()
	var scratch_outflow: PackedFloat64Array = PackedFloat64Array()
	var scratch_move: PackedFloat64Array = PackedFloat64Array()

	## How many (station, commodity) markets exist across the sector.
	func row_count() -> int:
		return row_stock.size()

	## Row for a station/commodity index pair, or NO_ROW.
	func row_for(station_slot: int, commodity_slot: int) -> int:
		if station_slot < 0 or commodity_slot < 0:
			return NO_ROW
		return row_lookup[station_slot * commodity_ids.size() + commodity_slot]

	## Index of a station content id, or -1.
	func station_index(station_id: StringName) -> int:
		return station_ids.find(station_id)

	## Index of a commodity content id, or -1.
	func commodity_index(commodity_id: StringName) -> int:
		return commodity_ids.find(commodity_id)

	## Row for a station/commodity id pair, or NO_ROW.
	func row_for_ids(station_id: StringName, commodity_id: StringName) -> int:
		return row_for(station_index(station_id), commodity_index(commodity_id))

	## Drop every active shock.
	func clear_shocks() -> void:
		var count: int = row_count()
		row_shock_magnitude = PackedFloat64Array()
		row_shock_expiry = PackedFloat64Array()
		row_shock_kind = []
		row_shock_magnitude.resize(count)
		row_shock_expiry.resize(count)
		row_shock_kind.resize(count)
		for i: int in count:
			row_shock_kind[i] = &""


## Build opening market state from the live content library.
static func build() -> Tables:
	var tables: Tables = Tables.new()
	tables.station_ids = ContentLibrary.ids_in(BalanceMarket.STATION_CONTENT_CATEGORY)
	tables.commodity_ids = ContentLibrary.ids_in(BalanceEconomy.COMMODITY_CONTENT_CATEGORY)
	_fill_display_names(tables)

	var commodity_count: int = tables.commodity_ids.size()
	tables.row_lookup.resize(tables.station_ids.size() * commodity_count)
	tables.row_lookup.fill(NO_ROW)

	for station_index: int in tables.station_ids.size():
		var station: Station = _station_at(tables, station_index)
		if station == null:
			continue
		for commodity_index: int in commodity_count:
			var commodity_id: StringName = tables.commodity_ids[commodity_index]
			if not station.stock_targets.has(commodity_id):
				continue
			var commodity: Commodity = ContentLibrary.item(commodity_id) as Commodity
			if commodity == null:
				continue
			_append_row(tables, station, station_index, commodity, commodity_index)

	tables.clear_shocks()
	_resize_scratch(tables)
	_build_links(tables)
	return tables


## Opening stock for every row, in row order — what `reset()` restores to.
static func opening_stock(tables: Tables) -> PackedFloat64Array:
	var opening: PackedFloat64Array = PackedFloat64Array()
	opening.resize(tables.row_count())
	for row: int in tables.row_count():
		var produces: bool = tables.row_produce[row] > 0.0
		var consumes: bool = tables.row_consume[row] > 0.0
		var factor: float = BalanceMarket.seed_factor_for(produces, consumes)
		opening[row] = tables.row_target[row] * factor
	return opening


static func _fill_display_names(tables: Tables) -> void:
	tables.station_names.resize(tables.station_ids.size())
	for i: int in tables.station_ids.size():
		tables.station_names[i] = _display_name_of(tables.station_ids[i])
	tables.commodity_names.resize(tables.commodity_ids.size())
	for i: int in tables.commodity_ids.size():
		tables.commodity_names[i] = _display_name_of(tables.commodity_ids[i])


static func _display_name_of(content_id: StringName) -> String:
	var item: ContentItem = ContentLibrary.item(content_id)
	if item == null or item.display_name.is_empty():
		return String(content_id)
	return item.display_name


static func _station_at(tables: Tables, station_index: int) -> Station:
	return ContentLibrary.item(tables.station_ids[station_index]) as Station


static func _append_row(
	tables: Tables, station: Station, station_index: int, commodity: Commodity, commodity_index: int
) -> void:
	# market_scale weights rates exactly as it weights targets and capacity
	# (docs/economy_sim.md §3): a `produces` value is per game hour at scale 1.0.
	# Without this a tiny frontier spur would eat as much grain as a core hub.
	var rate_scale: float = station.market_scale * BalanceMarket.STEP_HOURS
	var target: float = station.stock_targets[commodity.id] * station.market_scale
	var produce: float = 0.0
	if station.produces.has(commodity.id):
		produce = station.produces[commodity.id] * rate_scale
	var consume: float = 0.0
	var floor_stock: float = 0.0
	if station.consumes.has(commodity.id):
		consume = station.consumes[commodity.id] * rate_scale
		floor_stock = target * BalanceMarket.STOCK_FLOOR_FRACTION

	var row: int = tables.row_count()
	tables.row_lookup[station_index * tables.commodity_ids.size() + commodity_index] = row
	tables.row_station.append(station_index)
	tables.row_commodity.append(commodity_index)
	tables.row_target.append(target)
	tables.row_capacity.append(BalanceMarket.capacity_for(target))
	tables.row_hard_max.append(BalanceMarket.hard_max_for(target))
	tables.row_produce.append(produce)
	tables.row_consume.append(consume)
	tables.row_floor.append(floor_stock)
	tables.row_base_buy.append(commodity.base_buy_price)
	tables.row_base_sell.append(commodity.base_sell_price)
	var factor: float = BalanceMarket.seed_factor_for(produce > 0.0, consume > 0.0)
	tables.row_stock.append(target * factor)


static func _resize_scratch(tables: Tables) -> void:
	var count: int = tables.row_count()
	tables.scratch_delta.resize(count)
	tables.scratch_surplus.resize(count)
	tables.scratch_deficit.resize(count)
	tables.scratch_outflow.resize(count)


## Precompute every freight link once: ordered station pair × shared commodity
## × the rate that pair moves at, for pairs up to FLOW_MAX_HOPS gates apart.
##
## **SectorGraph is asked here and nowhere else.** Hop distance is a
## breadth-first walk of the gate graph; doing that inside the step would turn
## a 10,000-step catch-up into a crawl. One lookup per unordered system pair is
## enough — the graph is undirected for freight, so the rate is symmetric.
static func _build_links(tables: Tables) -> void:
	var systems: Array[StringName] = []
	systems.resize(tables.station_ids.size())
	for i: int in tables.station_ids.size():
		systems[i] = SectorGraph.system_of_station(tables.station_ids[i])
	var rates: Dictionary[String, float] = _system_pair_rates(systems)

	for source: int in tables.station_ids.size():
		for destination: int in tables.station_ids.size():
			if source == destination:
				continue
			var rate: float = _rate_between(systems[source], systems[destination], rates)
			if rate <= 0.0:
				continue
			for commodity_index: int in tables.commodity_ids.size():
				var from_row: int = tables.row_for(source, commodity_index)
				if from_row == NO_ROW:
					continue
				var to_row: int = tables.row_for(destination, commodity_index)
				if to_row == NO_ROW:
					continue
				tables.link_from.append(from_row)
				tables.link_to.append(to_row)
				tables.link_rate.append(rate)
	tables.scratch_move.resize(tables.link_rate.size())


## Freight rate for every unordered pair of distinct systems that hosts a
## station, keyed by `_pair_key`. One SectorGraph.hop_distance per pair.
static func _system_pair_rates(systems: Array[StringName]) -> Dictionary[String, float]:
	var unique: Array[StringName] = []
	for system_id: StringName in systems:
		if String(system_id).is_empty() or unique.has(system_id):
			continue
		unique.append(system_id)

	var rates: Dictionary[String, float] = {}
	for first: StringName in unique:
		for second: StringName in unique:
			if first == second:
				continue
			var key: String = _pair_key(first, second)
			if rates.has(key):
				continue
			var hops: int = SectorGraph.hop_distance(first, second)
			rates[key] = BalanceMarket.freight_rate_for_hops(hops)
	return rates


static func _rate_between(
	source_system: StringName, destination_system: StringName, rates: Dictionary[String, float]
) -> float:
	if String(source_system).is_empty() or String(destination_system).is_empty():
		return 0.0
	if source_system == destination_system:
		return BalanceMarket.FLOW_RATE_INTRA_SYSTEM
	var key: String = _pair_key(source_system, destination_system)
	if not rates.has(key):
		return 0.0
	return rates[key]


static func _pair_key(first: StringName, second: StringName) -> String:
	var a: String = String(first)
	var b: String = String(second)
	if a <= b:
		return a + "|" + b
	return b + "|" + a
