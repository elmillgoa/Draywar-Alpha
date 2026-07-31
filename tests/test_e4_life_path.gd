extends GutTest

## E4.1 life path data + apply — content, default New Game teeth, debt mark.
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.1

const CATEGORY: StringName = BalanceStanding.LIFE_PATH_CONTENT_CATEGORY
const ENTITY_REACH: StringName = BalanceStanding.PATH_ENTITY_REACH
const ENTITY_HAULERS: StringName = BalanceStanding.PATH_ENTITY_HAULERS
const ENTITY_DRIFT: StringName = BalanceStanding.PATH_ENTITY_DRIFT
const ENTITY_FRINGE: StringName = BalanceStanding.PATH_ENTITY_FRINGE
const PERSON_WREN: StringName = BalanceStanding.PATH_PERSON_WREN
const PERSON_DACE: StringName = BalanceStanding.PATH_PERSON_DACE
const PERSON_JAX: StringName = BalanceStanding.PATH_PERSON_JAX

const OPTION_IDS: Array[StringName] = [
	&"origin_core",
	&"origin_periphery",
	&"origin_charterfall",
	&"trade_navy",
	&"trade_merchant",
	&"trade_smuggler",
	&"mark_cancelled",
	&"mark_debt",
	&"mark_clean",
]

var _status_kinds: Array[StringName] = []
var _status_entities: Array[StringName] = []
var _status_standings: Array[float] = []


func after_each() -> void:
	StandingService.reset_to_defaults()
	CareerStart.reset()
	if EventBus.on_status_moment.is_connected(_on_status_moment):
		EventBus.on_status_moment.disconnect(_on_status_moment)
	_status_kinds.clear()
	_status_entities.clear()
	_status_standings.clear()


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _variant_to_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return as_float
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	return 0.0


func _variant_to_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""


func _owed(wallet: WalletService) -> int:
	return _variant_to_int(wallet.debt_state().get(&"owed", 0))


func _lender(wallet: WalletService) -> StringName:
	return _variant_to_name(wallet.debt_state().get(&"lender_id", &""))


func _on_status_moment(
	kind: StringName,
	_place_id: StringName,
	entity_id: StringName,
	standing: float,
	_tier: StringName
) -> void:
	_status_kinds.append(kind)
	_status_entities.append(entity_id)
	_status_standings.append(standing)


func test_content_loads_nine_options_under_budget() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(CATEGORY)
	assert_eq(ids.size(), BalanceStanding.LIFE_PATH_OPTION_COUNT)
	assert_eq(Balance.CONTENT_BUDGET[CATEGORY], BalanceStanding.LIFE_PATH_OPTION_COUNT)
	assert_lte(ids.size(), Balance.CONTENT_BUDGET[CATEGORY])
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))
	for option_id: StringName in OPTION_IDS:
		assert_true(ContentLibrary.has_item(option_id), "missing %s" % option_id)
		var item: ContentItem = ContentLibrary.item(option_id)
		assert_true(item is LifePathOption, "%s is LifePathOption" % option_id)


func test_three_options_per_axis() -> void:
	var origin_count: int = 0
	var trade_count: int = 0
	var mark_count: int = 0
	for option_id: StringName in ContentLibrary.ids_in(CATEGORY):
		var option: LifePathOption = ContentLibrary.item(option_id) as LifePathOption
		assert_ne(option, null)
		assert_true(
			BalanceStanding.LIFE_PATH_AXES.has(option.axis), "%s has known axis" % option_id
		)
		if option.axis == BalanceStanding.LIFE_PATH_AXIS_ORIGIN:
			origin_count += 1
		elif option.axis == BalanceStanding.LIFE_PATH_AXIS_TRADE:
			trade_count += 1
		elif option.axis == BalanceStanding.LIFE_PATH_AXIS_MARK:
			mark_count += 1
	assert_eq(origin_count, BalanceStanding.LIFE_PATH_OPTIONS_PER_AXIS)
	assert_eq(trade_count, BalanceStanding.LIFE_PATH_OPTIONS_PER_AXIS)
	assert_eq(mark_count, BalanceStanding.LIFE_PATH_OPTIONS_PER_AXIS)


func test_content_teeth_match_balance_constants() -> void:
	var core: LifePathOption = ContentLibrary.item(&"origin_core") as LifePathOption
	assert_eq(core.entity_deltas.size(), 2)
	assert_eq(core.entity_deltas[0].target_id, ENTITY_REACH)
	assert_almost_eq(core.entity_deltas[0].delta, BalanceStanding.PATH_ORIGIN_CORE_REACH, 0.001)
	assert_eq(core.entity_deltas[1].target_id, ENTITY_HAULERS)
	assert_almost_eq(core.entity_deltas[1].delta, BalanceStanding.PATH_ORIGIN_CORE_HAULERS, 0.001)

	var periphery: LifePathOption = ContentLibrary.item(&"origin_periphery") as LifePathOption
	assert_eq(periphery.entity_deltas[0].target_id, ENTITY_FRINGE)
	assert_almost_eq(
		periphery.entity_deltas[0].delta, BalanceStanding.PATH_ORIGIN_PERIPHERY_FRINGE, 0.001
	)

	var merchant: LifePathOption = ContentLibrary.item(&"trade_merchant") as LifePathOption
	assert_eq(merchant.entity_deltas[0].target_id, ENTITY_HAULERS)
	assert_almost_eq(
		merchant.entity_deltas[0].delta, BalanceStanding.PATH_TRADE_MERCHANT_HAULERS, 0.001
	)
	assert_eq(merchant.person_deltas[0].target_id, PERSON_DACE)
	assert_almost_eq(
		merchant.person_deltas[0].delta, BalanceStanding.PATH_TRADE_MERCHANT_DACE, 0.001
	)

	var debt: LifePathOption = ContentLibrary.item(&"mark_debt") as LifePathOption
	assert_true(debt.starts_with_debt)
	var clean: LifePathOption = ContentLibrary.item(&"mark_clean") as LifePathOption
	assert_false(clean.starts_with_debt)


func test_default_apply_not_all_zero_for_haulers() -> void:
	StandingService.reset_to_defaults()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	assert_almost_eq(StandingService.get_entity_standing(ENTITY_HAULERS), 0.0, 0.001)
	CareerStart.apply_default(wallet)

	var haulers: float = StandingService.get_entity_standing(ENTITY_HAULERS)
	var fringe: float = StandingService.get_entity_standing(ENTITY_FRINGE)
	var dace: float = StandingService.get_person_standing(PERSON_DACE)
	assert_almost_eq(haulers, BalanceStanding.PATH_TRADE_MERCHANT_HAULERS, 0.001)
	assert_almost_eq(fringe, BalanceStanding.PATH_ORIGIN_PERIPHERY_FRINGE, 0.001)
	assert_almost_eq(dace, BalanceStanding.PATH_TRADE_MERCHANT_DACE, 0.001)
	assert_false(is_equal_approx(haulers, 0.0), "default New Game Free Haulers must have teeth")
	assert_eq(_owed(wallet), 0, "default clean mark has no debt")
	assert_eq(
		StandingService.last_delta_reason,
		BalanceStanding.REASON_LIFE_PATH,
		"standing writes tagged life_path"
	)


func test_debt_mark_opens_free_haulers_loan_clean_does_not() -> void:
	StandingService.reset_to_defaults()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var start_credits: int = wallet.credits()

	CareerStart.apply(
		BalanceStanding.LIFE_PATH_DEFAULT_ORIGIN,
		BalanceStanding.LIFE_PATH_DEFAULT_TRADE,
		&"mark_debt",
		wallet
	)
	assert_eq(_owed(wallet), BalanceEconomy.LOAN_REPAY_TOTAL)
	assert_eq(_lender(wallet), BalanceEconomy.LOAN_LENDER_ENTITY_ID)
	assert_eq(wallet.credits(), start_credits + BalanceEconomy.LOAN_PRINCIPAL)

	StandingService.reset_to_defaults()
	wallet.reset()
	start_credits = wallet.credits()
	CareerStart.apply_default(wallet)
	assert_eq(_owed(wallet), 0)
	assert_eq(wallet.credits(), start_credits)


func test_standing_only_via_standing_service_reason() -> void:
	StandingService.reset_to_defaults()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.apply(&"origin_charterfall", &"trade_smuggler", &"mark_cancelled", wallet)
	assert_eq(StandingService.last_delta_reason, BalanceStanding.REASON_LIFE_PATH)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		(
			BalanceStanding.PATH_ORIGIN_CHARTERFALL_REACH
			+ BalanceStanding.PATH_TRADE_SMUGGLER_REACH
			+ BalanceStanding.PATH_MARK_CANCELLED_REACH
		),
		0.001
	)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_HAULERS),
		(
			BalanceStanding.PATH_ORIGIN_CHARTERFALL_HAULERS
			+ BalanceStanding.PATH_MARK_CANCELLED_HAULERS
		),
		0.001
	)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_DRIFT),
		BalanceStanding.PATH_TRADE_SMUGGLER_DRIFT,
		0.001
	)
	assert_almost_eq(
		StandingService.get_person_standing(PERSON_WREN),
		BalanceStanding.PATH_ORIGIN_CHARTERFALL_WREN,
		0.001
	)
	assert_almost_eq(
		StandingService.get_person_standing(PERSON_JAX),
		BalanceStanding.PATH_TRADE_SMUGGLER_JAX,
		0.001
	)


func test_navy_trade_hits_reach_and_drift() -> void:
	StandingService.reset_to_defaults()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.apply(&"origin_core", &"trade_navy", &"mark_clean", wallet)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		BalanceStanding.PATH_ORIGIN_CORE_REACH + BalanceStanding.PATH_TRADE_NAVY_REACH,
		0.001
	)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_DRIFT),
		BalanceStanding.PATH_TRADE_NAVY_DRIFT,
		0.001
	)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_HAULERS),
		BalanceStanding.PATH_ORIGIN_CORE_HAULERS,
		0.001
	)


func test_path_entity_and_person_ids_exist_in_content() -> void:
	for entity_id: StringName in [ENTITY_REACH, ENTITY_HAULERS, ENTITY_DRIFT, ENTITY_FRINGE]:
		assert_true(ContentLibrary.has_item(entity_id), "entity %s" % entity_id)
		assert_true(ContentLibrary.item(entity_id) is Entity)
	for person_id: StringName in [PERSON_WREN, PERSON_DACE, PERSON_JAX]:
		assert_true(ContentLibrary.has_item(person_id), "person %s" % person_id)
		assert_true(ContentLibrary.item(person_id) is Person)


func test_emit_status_for_system_after_path() -> void:
	StandingService.reset_to_defaults()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.apply(&"origin_core", &"trade_navy", &"mark_clean", wallet)

	EventBus.on_status_moment.connect(_on_status_moment)
	StandingService.emit_status_for_system(&"system_alpha")

	assert_eq(_status_kinds.size(), 1)
	assert_eq(_status_kinds[0], BalanceStanding.STATUS_KIND_SYSTEM)
	assert_eq(_status_entities[0], ENTITY_REACH)
	assert_almost_eq(
		_status_standings[0],
		BalanceStanding.PATH_ORIGIN_CORE_REACH + BalanceStanding.PATH_TRADE_NAVY_REACH,
		0.001
	)
