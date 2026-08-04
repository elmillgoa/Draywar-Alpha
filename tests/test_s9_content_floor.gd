extends GutTest

## S9 content floor — Steam §10 minimums for content-complete aim.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S9 + §10


func test_s9_live_counts_meet_floor() -> void:
	assert_eq(ContentLibrary.ids_in(&"star_systems").size(), 8)
	assert_eq(ContentLibrary.ids_in(&"stations").size(), 16)
	assert_eq(ContentLibrary.ids_in(&"entities").size(), 8)
	assert_eq(ContentLibrary.ids_in(&"people").size(), 35)
	assert_eq(ContentLibrary.ids_in(&"commodities").size(), 12)
	assert_eq(ContentLibrary.ids_in(&"recovery_chains").size(), 8)
	assert_gte(ContentLibrary.ids_in(&"contract_types").size(), 36)
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))


func test_s9_new_systems_and_powers_present() -> void:
	for system_id: StringName in [&"system_eta", &"system_theta"]:
		assert_true(ContentLibrary.has_item(system_id), "%s" % system_id)
	for entity_id: StringName in [
		&"entity_eta_consortium",
		&"entity_theta_watch",
		&"entity_lane_brokers",
	]:
		assert_true(ContentLibrary.has_item(entity_id), "%s" % entity_id)
	for commodity_id: StringName in [&"commodity_ice", &"commodity_components"]:
		assert_true(ContentLibrary.has_item(commodity_id), "%s" % commodity_id)


func test_s9_map_positions_cover_all_systems() -> void:
	for system_id: StringName in ContentLibrary.ids_in(&"star_systems"):
		assert_true(
			BalanceSession.SECTOR_MAP_NODE_POSITIONS.has(system_id),
			"%s needs a sector map node" % system_id
		)


func test_s9_flashpoint_hand_contracts_present() -> void:
	for cid: StringName in [
		&"contract_flash_ledger_1",
		&"contract_flash_ledger_2",
		&"contract_flash_watchline_1",
		&"contract_flash_watchline_2",
	]:
		assert_true(ContentLibrary.has_item(cid), "%s" % cid)
		var ct: ContractType = ContentLibrary.item(cid) as ContractType
		assert_ne(ct, null)
		assert_false(ct.is_spine, "flashpoints stay board hand, not spine")
