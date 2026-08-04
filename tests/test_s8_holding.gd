extends GutTest

## S8 Holding — purchase gates, claim override, standing-resolved ignition, save, sandbox.

const STATION_EPSILON: StringName = &"station_epsilon_belt"
const STATION_ZETA: StringName = &"station_zeta_spur"
const STATION_PORT: StringName = &"station_alpha_port"
const ENTITY_HOLDING: StringName = &"entity_player_holding"
const ENTITY_SYNDICATE: StringName = &"entity_beta_syndicate"
const ENTITY_HAULERS: StringName = &"entity_free_haulers"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const SPINE_PAPERS_EPS: StringName = &"spine_act3_ignition_epsilon"
const SPINE_FORCE_EPS: StringName = &"spine_act3_ignition_epsilon_force"
const SPINE_PAPERS_ZETA: StringName = &"spine_act3_ignition_zeta"
const SYSTEM_EPSILON: StringName = &"system_epsilon"


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()
	MarketService.reset()
	BoardService.reset()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()


func _make_stack() -> Dictionary:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	var cargo: CargoService = CargoService.new()
	var mission: MissionService = MissionService.new()
	var campaign: CampaignService = CampaignService.new()
	var docking: _FakeDock = _FakeDock.new()
	docking.station_id = STATION_EPSILON
	host.add_child(wallet)
	host.add_child(cargo)
	host.add_child(mission)
	host.add_child(campaign)
	host.add_child(docking)
	wallet.reset()
	cargo.reset()
	mission.reset()
	campaign.reset()
	wallet.set_credits(8000)
	return {
		&"host": host,
		&"wallet": wallet,
		&"cargo": cargo,
		&"mission": mission,
		&"campaign": campaign,
		&"docking": docking,
	}


func _set_all_milestones(campaign: CampaignService) -> void:
	for flag: StringName in BalanceHolding.MILESTONE_FLAGS:
		_force_flag(campaign, flag)
	_force_act(campaign, BalanceCampaign.ACT_III)
	_force_flag(campaign, BalanceCampaign.FLAG_ACT2_DONE)


func test_cannot_purchase_with_debt() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var wallet: WalletService = stack[&"wallet"]
	_set_all_milestones(campaign)
	wallet.borrow()
	assert_gt(_dict_int(wallet.debt_state(), &"owed"), 0)
	assert_false(campaign.can_purchase_holding(STATION_EPSILON))
	assert_false(campaign.try_purchase_holding(STATION_EPSILON))
	assert_false(campaign.is_holding_claimed())


func test_cannot_purchase_without_all_milestones() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	_force_act(campaign, BalanceCampaign.ACT_III)
	_force_flag(campaign, BalanceCampaign.FLAG_HOLDING_CLAIM)
	_force_flag(campaign, BalanceCampaign.FLAG_HOLDING_POWER)
	assert_eq(campaign.milestone_count(), 2)
	assert_false(campaign.can_purchase_holding(STATION_EPSILON))
	assert_false(campaign.try_purchase_holding(STATION_EPSILON))


func test_cannot_purchase_non_candidate() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var docking: _FakeDock = stack[&"docking"]
	docking.station_id = STATION_PORT
	_set_all_milestones(campaign)
	assert_false(campaign.is_candidate_station(STATION_PORT))
	assert_false(campaign.can_purchase_holding(STATION_PORT))
	assert_false(campaign.try_purchase_holding(STATION_PORT))


func test_cannot_purchase_while_docked_elsewhere() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var docking: _FakeDock = stack[&"docking"]
	_set_all_milestones(campaign)
	docking.station_id = STATION_PORT
	assert_false(campaign.can_purchase_holding(STATION_EPSILON))


func test_purchase_spends_price_sets_claimed_override_status() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var wallet: WalletService = stack[&"wallet"]
	_set_all_milestones(campaign)
	var price: int = campaign.effective_holding_price()
	assert_eq(price, BalanceHolding.MIN_PRICE)
	var before: int = wallet.credits()
	assert_true(campaign.try_purchase_holding(STATION_EPSILON))
	assert_eq(wallet.credits(), before - price)
	assert_true(campaign.is_holding_claimed())
	assert_true(campaign.has_flag(BalanceCampaign.FLAG_HOLDING_CLAIMED))
	assert_eq(campaign.claimed_station_id(), STATION_EPSILON)
	assert_eq(StandingService.station_controller_id(STATION_EPSILON), ENTITY_HOLDING)
	var status: Dictionary = StandingService.status_for_station(STATION_EPSILON)
	var status_entity: StringName = _as_name(status.get(StandingService.STATUS_KEY_ENTITY_ID, &""))
	assert_eq(status_entity, ENTITY_HOLDING)
	var holding: Dictionary = campaign.holding_state()
	var prior: StringName = _as_name(holding.get(BalanceHolding.KEY_PRIOR_CONTROLLER, &""))
	var paid: int = _dict_int(holding, BalanceHolding.KEY_PRICE_PAID)
	assert_eq(prior, ENTITY_SYNDICATE)
	assert_eq(paid, price)


func test_standoff_papers_requires_prior_neutral() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	_set_all_milestones(campaign)
	assert_true(campaign.try_purchase_holding(STATION_EPSILON))
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_NEUTRAL_MIN)
	# Hostile prior: papers blocked, force needs Friendly backing.
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_HOSTILE_MIN)
	StandingService.set_entity_standing(ENTITY_REACH, 0.0)
	assert_false(campaign.can_accept_spine(SPINE_PAPERS_EPS))
	assert_false(campaign.can_accept_spine(SPINE_FORCE_EPS))
	# Friendly Reach backs contested fight.
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_FRIENDLY_MIN)
	assert_false(campaign.can_accept_spine(SPINE_PAPERS_EPS))
	assert_true(campaign.can_accept_spine(SPINE_FORCE_EPS))
	# Neutral prior: papers open, force closed.
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_NEUTRAL_MIN)
	assert_true(campaign.can_accept_spine(SPINE_PAPERS_EPS))
	assert_false(campaign.can_accept_spine(SPINE_FORCE_EPS))
	assert_false(campaign.can_accept_spine(SPINE_PAPERS_ZETA))


func test_papers_ignition_requires_travel_destination() -> void:
	var item: ContentItem = ContentLibrary.item(SPINE_PAPERS_EPS)
	var ct: ContractType = item as ContractType
	assert_eq(ct.kind, BalanceStanding.MISSION_KIND_DELIVERY)
	assert_ne(ct.destination_station_id, ct.offer_station_id)
	assert_eq(ct.destination_station_id, STATION_PORT)


func test_papers_ignition_completes_peaceful_epitaph() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var mission: MissionService = stack[&"mission"]
	_set_all_milestones(campaign)
	assert_true(campaign.try_purchase_holding(STATION_EPSILON))
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_NEUTRAL_MIN)
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_NEUTRAL_MIN)
	assert_true(campaign.try_accept_spine(SPINE_PAPERS_EPS))
	var result: Dictionary = mission.complete()
	var attributed: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED] == true
	assert_true(attributed)
	assert_true(campaign.has_flag(BalanceCampaign.FLAG_CAMPAIGN_COMPLETE))
	assert_true(campaign.is_holding_ignited())
	var line: String = campaign.celebration_line()
	assert_false(line.is_empty())
	assert_string_contains(line, "uncontested")


func test_force_ignition_completes_contested_epitaph() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var mission: MissionService = stack[&"mission"]
	_set_all_milestones(campaign)
	assert_true(campaign.try_purchase_holding(STATION_EPSILON))
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_FRIENDLY_MIN)
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_HOSTILE_MIN)
	assert_true(campaign.try_accept_spine(SPINE_FORCE_EPS))
	assert_false(mission.is_objective_ready())
	EventBus.on_hostile_killed.emit(SYSTEM_EPSILON, ENTITY_SYNDICATE)
	assert_true(mission.is_objective_ready())
	var result: Dictionary = mission.complete()
	var attributed: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED] == true
	assert_true(attributed)
	assert_true(campaign.is_campaign_complete())
	assert_true(campaign.is_holding_ignited())
	var line: String = campaign.celebration_line()
	assert_string_contains(line, "contested")


func test_career_save_round_trip_after_ignition() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var mission: MissionService = stack[&"mission"]
	var docking: _FakeDock = stack[&"docking"]
	docking.station_id = STATION_ZETA
	_set_all_milestones(campaign)
	assert_true(campaign.try_purchase_holding(STATION_ZETA))
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_NEUTRAL_MIN)
	# Prior for zeta is gamma collective — set Neutral for papers.
	StandingService.set_entity_standing(
		&"entity_gamma_collective", BalanceStanding.TIER_NEUTRAL_MIN
	)
	assert_true(campaign.try_accept_spine(SPINE_PAPERS_ZETA))
	mission.complete()
	assert_true(campaign.is_holding_ignited())

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	var section: Dictionary = sections[BalanceCampaign.SAVE_SECTION_KEY]
	var holding: Dictionary = section[BalanceCampaign.KEY_HOLDING]
	var ignited_saved: bool = holding.get(BalanceHolding.KEY_IGNITED, false) == true
	var claimed_saved: bool = holding.get(BalanceHolding.KEY_CLAIMED, false) == true
	assert_true(ignited_saved)
	assert_true(claimed_saved)

	campaign.reset()
	StandingService.reset_to_defaults()
	assert_false(campaign.is_holding_ignited())

	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_true(campaign.is_holding_claimed())
	assert_true(campaign.is_holding_ignited())
	assert_true(campaign.is_campaign_complete())
	assert_eq(campaign.claimed_station_id(), STATION_ZETA)
	assert_eq(StandingService.station_controller_id(STATION_ZETA), ENTITY_HOLDING)
	assert_false(campaign.celebration_line().is_empty())


func test_sandbox_systems_live_after_campaign_complete() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var mission: MissionService = stack[&"mission"]
	_set_all_milestones(campaign)
	assert_true(campaign.try_purchase_holding(STATION_EPSILON))
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_NEUTRAL_MIN)
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_NEUTRAL_MIN)
	assert_true(campaign.try_accept_spine(SPINE_PAPERS_EPS))
	mission.complete()
	assert_true(campaign.is_campaign_complete())

	# Board radiant hand still non-empty (does not gate on campaign complete).
	var hand_method: Callable = BoardService._hand_templates_for
	var hand: Array[ContractType] = hand_method.call(&"entity_reach_authority")
	assert_gt(hand.size(), 0, "sandbox: board hand must stay non-empty after ignition")
	for ct: ContractType in hand:
		assert_false(ct.is_spine)

	# Market quotes still resolve at a live dock (no campaign-complete soft-lock).
	var quote: Dictionary = MarketService.quote_buy(STATION_PORT, &"commodity_ore", 1)
	assert_true(quote.has(BalanceMarket.QUOTE_KEY_REASON))
	assert_gt(quote.size(), 0)


func test_milestones_reduce_price() -> void:
	var stack: Dictionary = _make_stack()
	var campaign: CampaignService = stack[&"campaign"]
	assert_eq(campaign.effective_holding_price(), BalanceHolding.BASE_PRICE)
	_force_flag(campaign, BalanceCampaign.FLAG_HOLDING_CLAIM)
	assert_eq(
		campaign.effective_holding_price(),
		BalanceHolding.BASE_PRICE - BalanceHolding.MILESTONE_DISCOUNT
	)
	_force_flag(campaign, BalanceCampaign.FLAG_HOLDING_POWER)
	assert_eq(
		campaign.effective_holding_price(),
		BalanceHolding.BASE_PRICE - BalanceHolding.MILESTONE_DISCOUNT * 2
	)
	_set_all_milestones(campaign)
	assert_eq(campaign.effective_holding_price(), BalanceHolding.MIN_PRICE)
	assert_eq(campaign.milestone_count(), BalanceHolding.MILESTONE_COUNT)


func test_content_entity_and_spines_valid() -> void:
	assert_true(ContentLibrary.has_item(ENTITY_HOLDING))
	var ent: ContentItem = ContentLibrary.item(ENTITY_HOLDING)
	assert_true(ent is Entity)
	var entity: Entity = ent as Entity
	assert_eq(entity.dock_refusal_threshold, BalanceStanding.STANDING_MIN)
	assert_eq(entity.validation_errors().size(), 0)
	for id: StringName in [
		BalanceHolding.SPINE_CLAIM,
		BalanceHolding.SPINE_POWER,
		BalanceHolding.SPINE_SUPPLY,
		BalanceHolding.SPINE_PROTECT,
		BalanceHolding.SPINE_PEOPLE,
		BalanceHolding.SPINE_IGNITION_EPSILON,
		BalanceHolding.SPINE_IGNITION_ZETA,
		BalanceHolding.SPINE_IGNITION_EPSILON_FORCE,
		BalanceHolding.SPINE_IGNITION_ZETA_FORCE,
	]:
		assert_true(ContentLibrary.has_item(id), "missing %s" % String(id))
		var item: ContentItem = ContentLibrary.item(id)
		var ct: ContractType = item as ContractType
		assert_true(ct.is_spine)
		assert_eq(ct.spine_act, BalanceCampaign.ACT_III)
		assert_eq(ct.validation_errors().size(), 0, "invalid %s" % String(id))


func _force_flag(campaign: CampaignService, flag_name: StringName) -> void:
	var section: Dictionary = campaign.to_section()
	var flags: Dictionary = section[BalanceCampaign.KEY_FLAGS]
	flags[String(flag_name)] = true
	section[BalanceCampaign.KEY_FLAGS] = flags
	campaign.apply_section(section)


func _force_act(campaign: CampaignService, act: int) -> void:
	var section: Dictionary = campaign.to_section()
	section[BalanceCampaign.KEY_ACT] = act
	campaign.apply_section(section)


func _dict_int(data: Dictionary, key: Variant) -> int:
	var raw: Variant = data.get(key, 0)
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float_val: float = raw
		return int(as_float_val)
	return 0


func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return StringName(str(value))


class _FakeDock:
	extends Node
	var station_id: StringName = &""

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station_id
