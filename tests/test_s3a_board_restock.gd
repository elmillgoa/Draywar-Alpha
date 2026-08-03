extends GutTest

## Board restock on WorldClock — Steam S3a.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3a

const PORT: StringName = &"station_alpha_port"
const YARD: StringName = &"station_alpha_yard"


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	StandingService.reset_to_defaults()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	StandingService.reset_to_defaults()


func test_board_autoload_registered() -> void:
	var raw: Variant = ProjectSettings.get_setting("autoload/BoardService", "")
	assert_gt(str(raw).length(), 0, "project.godot must declare autoload/BoardService")
	assert_eq(BoardService.get_path(), NodePath("/root/BoardService"))


func test_board_step_advances_with_restock_interval() -> void:
	assert_eq(BoardService.steps_done(), 0)
	WorldClock.advance_seconds(BalanceBoard.BOARD_STEP_SECONDS - 1.0)
	assert_eq(BoardService.steps_done(), 0, "not yet a full restock step")
	WorldClock.advance_seconds(1.0)
	assert_eq(BoardService.steps_done(), 1)
	WorldClock.advance_seconds(BalanceBoard.BOARD_STEP_SECONDS * 2.0)
	assert_eq(BoardService.steps_done(), 3)


func test_jump_hours_match_live_hours_for_board_steps() -> void:
	## Same derivation as MarketService: floor(elapsed / STEP), no separate path.
	var jump_hours: float = BalanceWorldClock.JUMP_AWAY_HOURS
	WorldClockHelpers.reset_clock()
	BoardService.reset()
	WorldClock.advance_hours(jump_hours)
	var jump_steps: int = BoardService.steps_done()

	WorldClockHelpers.reset_clock()
	BoardService.reset()
	WorldClock.advance_seconds(jump_hours * BalanceWorldClock.SECONDS_PER_HOUR)
	var live_steps: int = BoardService.steps_done()
	assert_eq(jump_steps, live_steps)
	var expected: int = floori(
		(jump_hours * BalanceWorldClock.SECONDS_PER_HOUR) / BalanceBoard.BOARD_STEP_SECONDS
	)
	assert_eq(jump_steps, expected)


func test_board_lists_offers_and_restock_can_change_ids() -> void:
	var first: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(first.size(), 0, "controller dock always has board stock")
	assert_lte(first.size(), BalanceBoard.BOARD_SLOTS_PER_STATION)

	var first_ids: PackedStringArray = PackedStringArray()
	for id: StringName in first:
		first_ids.append(String(id))
	first_ids.sort()

	WorldClock.advance_seconds(BalanceBoard.BOARD_STEP_SECONDS)
	var second: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(second.size(), 0)
	var second_ids: PackedStringArray = PackedStringArray()
	for id: StringName in second:
		second_ids.append(String(id))
	second_ids.sort()
	# Step is embedded in instance ids — restock must mint a new cycle.
	assert_ne("\n".join(first_ids), "\n".join(second_ids), "restock changes offer ids")


func test_claim_removes_offer_until_restock() -> void:
	var ids: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(ids.size(), 0)
	var first_id: StringName = ids[0]
	assert_true(BoardService.claim_offer(first_id))
	assert_false(BoardService.is_offer_available(first_id))
	var after: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_false(after.has(first_id))
	# New restock cycle clears claims.
	WorldClock.advance_seconds(BalanceBoard.BOARD_STEP_SECONDS)
	var restocked: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(restocked.size(), 0)


func test_station_dock_queries_uses_board_ids() -> void:
	var offered: Array[StringName] = StationDockQueries.offered_templates(PORT)
	assert_gt(offered.size(), 0)
	for id: StringName in offered:
		# Board instance ids, not raw ContentLibrary dump of every controller job.
		assert_true(
			String(id).begins_with("board_") or String(id).begins_with("rad_"),
			"board id shape: %s" % id
		)


func test_boards_save_round_trip_steps_and_claims() -> void:
	WorldClock.advance_seconds(BalanceBoard.BOARD_STEP_SECONDS * 2.0)
	var ids: Array[StringName] = BoardService.offer_ids_for_station(YARD)
	assert_gt(ids.size(), 0)
	var claimed: StringName = ids[0]
	assert_true(BoardService.claim_offer(claimed))
	var section: Dictionary = BoardService.to_section()
	var steps_raw: Variant = section[BalanceBoard.SAVE_KEY_STEPS]
	var steps_saved: int = 0
	if typeof(steps_raw) == TYPE_INT:
		steps_saved = steps_raw
	assert_eq(steps_saved, 2)

	BoardService.reset()
	WorldClockHelpers.reset_clock()
	# Restore clock first (CareerSave order), then boards.
	WorldClock.advance_seconds(BalanceBoard.BOARD_STEP_SECONDS * 2.0)
	BoardService.apply_section(section)
	assert_eq(BoardService.steps_done(), 2)
	assert_false(BoardService.is_offer_available(claimed), "claim survives mid-cycle save")


func test_board_offer_accept_via_mission_service() -> void:
	## Live board id → MissionService.accept → active + claim removes offer.
	## A no-op accept would leave has_active false and the offer still listed.
	BoardService.reset()
	BoardService.catch_up()
	var ids: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_gt(ids.size(), 0, "Alpha Port must list work after reset/catch_up")
	# Prefer non-smuggle so accept does not need a cargo hold in this unit test.
	var offer_id: StringName = &""
	for candidate: StringName in ids:
		var snap: Dictionary = BoardService.get_offer(candidate)
		if snap.is_empty():
			continue
		if (
			str(snap.get(BalanceBoard.OFFER_KEY_KIND, ""))
			== String(BalanceStanding.MISSION_KIND_SMUGGLE)
		):
			continue
		offer_id = candidate
		break
	assert_false(String(offer_id).is_empty(), "board must list a non-smuggle accept path")
	assert_true(BoardService.is_offer_available(offer_id))
	var offer: Dictionary = BoardService.get_offer(offer_id)
	assert_false(offer.is_empty(), "board id must resolve to a full offer")

	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	assert_false(mission.has_active())
	assert_true(mission.accept(offer_id), "accept must take a real board instance id")
	assert_true(mission.has_active(), "accept must open the one active mission slot")
	assert_eq(mission.active_template_id(), offer_id)
	assert_false(BoardService.is_offer_available(offer_id), "accept claims the board row")
	var after: Array[StringName] = BoardService.offer_ids_for_station(PORT)
	assert_false(after.has(offer_id), "claimed offer gone until restock")
