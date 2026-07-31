extends GutTest

## B5 content pack, trade contrast, recovery drama, gate prep helpers.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B5

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const STATION_ALPHA: StringName = &"station_alpha_port"
const GRAIN: StringName = &"commodity_grain"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const PERSON_MENDI: StringName = &"person_ra_mendi"
const CHAIN_MENDI: StringName = &"recovery_reach_mendi"
const DEEP_NEGATIVE: float = -70.0


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_three_systems_distinct_controllers_and_policing() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(&"star_systems")
	assert_eq(ids.size(), 3, "Alpha ships three systems")
	var controllers: Dictionary = {}
	var polices: Dictionary = {}
	for id: StringName in ids:
		var item: ContentItem = ContentLibrary.item(id)
		assert_true(item is StarSystem, "%s is StarSystem" % id)
		var system: StarSystem = item as StarSystem
		assert_false(String(system.held_by).is_empty())
		assert_ne(system.held_by, StarSystem.HELD_BY_NOBODY)
		assert_true(StarSystem.KNOWN_POLICING.has(system.policing))
		controllers[system.held_by] = true
		polices[system.policing] = true
		assert_false(system.flavor_line.is_empty(), "%s has flavor for place feel" % id)
	assert_eq(controllers.size(), 3, "three distinct controllers")
	assert_eq(polices.size(), 3, "patrolled / contested / lawless all present")
	assert_true(ContentLibrary.has_item(SYSTEM_ALPHA))
	assert_true(ContentLibrary.has_item(SYSTEM_BETA))
	assert_true(ContentLibrary.has_item(SYSTEM_GAMMA))


func test_three_contract_destinations_span_systems() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY)
	assert_gte(ids.size(), 3, "at least original three courier templates")
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[BalanceStanding.MISSION_CONTENT_CATEGORY])
	var destinations: Dictionary = {}
	var offering: Dictionary = {}
	for id: StringName in ids:
		var item: ContentItem = ContentLibrary.item(id)
		assert_true(item is ContractType)
		var contract: ContractType = item as ContractType
		assert_false(contract.display_name.is_empty())
		assert_false(String(contract.destination_station_id).is_empty())
		assert_true(ContentLibrary.has_item(contract.destination_station_id))
		var station: Station = ContentLibrary.item(contract.destination_station_id) as Station
		assert_ne(station, null)
		destinations[contract.destination_station_id] = true
		offering[contract.offering_entity_id] = true
		assert_false(String(station.system_id).is_empty())
	assert_gte(destinations.size(), 2, "jobs deliver across at least two stations")
	assert_eq(offering.size(), 3, "each system controller offers a job")


func test_commodities_budget_and_positive_prices() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(BalanceEconomy.COMMODITY_CONTENT_CATEGORY)
	assert_gte(ids.size(), 6)
	assert_lte(ids.size(), 10)
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[BalanceEconomy.COMMODITY_CONTENT_CATEGORY])
	for id: StringName in ids:
		var commodity: Commodity = ContentLibrary.item(id) as Commodity
		assert_ne(commodity, null)
		assert_gt(commodity.base_buy_price, 0)
		assert_gt(commodity.base_sell_price, 0)
		var buy_a: int = BalanceEconomy.buy_price_at(commodity, SYSTEM_ALPHA)
		var sell_a: int = BalanceEconomy.sell_price_at(commodity, SYSTEM_ALPHA)
		assert_gte(buy_a, BalanceEconomy.TRADE_PRICE_MIN)
		assert_gte(sell_a, BalanceEconomy.TRADE_PRICE_MIN)


func test_grain_sell_price_differs_by_system() -> void:
	var grain: Commodity = ContentLibrary.item(GRAIN) as Commodity
	assert_ne(grain, null)
	var sell_alpha: int = BalanceEconomy.sell_price_at(grain, SYSTEM_ALPHA)
	var sell_beta: int = BalanceEconomy.sell_price_at(grain, SYSTEM_BETA)
	var sell_gamma: int = BalanceEconomy.sell_price_at(grain, SYSTEM_GAMMA)
	assert_ne(sell_alpha, sell_gamma, "grain should pay differently Alpha vs Gamma")
	assert_gt(sell_gamma, sell_alpha, "fringe pays more for grain than Authority port")
	assert_ne(sell_alpha, sell_beta)
	var buy_alpha: int = BalanceEconomy.buy_price_at(grain, SYSTEM_ALPHA)
	var buy_gamma: int = BalanceEconomy.buy_price_at(grain, SYSTEM_GAMMA)
	assert_lt(buy_alpha, buy_gamma, "grain cheaper to buy at Alpha than Gamma")


func test_recovery_chain_and_station_surfaces_favor_person() -> void:
	var chains: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY)
	assert_eq(chains.size(), 1)
	assert_true(ContentLibrary.has_item(CHAIN_MENDI))
	var chain: RecoveryChain = ContentLibrary.item(CHAIN_MENDI) as RecoveryChain
	assert_ne(chain, null)
	assert_eq(chain.person_id, PERSON_MENDI)
	assert_eq(chain.entity_id, ENTITY_REACH)
	assert_gte(chain.steps.size(), BalanceStanding.RECOVERY_CHAIN_MIN_STEPS)

	var host: Node = Node.new()
	add_child_autofree(host)
	var recovery: RecoveryService = RecoveryService.new()
	host.add_child(recovery)
	await get_tree().process_frame
	recovery.reset()

	var menu: StationMenu = StationMenu.new()
	host.add_child(menu)
	await get_tree().process_frame

	# Neutral: favor contact still visible by name at Alpha Port.
	EventBus.on_docked.emit(STATION_ALPHA)
	await get_tree().process_frame
	var favor_btn: Button = _find_button_containing(menu, "Mendi")
	assert_ne(favor_btn, null, "favor / recovery person named on station button")
	assert_true(favor_btn.visible)

	# Deep negative: drama section header + hint without console.
	StandingService.apply_entity_delta(
		ENTITY_REACH, DEEP_NEGATIVE, BalanceStanding.REASON_MISSION_ABANDON, false
	)
	# Force refresh (entity bus already connected; re-dock to be sure).
	EventBus.on_undocked.emit(STATION_ALPHA)
	EventBus.on_docked.emit(STATION_ALPHA)
	await get_tree().process_frame

	var drama_header: Label = _find_label_with_text(
		menu, BalanceEconomy.STATION_SECTION_RECOVERY_DRAMA
	)
	assert_ne(drama_header, null, "deep-negative shows Recovery foothold header")
	var hint: Label = _find_label_containing(menu, "Mendi")
	assert_ne(hint, null, "drama hint names recovery person")
	EventBus.on_undocked.emit(STATION_ALPHA)


func test_new_game_tip_copy_and_dismiss() -> void:
	assert_false(BalanceSession.NEW_GAME_TIP_BODY.is_empty())
	assert_true(BalanceSession.NEW_GAME_TIP_BODY.contains("F"))
	assert_true(BalanceSession.NEW_GAME_TIP_BODY.contains("Esc"))
	assert_true(BalanceSession.NEW_GAME_TIP_BODY.contains("Space"))

	var tip: NewGameTip = NewGameTip.new()
	add_child_autofree(tip)
	await get_tree().process_frame
	assert_false(tip.is_open())
	tip.show_tip()
	assert_true(tip.is_open())
	assert_true(tip.visible)
	var title: Label = _find_label_with_text(tip, BalanceSession.NEW_GAME_TIP_TITLE)
	assert_ne(title, null)
	var dismiss: Button = _find_button_with_text(tip, BalanceSession.NEW_GAME_TIP_DISMISS)
	assert_ne(dismiss, null)
	dismiss.pressed.emit()
	await get_tree().process_frame
	assert_false(tip.is_open())


func test_station_flavor_present() -> void:
	for id: StringName in ContentLibrary.ids_in(&"stations"):
		var station: Station = ContentLibrary.item(id) as Station
		assert_ne(station, null)
		assert_false(station.flavor_line.is_empty(), "%s flavor" % id)


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


func _find_label_containing(node: Node, fragment: String) -> Label:
	if node is Label:
		var label: Label = node as Label
		if label.text.contains(fragment):
			return label
	for child: Node in node.get_children():
		var found: Label = _find_label_containing(child, fragment)
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


func _find_button_containing(node: Node, fragment: String) -> Button:
	if node is Button:
		var btn: Button = node as Button
		if btn.visible and btn.text.contains(fragment):
			return btn
	for child: Node in node.get_children():
		var found: Button = _find_button_containing(child, fragment)
		if found != null:
			return found
	return null
