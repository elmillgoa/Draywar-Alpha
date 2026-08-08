extends GutTest

## Job 6 phase 2 — the campaign may dead-end, and the game must say so.
##
## Decision: Draywar Review/DECISION_campaign-dead-end.md (Elliot, 2026-08-07).
## Findings closed: #5 (ignition dual-path dead end) and IF-24 (Free Haulers
## gate every ending and owned no dock).
## Law: docs/reputation_and_standing.md — nothing here moves a threshold.
##
## Two halves:
##   * the station half — Free Haulers control Delta Yard, so their board,
##     their contacts and their recovery chains can be reached at all;
##   * the legibility half — when the last ignition route shuts, a message
##     fires at that moment, the journal gets its own word for a permanently
##     dead ending, and a merely-grindy dead end is never called finished.

const EndingStatusRef = preload("res://src/systems/campaign/CampaignEndingStatus.gd")

const STATION_YARD: StringName = &"station_delta_yard"
const STATION_EPSILON: StringName = &"station_epsilon_belt"
const STATION_ZETA: StringName = &"station_zeta_spur"
const STATION_PORT: StringName = &"station_alpha_port"

const ENTITY_HAULERS: StringName = &"entity_free_haulers"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_SYNDICATE: StringName = &"entity_beta_syndicate"
const ENTITY_GAMMA: StringName = &"entity_gamma_collective"
const ENTITY_ETA: StringName = &"entity_eta_consortium"

const PERSON_REED: StringName = &"person_fh_reed"
const PERSON_WREN: StringName = &"person_fh_wren"
const PERSON_MENDI: StringName = &"person_ra_mendi"
const PERSON_KADE: StringName = &"person_gc_kade"
const PERSON_RHEA: StringName = &"person_ec_rhea"

const SPINE_PAPERS_EPS: StringName = &"spine_act3_ignition_epsilon"
const SPINE_FORCE_EPS: StringName = &"spine_act3_ignition_epsilon_force"

const REASON_TEST: StringName = &"test_closed"

## Every dock the Act I-III spine offers work at, and who must still hold it.
## Moving one of these moves who has to tolerate the player to reach that beat.
const SPINE_DOCK_CONTROLLERS: Dictionary = {
	&"station_alpha_port": &"entity_reach_authority",
	&"station_alpha_yard": &"entity_reach_authority",
	&"station_beta_hub": &"entity_beta_syndicate",
	&"station_beta_spit": &"entity_beta_syndicate",
	&"station_delta_port": &"entity_reach_authority",
	&"station_gamma_outpost": &"entity_gamma_collective",
	&"station_epsilon_belt": &"entity_beta_syndicate",
	&"station_zeta_spur": &"entity_gamma_collective",
}

var _blocked_grades: Array[StringName] = []
var _blocked_lines: PackedStringArray = []
var _hosts: Array[Node] = []


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	StandingService.reset_to_defaults()
	MarketService.reset()
	BoardService.reset()
	_blocked_grades = []
	_blocked_lines = []
	EventBus.on_campaign_ending_blocked.connect(_on_ending_blocked)


func after_each() -> void:
	if EventBus.on_campaign_ending_blocked.is_connected(_on_ending_blocked):
		EventBus.on_campaign_ending_blocked.disconnect(_on_ending_blocked)
	# Torn down by hand, not by autofree: a CampaignService left alive into the
	# next test would still be listening to the standing bus and would emit into
	# that test's counters (docs/traps.md #15).
	for host: Node in _hosts:
		if is_instance_valid(host):
			remove_child(host)
			host.free()
	_hosts = []
	StandingService.reset_to_defaults()
	WorldClockHelpers.reset_clock()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()


func _on_ending_blocked(grade: StringName, line: String) -> void:
	_blocked_grades.append(grade)
	_blocked_lines.append(line)


# --- The station half (IF-24) -----------------------------------------------


func test_free_haulers_hold_a_dock_somewhere() -> void:
	var owned: Array[StringName] = []
	for station_id: StringName in ContentLibrary.ids_in(BalanceMarket.STATION_CONTENT_CATEGORY):
		var station: Station = ContentLibrary.item(station_id) as Station
		if station != null and station.controller_entity_id == ENTITY_HAULERS:
			owned.append(station_id)
	assert_gt(owned.size(), 0, "the endgame's offering faction must own a dock")
	assert_true(owned.has(STATION_YARD), "Delta Yard is the Free Haulers berth")


func test_free_haulers_dock_carries_a_job_board() -> void:
	var offers: Array[StringName] = BoardService.offer_ids_for_station(STATION_YARD)
	assert_gt(offers.size(), 0, "a Free Haulers dock must list work")
	var haulers_offers: int = 0
	for offer_id: StringName in offers:
		var offer: Dictionary = BoardService.get_offer(offer_id)
		var offering: StringName = StringName(
			str(offer.get(BalanceBoard.OFFER_KEY_OFFERING_ENTITY, &""))
		)
		if offering == ENTITY_HAULERS:
			haulers_offers += 1
	assert_gt(haulers_offers, 0, "board work at their dock must be Free Haulers work")


func test_free_haulers_recovery_chains_can_be_reached() -> void:
	var person: StringName = StationDockQueries.favor_person(STATION_YARD)
	assert_false(String(person).is_empty(), "a Free Haulers contact is offered at their dock")
	var item: ContentItem = ContentLibrary.item(person)
	var contact: Person = item as Person
	assert_ne(contact, null)
	assert_eq(contact.primary_entity_id, ENTITY_HAULERS)
	assert_true(StandingService.has_open_recovery_contact_for_controller(ENTITY_HAULERS))


func test_hostile_player_can_still_reach_the_hauler_yard() -> void:
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HOSTILE_MIN)
	assert_true(
		StandingService.can_dock_at_station(STATION_YARD),
		"Hostile with an open contact still docks (law section 5)"
	)
	StandingService.close_person(PERSON_REED, REASON_TEST)
	StandingService.close_person(PERSON_WREN, REASON_TEST)
	assert_false(
		StandingService.can_dock_at_station(STATION_YARD),
		"both contacts closed and Hostile: the yard shuts, and that is the hard grade"
	)


func test_giving_them_a_dock_did_not_move_the_campaign_spine() -> void:
	for raw_station: Variant in SPINE_DOCK_CONTROLLERS.keys():
		var station_id: StringName = StringName(str(raw_station))
		var expected: StringName = StringName(str(SPINE_DOCK_CONTROLLERS[raw_station]))
		var station: Station = ContentLibrary.item(station_id) as Station
		assert_ne(station, null, "%s loads" % String(station_id))
		assert_eq(
			station.controller_entity_id,
			expected,
			"%s controller must not move: a spine beat is offered there" % String(station_id)
		)
	for id: StringName in BalanceHolding.CANDIDATE_STATION_IDS:
		var candidate: Station = ContentLibrary.item(id) as Station
		assert_ne(candidate, null)
		assert_ne(
			candidate.controller_entity_id,
			ENTITY_HAULERS,
			"a Holding candidate's prior controller may not become the offerer"
		)


func test_free_haulers_entity_still_validates_with_its_new_reach() -> void:
	var haulers: Entity = ContentLibrary.item(ENTITY_HAULERS) as Entity
	assert_ne(haulers, null)
	assert_eq(haulers.validation_errors().size(), 0)
	assert_true(haulers.reach_station_ids.has(STATION_YARD))
	var reach: Entity = ContentLibrary.item(ENTITY_REACH) as Entity
	assert_ne(reach, null)
	assert_eq(reach.validation_errors().size(), 0)
	assert_false(reach.reach_station_ids.has(STATION_YARD), "the yard left Reach's reach list")


# --- The legibility half (#5) -----------------------------------------------


## THE REGRESSION TEST the definition of done names: build the double
## dock-refusal state and prove the player is told at the moment it closes.
func test_double_dock_refusal_tells_the_player_when_the_last_route_shuts() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	assert_eq(campaign.ending_grade(), BalanceCampaign.ENDING_GRADE_OPEN)

	# No Friendly personal contact left with either backing Entity.
	StandingService.close_person(PERSON_MENDI, REASON_TEST)
	StandingService.close_person(PERSON_REED, REASON_TEST)
	StandingService.close_person(PERSON_WREN, REASON_TEST)
	assert_eq(_blocked_grades.size(), 0, "nothing has closed yet")

	# Dock-refused by Reach: the force path loses one backer.
	StandingService.set_entity_standing(ENTITY_REACH, BalanceStanding.TIER_HOSTILE_MIN)
	assert_false(StandingService.can_dock_at_station(STATION_PORT))
	assert_eq(_blocked_grades.size(), 0, "papers is still open, so nothing is announced")

	# Dock-refused by Free Haulers too. They offer every ignition beat, so this
	# one write shuts papers AND force at the same instant.
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HOSTILE_MIN)
	assert_false(StandingService.can_dock_at_station(STATION_YARD))
	assert_eq(_blocked_grades.size(), 1, "told once, at the moment the last route closed")

	assert_false(campaign.can_accept_spine(SPINE_PAPERS_EPS))
	assert_false(campaign.can_accept_spine(SPINE_FORCE_EPS))
	assert_string_contains(_blocked_lines[0], "Free Haulers")
	assert_eq(campaign.ending_grade(), BalanceCampaign.ENDING_GRADE_STALLED)


func test_the_message_is_not_repeated_on_every_later_standing_change() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HOSTILE_MIN)
	assert_eq(_blocked_grades.size(), 1)
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HATED_MIN)
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_HOSTILE_MIN)
	assert_eq(_blocked_grades.size(), 1, "the edge is the news, not every point lost")
	assert_eq(campaign.ending_grade(), BalanceCampaign.ENDING_GRADE_STALLED)


func test_a_recoverable_player_is_never_told_they_are_finished() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HATED_MIN)
	assert_eq(_blocked_grades.size(), 1)
	assert_eq(
		_blocked_grades[0],
		BalanceCampaign.ENDING_GRADE_STALLED,
		"Hated with Free Haulers is a grind while their yard still takes work"
	)
	assert_eq(campaign.ending_grade(), BalanceCampaign.ENDING_GRADE_STALLED)
	assert_string_contains(_blocked_lines[0], "earned back")
	for row: Dictionary in campaign.journal_lines():
		var id: StringName = StringName(str(row.get(BalanceCampaign.JOURNAL_KEY_ID, &"")))
		if id != SPINE_PAPERS_EPS:
			continue
		var status: StringName = StringName(str(row.get(BalanceCampaign.JOURNAL_KEY_STATUS, &"")))
		assert_eq(status, BalanceCampaign.JOURNAL_STATUS_LOCKED, "a grind still reads Locked")


## The memo's hard grade: Free Haulers below the offerer floor with no way to
## work for Fringe or Eta either. Before they owned a dock this was the end of
## the campaign; their yard is the whole difference between stalled and closed.
func test_the_hauler_yard_is_what_keeps_a_stranded_player_alive() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	StandingService.close_person(PERSON_KADE, REASON_TEST)
	StandingService.close_person(PERSON_RHEA, REASON_TEST)
	StandingService.set_entity_standing(ENTITY_GAMMA, BalanceStanding.TIER_HOSTILE_MIN)
	StandingService.set_entity_standing(ENTITY_ETA, BalanceStanding.TIER_HOSTILE_MIN)
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HOSTILE_MIN)
	assert_false(EndingStatusRef.has_workable_dock(ENTITY_GAMMA), "no bleed-over from Fringe left")
	assert_false(EndingStatusRef.has_workable_dock(ENTITY_ETA), "no bleed-over from Eta left")
	assert_true(
		EndingStatusRef.has_workable_dock(ENTITY_HAULERS),
		"their own yard still takes work: an open contact docks a Hostile player"
	)
	assert_true(EndingStatusRef.can_still_earn_standing(ENTITY_HAULERS))
	assert_eq(
		campaign.ending_grade(),
		BalanceCampaign.ENDING_GRADE_STALLED,
		"with a dock of their own this is a grind, not a finished career"
	)


func test_a_truly_stuck_career_is_graded_closed_and_says_so() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	_strand_free_haulers_completely()
	assert_eq(campaign.ending_grade(), BalanceCampaign.ENDING_GRADE_CLOSED)
	assert_gt(_blocked_grades.size(), 0, "the player is told")
	var last: StringName = _blocked_grades[_blocked_grades.size() - 1]
	assert_eq(last, BalanceCampaign.ENDING_GRADE_CLOSED)
	var line: String = _blocked_lines[_blocked_lines.size() - 1]
	assert_string_contains(line, "closed for good")
	assert_false(EndingStatusRef.can_still_earn_standing(ENTITY_HAULERS))


func test_journal_gives_a_dead_ending_its_own_word() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	_strand_free_haulers_completely()
	var seen: int = 0
	for row: Dictionary in campaign.journal_lines():
		var id: StringName = StringName(str(row.get(BalanceCampaign.JOURNAL_KEY_ID, &"")))
		var status: StringName = StringName(str(row.get(BalanceCampaign.JOURNAL_KEY_STATUS, &"")))
		if id == SPINE_PAPERS_EPS or id == SPINE_FORCE_EPS:
			seen += 1
			assert_eq(status, BalanceCampaign.JOURNAL_STATUS_CLOSED, "%s" % String(id))
		else:
			assert_ne(status, BalanceCampaign.JOURNAL_STATUS_CLOSED, "%s" % String(id))
	assert_eq(seen, 2, "both ignition beats at the claimed dock are marked closed")
	assert_ne(BalanceCampaign.JOURNAL_SECTION_CLOSED, BalanceCampaign.JOURNAL_SECTION_LOCKED)
	assert_ne(BalanceUi.FONT_COLOR_CLOSED, BalanceUi.FONT_COLOR_MUTED)


func test_dock_hint_names_the_factions_that_are_short() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_HOSTILE_MIN)
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HOSTILE_MIN)
	var hint: String = campaign.locked_hint_at(STATION_EPSILON)
	assert_false(hint.is_empty())
	assert_ne(hint, BalanceCampaign.STATION_STORY_NEED_STANDING, "the vague line is gone")
	assert_ne(hint, BalanceCampaign.STATION_STORY_NEED_STANDOFF)
	assert_string_contains(hint, "Free Haulers")
	assert_string_contains(hint, "Drift Syndicate")


func test_hint_names_the_prior_and_the_backers_when_only_the_standoff_is_shut() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_HOSTILE_MIN)
	var hint: String = campaign.locked_hint_at(STATION_EPSILON)
	assert_string_contains(hint, "Drift Syndicate")
	assert_string_contains(hint, "Reach Authority")
	assert_string_contains(hint, BalanceStanding.TIER_DISPLAY_FRIENDLY)


func test_an_ending_that_reopens_stops_being_reported_as_shut() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_HOSTILE_MIN)
	assert_eq(campaign.ending_grade(), BalanceCampaign.ENDING_GRADE_STALLED)
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_NEUTRAL_MIN)
	assert_eq(campaign.ending_grade(), BalanceCampaign.ENDING_GRADE_OPEN)
	assert_true(campaign.can_accept_spine(SPINE_PAPERS_EPS))
	assert_true(campaign.ending_block_line().is_empty())


func test_loading_a_blocked_career_does_not_re_announce_it() -> void:
	var campaign: CampaignService = _claim_epsilon_holding()
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HOSTILE_MIN)
	assert_eq(_blocked_grades.size(), 1)
	var section: Dictionary = campaign.to_section()
	_blocked_grades = []
	_blocked_lines = []
	campaign.apply_section(section)
	assert_eq(_blocked_grades.size(), 0, "a reload is not a fresh closure")
	assert_eq(campaign.ending_grade(), BalanceCampaign.ENDING_GRADE_STALLED)


func test_flight_hud_shows_the_ending_message() -> void:
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	EventBus.on_campaign_ending_blocked.emit(
		BalanceCampaign.ENDING_GRADE_CLOSED, "Both endings are closed for good: test."
	)
	assert_eq(hud.kill_toast_text(), "Both endings are closed for good: test.")


func test_no_verdict_before_a_holding_is_claimed() -> void:
	var stack: Dictionary = _make_stack(STATION_EPSILON)
	var campaign: CampaignService = stack[&"campaign"]
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HATED_MIN)
	StandingService.set_entity_standing(ENTITY_SYNDICATE, BalanceStanding.TIER_HATED_MIN)
	assert_eq(campaign.ending_grade(), BalanceCampaign.ENDING_GRADE_OPEN)
	assert_eq(_blocked_grades.size(), 0, "there is no ending to lose yet")


# --- Fixtures ---------------------------------------------------------------


func _make_stack(dock_station: StringName) -> Dictionary:
	var host: Node = Node.new()
	add_child(host)
	_hosts.append(host)
	var wallet: WalletService = WalletService.new()
	var cargo: CargoService = CargoService.new()
	var mission: MissionService = MissionService.new()
	var campaign: CampaignService = CampaignService.new()
	var docking: _FakeDock = _FakeDock.new()
	docking.station_id = dock_station
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
		&"mission": mission,
		&"campaign": campaign,
	}


func _claim_epsilon_holding() -> CampaignService:
	var stack: Dictionary = _make_stack(STATION_EPSILON)
	var campaign: CampaignService = stack[&"campaign"]
	for flag: StringName in BalanceHolding.MILESTONE_FLAGS:
		_force_flag(campaign, flag)
	_force_act(campaign, BalanceCampaign.ACT_III)
	_force_flag(campaign, BalanceCampaign.FLAG_ACT2_DONE)
	assert_true(campaign.try_purchase_holding(STATION_EPSILON), "Holding claimed for the fixture")
	_blocked_grades = []
	_blocked_lines = []
	return campaign


## The hard grade: Free Haulers refused at their own yard, and refused at both
## allies whose work bleeds over to them. Nothing left can raise them.
func _strand_free_haulers_completely() -> void:
	StandingService.close_person(PERSON_REED, REASON_TEST)
	StandingService.close_person(PERSON_WREN, REASON_TEST)
	StandingService.close_person(PERSON_KADE, REASON_TEST)
	StandingService.close_person(PERSON_RHEA, REASON_TEST)
	StandingService.set_entity_standing(ENTITY_GAMMA, BalanceStanding.TIER_HOSTILE_MIN)
	StandingService.set_entity_standing(ENTITY_ETA, BalanceStanding.TIER_HOSTILE_MIN)
	StandingService.set_entity_standing(ENTITY_HAULERS, BalanceStanding.TIER_HOSTILE_MIN)


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


class _FakeDock:
	extends Node
	var station_id: StringName = &""

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station_id
