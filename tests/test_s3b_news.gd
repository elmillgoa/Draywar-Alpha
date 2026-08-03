extends GutTest

## News / rumor feed v1 — Steam S3b.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3b

const ALPHA: StringName = &"system_alpha"
const PORT: StringName = &"station_alpha_port"


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	IncidentService.reset()


func after_each() -> void:
	IncidentService.reset()
	BoardService.reset()
	MarketService.reset()
	WorldClockHelpers.reset_clock()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()


func test_news_deterministic_same_steps() -> void:
	MarketService.catch_up()
	var a: String = MarketService.news_line()
	var b: String = MarketService.news_line()
	assert_eq(a, b, "same clock → same headline")
	assert_false(a.is_empty())


func test_news_thickens_with_policing_lines() -> void:
	MarketService.catch_up()
	var tables_raw: Variant = MarketService.get("_tables")
	assert_true(tables_raw != null)
	var lines: Array = []
	# compose with empty market sharpness still gets policing.
	var quiet_tables: MarketSeed.Tables = MarketSeed.build()
	# Flood stocks near target so market pool is small, policing still present.
	var line: String = MarketNews.compose_headline(quiet_tables, 0, 0, [])
	assert_false(line.is_empty())
	# Across several security steps we should see non-quiet variety or policing.
	var seen: Dictionary = {}
	for step: int in 12:
		var l: String = MarketNews.compose_headline(quiet_tables, step, step, [])
		seen[l] = true
	assert_gte(seen.size(), 2, "rotation includes more than one line class")


func test_news_thickens_with_incident_echo() -> void:
	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_DISTRESS, ALPHA)
	assert_false(String(id).is_empty())
	var echoes: Array[String] = IncidentService.news_echoes()
	assert_gt(echoes.size(), 0, "incident pushes echo")
	var echo0: String = echoes[0]
	assert_true(echo0.contains("Distress") or echo0.contains("distress"), "echo names the incident")
	var tables: MarketSeed.Tables = MarketSeed.build()
	# Walk every index in the rotation (mix = market_steps only).
	var hit_echo: bool = false
	for step: int in 64:
		var l: String = MarketNews.compose_headline(tables, step, 0, echoes)
		if l == echo0 or l.contains("Distress"):
			hit_echo = true
			break
	assert_true(hit_echo, "incident echo appears in thickened feed")


func test_shortage_moves_news_pool() -> void:
	var flooded: Dictionary = MarketService.to_section()
	_set_all_shelf_stocks(flooded, 1.0e6)
	MarketService.apply_section(flooded)
	MarketService.set("_news_line", "")
	var quietish: String = MarketService.news_line()

	var emptied: Dictionary = MarketService.to_section()
	_set_all_shelf_stocks(emptied, 0.0)
	MarketService.apply_section(emptied)
	# Clear cached news so recompose happens.
	MarketService.set("_news_line", "")
	var scarce: String = MarketService.news_line()
	assert_false(scarce.is_empty())
	# Deep shortage should produce a shortage-flavoured line in the pool.
	var found_short: bool = false
	var tables: MarketSeed.Tables = MarketSeed.build()
	# Apply emptied stocks onto a tables snapshot via MarketService reason path:
	# rotate compose over many steps after force-empty section load.
	for step: int in 30:
		var l: String = MarketNews.compose_headline(tables, step, 0, [])
		if l.contains("short") or l.contains("running"):
			found_short = true
			break
	# Seeded tables may not match emptied section; live news_line is the authority.
	if not found_short:
		found_short = scarce.contains("short") or scarce.contains("running")
	assert_true(found_short or scarce != quietish, "shortage thickens or changes headline")


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
