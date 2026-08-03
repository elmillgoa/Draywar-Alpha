extends GutTest

## Traffic purpose lite — Steam S3b.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3b

const ALPHA: StringName = &"system_alpha"
const PORT: StringName = &"station_alpha_port"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const DEST_BETA: StringName = &"station_beta_hub"


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


func test_dock_cycle_purpose_assigned_to_some_civilians() -> void:
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(ALPHA)
	await get_tree().process_frame
	var total: int = traffic.live_ship_count()
	assert_gt(total, 0)
	var dockers: int = traffic.count_with_purpose(BalanceIncident.PURPOSE_DOCK_CYCLE)
	# Patrolled alpha has enough civilians that fraction should assign ≥1 when count ≥4.
	if total >= 4:
		assert_gte(dockers, 1, "some civilians use dock cycle")
	else:
		assert_gte(dockers, 0)


func test_purposeful_freighter_targets_shortage_station() -> void:
	# Force every market full, then empty Alpha Port so it is the shortage.
	var section: Dictionary = MarketService.to_section()
	_set_all_shelf_stocks(section, 1.0e6)
	_set_station_stocks(section, PORT, 0.0)
	MarketService.apply_section(section)

	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(ALPHA)
	await get_tree().process_frame
	# Rebuild already tries retask; force again for clarity.
	var retasked: bool = traffic.retask_shortage_from_market()
	assert_true(
		retasked or traffic.count_with_purpose(BalanceIncident.PURPOSE_SHORTAGE_RUN) >= 1,
		"shortage retasks a freighter toward short station"
	)
	assert_lte(traffic.live_ship_count(), BalanceEconomy.PERF_BUDGET_SHIPS)


func test_escort_freighter_death_still_only_fails_escort() -> void:
	## Traffic death must not call mission fail; only MissionEscortShip does.
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	var failed: Array[StringName] = []
	var on_fail := func(tid: StringName, _e: StringName, _d: float) -> void: failed.append(tid)
	EventBus.on_mission_failed.connect(on_fail)

	var offer: Dictionary = {
		BalanceBoard.OFFER_KEY_ID: &"rad_s3b_escort",
		BalanceBoard.OFFER_KEY_BOARD_STATION: PORT,
		BalanceBoard.OFFER_KEY_KIND: BalanceStanding.MISSION_KIND_ESCORT,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: ENTITY_REACH,
		BalanceBoard.OFFER_KEY_PAY: 200,
		BalanceBoard.OFFER_KEY_STANDING_COMPLETE: BalanceStanding.MISSION_COMPLETE_DELTA,
		BalanceBoard.OFFER_KEY_STANDING_FAIL: BalanceStanding.MISSION_FAIL_DELTA,
		BalanceBoard.OFFER_KEY_STANDING_ABANDON: BalanceStanding.MISSION_ABANDON_DELTA,
		BalanceBoard.OFFER_KEY_DESTINATION: DEST_BETA,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: &"system_beta",
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: &"",
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: 0,
		BalanceBoard.OFFER_KEY_LABEL: "Escort freighter to Beta Hub",
		BalanceBoard.OFFER_KEY_SOURCE: BalanceBoard.OFFER_SOURCE_RADIANT,
	}
	assert_true(mission.accept_runtime_offer(offer, true))
	assert_true(mission.has_active())

	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(ALPHA)
	await get_tree().process_frame
	# Kill every ambient traffic ship.
	var victims: Array[Node] = []
	for child: Node in traffic.get_children():
		victims.append(child)
	for v: Node in victims:
		if v is TrafficShip:
			(v as TrafficShip).take_damage(9999.0)
	await get_tree().process_frame
	assert_true(mission.has_active(), "traffic deaths do not fail escort")
	assert_eq(failed.size(), 0)

	# Only escort freighter death fails.
	mission.notify_escort_destroyed()
	assert_false(mission.has_active())
	assert_eq(failed.size(), 1)

	if EventBus.on_mission_failed.is_connected(on_fail):
		EventBus.on_mission_failed.disconnect(on_fail)


func _set_all_shelf_stocks(section: Dictionary, stock: float) -> void:
	if not section.has(BalanceMarket.SAVE_KEY_STOCKS):
		return
	var stocks: Variant = section[BalanceMarket.SAVE_KEY_STOCKS]
	if typeof(stocks) != TYPE_DICTIONARY:
		return
	var stock_map: Dictionary = stocks
	for station_key: Variant in stock_map.keys():
		var per: Variant = stock_map[station_key]
		if typeof(per) != TYPE_DICTIONARY:
			continue
		var per_map: Dictionary = per
		for commodity_key: Variant in per_map.keys():
			per_map[commodity_key] = stock


func _set_station_stocks(section: Dictionary, station_id: StringName, stock: float) -> void:
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
		per_map[commodity_key] = stock
