extends GutTest

## E1.5 enforcement lite (package A) — standing surcharge + service friction.
##
## Implements: docs/BETA_E1_LEGIBLE_SECTOR.md E1.5 option A
## Standing law: docs/reputation_and_standing.md (no new tiers/math).

const ENTITY_REACH: StringName = &"entity_reach_authority"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const STATION_ALPHA: StringName = &"station_alpha_port"
const PERSON_MENDI: StringName = &"person_ra_mendi"
const GRAIN: StringName = &"commodity_grain"
const TOLERANCE: float = 0.001

var _status_kinds: Array[StringName] = []
var _status_places: Array[StringName] = []
var _status_entities: Array[StringName] = []
var _status_tiers: Array[StringName] = []


class FakeDock:
	extends Node
	var station: StringName = STATION_ALPHA

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station


func before_each() -> void:
	_status_kinds.clear()
	_status_places.clear()
	_status_entities.clear()
	_status_tiers.clear()
	StandingService.reset_to_defaults()


func after_each() -> void:
	if EventBus.on_status_moment.is_connected(_on_status_moment):
		EventBus.on_status_moment.disconnect(_on_status_moment)
	StandingService.reset_to_defaults()


func test_unfriendly_dock_fee_exceeds_base_policing() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_UNFRIENDLY_MIN)
	var base_fee: int = BalanceEconomy.DOCK_FEE_PATROLLED
	var fee: int = wallet.dock_fee_for_system(SYSTEM_ALPHA, STATION_ALPHA)
	var expected: int = int(
		ceilf(float(base_fee) * BalanceEconomy.DOCK_FEE_STANDING_MULT_UNFRIENDLY)
	)
	assert_eq(fee, expected, "Unfriendly must surcharge dock fee")
	assert_gt(fee, base_fee)
	assert_almost_eq(
		BalanceEconomy.dock_fee_mult_for_tier(BalanceStanding.TIER_UNFRIENDLY),
		BalanceEconomy.DOCK_FEE_STANDING_MULT_UNFRIENDLY,
		TOLERANCE
	)


func test_friendly_and_neutral_dock_fee_is_base() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	var base_fee: int = BalanceEconomy.DOCK_FEE_PATROLLED
	# Default standing is Neutral (0).
	assert_eq(wallet.dock_fee_for_system(SYSTEM_ALPHA, STATION_ALPHA), base_fee)
	assert_almost_eq(
		BalanceEconomy.dock_fee_mult_for_tier(BalanceStanding.TIER_NEUTRAL),
		BalanceEconomy.DOCK_FEE_STANDING_MULT_DEFAULT,
		TOLERANCE
	)

	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_FRIENDLY_MIN)
	assert_eq(wallet.dock_fee_for_system(SYSTEM_ALPHA, STATION_ALPHA), base_fee)
	assert_eq(wallet.charge_dock_fee(SYSTEM_ALPHA, STATION_ALPHA), base_fee)


func test_hostile_denies_repair_and_trade_marks_up_refuel() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	var dock: FakeDock = FakeDock.new()
	host.add_child(dock)

	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var fuel: FuelService = FuelService.new()
	host.add_child(fuel)
	var hull: HullConditionService = HullConditionService.new()
	host.add_child(hull)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	wallet.reset()
	fuel.reset()
	hull.reset()
	cargo.reset()
	wallet.set_credits(5000)

	# Hostile band; recovery contact still open so dock would be allowed in play.
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_HOSTILE_MIN)
	assert_eq(
		StandingService.tier_for(StandingService.get_entity_standing(ENTITY_REACH)),
		BalanceStanding.TIER_HOSTILE
	)

	assert_false(
		hull.can_repair_at_station(STATION_ALPHA),
		"Hostile must refuse repair at controller station"
	)
	# Drain hull so repair would otherwise apply.
	hull.wear_condition(40.0, true)
	assert_lt(hull.condition(), BalanceEconomy.CONDITION_MAX)
	assert_false(hull.repair_full(), "repair_full must refuse when Hostile at dock")

	assert_false(cargo.trade_allowed_at_dock(), "Hostile must close trade")
	assert_false(cargo.try_buy(GRAIN, 1), "buy refused at Hostile")
	cargo.add(GRAIN, 1)
	assert_false(cargo.try_sell(GRAIN, 1), "sell refused at Hostile")

	# Refuel still allowed, but standing markup raises cost vs neutral base.
	while fuel.fuel() > 1.0:
		fuel.burn_fuel(1.0, 1.0, true)
	var room: float = BalanceEconomy.FUEL_MAX - fuel.fuel()
	var units: float = minf(BalanceEconomy.REFUEL_CHUNK, room)
	var expected_cost: int = int(
		ceilf(
			(
				units
				* BalanceEconomy.REFUEL_CREDITS_PER_UNIT
				* BalanceEconomy.SERVICE_COST_MULT_HOSTILE
			)
		)
	)
	var credits_before: int = wallet.credits()
	var added: float = fuel.refuel_chunk()
	assert_gt(added, 0.0, "Hostile still allows refuel so player can leave")
	assert_eq(wallet.credits(), credits_before - expected_cost)

	# Hated is worse on dock fee than Hostile.
	var base_fee: int = BalanceEconomy.DOCK_FEE_PATROLLED
	var hostile_fee: int = wallet.dock_fee_for_system(SYSTEM_ALPHA, STATION_ALPHA)
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_HATED_MIN)
	var hated_fee: int = wallet.dock_fee_for_system(SYSTEM_ALPHA, STATION_ALPHA)
	assert_gt(hostile_fee, base_fee)
	assert_gt(hated_fee, hostile_fee)
	assert_false(hull.can_repair_at_station(STATION_ALPHA))
	assert_false(cargo.trade_allowed_at_dock())


func test_recovery_still_available_when_deep_negative() -> void:
	# Open recovery contact for Reach keeps dock open at Hostile/Hated.
	assert_true(
		StandingService.has_open_recovery_contact_for_controller(ENTITY_REACH),
		"Alpha recovery contact must exist for Reach"
	)
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_HATED_MIN)
	assert_true(
		StandingService.can_dock_at_station(STATION_ALPHA),
		"recovery exception must keep dock open when Hated"
	)

	# Favor / talk path still reachable (personal bootstrap not closed).
	assert_false(StandingService.is_person_closed(PERSON_MENDI))
	var recovery: RecoveryService = RecoveryService.new()
	add_child_autofree(recovery)
	recovery.reset()
	var before_personal: float = StandingService.get_person_standing(PERSON_MENDI)
	EventBus.on_recovery_favor_requested.emit(PERSON_MENDI)
	var after_personal: float = StandingService.get_person_standing(PERSON_MENDI)
	assert_gt(after_personal, before_personal, "favor must still move personal standing")


func test_status_moment_still_fires_when_hostile() -> void:
	EventBus.on_status_moment.connect(_on_status_moment)
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_HOSTILE_MIN)
	EventBus.on_docked.emit(STATION_ALPHA)
	assert_eq(_status_kinds.size(), 1, "station status moment must still fire")
	assert_eq(_status_kinds[0], BalanceStanding.STATUS_KIND_STATION)
	assert_eq(_status_places[0], STATION_ALPHA)
	assert_eq(_status_entities[0], ENTITY_REACH)
	assert_eq(_status_tiers[0], BalanceStanding.TIER_HOSTILE)

	EventBus.on_system_entered.emit(SYSTEM_ALPHA)
	assert_eq(_status_kinds.size(), 2)
	assert_eq(_status_kinds[1], BalanceStanding.STATUS_KIND_SYSTEM)
	assert_eq(_status_tiers[1], BalanceStanding.TIER_HOSTILE)


func test_unfriendly_service_markup_without_denial() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var dock: FakeDock = FakeDock.new()
	host.add_child(dock)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var fuel: FuelService = FuelService.new()
	host.add_child(fuel)
	var hull: HullConditionService = HullConditionService.new()
	host.add_child(hull)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	wallet.reset()
	fuel.reset()
	hull.reset()
	cargo.reset()
	wallet.set_credits(5000)
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_UNFRIENDLY_MIN)

	assert_true(hull.can_repair_at_station(STATION_ALPHA), "Unfriendly may still repair")
	assert_true(cargo.trade_allowed_at_dock(), "Unfriendly may still trade")
	assert_almost_eq(
		BalanceEconomy.service_cost_mult_for_tier(BalanceStanding.TIER_UNFRIENDLY),
		BalanceEconomy.SERVICE_COST_MULT_UNFRIENDLY,
		TOLERANCE
	)

	while fuel.fuel() > 1.0:
		fuel.burn_fuel(1.0, 1.0, true)
	var room: float = BalanceEconomy.FUEL_MAX - fuel.fuel()
	var units: float = minf(BalanceEconomy.REFUEL_CHUNK, room)
	var expected: int = int(
		ceilf(
			(
				units
				* BalanceEconomy.REFUEL_CREDITS_PER_UNIT
				* BalanceEconomy.SERVICE_COST_MULT_UNFRIENDLY
			)
		)
	)
	var before: int = wallet.credits()
	assert_gt(fuel.refuel_chunk(), 0.0)
	assert_eq(wallet.credits(), before - expected)


func _on_status_moment(
	kind: StringName,
	place_id: StringName,
	entity_id: StringName,
	_standing: float,
	tier: StringName
) -> void:
	_status_kinds.append(kind)
	_status_places.append(place_id)
	_status_entities.append(entity_id)
	_status_tiers.append(tier)
