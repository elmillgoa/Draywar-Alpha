extends GutTest

## S7 spine content — loads, budget, validation, requires chain.

const SPINE_IDS: Array[StringName] = [
	&"spine_act1_wake",
	&"spine_act1_first_jump",
	&"spine_act1_trade_lesson",
	&"spine_act1_debt_bite",
	&"spine_act1_standing",
	&"spine_act2_lane_trade",
	&"spine_act2_lane_gun",
	&"spine_act2_lane_shadow",
	&"spine_act2_ops_intro",
]


func before_each() -> void:
	StandingService.reset_to_defaults()


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_spine_count_and_budget() -> void:
	var all_ids: Array[StringName] = ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY)
	assert_lte(all_ids.size(), Balance.CONTENT_BUDGET[&"contract_types"])
	var spine_count: int = 0
	for id: StringName in all_ids:
		var item: ContentItem = ContentLibrary.item(id)
		if item is ContractType:
			var ct: ContractType = item as ContractType
			if ct.is_spine:
				spine_count += 1
	assert_gte(spine_count, 8, "S7 ships at least 8 spine beats")
	assert_eq(Balance.CONTENT_BUDGET[&"contract_types"], 24)


func test_all_spine_rows_valid_and_present() -> void:
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))
	for id: StringName in SPINE_IDS:
		assert_true(ContentLibrary.has_item(id), "missing %s" % String(id))
		var item: ContentItem = ContentLibrary.item(id)
		assert_true(item is ContractType)
		var ct: ContractType = item as ContractType
		assert_true(ct.is_spine)
		assert_eq(ct.validation_errors().size(), 0, "spine %s invalid" % String(id))
		assert_false(ct.journal_blurb.strip_edges().is_empty())
		assert_false(String(ct.offer_station_id).is_empty())
		assert_true(ct.spine_act == 1 or ct.spine_act == 2)


func test_requires_chain_completable_in_order() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	var cargo: CargoService = CargoService.new()
	var mission: MissionService = MissionService.new()
	var campaign: CampaignService = CampaignService.new()
	host.add_child(wallet)
	host.add_child(cargo)
	host.add_child(mission)
	host.add_child(campaign)
	wallet.reset()
	cargo.reset()
	mission.reset()
	campaign.reset()
	wallet.set_credits(8000)

	var act1: Array[StringName] = [
		&"spine_act1_wake",
		&"spine_act1_first_jump",
		&"spine_act1_trade_lesson",
		&"spine_act1_debt_bite",
		&"spine_act1_standing",
	]
	for id: StringName in act1:
		assert_true(campaign.can_accept_spine(id), "should accept %s" % String(id))
		assert_true(campaign.try_accept_spine(id))
		# Delivery spines: complete() works without dock when objective ready.
		var result: Dictionary = mission.complete()
		var attributed: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
		assert_true(attributed)
		assert_true(campaign.is_spine_completed(id))

	assert_eq(campaign.current_act(), BalanceCampaign.ACT_II)
	assert_true(campaign.has_flag(BalanceCampaign.FLAG_ACT1_DONE))

	# Pick trade lane (delivery).
	assert_true(campaign.try_accept_spine(&"spine_act2_lane_trade"))
	var lane_result: Dictionary = mission.complete()
	var lane_ok: bool = lane_result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	assert_true(lane_ok)
	assert_true(campaign.has_flag(BalanceCampaign.FLAG_LANE_TRADE))
	assert_false(campaign.can_accept_spine(&"spine_act2_lane_gun"))
	assert_false(campaign.can_accept_spine(&"spine_act2_lane_shadow"))

	# Ops intro needs Friendly Reach.
	StandingService.set_entity_standing(
		&"entity_reach_authority", BalanceStanding.TIER_FRIENDLY_MIN
	)
	assert_true(campaign.can_accept_spine(&"spine_act2_ops_intro"))
	assert_true(campaign.try_accept_spine(&"spine_act2_ops_intro"))
	var ops_result: Dictionary = mission.complete()
	var ops_ok: bool = ops_result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	assert_true(ops_ok)
	assert_true(campaign.has_flag(BalanceCampaign.FLAG_ACT2_DONE))
	assert_eq(campaign.current_act(), BalanceCampaign.ACT_III)


func test_spine_validation_requires_fields() -> void:
	var bare: ContractType = ContractType.new()
	bare.id = &"fixture_spine_bad"
	bare.display_name = "Bad spine"
	bare.offering_entity_id = &"entity_reach_authority"
	bare.kind = BalanceStanding.MISSION_KIND_DELIVERY
	bare.is_spine = true
	var joined: String = "\n".join(bare.validation_errors())
	assert_string_contains(joined, "spine_act")
	assert_string_contains(joined, "offer_station_id")
	assert_string_contains(joined, "journal_blurb")
	bare.spine_act = 1
	bare.offer_station_id = &"station_alpha_port"
	bare.journal_blurb = "A valid journal line for the fixture."
	assert_eq(bare.validation_errors().size(), 0)
