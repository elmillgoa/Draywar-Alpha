extends GutTest

## E3.3 contraband jurisdiction — munitions restricted for Reach Authority.
##
## Implements: docs/BETA_E3_ECONOMY.md E3.3 / locked D3

const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_BETA: StringName = &"entity_beta_syndicate"
const STATION_ALPHA: StringName = &"station_alpha_port"
const STATION_YARD: StringName = &"station_alpha_yard"
const STATION_BETA: StringName = &"station_beta_hub"
const MUNITIONS: StringName = &"commodity_munitions"
const GRAIN: StringName = &"commodity_grain"


class FakeDock:
	extends Node
	var station: StringName = STATION_ALPHA

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station


func after_each() -> void:
	StandingService.reset_to_defaults()


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _dict_bool(data: Dictionary, key: StringName) -> bool:
	return data.get(key, false) == true


func _dict_int(data: Dictionary, key: StringName) -> int:
	return _variant_to_int(data.get(key, 0))


func _dict_float(data: Dictionary, key: StringName) -> float:
	var raw: Variant = data.get(key, 0.0)
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return as_float
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return float(as_int)
	return 0.0


func _dict_name(data: Dictionary, key: StringName) -> StringName:
	var raw: Variant = data.get(key, &"")
	if typeof(raw) == TYPE_STRING_NAME:
		var as_name: StringName = raw
		return as_name
	if typeof(raw) == TYPE_STRING:
		var as_text: String = raw
		return StringName(as_text)
	return &""


func _setup_trade(station_id: StringName) -> Dictionary:
	var host: Node = Node.new()
	add_child_autofree(host)
	var dock: FakeDock = FakeDock.new()
	dock.station = station_id
	host.add_child(dock)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	return {&"host": host, &"dock": dock, &"wallet": wallet, &"cargo": cargo}


func test_munitions_content_lists_reach_only() -> void:
	assert_true(ContentLibrary.has_item(MUNITIONS))
	var munitions: Commodity = ContentLibrary.item(MUNITIONS) as Commodity
	assert_ne(munitions, null)
	assert_eq(munitions.validation_errors().size(), 0)
	assert_true(munitions.is_contraband_for(ENTITY_REACH))
	assert_false(munitions.is_contraband_for(ENTITY_BETA))
	assert_false(munitions.is_contraband_for(Station.CONTROLLER_NOBODY))
	assert_eq(munitions.contraband_for_entity_ids.size(), 1)
	assert_eq(munitions.contraband_for_entity_ids[0], ENTITY_REACH)


func test_validation_fails_bad_contraband_lists() -> void:
	var bad_empty: Commodity = Commodity.new()
	bad_empty.id = &"commodity_test_bad_empty"
	bad_empty.display_name = "Bad Empty"
	bad_empty.base_buy_price = 10
	bad_empty.base_sell_price = 8
	bad_empty.unit_volume = 1
	bad_empty.contraband_for_entity_ids = [&""]
	var empty_problems: PackedStringArray = bad_empty.validation_errors()
	assert_gt(empty_problems.size(), 0, "empty entity id in contraband list must fail")
	var joined_empty: String = " ".join(empty_problems)
	assert_true(
		joined_empty.contains("contraband_for_entity_ids"),
		"problem should name the field: %s" % joined_empty
	)

	var bad_nobody: Commodity = Commodity.new()
	bad_nobody.id = &"commodity_test_bad_nobody"
	bad_nobody.display_name = "Bad Nobody"
	bad_nobody.base_buy_price = 10
	bad_nobody.base_sell_price = 8
	bad_nobody.unit_volume = 1
	bad_nobody.contraband_for_entity_ids = [Station.CONTROLLER_NOBODY]
	var nobody_problems: PackedStringArray = bad_nobody.validation_errors()
	assert_gt(nobody_problems.size(), 0, "nobody in contraband list must fail")

	var bad_chars: Commodity = Commodity.new()
	bad_chars.id = &"commodity_test_bad_chars"
	bad_chars.display_name = "Bad Chars"
	bad_chars.base_buy_price = 10
	bad_chars.base_sell_price = 8
	bad_chars.unit_volume = 1
	bad_chars.contraband_for_entity_ids = [&"Entity Reach!"]
	var char_problems: PackedStringArray = bad_chars.validation_errors()
	assert_gt(char_problems.size(), 0, "invalid id characters must fail")

	var bad_dup: Commodity = Commodity.new()
	bad_dup.id = &"commodity_test_bad_dup"
	bad_dup.display_name = "Bad Dup"
	bad_dup.base_buy_price = 10
	bad_dup.base_sell_price = 8
	bad_dup.unit_volume = 1
	bad_dup.contraband_for_entity_ids = [ENTITY_REACH, ENTITY_REACH]
	var dup_problems: PackedStringArray = bad_dup.validation_errors()
	assert_gt(dup_problems.size(), 0, "duplicate entity ids must fail")


func test_cannot_buy_or_sell_munitions_at_reach_stations() -> void:
	for station_id: StringName in [STATION_ALPHA, STATION_YARD]:
		var setup: Dictionary = _setup_trade(station_id)
		var wallet: WalletService = setup[&"wallet"]
		var cargo: CargoService = setup[&"cargo"]
		await get_tree().process_frame
		wallet.reset()
		cargo.reset()
		wallet.set_credits(2000)

		assert_true(cargo.trade_allowed_at_dock(), "standing trade open at %s" % station_id)
		assert_true(
			cargo.is_restricted_at_dock(MUNITIONS), "munitions restricted at %s" % station_id
		)
		assert_false(cargo.can_buy(MUNITIONS, 1), "cannot buy munitions at %s" % station_id)
		assert_false(cargo.try_buy(MUNITIONS, 1), "try_buy munitions blocked at %s" % station_id)
		assert_eq(cargo.quantity(MUNITIONS), 0)

		assert_true(cargo.add(MUNITIONS, 2), "hold can still carry munitions")
		assert_false(cargo.can_sell(MUNITIONS, 1), "cannot sell munitions at %s" % station_id)
		assert_false(cargo.try_sell(MUNITIONS, 1), "try_sell munitions blocked at %s" % station_id)
		assert_eq(cargo.quantity(MUNITIONS), 2, "hold unchanged after blocked sell")

		# Legal goods still trade at Reach.
		assert_false(cargo.is_restricted_at_dock(GRAIN))
		assert_true(cargo.can_buy(GRAIN, 1), "grain still buyable at Reach")
		assert_true(cargo.try_buy(GRAIN, 1))
		assert_eq(cargo.quantity(GRAIN), 1)


func test_can_trade_munitions_at_non_reach_dock() -> void:
	var setup: Dictionary = _setup_trade(STATION_BETA)
	var wallet: WalletService = setup[&"wallet"]
	var cargo: CargoService = setup[&"cargo"]
	await get_tree().process_frame
	wallet.reset()
	cargo.reset()
	wallet.set_credits(2000)

	assert_false(cargo.is_restricted_at_dock(MUNITIONS), "legal at Beta Hub")
	assert_true(cargo.can_buy(MUNITIONS, 1))
	assert_true(cargo.try_buy(MUNITIONS, 1))
	assert_eq(cargo.quantity(MUNITIONS), 1)
	assert_true(cargo.can_sell(MUNITIONS, 1))
	assert_true(cargo.try_sell(MUNITIONS, 1))
	assert_eq(cargo.quantity(MUNITIONS), 0)


func test_reach_dock_inspection_fine_standing_seize() -> void:
	var setup: Dictionary = _setup_trade(STATION_ALPHA)
	var wallet: WalletService = setup[&"wallet"]
	var cargo: CargoService = setup[&"cargo"]
	await get_tree().process_frame
	wallet.reset()
	cargo.reset()
	StandingService.reset_to_defaults()
	wallet.set_credits(500)
	assert_true(cargo.add(MUNITIONS, 3))
	assert_true(cargo.add(GRAIN, 2))
	var credits_before: int = wallet.credits()
	var standing_before: float = StandingService.get_entity_standing(ENTITY_REACH)

	var result: Dictionary = cargo.inspect_on_dock()
	assert_true(_dict_bool(result, &"found"))
	assert_eq(_dict_int(result, &"fine_paid"), BalanceEconomy.CONTRABAND_FINE_BASE)
	assert_eq(wallet.credits(), credits_before - BalanceEconomy.CONTRABAND_FINE_BASE)
	assert_eq(_dict_name(result, &"entity_id"), ENTITY_REACH)
	assert_eq(_dict_name(result, &"station_id"), STATION_ALPHA)
	assert_eq(_dict_int(result, &"seized_units"), 3)
	assert_eq(cargo.quantity(MUNITIONS), 0, "munitions seized")
	assert_eq(cargo.quantity(GRAIN), 2, "legal cargo kept")
	assert_eq(StandingService.last_delta_reason, BalanceStanding.REASON_CONTRABAND)
	var standing_after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(
		standing_after, standing_before + BalanceStanding.CONTRABAND_STANDING_DELTA, 0.001
	)
	assert_almost_eq(
		_dict_float(result, &"standing_delta"), BalanceStanding.CONTRABAND_STANDING_DELTA, 0.001
	)


func test_inspection_partial_fine_when_broke_still_seizes_and_hits_standing() -> void:
	var setup: Dictionary = _setup_trade(STATION_ALPHA)
	var wallet: WalletService = setup[&"wallet"]
	var cargo: CargoService = setup[&"cargo"]
	await get_tree().process_frame
	wallet.reset()
	cargo.reset()
	StandingService.reset_to_defaults()
	wallet.set_credits(25)
	assert_true(cargo.add(MUNITIONS, 1))
	var standing_before: float = StandingService.get_entity_standing(ENTITY_REACH)

	var result: Dictionary = cargo.inspect_on_dock()
	assert_true(_dict_bool(result, &"found"))
	assert_eq(_dict_int(result, &"fine_paid"), 25)
	assert_eq(wallet.credits(), 0)
	assert_eq(cargo.quantity(MUNITIONS), 0)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		standing_before + BalanceStanding.CONTRABAND_STANDING_DELTA,
		0.001
	)


func test_non_reach_dock_does_not_inspect_munitions() -> void:
	var setup: Dictionary = _setup_trade(STATION_BETA)
	var wallet: WalletService = setup[&"wallet"]
	var cargo: CargoService = setup[&"cargo"]
	await get_tree().process_frame
	wallet.reset()
	cargo.reset()
	StandingService.reset_to_defaults()
	wallet.set_credits(500)
	assert_true(cargo.add(MUNITIONS, 2))
	var credits_before: int = wallet.credits()
	var standing_before: float = StandingService.get_entity_standing(ENTITY_REACH)
	var beta_before: float = StandingService.get_entity_standing(ENTITY_BETA)

	var result: Dictionary = cargo.inspect_on_dock()
	assert_false(_dict_bool(result, &"found"))
	assert_eq(wallet.credits(), credits_before)
	assert_eq(cargo.quantity(MUNITIONS), 2)
	assert_eq(StandingService.get_entity_standing(ENTITY_REACH), standing_before)
	assert_eq(StandingService.get_entity_standing(ENTITY_BETA), beta_before)


func test_clean_hold_no_fine_at_reach() -> void:
	var setup: Dictionary = _setup_trade(STATION_ALPHA)
	var wallet: WalletService = setup[&"wallet"]
	var cargo: CargoService = setup[&"cargo"]
	await get_tree().process_frame
	wallet.reset()
	cargo.reset()
	StandingService.reset_to_defaults()
	assert_true(cargo.add(GRAIN, 4))
	var credits_before: int = wallet.credits()
	var standing_before: float = StandingService.get_entity_standing(ENTITY_REACH)

	var result: Dictionary = cargo.inspect_on_dock()
	assert_false(_dict_bool(result, &"found"))
	assert_eq(wallet.credits(), credits_before)
	assert_eq(cargo.quantity(GRAIN), 4)
	assert_eq(StandingService.get_entity_standing(ENTITY_REACH), standing_before)


func test_save_cargo_persists_munitions_qty() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame
	cargo.reset()
	assert_true(cargo.add(MUNITIONS, 4))
	var section: Dictionary = cargo.to_section()
	assert_eq(_variant_to_int(section[String(MUNITIONS)]), 4)
	cargo.reset()
	assert_eq(cargo.quantity(MUNITIONS), 0)
	cargo.apply_section(section)
	assert_eq(cargo.quantity(MUNITIONS), 4)


func test_no_new_standing_tiers_contraband_uses_existing_writer() -> void:
	assert_eq(BalanceStanding.KNOWN_TIERS.size(), 7)
	assert_true(BalanceStanding.KNOWN_TIERS.has(BalanceStanding.TIER_NEUTRAL))
	assert_true(BalanceStanding.KNOWN_TIERS.has(BalanceStanding.TIER_UNFRIENDLY))
	# Reason tag exists; single writer remains StandingService.apply_entity_delta.
	assert_eq(String(BalanceStanding.REASON_CONTRABAND), "contraband")
	assert_eq(BalanceEconomy.CONTRABAND_FINE_BASE, 100)
	assert_true(BalanceEconomy.CONTRABAND_SEIZE_ALL)
	assert_eq(BalanceStanding.CONTRABAND_STANDING_DELTA, -10.0)


func test_status_moment_still_fires_on_dock_unchanged_shape() -> void:
	# Status moment shape keys must still exist; inspection must not replace it.
	var status: Dictionary = StandingService.status_for_station(STATION_ALPHA)
	assert_true(status.has(StandingService.STATUS_KEY_ENTITY_ID))
	assert_true(status.has(StandingService.STATUS_KEY_STANDING))
	assert_true(status.has(StandingService.STATUS_KEY_TIER))
	assert_true(status.has(StandingService.STATUS_KEY_LINE))
	assert_eq(_dict_name(status, StandingService.STATUS_KEY_ENTITY_ID), ENTITY_REACH)
