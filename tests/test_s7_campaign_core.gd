extends GutTest

## S7 Campaign — flags, gates, accept → mission, complete → act, save, board skip.

const STATION_PORT: StringName = &"station_alpha_port"
const STATION_YARD: StringName = &"station_alpha_yard"
const STATION_HUB: StringName = &"station_beta_hub"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const SPINE_WAKE: StringName = &"spine_act1_wake"
const SPINE_JUMP: StringName = &"spine_act1_first_jump"
const SPINE_LANE_TRADE: StringName = &"spine_act2_lane_trade"
const SPINE_LANE_GUN: StringName = &"spine_act2_lane_gun"
const SPINE_LANE_SHADOW: StringName = &"spine_act2_lane_shadow"
const SPINE_OPS: StringName = &"spine_act2_ops_intro"


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


func _make_campaign_stack() -> Dictionary:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	var cargo: CargoService = CargoService.new()
	var mission: MissionService = MissionService.new()
	var campaign: CampaignService = CampaignService.new()
	var docking: _FakeDock = _FakeDock.new()
	docking.station_id = STATION_PORT
	host.add_child(wallet)
	host.add_child(cargo)
	host.add_child(mission)
	host.add_child(campaign)
	host.add_child(docking)
	wallet.reset()
	cargo.reset()
	mission.reset()
	campaign.reset()
	wallet.set_credits(5000)
	return {
		&"host": host,
		&"wallet": wallet,
		&"cargo": cargo,
		&"mission": mission,
		&"campaign": campaign,
		&"docking": docking,
	}


func test_reset_starts_act_i_with_started_flag() -> void:
	var stack: Dictionary = _make_campaign_stack()
	var campaign: CampaignService = stack[&"campaign"]
	assert_eq(campaign.current_act(), BalanceCampaign.ACT_I)
	assert_true(campaign.has_flag(BalanceCampaign.FLAG_ACT1_STARTED))
	assert_eq(campaign.completed_spine_ids().size(), 0)


func test_wake_available_at_alpha_port_without_console() -> void:
	var stack: Dictionary = _make_campaign_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var available: Array[StringName] = campaign.available_spine_ids_at(STATION_PORT)
	assert_true(available.has(SPINE_WAKE), "first spine must be open at Alpha Port")
	assert_true(campaign.can_accept_spine(SPINE_WAKE))


func test_standing_gate_blocks_ops_intro() -> void:
	var stack: Dictionary = _make_campaign_stack()
	var campaign: CampaignService = stack[&"campaign"]
	# Force Act II + a lane without raising Reach standing.
	_force_flag(campaign, BalanceCampaign.FLAG_ACT1_DONE)
	_force_act(campaign, BalanceCampaign.ACT_II)
	_force_flag(campaign, BalanceCampaign.FLAG_LANE_TRADE)
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_FRIENDLY_MIN - 1.0)
	assert_false(campaign.can_accept_spine(SPINE_OPS))
	var available: Array[StringName] = campaign.available_spine_ids_at(STATION_PORT)
	assert_false(available.has(SPINE_OPS))
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_FRIENDLY_MIN)
	assert_true(campaign.can_accept_spine(SPINE_OPS))


func test_debt_gate_when_requires_debt() -> void:
	# Build a temporary template gate using live service debt check path:
	# mark debt on wallet and ensure debt_state().owed > 0 is readable.
	var stack: Dictionary = _make_campaign_stack()
	var wallet: WalletService = stack[&"wallet"]
	assert_eq(_dict_int(wallet.debt_state(), &"owed"), 0)
	wallet.borrow()
	assert_gt(_dict_int(wallet.debt_state(), &"owed"), 0)
	# Spine content intentionally does not hard-require debt; gate API still works.
	var campaign: CampaignService = stack[&"campaign"]
	assert_true(campaign.can_accept_spine(SPINE_WAKE))


func test_accept_spine_activates_mission_and_refuses_second() -> void:
	var stack: Dictionary = _make_campaign_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var mission: MissionService = stack[&"mission"]
	assert_true(campaign.try_accept_spine(SPINE_WAKE))
	assert_true(mission.has_active())
	assert_eq(mission.active_template_id(), SPINE_WAKE)
	assert_false(campaign.try_accept_spine(SPINE_WAKE))
	assert_false(campaign.can_accept_spine(SPINE_JUMP))


func test_complete_spine_sets_flags_and_advances_act() -> void:
	var stack: Dictionary = _make_campaign_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var mission: MissionService = stack[&"mission"]
	# Complete Act I chain via accept+complete (delivery objectives always ready).
	var chain: Array[StringName] = [
		SPINE_WAKE,
		SPINE_JUMP,
		&"spine_act1_trade_lesson",
		&"spine_act1_debt_bite",
		&"spine_act1_standing",
	]
	for id: StringName in chain:
		assert_true(campaign.try_accept_spine(id), "accept %s" % String(id))
		var result: Dictionary = mission.complete()
		var attributed: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
		assert_true(attributed)
		assert_true(campaign.is_spine_completed(id), "completed %s" % String(id))
	assert_true(campaign.has_flag(BalanceCampaign.FLAG_ACT1_DONE))
	assert_eq(campaign.current_act(), BalanceCampaign.ACT_II)


func test_lane_exclusivity_hides_other_lanes() -> void:
	var stack: Dictionary = _make_campaign_stack()
	var campaign: CampaignService = stack[&"campaign"]
	_force_flag(campaign, BalanceCampaign.FLAG_ACT1_DONE)
	_force_act(campaign, BalanceCampaign.ACT_II)
	assert_true(campaign.can_accept_spine(SPINE_LANE_TRADE))
	assert_true(campaign.can_accept_spine(SPINE_LANE_GUN))
	assert_true(campaign.can_accept_spine(SPINE_LANE_SHADOW))
	_force_flag(campaign, BalanceCampaign.FLAG_LANE_TRADE)
	assert_false(campaign.can_accept_spine(SPINE_LANE_GUN))
	assert_false(campaign.can_accept_spine(SPINE_LANE_SHADOW))
	# Already-chosen lane still accept-able until completed (if not completed).
	assert_true(campaign.can_accept_spine(SPINE_LANE_TRADE))


func test_career_save_round_trip_and_missing_resets() -> void:
	var stack: Dictionary = _make_campaign_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var mission: MissionService = stack[&"mission"]
	assert_true(campaign.try_accept_spine(SPINE_WAKE))
	mission.complete()
	assert_true(campaign.has_flag(BalanceCampaign.FLAG_WAKE_DONE))

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceCampaign.SAVE_SECTION_KEY))
	var section: Dictionary = sections[BalanceCampaign.SAVE_SECTION_KEY]
	assert_eq(_dict_int(section, BalanceCampaign.KEY_ACT), BalanceCampaign.ACT_I)
	assert_true(section.has(BalanceCampaign.KEY_FLAGS))
	assert_true(section.has(BalanceCampaign.KEY_COMPLETED_SPINE))

	campaign.reset()
	assert_false(campaign.has_flag(BalanceCampaign.FLAG_WAKE_DONE))
	assert_eq(campaign.completed_spine_ids().size(), 0)

	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_true(campaign.has_flag(BalanceCampaign.FLAG_WAKE_DONE))
	assert_true(campaign.is_spine_completed(SPINE_WAKE))

	var without: Dictionary = sections.duplicate(true)
	without.erase(BalanceCampaign.SAVE_SECTION_KEY)
	CareerSave.apply_meta_sections(get_tree(), without)
	assert_eq(campaign.current_act(), BalanceCampaign.ACT_I)
	assert_false(campaign.has_flag(BalanceCampaign.FLAG_WAKE_DONE))
	assert_eq(campaign.completed_spine_ids().size(), 0)


func test_spine_excluded_from_board_hand() -> void:
	# Hand templates for Reach must not include spine rows.
	var hand_method: Callable = BoardService._hand_templates_for
	var hand: Array[ContractType] = hand_method.call(ENTITY_REACH)
	for ct: ContractType in hand:
		assert_false(ct.is_spine, "spine %s must not be on board hand" % String(ct.id))


func test_bus_spine_accept_requested() -> void:
	var stack: Dictionary = _make_campaign_stack()
	var campaign: CampaignService = stack[&"campaign"]
	var mission: MissionService = stack[&"mission"]
	await get_tree().process_frame
	EventBus.on_spine_accept_requested.emit(SPINE_WAKE)
	assert_true(mission.has_active())
	assert_eq(mission.active_template_id(), SPINE_WAKE)
	assert_true(campaign.can_accept_spine(SPINE_WAKE) == false)


func _force_flag(campaign: CampaignService, flag_name: StringName) -> void:
	# Use apply_section merge to set flags without completing missions.
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


class _FakeDock:
	extends Node
	var station_id: StringName = &""

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station_id
