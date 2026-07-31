extends GutTest

## E1.4 trade contrast + money pressure.
##
## Implements: docs/BETA_E1_LEGIBLE_SECTOR.md E1.4

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"

const STATION_ALPHA: StringName = &"station_alpha_port"
const STATION_GAMMA: StringName = &"station_gamma_outpost"

const GRAIN: StringName = &"commodity_grain"
const SCRAP: StringName = &"commodity_scrap"
const ORE: StringName = &"commodity_ore"
const LUXURIES: StringName = &"commodity_luxuries"
const MUNITIONS: StringName = &"commodity_munitions"
const RATIONS: StringName = &"commodity_rations"


class FakeDock:
	extends Node
	var station: StringName = STATION_ALPHA

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station


func after_each() -> void:
	StandingService.reset_to_defaults()


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


## Documented routes: buy at A < sell at B (static tables in BalanceEconomy).
func test_documented_route_profitability() -> void:
	_assert_route_profit(GRAIN, SYSTEM_ALPHA, SYSTEM_GAMMA, "Grain Alpha→Gamma")
	_assert_route_profit(SCRAP, SYSTEM_GAMMA, SYSTEM_ALPHA, "Scrap Gamma→Alpha reverse industrial")
	_assert_route_profit(ORE, SYSTEM_GAMMA, SYSTEM_ALPHA, "Ore Gamma→Alpha")
	_assert_route_profit(LUXURIES, SYSTEM_ALPHA, SYSTEM_GAMMA, "Luxuries Alpha→Gamma")
	_assert_route_profit(MUNITIONS, SYSTEM_BETA, SYSTEM_GAMMA, "Munitions Beta→Gamma")
	_assert_route_profit(RATIONS, SYSTEM_ALPHA, SYSTEM_BETA, "Rations Alpha→Beta")


func test_grain_and_scrap_spreads_clearer() -> void:
	var grain: Commodity = ContentLibrary.item(GRAIN) as Commodity
	var scrap: Commodity = ContentLibrary.item(SCRAP) as Commodity
	assert_ne(grain, null)
	assert_ne(scrap, null)

	var grain_buy_a: int = BalanceEconomy.buy_price_at(grain, SYSTEM_ALPHA)
	var grain_sell_g: int = BalanceEconomy.sell_price_at(grain, SYSTEM_GAMMA)
	assert_lt(grain_buy_a, grain_sell_g)
	assert_gte(grain_sell_g - grain_buy_a, 3, "grain route should clear at least 3c/unit")

	var scrap_buy_g: int = BalanceEconomy.buy_price_at(scrap, SYSTEM_GAMMA)
	var scrap_sell_a: int = BalanceEconomy.sell_price_at(scrap, SYSTEM_ALPHA)
	assert_lt(scrap_buy_g, scrap_sell_a)
	assert_gte(scrap_sell_a - scrap_buy_g, 2, "scrap reverse route should clear at least 2c/unit")

	# Same-station still not free money.
	assert_lt(
		BalanceEconomy.sell_price_at(grain, SYSTEM_ALPHA),
		BalanceEconomy.buy_price_at(grain, SYSTEM_ALPHA)
	)


func test_buy_sell_across_systems_via_services() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	var dock: FakeDock = FakeDock.new()
	dock.station = STATION_ALPHA
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

	var grain: Commodity = ContentLibrary.item(GRAIN) as Commodity
	assert_ne(grain, null)
	var buy_alpha: int = BalanceEconomy.buy_price_at(grain, SYSTEM_ALPHA)
	assert_true(cargo.try_buy(GRAIN, 2), "buy grain at Alpha via CargoService")
	assert_eq(cargo.quantity(GRAIN), 2)
	assert_eq(wallet.credits(), start - buy_alpha * 2)

	# "Jump" to Gamma by changing docked station (static prices, no travel sim).
	dock.station = STATION_GAMMA
	var sell_gamma: int = BalanceEconomy.sell_price_at(grain, SYSTEM_GAMMA)
	assert_true(cargo.try_sell(GRAIN, 2), "sell grain at Gamma via CargoService")
	assert_eq(cargo.quantity(GRAIN), 0)
	var expected: int = start - buy_alpha * 2 + sell_gamma * 2
	assert_eq(wallet.credits(), expected)
	assert_gt(wallet.credits(), start, "Alpha→Gamma grain run should profit")


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


func _assert_route_profit(
	commodity_id: StringName, buy_system: StringName, sell_system: StringName, label: String
) -> void:
	var commodity: Commodity = ContentLibrary.item(commodity_id) as Commodity
	assert_ne(commodity, null, "%s missing for route %s" % [commodity_id, label])
	var buy_p: int = BalanceEconomy.buy_price_at(commodity, buy_system)
	var sell_p: int = BalanceEconomy.sell_price_at(commodity, sell_system)
	assert_lt(
		buy_p,
		sell_p,
		"%s: buy@%s (%d) must be < sell@%s (%d)" % [label, buy_system, buy_p, sell_system, sell_p]
	)
	assert_gte(buy_p, BalanceEconomy.TRADE_PRICE_MIN)
	assert_gte(sell_p, BalanceEconomy.TRADE_PRICE_MIN)
