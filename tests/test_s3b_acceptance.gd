extends GutTest

## S3b acceptance proxies — varied work classes without fixed-board-only loop.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3b accept criteria (headless).

const ALPHA: StringName = &"system_alpha"
const PORT: StringName = &"station_alpha_port"
const MUNITIONS: StringName = &"commodity_munitions"


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	IncidentService.reset()
	StandingService.reset_to_defaults()


func after_each() -> void:
	IncidentService.reset()
	BoardService.reset()
	MarketService.reset()
	StandingService.reset_to_defaults()
	WorldClockHelpers.reset_clock()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()


func test_varied_activity_classes_available() -> void:
	## Board / radiant + incidents + purposeful traffic/news must all exist
	## as separate activity classes a free session can find.
	var classes: Dictionary = {}

	# 1) Board / radiant work surface
	var board_ids: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(board_ids.size(), 0, "board lists work")
	classes[&"board"] = true

	# 2) Incidents (space life)
	IncidentService.set_ship_count_override(1)
	var distress: StringName = IncidentService.force_offer(BalanceIncident.KIND_DISTRESS, ALPHA)
	assert_false(String(distress).is_empty())
	classes[&"incident"] = true

	# 3) News feed (thickened)
	var news: String = MarketService.news_line()
	assert_false(news.is_empty())
	classes[&"news"] = true

	# 4) Purposeful traffic (shortage run or dock cycle)
	var emptied: Dictionary = MarketService.to_section()
	_zero_station(emptied, PORT)
	MarketService.apply_section(emptied)
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(ALPHA)
	await get_tree().process_frame
	var purposeful: int = (
		traffic.count_with_purpose(BalanceIncident.PURPOSE_SHORTAGE_RUN)
		+ traffic.count_with_purpose(BalanceIncident.PURPOSE_DOCK_CYCLE)
	)
	assert_gt(purposeful, 0, "traffic has purpose beyond pure orbit")
	classes[&"traffic_purpose"] = true

	assert_eq(classes.size(), 4, "four activity classes present")


func test_board_restock_still_works_regression() -> void:
	var before: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(before.size(), 0)
	var steps_before: int = BoardService.steps_done()
	WorldClock.advance_hours(BalanceBoard.BOARD_STEP_HOURS * 2.0)
	BoardService.catch_up()
	var steps_after: int = BoardService.steps_done()
	assert_gt(steps_after, steps_before, "board advances on clock")
	var after: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(after.size(), 0, "board still lists after restock")


func test_incident_and_board_coexist() -> void:
	var board_ids: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(board_ids.size(), 0)
	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_INTERCEPT, ALPHA)
	assert_false(String(id).is_empty())
	# Board still available after incident offer.
	var still: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(still.size(), 0)
	assert_eq(IncidentService.offered_count(), 1)


func _zero_station(section: Dictionary, station_id: StringName) -> void:
	if not section.has(BalanceMarket.SAVE_KEY_STOCKS):
		return
	var stocks: Variant = section[BalanceMarket.SAVE_KEY_STOCKS]
	if typeof(stocks) != TYPE_DICTIONARY:
		return
	var stock_map: Dictionary = stocks
	var key: String = String(station_id)
	if not stock_map.has(key):
		return
	var per: Variant = stock_map[key]
	if typeof(per) != TYPE_DICTIONARY:
		return
	var per_map: Dictionary = per
	for commodity_key: Variant in per_map.keys():
		per_map[commodity_key] = 0.0
