extends GutTest

## B3 station depth + trade + money loop.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B3

const STATION_ALPHA: StringName = &"station_alpha_port"
const GRAIN: StringName = &"commodity_grain"
const ALLOY: StringName = &"commodity_alloy"


class FakeDock:
	extends Node
	var station: StringName = STATION_ALPHA

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_commodities_loaded_under_budget() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceEconomy.COMMODITY_CONTENT_CATEGORY)
	assert_gte(ids.size(), 6, "need at least 6 commodities for trade contrast")
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[BalanceEconomy.COMMODITY_CONTENT_CATEGORY])
	assert_lte(ids.size(), 10, "E1 commodity ceiling is 10")
	for id: StringName in ids:
		assert_true(ContentLibrary.has_item(id))
		var item: ContentItem = ContentLibrary.item(id)
		assert_true(item is Commodity, "%s must be Commodity" % id)
		var commodity: Commodity = item as Commodity
		assert_gt(commodity.base_buy_price, 0)
		assert_gt(commodity.base_sell_price, 0)
		assert_gt(commodity.unit_volume, 0)


func test_content_library_validates_commodity_files() -> void:
	var problems: PackedStringArray = ContentLibrary.problems()
	for problem: String in problems:
		assert_false(
			problem.contains("commodit"),
			"commodity content should not report problems: %s" % problem
		)
	var grain: Commodity = ContentLibrary.item(GRAIN) as Commodity
	assert_ne(grain, null)
	assert_eq(grain.validation_errors().size(), 0)


func test_buy_spends_credits_and_adds_cargo_when_docked() -> void:
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
	var grain: Commodity = ContentLibrary.item(GRAIN) as Commodity
	assert_ne(grain, null)

	assert_true(cargo.try_buy(GRAIN, 1), "buy should succeed when docked and funded")
	assert_eq(cargo.quantity(GRAIN), 1)
	var buy_at_alpha: int = BalanceEconomy.buy_price_at(grain, &"system_alpha")
	assert_eq(wallet.credits(), start_credits - buy_at_alpha)
	assert_eq(cargo.used_volume(), grain.unit_volume)


func test_sell_reduces_cargo_and_net_credit_change() -> void:
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
	var grain: Commodity = ContentLibrary.item(GRAIN) as Commodity
	assert_ne(grain, null)

	assert_true(cargo.try_buy(GRAIN, 1))
	assert_true(cargo.try_sell(GRAIN, 1))
	assert_eq(cargo.quantity(GRAIN), 0)
	var buy_at_alpha: int = BalanceEconomy.buy_price_at(grain, &"system_alpha")
	var sell_at_alpha: int = BalanceEconomy.sell_price_at(grain, &"system_alpha")
	var expected: int = start_credits - buy_at_alpha + sell_at_alpha
	assert_eq(wallet.credits(), expected)
	assert_ne(wallet.credits(), start_credits, "same-station round-trip must move credits")
	assert_lt(wallet.credits(), start_credits, "sell < buy so net loss on same station")


func test_cargo_section_save_round_trip() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	cargo.reset()
	assert_true(cargo.add(ALLOY, 3))
	assert_true(cargo.add(GRAIN, 2))
	var section: Dictionary = cargo.to_section()
	assert_eq(_as_int(section[String(ALLOY)]), 3)
	assert_eq(_as_int(section[String(GRAIN)]), 2)

	cargo.reset()
	assert_eq(cargo.quantity(ALLOY), 0)
	cargo.apply_section(section)
	assert_eq(cargo.quantity(ALLOY), 3)
	assert_eq(cargo.quantity(GRAIN), 2)

	# CareerSave gather/apply path.
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceEconomy.SAVE_SECTION_CARGO), "cargo section present")
	cargo.reset()
	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_eq(cargo.quantity(ALLOY), 3)
	assert_eq(cargo.quantity(GRAIN), 2)


func test_cannot_buy_when_broke_or_full_cargo() -> void:
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
	wallet.set_credits(0)
	assert_false(cargo.can_buy(GRAIN, 1))
	assert_false(cargo.try_buy(GRAIN, 1))
	assert_eq(cargo.quantity(GRAIN), 0)

	wallet.set_credits(10000)
	# Fill hold with grain (volume 1 each) up to capacity.
	var cap: int = BalanceEconomy.CARGO_CAPACITY
	assert_true(cargo.add(GRAIN, cap))
	assert_eq(cargo.free_volume(), 0)
	assert_false(cargo.can_add(GRAIN, 1))
	assert_false(cargo.can_buy(ALLOY, 1))
	assert_false(cargo.try_buy(ALLOY, 1))


func test_cannot_trade_when_not_docked() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	var dock: FakeDock = FakeDock.new()
	dock.station = &""
	host.add_child(dock)

	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	wallet.reset()
	cargo.reset()
	assert_false(cargo.try_buy(GRAIN, 1))
	assert_true(cargo.add(GRAIN, 1))
	assert_false(cargo.try_sell(GRAIN, 1))
	assert_eq(cargo.quantity(GRAIN), 1)


func test_station_menu_has_trade_section_and_theme() -> void:
	var menu: StationMenu = StationMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame

	assert_ne(menu, null)
	# Theme applied to panel.
	var panel: PanelContainer = null
	for child: Node in menu.get_children():
		panel = _find_panel(child)
		if panel != null:
			break
	assert_ne(panel, null, "StationMenu panel exists")
	assert_ne(panel.theme, null, "B1 theme non-null")

	var trade_header: Label = _find_label_with_text(menu, BalanceEconomy.STATION_SECTION_TRADE)
	assert_ne(trade_header, null, "Trade section header present")

	# Simulate dock so trade rows build.
	EventBus.on_docked.emit(STATION_ALPHA)
	await get_tree().process_frame
	var buy_btn: Button = _find_button_with_text(menu, BalanceEconomy.STATION_TRADE_BUY_LABEL)
	assert_ne(buy_btn, null, "Buy 1 button after dock")
	EventBus.on_undocked.emit(STATION_ALPHA)


func test_event_bus_trade_request_path() -> void:
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
	var start: int = wallet.credits()
	EventBus.on_trade_buy_requested.emit(GRAIN, 1)
	await get_tree().process_frame
	assert_eq(cargo.quantity(GRAIN), 1)
	assert_lt(wallet.credits(), start)
	EventBus.on_trade_sell_requested.emit(GRAIN, 1)
	await get_tree().process_frame
	assert_eq(cargo.quantity(GRAIN), 0)


func test_commodity_shape_rejects_bad_prices() -> void:
	var bad: Commodity = Commodity.new()
	bad.id = &"fixture_bad_commodity"
	bad.display_name = "Bad"
	bad.base_buy_price = 0
	bad.base_sell_price = 0
	bad.unit_volume = 0
	var problems: PackedStringArray = bad.validation_errors()
	var joined: String = "\n".join(problems)
	assert_string_contains(joined, "base_buy_price")
	assert_string_contains(joined, "base_sell_price")
	assert_string_contains(joined, "unit_volume")


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _find_panel(node: Node) -> PanelContainer:
	if node is PanelContainer:
		return node as PanelContainer
	for child: Node in node.get_children():
		var found: PanelContainer = _find_panel(child)
		if found != null:
			return found
	return null


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


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button:
		var btn: Button = node as Button
		if btn.text == text:
			return btn
	for child: Node in node.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null
