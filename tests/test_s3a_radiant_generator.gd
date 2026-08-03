extends GutTest

## Radiant job generator heuristics — Steam S3a.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3a

const PORT: StringName = &"station_alpha_port"
const GAMMA: StringName = &"station_gamma_rim"
const BETA: StringName = &"station_beta_hub"
const ZETA: StringName = &"station_zeta_spur"


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	StandingService.reset_to_defaults()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	StandingService.reset_to_defaults()


func test_same_inputs_same_offer_ids() -> void:
	var a: Dictionary = RadiantJobGenerator.build_offer(PORT, 3, 1, {})
	var b: Dictionary = RadiantJobGenerator.build_offer(PORT, 3, 1, {})
	assert_false(a.is_empty())
	assert_eq(
		str(a.get(BalanceBoard.OFFER_KEY_ID, "")),
		str(b.get(BalanceBoard.OFFER_KEY_ID, "")),
		"deterministic instance id"
	)
	assert_eq(
		str(a.get(BalanceBoard.OFFER_KEY_KIND, "")), str(b.get(BalanceBoard.OFFER_KEY_KIND, ""))
	)
	assert_eq(_pay_of(a), _pay_of(b))


func test_generator_produces_valid_kinds_only() -> void:
	var kinds: Dictionary = {}
	for step: int in 8:
		for slot: int in BalanceBoard.BOARD_SLOTS_PER_STATION:
			for station_id: StringName in [PORT, BETA, GAMMA, ZETA]:
				var offer: Dictionary = RadiantJobGenerator.build_offer(station_id, step, slot, {})
				if offer.is_empty():
					continue
				var kind: StringName = StringName(str(offer.get(BalanceBoard.OFFER_KEY_KIND, &"")))
				kinds[kind] = true
				assert_true(
					(
						kind == BalanceStanding.MISSION_KIND_DELIVERY
						or kind == BalanceStanding.MISSION_KIND_BOUNTY
						or kind == BalanceStanding.MISSION_KIND_SMUGGLE
						or kind == BalanceStanding.MISSION_KIND_ESCORT
					),
					"kind is one of four: %s" % kind
				)
				assert_gt(_pay_of(offer), 0)
				assert_false(str(offer.get(BalanceBoard.OFFER_KEY_OFFERING_ENTITY, "")).is_empty())
	assert_true(kinds.has(BalanceStanding.MISSION_KIND_DELIVERY), "delivery present")
	# Sector has contested/lawless + risk legs — expect variety beyond pure hauls.
	var variety: int = kinds.size()
	assert_gte(variety, 2, "generator produces more than one kind class across fixtures")


func _pay_of(offer: Dictionary) -> int:
	var raw: Variant = offer.get(BalanceBoard.OFFER_KEY_PAY, 0)
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return int(as_float)
	return 0


func test_system_can_produce_escort_kind() -> void:
	var found_escort: bool = false
	for step: int in 24:
		for slot: int in 8:
			for station_id: StringName in ContentLibrary.ids_in(&"stations"):
				var offer: Dictionary = RadiantJobGenerator.build_offer(station_id, step, slot, {})
				if offer.is_empty():
					continue
				if (
					str(offer.get(BalanceBoard.OFFER_KEY_KIND, ""))
					== String(BalanceStanding.MISSION_KIND_ESCORT)
				):
					found_escort = true
					assert_false(
						str(offer.get(BalanceBoard.OFFER_KEY_DESTINATION, "")).is_empty(),
						"escort names destination"
					)
					break
			if found_escort:
				break
		if found_escort:
			break
	assert_true(found_escort, "game can produce escort via radiant generator")


func test_board_mix_includes_hand_and_radiant_sources() -> void:
	## Alpha Port controller ships hand couriers and fills remaining slots radiant.
	## Both sources must show — hand-only or radiant-only would pass the old OR.
	var ids: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(ids.size(), 0)
	var sources: Dictionary = {}
	for id: StringName in ids:
		var offer: Dictionary = BoardService.get_offer(id)
		assert_false(offer.is_empty(), "listed id must resolve: %s" % id)
		sources[str(offer.get(BalanceBoard.OFFER_KEY_SOURCE, ""))] = true
	assert_true(
		sources.has(String(BalanceBoard.OFFER_SOURCE_HAND)),
		"Alpha Port must list at least one hand template row"
	)
	assert_true(
		sources.has(String(BalanceBoard.OFFER_SOURCE_RADIANT)),
		"Alpha Port must fill remaining slots with radiant work"
	)


func test_shortage_route_boosts_delivery_candidates() -> void:
	## Market shelves must change radiant output in a measurable way.
	## Flood every shelf so no destination counts as a shortage, then zero them
	## so shortage severity pays apply. A no-op generator (ignoring market) fails.
	var flooded: Dictionary = MarketService.to_section()
	_set_all_shelf_stocks(flooded, 1.0e6)
	MarketService.apply_section(flooded)
	var before: Dictionary = _delivery_grid_stats(PORT)
	var max_pay_before: int = _dict_int(before, &"max_pay")
	var delivery_count_before: int = _dict_int(before, &"delivery_count")
	assert_gt(delivery_count_before, 0, "flooded market still produces delivery fallbacks")

	var emptied: Dictionary = MarketService.to_section()
	_set_all_shelf_stocks(emptied, 0.0)
	MarketService.apply_section(emptied)
	var after: Dictionary = _delivery_grid_stats(PORT)
	var max_pay_after: int = _dict_int(after, &"max_pay")
	var delivery_count_after: int = _dict_int(after, &"delivery_count")

	var pay_msg: String = (
		"deep shortage must raise max delivery pay (before=%d after=%d)"
		% [max_pay_before, max_pay_after]
	)
	assert_gt(max_pay_after, max_pay_before, pay_msg)
	assert_gte(
		max_pay_after,
		max_pay_before + BalanceBoard.PAY_SHORTAGE_BASE,
		"at least one severity band of shortage pay must appear"
	)
	# Weight bonus can also mint more delivery picks; pay lift is the hard proof.
	assert_gte(delivery_count_after, delivery_count_before)


func _set_all_shelf_stocks(section: Dictionary, stock_value: float) -> void:
	if not section.has(BalanceMarket.SAVE_KEY_STOCKS):
		return
	var stocks_raw: Variant = section[BalanceMarket.SAVE_KEY_STOCKS]
	if typeof(stocks_raw) != TYPE_DICTIONARY:
		return
	var stocks: Dictionary = stocks_raw
	for station_key: Variant in stocks.keys():
		var per_raw: Variant = stocks[station_key]
		if typeof(per_raw) != TYPE_DICTIONARY:
			continue
		var per: Dictionary = per_raw
		for commodity_key: Variant in per.keys():
			per[commodity_key] = stock_value


func _delivery_grid_stats(station_id: StringName) -> Dictionary:
	var delivery_count: int = 0
	var max_pay: int = 0
	for step: int in 16:
		for slot: int in 8:
			var offer: Dictionary = RadiantJobGenerator.build_offer(station_id, step, slot, {})
			if offer.is_empty():
				continue
			if (
				str(offer.get(BalanceBoard.OFFER_KEY_KIND, ""))
				!= String(BalanceStanding.MISSION_KIND_DELIVERY)
			):
				continue
			delivery_count += 1
			var pay: int = _pay_of(offer)
			if pay > max_pay:
				max_pay = pay
	return {&"delivery_count": delivery_count, &"max_pay": max_pay}


func _dict_int(data: Dictionary, key: StringName) -> int:
	var raw: Variant = data.get(key, 0)
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return int(as_float)
	return 0
