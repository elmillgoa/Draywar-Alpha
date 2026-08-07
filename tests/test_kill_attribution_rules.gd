extends GutTest

## Sanctioned bounty kills and escort deaths — reputation law §7.
##
## Law: docs/reputation_and_standing.md §7 "Combat Attribution"
##
## Two rules: an Entity does not charge the player for a kill it paid for, and
## an escort freighter's death is attributed like any other kill.

const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_BETA: StringName = &"entity_beta_syndicate"
const ENTITY_HAULERS: StringName = &"entity_free_haulers"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const CONTRACT_BOUNTY_BETA: StringName = &"contract_bounty_beta_spit"
const STATION_BETA_SPIT: StringName = &"station_beta_spit"
const STATION_BETA_HUB: StringName = &"station_beta_hub"
const STATION_ALPHA_PORT: StringName = &"station_alpha_port"
const TOLERANCE: float = 0.0001
const NO_EVIDENCE: bool = false
const NO_WITNESS: int = 0
const OFFER_PAY: int = 200
const OVERKILL_DAMAGE: float = 10.0

var _attribution: AttributionService = null
var _mission: MissionService = null
var _wallet: WalletService = null
var _attributed_entities: Array[StringName] = []
var _attributed_deltas: Array[float] = []
var _unattributed_systems: Array[StringName] = []
var _mission_failed: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	_attributed_entities = []
	_attributed_deltas = []
	_unattributed_systems = []
	_mission_failed = []

	# Attribution first: it caches the offering Entity off on_mission_accepted.
	_attribution = AttributionService.new()
	add_child_autofree(_attribution)
	_mission = MissionService.new()
	add_child_autofree(_mission)
	_wallet = WalletService.new()
	add_child_autofree(_wallet)
	_mission.reset()
	_wallet.reset()

	EventBus.on_kill_attributed.connect(_on_kill_attributed)
	EventBus.on_kill_unattributed.connect(_on_kill_unattributed)
	EventBus.on_mission_failed.connect(_on_mission_failed)


func after_each() -> void:
	if EventBus.on_kill_attributed.is_connected(_on_kill_attributed):
		EventBus.on_kill_attributed.disconnect(_on_kill_attributed)
	if EventBus.on_kill_unattributed.is_connected(_on_kill_unattributed):
		EventBus.on_kill_unattributed.disconnect(_on_kill_unattributed)
	if EventBus.on_mission_failed.is_connected(_on_mission_failed):
		EventBus.on_mission_failed.disconnect(_on_mission_failed)
	_mission.reset()
	StandingService.reset_to_defaults()
	BoardService.reset()
	MarketService.reset()
	WorldClockHelpers.reset_clock()


func _on_kill_attributed(
	_system_id: StringName, entity_id: StringName, delta: float, _reason: StringName
) -> void:
	_attributed_entities.append(entity_id)
	_attributed_deltas.append(delta)


func _on_kill_unattributed(system_id: StringName, _victim: StringName) -> void:
	_unattributed_systems.append(system_id)


func _on_mission_failed(template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_mission_failed.append(template_id)


func _attributed(result: Dictionary) -> bool:
	var value: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	return value


func _entity_from(result: Dictionary) -> StringName:
	var value: StringName = result[BalanceStanding.REPORT_KEY_ENTITY_ID]
	return value


## Contested Beta needs a witness (or evidence) before anything is attributed.
func _kill_in_beta() -> Dictionary:
	return _attribution.report_kill(
		SYSTEM_BETA, ENTITY_HAULERS, BalanceStanding.ATTRIBUTION_WITNESS_THRESHOLD, NO_EVIDENCE
	)


func _offer(
	offer_id: StringName,
	kind: StringName,
	offering_entity_id: StringName,
	target_system_id: StringName
) -> Dictionary:
	return {
		BalanceBoard.OFFER_KEY_ID: offer_id,
		BalanceBoard.OFFER_KEY_BOARD_STATION: STATION_ALPHA_PORT,
		BalanceBoard.OFFER_KEY_KIND: kind,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: offering_entity_id,
		BalanceBoard.OFFER_KEY_PAY: OFFER_PAY,
		BalanceBoard.OFFER_KEY_STANDING_COMPLETE: BalanceStanding.MISSION_COMPLETE_DELTA,
		BalanceBoard.OFFER_KEY_STANDING_FAIL: BalanceStanding.MISSION_FAIL_DELTA,
		BalanceBoard.OFFER_KEY_STANDING_ABANDON: BalanceStanding.MISSION_ABANDON_DELTA,
		BalanceBoard.OFFER_KEY_DESTINATION: STATION_BETA_HUB,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: target_system_id,
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: &"",
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: 0,
		BalanceBoard.OFFER_KEY_LABEL: "Job 4 fixture",
		BalanceBoard.OFFER_KEY_SOURCE: BalanceBoard.OFFER_SOURCE_RADIANT,
	}


func _first_escort() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(BalanceBoard.GROUP_MISSION_ESCORT):
		if is_instance_valid(node):
			return node
	return null


# --- Question 1: sanctioned bounty kills ------------------------------------


func test_beta_spit_bounty_leaves_offering_entity_net_non_negative() -> void:
	## The headline case. Beta Spit is offered by the Syndicate, hunts in the
	## system the Syndicate holds, and used to cost -12 against a +8 reward.
	StandingService.set_entity_standing(ENTITY_BETA, 0.0)
	var before: float = StandingService.get_entity_standing(ENTITY_BETA)

	assert_true(_mission.accept(CONTRACT_BOUNTY_BETA))
	assert_eq(_mission.active_kind(), BalanceStanding.MISSION_KIND_BOUNTY)
	assert_eq(_mission.active_target_system_id(), SYSTEM_BETA)

	# Same order HostileNpc._die() uses: bus first, then the attribution report.
	EventBus.on_hostile_killed.emit(SYSTEM_BETA, ENTITY_HAULERS)
	var kill: Dictionary = _kill_in_beta()
	assert_false(_attributed(kill), "a kill the Syndicate paid for must not charge the Syndicate")
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_BETA),
		before,
		TOLERANCE,
		"sanctioned kill moved standing"
	)
	assert_eq(_attributed_entities.size(), 0, "no attributed-kill event for a sanctioned kill")
	assert_eq(_unattributed_systems.size(), 1, "the kill still reports, it just costs nothing")

	assert_true(_mission.is_objective_ready())
	var turned_in: Dictionary = _mission.try_complete_at(STATION_BETA_SPIT)
	assert_true(_attributed(turned_in))
	assert_false(_mission.has_active())

	var after: float = StandingService.get_entity_standing(ENTITY_BETA)
	assert_gte(after, before, "a paid job may not leave the payer worse off")
	assert_almost_eq(after - before, BalanceStanding.MISSION_COMPLETE_DELTA, TOLERANCE)


func test_exemption_covers_only_the_entity_that_paid() -> void:
	## Reach Authority hires the player to hunt in Syndicate-held Beta. The
	## Syndicate did not pay for that kill and still charges for it.
	StandingService.set_entity_standing(ENTITY_BETA, 0.0)
	var before: float = StandingService.get_entity_standing(ENTITY_BETA)
	assert_true(
		_mission.accept_runtime_offer(
			_offer(
				&"job4_bounty_reach", BalanceStanding.MISSION_KIND_BOUNTY, ENTITY_REACH, SYSTEM_BETA
			),
			false
		)
	)

	EventBus.on_hostile_killed.emit(SYSTEM_BETA, ENTITY_HAULERS)
	var kill: Dictionary = _kill_in_beta()
	assert_true(_attributed(kill), "the Syndicate did not pay for this kill")
	assert_eq(_entity_from(kill), ENTITY_BETA)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_BETA),
		before + BalanceStanding.COMBAT_KILL_DELTA,
		TOLERANCE
	)


func test_kill_outside_the_target_system_is_still_charged() -> void:
	## Same Entity, wrong system. The bounty is for Beta; Alpha is not the job.
	StandingService.set_entity_standing(ENTITY_REACH, 0.0)
	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_true(
		_mission.accept_runtime_offer(
			_offer(
				&"job4_bounty_alpha_test",
				BalanceStanding.MISSION_KIND_BOUNTY,
				ENTITY_REACH,
				SYSTEM_BETA
			),
			false
		)
	)

	var kill: Dictionary = _attribution.report_kill(
		SYSTEM_ALPHA, ENTITY_HAULERS, NO_WITNESS, NO_EVIDENCE
	)
	assert_true(_attributed(kill))
	assert_eq(_entity_from(kill), ENTITY_REACH)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		before + BalanceStanding.COMBAT_KILL_DELTA,
		TOLERANCE
	)


func test_a_courier_job_from_the_same_entity_does_not_exempt() -> void:
	## Only a bounty sanctions a kill. Carrying the Syndicate's parcel does not.
	StandingService.set_entity_standing(ENTITY_BETA, 0.0)
	assert_true(
		_mission.accept_runtime_offer(
			_offer(
				&"job4_courier_beta",
				BalanceStanding.MISSION_KIND_DELIVERY,
				ENTITY_BETA,
				SYSTEM_BETA
			),
			false
		)
	)

	var kill: Dictionary = _kill_in_beta()
	assert_true(_attributed(kill), "a delivery job is not a licence to kill")
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_BETA),
		BalanceStanding.COMBAT_KILL_DELTA,
		TOLERANCE
	)


func test_exemption_ends_when_the_contract_does() -> void:
	## Judged at the moment of the kill: with no live contract there is no cover.
	assert_true(_mission.accept(CONTRACT_BOUNTY_BETA))
	_mission.abandon()
	assert_false(_mission.has_active())

	StandingService.set_entity_standing(ENTITY_BETA, 0.0)
	var kill: Dictionary = _kill_in_beta()
	assert_true(_attributed(kill), "no live contract, no exemption")
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_BETA),
		BalanceStanding.COMBAT_KILL_DELTA,
		TOLERANCE
	)


func test_kill_with_no_mission_at_all_is_unchanged() -> void:
	## Regression guard: the ordinary path must behave exactly as it did.
	StandingService.set_entity_standing(ENTITY_BETA, 0.0)
	assert_false(_mission.has_active())
	var kill: Dictionary = _kill_in_beta()
	assert_true(_attributed(kill))
	assert_eq(_entity_from(kill), ENTITY_BETA)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_BETA),
		BalanceStanding.COMBAT_KILL_DELTA,
		TOLERANCE
	)


# --- Question 2: escort deaths ----------------------------------------------


func test_escort_death_is_attributed_like_any_other_kill() -> void:
	## The escort job is offered by the Reach Authority and its target system is
	## Alpha — the strongest guard there is on the bounty-only clause, because
	## every part of the exemption except "is it a bounty" lines up here.
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	# src/Main.gd is what puts the live world in this group, not SystemWorld.
	# Without it the dying hull cannot resolve which system it died in.
	world.add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)
	world.build()
	await get_tree().process_frame

	assert_true(
		_mission.accept_runtime_offer(
			_offer(&"job4_escort", BalanceStanding.MISSION_KIND_ESCORT, ENTITY_REACH, SYSTEM_ALPHA),
			false
		)
	)
	world.ensure_escort_freighter()
	await get_tree().process_frame

	var freighter: Node = _first_escort()
	assert_ne(freighter, null, "escort must spawn before it can die")

	StandingService.set_entity_standing(ENTITY_REACH, 0.0)
	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	freighter.call(&"take_damage", BalanceBoard.ESCORT_HULL_HP + OVERKILL_DAMAGE)
	await get_tree().process_frame

	assert_eq(_attributed_entities.size(), 1, "escort death must report a kill")
	if _attributed_entities.size() == 1:
		assert_eq(
			_attributed_entities[0], ENTITY_REACH, "patrolled Alpha's controller takes the hit"
		)
		assert_almost_eq(
			_attributed_deltas[0],
			BalanceStanding.COMBAT_KILL_DELTA,
			TOLERANCE,
			"escort death costs exactly what any other attributed kill costs"
		)
	assert_lt(StandingService.get_entity_standing(ENTITY_REACH), before)
	assert_eq(_mission_failed.size(), 1, "the job still fails when the freighter dies")
	assert_false(_mission.has_active())


func test_escort_death_in_lawless_space_is_not_attributed() -> void:
	## "Same rules as any other kill" cuts both ways: deep space still hides it.
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_GAMMA
	add_child_autofree(world)
	world.add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)
	world.build()
	await get_tree().process_frame

	assert_true(
		_mission.accept_runtime_offer(
			_offer(
				&"job4_escort_gamma",
				BalanceStanding.MISSION_KIND_ESCORT,
				ENTITY_REACH,
				SYSTEM_GAMMA
			),
			false
		)
	)
	world.ensure_escort_freighter()
	await get_tree().process_frame

	var freighter: Node = _first_escort()
	assert_ne(freighter, null)
	freighter.call(&"take_damage", BalanceBoard.ESCORT_HULL_HP + OVERKILL_DAMAGE)
	await get_tree().process_frame

	assert_eq(_attributed_entities.size(), 0, "no evidence in lawless space, no attribution")
	assert_eq(_unattributed_systems.size(), 1, "the death is still reported")
	assert_eq(_mission_failed.size(), 1, "the job fails either way")
