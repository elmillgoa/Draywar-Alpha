extends GutTest

## The player's half of the economy simulator — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2 + §5.5–§5.6, docs/economy_sim.md §5–§6, §10
##
## Everything a captain can actually do to a market: buy and sell through
## CargoService at the docked **station**, get charged the ladder price rather
## than a flat one, run into the station's weight caps, move the price by
## clearing a shelf, and leave exactly one row in the money telemetry log.
##
## Nothing here asserts a credit amount. The other half of S2 is still tuning
## production and freight, so every check is a **relationship** — cheaper where
## there is more stock, dearer after you buy, total above quantity times price —
## which is what the design actually promises and what would still be true after
## any honest rebalance.

const PORT: StringName = &"station_alpha_port"
const YARD: StringName = &"station_alpha_yard"
const BETA_HUB: StringName = &"station_beta_hub"
const ALLOY: StringName = &"commodity_alloy"
const GRAIN: StringName = &"commodity_grain"
const MUNITIONS: StringName = &"commodity_munitions"
const ENTITY_REACH: StringName = &"entity_reach_authority"

const RICH_CREDITS: int = 1000000
const SMALL_TRADE: int = 4
const DRAIN_PASSES: int = 12
## A trade big enough that the ladder's climb clears integer rounding, and small
## enough that twice it still fits under the station's per-trade cap.
const LADDER_CAP_DIVISOR: int = 3

var _cargo_service: CargoService = null
var _wallet_service: WalletService = null


class FakeDock:
	extends Node
	var station: StringName = PORT

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	StandingService.reset_to_defaults()
	_delete_log_files()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	StandingService.reset_to_defaults()
	_delete_log_files()


func test_a_buy_moves_this_station_and_leaves_its_neighbour_alone() -> void:
	var dock: FakeDock = await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	var wallet: WalletService = _wallet()
	wallet.set_credits(RICH_CREDITS)

	var here_before: float = MarketService.stock_exact(YARD, ALLOY)
	var neighbour_before: float = MarketService.stock_exact(PORT, ALLOY)
	var quote: Dictionary = cargo.quote_buy(ALLOY, SMALL_TRADE)
	var quoted_units: int = quote[BalanceMarket.QUOTE_KEY_UNITS]
	var quoted_total: int = quote[BalanceMarket.QUOTE_KEY_TOTAL]
	assert_eq(quoted_units, SMALL_TRADE, "the yard can release this many alloy")
	assert_gt(quoted_total, 0)

	var credits_before: int = wallet.credits()
	assert_true(cargo.try_buy(ALLOY, SMALL_TRADE), "buy through the market")
	assert_eq(cargo.quantity(ALLOY), SMALL_TRADE)
	assert_eq(wallet.credits(), credits_before - quoted_total, "charged exactly what it quoted")
	assert_almost_eq(
		MarketService.stock_exact(YARD, ALLOY), here_before - float(SMALL_TRADE), 0.0001
	)
	assert_almost_eq(
		MarketService.stock_exact(PORT, ALLOY),
		neighbour_before,
		0.0001,
		"the other dock in the same system is untouched — stock is station-keyed"
	)
	assert_eq(dock.station, YARD)


func test_two_docks_in_one_system_price_the_same_good_by_their_own_stock() -> void:
	## The pillar: same system, same commodity, different number, and the
	## cheaper dock is always the fuller one.
	var compared: int = 0
	for commodity_id: StringName in MarketService.traded_commodity_ids(PORT):
		if not MarketService.trades(YARD, commodity_id):
			continue
		var port_fill: float = _fill(PORT, commodity_id)
		var yard_fill: float = _fill(YARD, commodity_id)
		if is_equal_approx(port_fill, yard_fill):
			continue
		var port_buy: int = MarketService.unit_buy_price(PORT, commodity_id)
		var yard_buy: int = MarketService.unit_buy_price(YARD, commodity_id)
		assert_ne(port_buy, yard_buy, "%s must not quote the same at both docks" % commodity_id)
		assert_eq(
			port_fill > yard_fill,
			port_buy < yard_buy,
			"%s: the dock holding more of it must be the cheaper one" % commodity_id
		)
		compared += 1
	assert_gt(compared, 0, "Alpha's two docks must differ on at least one shared good")


func test_the_quoted_total_is_not_quantity_times_the_unit_price() -> void:
	## docs/economy_sim.md §5: each unit is priced at the stock level it moves
	## through, so a bigger trade is worse per unit — not merely bigger.
	await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	_wallet().set_credits(RICH_CREDITS)

	var cap: int = MarketService.max_buy_units(YARD, ALLOY)
	var units: int = maxi(SMALL_TRADE, cap / LADDER_CAP_DIVISOR)
	var unit_price: int = MarketService.unit_buy_price(YARD, ALLOY)
	var small: Dictionary = cargo.quote_buy(ALLOY, units)
	var large: Dictionary = cargo.quote_buy(ALLOY, units * 2)
	var small_total: int = small[BalanceMarket.QUOTE_KEY_TOTAL]
	var large_total: int = large[BalanceMarket.QUOTE_KEY_TOTAL]
	var large_units: int = large[BalanceMarket.QUOTE_KEY_UNITS]

	assert_eq(large_units, units * 2, "the cap must leave room for the doubled trade")
	assert_ne(small_total, units * unit_price, "a flat unit price would give exactly this")
	assert_gt(small_total, units * unit_price, "the ladder only ever climbs while buying")
	assert_gt(large_total, small_total * 2, "twice the units costs more than twice the credits")

	# The sell ladder runs the other way: dumping more pays less per unit.
	var small_sell: Dictionary = cargo.quote_sell(ALLOY, units)
	var large_sell: Dictionary = cargo.quote_sell(ALLOY, units * 2)
	var small_pay: int = small_sell[BalanceMarket.QUOTE_KEY_TOTAL]
	var large_pay: int = large_sell[BalanceMarket.QUOTE_KEY_TOTAL]
	assert_lt(large_pay, small_pay * 2, "twice the units pays less than twice the credits")


func test_weight_caps_refuse_an_oversized_buy_and_say_which_cap_bit() -> void:
	await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	_wallet().set_credits(RICH_CREDITS)

	var stock: int = MarketService.stock(YARD, ALLOY)
	var cap: int = MarketService.max_buy_units(YARD, ALLOY)
	assert_gt(cap, 0, "the yard trades alloy at all")
	assert_lt(cap, stock, "one captain may never clear a shelf in one trade")

	var greedy: Dictionary = cargo.quote_buy(ALLOY, cap + DRAIN_PASSES)
	var granted: int = greedy[BalanceMarket.QUOTE_KEY_UNITS]
	var capped: bool = greedy[BalanceMarket.QUOTE_KEY_CAPPED]
	var reason: StringName = greedy[BalanceMarket.QUOTE_KEY_REASON]
	assert_eq(granted, cap, "the quote is trimmed to the cap, not refused outright")
	assert_true(capped, "and it says so")
	assert_eq(reason, BalanceMarket.QUOTE_REASON_CAPPED)

	var before: float = MarketService.stock_exact(YARD, ALLOY)
	assert_false(
		cargo.try_buy(ALLOY, cap + DRAIN_PASSES), "an over-cap buy is refused, not clamped"
	)
	assert_eq(cargo.quantity(ALLOY), 0)
	assert_almost_eq(MarketService.stock_exact(YARD, ALLOY), before, 0.0001)


func test_buying_out_a_shelf_raises_the_price_and_tightens_the_next_buy() -> void:
	await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	_wallet().set_credits(RICH_CREDITS)

	var start_stock: int = MarketService.stock(YARD, ALLOY)
	var start_price: int = MarketService.unit_buy_price(YARD, ALLOY)
	var start_cap: int = MarketService.max_buy_units(YARD, ALLOY)

	# Repeated hold-sized runs: the hull only carries so much, so a real captain
	# strips a shelf over several trips, not in one click.
	var moved: int = 0
	for _trip: int in DRAIN_PASSES:
		var want: int = mini(cargo.free_volume(), MarketService.max_buy_units(YARD, ALLOY))
		if want <= 0:
			break
		assert_true(cargo.try_buy(ALLOY, want), "run %d of the buy-out" % moved)
		moved += want
		cargo.reset()
	assert_gt(moved, 0, "the buy-out must actually have moved units")

	assert_lt(MarketService.stock(YARD, ALLOY), start_stock, "the shelf is emptier")
	assert_gt(MarketService.unit_buy_price(YARD, ALLOY), start_price, "and the price is up")
	assert_lt(MarketService.max_buy_units(YARD, ALLOY), start_cap, "and the next buy is smaller")

	# With the shelf thin and the wallet fat, the station is now the binding cap.
	var row: Dictionary = cargo.trade_row(ALLOY)
	var limit: StringName = row[BalanceEconomy.TRADE_ROW_KEY_BUY_LIMIT]
	assert_eq(limit, BalanceEconomy.TRADE_LIMIT_MARKET, "the row blames the shelf, not the hold")


func test_a_sell_pays_the_quoted_total_and_fills_this_station() -> void:
	await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	var wallet: WalletService = _wallet()
	wallet.set_credits(RICH_CREDITS)

	assert_true(cargo.add(ALLOY, SMALL_TRADE))
	var stock_before: float = MarketService.stock_exact(YARD, ALLOY)
	var quote: Dictionary = cargo.quote_sell(ALLOY, SMALL_TRADE)
	var quoted_total: int = quote[BalanceMarket.QUOTE_KEY_TOTAL]
	assert_gt(quoted_total, 0)

	var credits_before: int = wallet.credits()
	assert_true(cargo.try_sell(ALLOY, SMALL_TRADE))
	assert_eq(cargo.quantity(ALLOY), 0)
	assert_eq(wallet.credits(), credits_before + quoted_total, "paid exactly what it quoted")
	assert_almost_eq(
		MarketService.stock_exact(YARD, ALLOY), stock_before + float(SMALL_TRADE), 0.0001
	)


func test_a_same_dock_round_trip_through_the_service_still_loses_credits() -> void:
	await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	var wallet: WalletService = _wallet()
	wallet.set_credits(RICH_CREDITS)
	var start: int = wallet.credits()

	assert_true(cargo.try_buy(ALLOY, SMALL_TRADE))
	assert_true(cargo.try_sell(ALLOY, SMALL_TRADE))
	assert_eq(cargo.quantity(ALLOY), 0)
	assert_lt(wallet.credits(), start, "no same-station money pump through CargoService")


func test_contraband_still_refuses_at_a_controlling_dock() -> void:
	## E3.3 law, unchanged by S2: Reach Authority restricts munitions at its own
	## pads. Grain at the same pad still trades, so the refusal is the law and
	## not a dead market; the same munitions trade fine at a Syndicate dock.
	var dock: FakeDock = await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	_wallet().set_credits(RICH_CREDITS)

	assert_true(cargo.trade_allowed_at_dock(), "standing is fine here")
	assert_true(cargo.is_restricted_at_dock(MUNITIONS), "munitions are Reach contraband")
	assert_false(cargo.can_buy(MUNITIONS, 1))
	assert_false(cargo.try_buy(MUNITIONS, 1))
	assert_true(cargo.add(MUNITIONS, 2), "the hold can still carry them")
	assert_false(cargo.can_sell(MUNITIONS, 1))
	assert_false(cargo.try_sell(MUNITIONS, 1))
	assert_eq(cargo.quantity(MUNITIONS), 2, "a refused sell leaves the hold alone")

	assert_false(cargo.is_restricted_at_dock(GRAIN))
	assert_true(cargo.try_buy(GRAIN, 1), "a legal good still trades at the same pad")

	dock.station = BETA_HUB
	assert_false(cargo.is_restricted_at_dock(MUNITIONS), "legal under the Syndicate")
	assert_true(cargo.try_sell(MUNITIONS, 2), "and the same crates sell there")


func test_hostile_standing_still_closes_the_dock_to_trade() -> void:
	await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	_wallet().set_credits(RICH_CREDITS)
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_HOSTILE_MIN)
	assert_eq(
		StandingService.tier_for(StandingService.get_entity_standing(ENTITY_REACH)),
		BalanceStanding.TIER_HOSTILE
	)

	var stock_before: float = MarketService.stock_exact(YARD, GRAIN)
	assert_false(cargo.trade_allowed_at_dock(), "Hostile closes trade")
	assert_false(cargo.can_buy(GRAIN, 1))
	assert_false(cargo.try_buy(GRAIN, 1))
	assert_true(cargo.add(GRAIN, 1))
	assert_false(cargo.try_sell(GRAIN, 1))
	assert_almost_eq(
		MarketService.stock_exact(YARD, GRAIN),
		stock_before,
		0.0001,
		"a refused trade must not touch the market either"
	)


func test_one_completed_trade_writes_exactly_one_money_row() -> void:
	## CargoService has to emit this itself: a trade moves credits through the
	## generic try_spend / add_credits path, which carries no activity tag, so
	## without it the log would show every fee and no trades (economy_sim §10).
	await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	var wallet: WalletService = _wallet()
	wallet.set_credits(RICH_CREDITS)
	var money_log: MoneyLog = MoneyLog.new()
	add_child(money_log)
	await get_tree().process_frame

	var buy_quote: Dictionary = cargo.quote_buy(ALLOY, SMALL_TRADE)
	var buy_total: int = buy_quote[BalanceMarket.QUOTE_KEY_TOTAL]
	assert_true(cargo.try_buy(ALLOY, SMALL_TRADE))
	assert_eq(money_log.row_count(), 1, "one buy is one row — not zero, not two")
	var credits_after_buy: int = wallet.credits()

	var sell_quote: Dictionary = cargo.quote_sell(ALLOY, SMALL_TRADE)
	var sell_total: int = sell_quote[BalanceMarket.QUOTE_KEY_TOTAL]
	assert_true(cargo.try_sell(ALLOY, SMALL_TRADE))
	assert_eq(money_log.row_count(), 2, "the sell adds exactly one more")

	money_log.flush()
	remove_child(money_log)
	money_log.free()

	var rows: Array[PackedStringArray] = _data_rows()
	assert_eq(rows.size(), 2)
	var buy_row: PackedStringArray = rows[0]
	assert_eq(buy_row.size(), BalanceTelemetry.CSV_COLUMN_COUNT)
	assert_eq(buy_row[1], String(BalanceTelemetry.REASON_TRADE_BUY))
	assert_eq(int(buy_row[2]), -buy_total)
	assert_eq(int(buy_row[3]), credits_after_buy)
	assert_eq(buy_row[4], String(ALLOY))
	assert_eq(int(buy_row[5]), SMALL_TRADE)
	assert_gt(int(buy_row[6]), 0, "the unit price column is filled in")
	assert_eq(buy_row[7], String(YARD), "the row names the dock, not just the system")
	assert_eq(buy_row[8], "system_alpha")

	var sell_row: PackedStringArray = rows[1]
	assert_eq(sell_row[1], String(BalanceTelemetry.REASON_TRADE_SELL))
	assert_eq(int(sell_row[2]), sell_total)
	assert_eq(sell_row[7], String(YARD))


func test_the_trade_row_names_which_of_the_three_limits_bit() -> void:
	## "The shelf only has 14" and "you cannot carry more" are different
	## sentences, so the row has to know which one is true.
	await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	var wallet: WalletService = _wallet()

	wallet.set_credits(RICH_CREDITS)
	var roomy: Dictionary = cargo.trade_row(ALLOY)
	var roomy_max: int = roomy[BalanceEconomy.TRADE_ROW_KEY_MAX_BUY]
	var roomy_limit: StringName = roomy[BalanceEconomy.TRADE_ROW_KEY_BUY_LIMIT]
	assert_eq(roomy_max, cargo.free_volume(), "a fat wallet buys exactly what the hold takes")
	assert_eq(roomy_limit, BalanceEconomy.TRADE_LIMIT_HOLD)

	wallet.set_credits(MarketService.unit_buy_price(YARD, ALLOY))
	var broke: Dictionary = cargo.trade_row(ALLOY)
	var broke_max: int = broke[BalanceEconomy.TRADE_ROW_KEY_MAX_BUY]
	var broke_limit: StringName = broke[BalanceEconomy.TRADE_ROW_KEY_BUY_LIMIT]
	assert_eq(broke_max, 1, "one unit's worth of credits buys one unit")
	assert_eq(broke_limit, BalanceEconomy.TRADE_LIMIT_CREDITS)

	wallet.set_credits(0)
	var skint: Dictionary = cargo.trade_row(ALLOY)
	var skint_max: int = skint[BalanceEconomy.TRADE_ROW_KEY_MAX_BUY]
	assert_eq(skint_max, 0)

	# Nothing aboard is a hold limit on the sell side, whatever the dock allows.
	var sell_limit: StringName = skint[BalanceEconomy.TRADE_ROW_KEY_SELL_LIMIT]
	var sell_max: int = skint[BalanceEconomy.TRADE_ROW_KEY_MAX_SELL]
	assert_eq(sell_max, 0)
	assert_eq(sell_limit, BalanceEconomy.TRADE_LIMIT_HOLD)


func test_a_dock_with_no_market_in_a_good_never_pretends_to_trade_it() -> void:
	await _dock_at(PORT)
	var cargo: CargoService = _cargo()
	_wallet().set_credits(RICH_CREDITS)

	assert_false(MarketService.trades(PORT, GRAIN), "Alpha Port keeps no grain market")
	var row: Dictionary = cargo.trade_row(GRAIN)
	var traded: bool = row[BalanceEconomy.TRADE_ROW_KEY_TRADED]
	var reason: String = row[BalanceEconomy.TRADE_ROW_KEY_REASON]
	var max_buy: int = row[BalanceEconomy.TRADE_ROW_KEY_MAX_BUY]
	assert_false(traded)
	assert_eq(reason, BalanceMarket.REASON_NO_MARKET)
	assert_eq(max_buy, 0)
	assert_false(cargo.can_buy(GRAIN, 1))
	assert_false(cargo.try_buy(GRAIN, 1))
	assert_true(cargo.can_buy(ALLOY, 1), "goods it does keep still trade here")


func test_the_station_screen_carries_the_reason_line_ticker_and_quantity_control() -> void:
	## §5.5's three gate surfaces, on the screen a docked captain actually reads.
	await _dock_at(YARD)
	var cargo: CargoService = _cargo()
	_wallet().set_credits(RICH_CREDITS)
	var menu: StationMenu = StationMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	EventBus.on_docked.emit(YARD)
	await get_tree().process_frame

	var ticker: Label = _find_label_starting_with(menu, "SECTOR")
	assert_ne(ticker, null, "one sector headline, above the scrolling body")
	assert_true(ticker.visible)
	assert_eq(ticker.text, BalanceEconomy.STATION_NEWS_PREFIX_FORMAT % MarketService.news_line())

	var reason: Label = _find_label_with_text(menu, MarketService.price_reason(YARD, ALLOY))
	assert_ne(reason, null, "the alloy row explains its own price in words")

	var amount: SpinBox = _find_spin_box(menu)
	assert_ne(amount, null, "a quantity control, not one-unit-per-click")
	assert_gt(amount.max_value, BalanceEconomy.STATION_TRADE_QTY_MIN)

	var max_buy_btn: Button = _find_button_with_text(
		menu, BalanceEconomy.STATION_TRADE_MAX_BUY_LABEL
	)
	assert_ne(max_buy_btn, null, "a Max affordance")
	assert_false(max_buy_btn.disabled)

	# The action buttons carry the live total for the amount currently chosen.
	var one_unit: Dictionary = cargo.quote_buy(ALLOY, 1)
	var one_total: int = one_unit[BalanceMarket.QUOTE_KEY_TOTAL]
	var buy_btn: Button = _find_button_with_text(
		menu, BalanceEconomy.STATION_TRADE_BUY_FORMAT % [1, one_total]
	)
	assert_ne(buy_btn, null, "the Buy button shows what this trade costs, from the quote")
	EventBus.on_undocked.emit(YARD)


# --- fixture ----------------------------------------------------------------


## Dock, wallet and cargo wired under one host, docked at `station_id`. The
## services are kept as references rather than looked up by group, so a fixture
## still awaiting free from the previous test can never be picked up by mistake.
func _dock_at(station_id: StringName) -> FakeDock:
	var host: Node = Node.new()
	add_child_autofree(host)
	var dock: FakeDock = FakeDock.new()
	dock.station = station_id
	host.add_child(dock)
	_wallet_service = WalletService.new()
	host.add_child(_wallet_service)
	_cargo_service = CargoService.new()
	host.add_child(_cargo_service)
	await get_tree().process_frame
	_wallet_service.reset()
	_cargo_service.reset()
	return dock


func _cargo() -> CargoService:
	return _cargo_service


func _wallet() -> WalletService:
	return _wallet_service


## Stock as a fraction of this market's own price-neutral target.
func _fill(station_id: StringName, commodity_id: StringName) -> float:
	var target: float = MarketService.target_stock(station_id, commodity_id)
	if target <= 0.0:
		return 0.0
	return MarketService.stock_exact(station_id, commodity_id) / target


func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label:
		var label: Label = node as Label
		if label.text == text:
			return label
	for child: Node in node.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null


func _find_label_starting_with(node: Node, prefix: String) -> Label:
	if node is Label:
		var label: Label = node as Label
		if label.text.begins_with(prefix):
			return label
	for child: Node in node.get_children():
		var found: Label = _find_label_starting_with(child, prefix)
		if found != null:
			return found
	return null


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button:
		var button: Button = node as Button
		if button.text == text:
			return button
	for child: Node in node.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func _find_spin_box(node: Node) -> SpinBox:
	if node is SpinBox:
		return node as SpinBox
	for child: Node in node.get_children():
		var found: SpinBox = _find_spin_box(child)
		if found != null:
			return found
	return null


func _delete_log_files() -> void:
	if FileAccess.file_exists(BalanceTelemetry.LOG_PATH):
		DirAccess.remove_absolute(BalanceTelemetry.LOG_PATH)
	if FileAccess.file_exists(BalanceTelemetry.ROTATED_PATH):
		DirAccess.remove_absolute(BalanceTelemetry.ROTATED_PATH)


func _data_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(BalanceTelemetry.LOG_PATH, FileAccess.READ)
	if file == null:
		return rows
	var length: int = file.get_length()
	var first: bool = true
	while file.get_position() < length:
		var line: PackedStringArray = file.get_csv_line()
		if first:
			first = false
			continue
		rows.append(line)
	file.close()
	return rows
