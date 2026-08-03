extends GutTest

## Phase S2 — station economic identity content checks.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2, docs/economy_sim.md §3, §8
##
## Guards the seeded content, not the simulator: every station declares a
## real economic identity, sits at a real distinct world position, trades
## nothing it does not keep a market row for, and the sector produces enough
## of every commodity to cover its own consumption with headroom to spare.

const STATION_CATEGORY: StringName = &"stations"
const COMMODITY_CATEGORY: StringName = &"commodities"
const MUNITIONS_ID: StringName = &"commodity_munitions"


func test_every_station_has_a_valid_economic_identity() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(STATION_CATEGORY)
	assert_gt(ids.size(), 0, "stations exist")
	for id: StringName in ids:
		var station: Station = ContentLibrary.item(id) as Station
		assert_ne(station, null, "%s loads as Station" % id)
		assert_false(String(station.economy_role).is_empty(), "%s has an economy_role" % id)
		assert_true(
			BalanceMarket.KNOWN_ROLES.has(station.economy_role),
			"%s economy_role '%s' is a known role" % [id, String(station.economy_role)]
		)
		assert_false(station.stock_targets.is_empty(), "%s has stock_targets" % id)
		assert_gt(station.market_scale, 0.0, "%s market_scale is positive" % id)


func test_every_station_offset_is_nonzero_and_all_ten_are_distinct() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(STATION_CATEGORY)
	assert_eq(ids.size(), Balance.CONTENT_BUDGET[STATION_CATEGORY], "sector holds exactly budget")
	var seen: Array[Vector3] = []
	for id: StringName in ids:
		var station: Station = ContentLibrary.item(id) as Station
		assert_ne(station.position_offset, Vector3.ZERO, "%s position_offset is nonzero" % id)
		for other: Vector3 in seen:
			assert_ne(
				station.position_offset,
				other,
				"%s position_offset distinct from a prior station" % id
			)
		seen.append(station.position_offset)


func test_produces_and_consumes_keys_have_a_stock_targets_row() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(STATION_CATEGORY)
	for id: StringName in ids:
		var station: Station = ContentLibrary.item(id) as Station
		for commodity_id: StringName in station.produces:
			assert_true(
				station.stock_targets.has(commodity_id),
				"%s produces '%s' with no stock_targets row" % [id, String(commodity_id)]
			)
		for commodity_id: StringName in station.consumes:
			assert_true(
				station.stock_targets.has(commodity_id),
				"%s consumes '%s' with no stock_targets row" % [id, String(commodity_id)]
			)


func test_every_commodity_is_produced_and_consumed_somewhere() -> void:
	var station_ids: Array[StringName] = ContentLibrary.ids_in(STATION_CATEGORY)
	var commodity_ids: Array[StringName] = ContentLibrary.ids_in(COMMODITY_CATEGORY)
	assert_gt(commodity_ids.size(), 0, "commodities exist")
	var produced: Dictionary[StringName, bool] = {}
	var consumed: Dictionary[StringName, bool] = {}
	for station_id: StringName in station_ids:
		var station: Station = ContentLibrary.item(station_id) as Station
		for commodity_id: StringName in station.produces:
			produced[commodity_id] = true
		for commodity_id: StringName in station.consumes:
			consumed[commodity_id] = true
	for commodity_id: StringName in commodity_ids:
		assert_true(produced.has(commodity_id), "%s produced somewhere" % String(commodity_id))
		assert_true(consumed.has(commodity_id), "%s consumed somewhere" % String(commodity_id))


func test_no_contraband_controller_station_trades_munitions() -> void:
	var munitions: Commodity = ContentLibrary.item(MUNITIONS_ID) as Commodity
	assert_ne(munitions, null, "commodity_munitions loads")
	assert_gt(munitions.contraband_for_entity_ids.size(), 0, "munitions has a contraband entry")
	var station_ids: Array[StringName] = ContentLibrary.ids_in(STATION_CATEGORY)
	for entity_id: StringName in munitions.contraband_for_entity_ids:
		for station_id: StringName in station_ids:
			var station: Station = ContentLibrary.item(station_id) as Station
			if station.controller_entity_id != entity_id:
				continue
			assert_false(
				station.stock_targets.has(MUNITIONS_ID),
				(
					"%s (controlled by %s) must not stock contraband munitions"
					% [station_id, entity_id]
				)
			)
			assert_false(
				station.produces.has(MUNITIONS_ID),
				(
					"%s (controlled by %s) must not produce contraband munitions"
					% [station_id, entity_id]
				)
			)
			assert_false(
				station.consumes.has(MUNITIONS_ID),
				(
					"%s (controlled by %s) must not consume contraband munitions"
					% [station_id, entity_id]
				)
			)


func test_sector_production_covers_consumption_with_headroom() -> void:
	var station_ids: Array[StringName] = ContentLibrary.ids_in(STATION_CATEGORY)
	var commodity_ids: Array[StringName] = ContentLibrary.ids_in(COMMODITY_CATEGORY)
	for commodity_id: StringName in commodity_ids:
		var produced: float = 0.0
		var consumed: float = 0.0
		for station_id: StringName in station_ids:
			var station: Station = ContentLibrary.item(station_id) as Station
			if station.produces.has(commodity_id):
				produced += station.produces[commodity_id] * station.market_scale
			if station.consumes.has(commodity_id):
				consumed += station.consumes[commodity_id] * station.market_scale
		assert_gt(consumed, 0.0, "%s consumed somewhere (weighted)" % String(commodity_id))
		var ratio: float = produced / consumed
		assert_gte(
			ratio,
			BalanceMarket.SECTOR_PRODUCTION_MIN_RATIO,
			(
				"%s sector production/consumption ratio %.3f below the %.1fx floor"
				% [String(commodity_id), ratio, BalanceMarket.SECTOR_PRODUCTION_MIN_RATIO]
			)
		)
		assert_lte(
			ratio,
			BalanceMarket.SECTOR_PRODUCTION_MAX_RATIO,
			(
				"%s sector production/consumption ratio %.3f above the %.1fx ceiling"
				% [String(commodity_id), ratio, BalanceMarket.SECTOR_PRODUCTION_MAX_RATIO]
			)
		)


func test_validation_errors_empty_for_every_station() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(STATION_CATEGORY)
	for id: StringName in ids:
		var station: Station = ContentLibrary.item(id) as Station
		var problems: PackedStringArray = station.validation_errors()
		assert_eq(problems.size(), 0, "%s validation_errors: %s" % [id, ", ".join(problems)])


func test_content_library_reports_no_problems() -> void:
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))
