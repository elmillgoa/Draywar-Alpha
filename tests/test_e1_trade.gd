extends GutTest

## E1.4 trade contrast + money pressure.
##
## Implements: docs/BETA_E1_LEGIBLE_SECTOR.md E1.4, docs/economy_sim.md §4, §11
##
## E1.4's claim was "the sector has legible trade contrast and real routes".
## That claim survives S2 intact; what changed is *why* it is true. It used to
## come from a hand-written per-system multiplier table, so these tests asserted
## the table. Prices now come from stock at a station, so they assert the same
## thing against stock: the dock holding more of a good quotes it cheaper, the
## dock holding less pays more for it, and that gap is what makes a route.
##
## Deliberately no hardcoded credit amounts — the sim's production and freight
## balance is still moving, and every claim here would survive any honest
## rebalance because it is a relationship, not a number.

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"

const STATION_ALPHA: StringName = &"station_alpha_port"
const STATION_YARD: StringName = &"station_alpha_yard"
const STATION_GAMMA: StringName = &"station_gamma_outpost"

const GRAIN: StringName = &"commodity_grain"
const SCRAP: StringName = &"commodity_scrap"
const ORE: StringName = &"commodity_ore"
const ALLOY: StringName = &"commodity_alloy"
const LUXURIES: StringName = &"commodity_luxuries"
const MUNITIONS: StringName = &"commodity_munitions"
const RATIONS: StringName = &"commodity_rations"

## How many of the ten commodities must already have a profitable buy-here /
## sell-there pair on a fresh career. This is the acceptance bar itself
## (docs/economy_sim.md §8, docs/STEAM_PHASE_PLAN.md §5.6), not a softer
## regression floor. **It sat at six for a while and that slack is precisely what
## hid the defect**: grain and scrap were both quoting a margin of exactly zero
## at boot and nothing in the suite went red, because eight of ten still paid.
## The count of live commodities is asserted against this too, so "all of them"
## cannot quietly shrink to "all two of them".
const MIN_PROFITABLE_COMMODITIES: int = 10

## Units moved on the worked cross-system route (fits the starter hold).
const ROUTE_UNITS: int = 4


class FakeDock:
	extends Node
	var station: StringName = STATION_ALPHA

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station


func before_each() -> void:
	WorldClockHelpers.reset_clock()
	MarketService.reset()


func after_each() -> void:
	StandingService.reset_to_defaults()
	WorldClockHelpers.reset_clock()
	MarketService.reset()


func test_commodity_count_meets_e1_target() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceEconomy.COMMODITY_CONTENT_CATEGORY)
	assert_gte(ids.size(), 8, "E1.4 targets 8–10 commodities")
	assert_lte(ids.size(), 10, "E1 commodity cap is 10")
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[BalanceEconomy.COMMODITY_CONTENT_CATEGORY])
	assert_eq(Balance.CONTENT_BUDGET[BalanceEconomy.COMMODITY_CONTENT_CATEGORY], 10)
	for id: StringName in ids:
		var commodity: Commodity = ContentLibrary.item(id) as Commodity
		assert_ne(commodity, null, "%s must load as Commodity" % id)
		assert_gt(commodity.base_buy_price, 0)
		assert_gt(commodity.base_sell_price, 0)
		assert_gt(commodity.unit_volume, 0)


func test_new_e1_commodities_present() -> void:
	for id: StringName in [ORE, LUXURIES, MUNITIONS, RATIONS]:
		assert_true(ContentLibrary.has_item(id), "%s should be content" % id)
		var commodity: Commodity = ContentLibrary.item(id) as Commodity
		assert_ne(commodity, null)
		assert_eq(commodity.validation_errors().size(), 0, "%s must validate" % id)


## Routes exist, and they exist **because of stock**: for every commodity that
## pays at all, the cheapest dock to buy it at is the fullest one and the dock
## that pays most for it is the emptiest.
func test_routes_are_profitable_because_of_stock() -> void:
	var profitable: int = 0
	for commodity_id: StringName in ContentLibrary.ids_in(
		BalanceEconomy.COMMODITY_CONTENT_CATEGORY
	):
		var route: Dictionary = _best_route(commodity_id)
		if route.is_empty():
			continue
		var margin: int = route[&"margin"]
		if margin <= 0:
			continue
		profitable += 1
		var source: StringName = route[&"buy_at"]
		var destination: StringName = route[&"sell_at"]
		assert_ne(source, destination, "%s: a route needs two different docks" % commodity_id)
		assert_gt(
			_fill(source, commodity_id),
			_fill(destination, commodity_id),
			"%s: the cheap dock must be the one holding more of it" % commodity_id
		)
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceEconomy.COMMODITY_CONTENT_CATEGORY)
	var live_commodities: int = ids.size()
	assert_eq(
		live_commodities, MIN_PROFITABLE_COMMODITIES, "the commodity library is still ten goods"
	)
	assert_eq(
		profitable,
		live_commodities,
		"every commodity must carry a real route at boot, not a flat market"
	)
	assert_gte(
		profitable,
		MIN_PROFITABLE_COMMODITIES,
		"the live sector must carry real routes, not a flat market"
	)


## The dock that makes a good undercuts the dock that eats it — same system, so
## the difference cannot be distance or policing. This is E1.4's "legible
## contrast" restated against the model that now produces it.
func test_a_producing_dock_undercuts_a_consuming_one_in_the_same_system() -> void:
	assert_true(MarketService.trades(STATION_YARD, ALLOY), "Alpha Yard makes alloy")
	assert_true(MarketService.trades(STATION_ALPHA, ALLOY), "Alpha Port buys alloy in")
	assert_gt(
		_fill(STATION_YARD, ALLOY),
		_fill(STATION_ALPHA, ALLOY),
		"the yard that makes alloy holds more of it than the port that consumes it"
	)
	assert_lt(
		MarketService.unit_buy_price(STATION_YARD, ALLOY),
		MarketService.unit_buy_price(STATION_ALPHA, ALLOY),
		"and therefore sells it cheaper"
	)
	assert_lt(
		MarketService.unit_sell_price(STATION_YARD, ALLOY),
		MarketService.unit_sell_price(STATION_ALPHA, ALLOY),
		"while the port that wants it pays more for it"
	)

	# Same dock is still never free money, at either end of the contrast.
	for station_id: StringName in [STATION_YARD, STATION_ALPHA]:
		assert_lt(
			MarketService.unit_sell_price(station_id, ALLOY),
			MarketService.unit_buy_price(station_id, ALLOY),
			"%s must not pay more than it charges" % station_id
		)


func test_buy_sell_across_systems_via_services() -> void:
	## The whole loop through the real services: pick the sector's best route out
	## of live market state, buy there, "jump" by changing the docked station,
	## sell, and come out ahead. Which commodity and which docks are discovered
	## rather than hardcoded, so a rebalance moves the route instead of
	## falsifying the test.
	var route: Dictionary = _best_sector_route()
	assert_false(route.is_empty(), "the live sector must carry at least one profitable route")
	var commodity_id: StringName = route[&"commodity"]
	var source: StringName = route[&"buy_at"]
	var destination: StringName = route[&"sell_at"]

	var host: Node = Node.new()
	add_child_autofree(host)
	var dock: FakeDock = FakeDock.new()
	dock.station = source
	host.add_child(dock)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	wallet.reset()
	cargo.reset()
	wallet.set_credits(2000)
	var start: int = wallet.credits()

	var buy_quote: Dictionary = cargo.quote_buy(commodity_id, ROUTE_UNITS)
	var spent: int = buy_quote[BalanceMarket.QUOTE_KEY_TOTAL]
	assert_true(cargo.try_buy(commodity_id, ROUTE_UNITS), "buy %s at %s" % [commodity_id, source])
	assert_eq(cargo.quantity(commodity_id), ROUTE_UNITS)
	assert_eq(wallet.credits(), start - spent)

	dock.station = destination
	var sell_quote: Dictionary = cargo.quote_sell(commodity_id, ROUTE_UNITS)
	var paid: int = sell_quote[BalanceMarket.QUOTE_KEY_TOTAL]
	assert_true(cargo.try_sell(commodity_id, ROUTE_UNITS), "sell it at %s" % destination)
	assert_eq(cargo.quantity(commodity_id), 0)
	assert_eq(wallet.credits(), start - spent + paid)
	assert_gt(
		wallet.credits(), start, "%s from %s to %s must pay" % [commodity_id, source, destination]
	)


func test_save_load_preserves_cargo_and_credits() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	wallet.reset()
	cargo.reset()
	wallet.set_credits(777)
	assert_true(cargo.add(ORE, 4))
	assert_true(cargo.add(LUXURIES, 1))
	assert_true(cargo.add(GRAIN, 3))

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceEconomy.SAVE_SECTION_CARGO))
	assert_true(sections.has(BalanceEconomy.SAVE_SECTION_KEY))

	wallet.reset()
	cargo.reset()
	assert_eq(cargo.quantity(ORE), 0)
	assert_eq(wallet.credits(), BalanceEconomy.STARTING_CREDITS)

	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_eq(wallet.credits(), 777)
	assert_eq(cargo.quantity(ORE), 4)
	assert_eq(cargo.quantity(LUXURIES), 1)
	assert_eq(cargo.quantity(GRAIN), 3)


func test_wallet_and_cargo_only_through_services() -> void:
	# Smoke: buy/sell mutate only via CargoService + WalletService (not free sets).
	var host: Node = Node.new()
	add_child_autofree(host)

	var dock: FakeDock = FakeDock.new()
	host.add_child(dock)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	wallet.reset()
	cargo.reset()
	var start_credits: int = wallet.credits()
	var start_qty: int = cargo.quantity(SCRAP)

	EventBus.on_trade_buy_requested.emit(SCRAP, 1)
	await get_tree().process_frame
	assert_eq(cargo.quantity(SCRAP), start_qty + 1)
	assert_lt(wallet.credits(), start_credits)

	EventBus.on_trade_sell_requested.emit(SCRAP, 1)
	await get_tree().process_frame
	assert_eq(cargo.quantity(SCRAP), start_qty)


## Cheapest dock to buy this good at and dearest dock to sell it at, with the
## per-unit margin between them. Empty when nowhere trades it. Docks whose
## controller restricts the good are skipped — a route the law refuses is not a
## route (E3.3).
func _best_route(commodity_id: StringName) -> Dictionary:
	var commodity: Commodity = ContentLibrary.item(commodity_id) as Commodity
	if commodity == null:
		return {}
	var buy_at: StringName = &""
	var sell_at: StringName = &""
	var best_buy: int = 0
	var best_sell: int = 0
	for station_id: StringName in ContentLibrary.ids_in(BalanceMarket.STATION_CONTENT_CATEGORY):
		if not MarketService.trades(station_id, commodity_id):
			continue
		var station: Station = ContentLibrary.item(station_id) as Station
		if station == null or commodity.is_contraband_for(station.controller_entity_id):
			continue
		var buy_price: int = MarketService.unit_buy_price(station_id, commodity_id)
		var sell_price: int = MarketService.unit_sell_price(station_id, commodity_id)
		assert_gte(buy_price, BalanceEconomy.TRADE_PRICE_MIN)
		assert_gte(sell_price, BalanceEconomy.TRADE_PRICE_MIN)
		if String(buy_at).is_empty() or buy_price < best_buy:
			best_buy = buy_price
			buy_at = station_id
		if sell_price > best_sell:
			best_sell = sell_price
			sell_at = station_id
	if String(buy_at).is_empty() or String(sell_at).is_empty():
		return {}
	return {
		&"commodity": commodity_id,
		&"buy_at": buy_at,
		&"sell_at": sell_at,
		&"margin": best_sell - best_buy,
	}


## The widest per-unit margin anywhere in the live sector, across two different
## docks. Empty when the sector carries no profitable route at all.
func _best_sector_route() -> Dictionary:
	var best: Dictionary = {}
	var best_margin: int = 0
	for commodity_id: StringName in ContentLibrary.ids_in(
		BalanceEconomy.COMMODITY_CONTENT_CATEGORY
	):
		var route: Dictionary = _best_route(commodity_id)
		if route.is_empty():
			continue
		var margin: int = route[&"margin"]
		var buy_at: StringName = route[&"buy_at"]
		var sell_at: StringName = route[&"sell_at"]
		if margin <= best_margin or buy_at == sell_at:
			continue
		best_margin = margin
		best = route
	return best


## Stock as a fraction of this market's own price-neutral target.
func _fill(station_id: StringName, commodity_id: StringName) -> float:
	var target: float = MarketService.target_stock(station_id, commodity_id)
	if target <= 0.0:
		return 0.0
	return MarketService.stock_exact(station_id, commodity_id) / target
