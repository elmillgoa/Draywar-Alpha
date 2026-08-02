extends GutTest

## E6.3 Package B — every ship a target: lock, bolts, ram, attribution, roles.
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.3

const ENTITY_REACH: StringName = &"entity_reach_authority"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const TOLERANCE: float = 0.0001


class FakeSystemWorld:
	extends Node3D
	## Minimal stand-in so TrafficShip / HostileNpc resolve system_id.
	var system_id: StringName = SYSTEM_ALPHA

	func _ready() -> void:
		add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)


var _kill_attributed: Array[StringName] = []
var _kill_unattributed: Array[StringName] = []
var _hostile_killed: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	_kill_attributed = []
	_kill_unattributed = []
	_hostile_killed = []
	EventBus.on_kill_attributed.connect(_on_kill_attributed)
	EventBus.on_kill_unattributed.connect(_on_kill_unattributed)
	EventBus.on_hostile_killed.connect(_on_hostile_killed)


func after_each() -> void:
	if EventBus.on_kill_attributed.is_connected(_on_kill_attributed):
		EventBus.on_kill_attributed.disconnect(_on_kill_attributed)
	if EventBus.on_kill_unattributed.is_connected(_on_kill_unattributed):
		EventBus.on_kill_unattributed.disconnect(_on_kill_unattributed)
	if EventBus.on_hostile_killed.is_connected(_on_hostile_killed):
		EventBus.on_hostile_killed.disconnect(_on_hostile_killed)
	StandingService.reset_to_defaults()
	TimeScale.set_combat_lock(false)


func _on_kill_attributed(
	system_id: StringName, _entity_id: StringName, _delta: float, _reason: StringName
) -> void:
	_kill_attributed.append(system_id)


func _on_kill_unattributed(system_id: StringName, _victim: StringName) -> void:
	_kill_unattributed.append(system_id)


func _on_hostile_killed(system_id: StringName, _victim: StringName) -> void:
	_hostile_killed.append(system_id)


func _make_traffic(
	parent: Node3D, pos: Vector3, role: StringName = BalanceCombat.ROLE_CIVILIAN
) -> TrafficShip:
	var ship: TrafficShip = TrafficShip.new()
	ship.apply_role(role)
	ship.build_visual(BalanceCombat.COLOR_TRAFFIC_CIVILIAN)
	parent.add_child(ship)
	ship.global_position = pos
	return ship


func test_role_display_strings_distinct() -> void:
	var civ: String = BalanceCombat.role_display_name(BalanceCombat.ROLE_CIVILIAN)
	var patrol: String = BalanceCombat.role_display_name(BalanceCombat.ROLE_PATROL)
	var pirate: String = BalanceCombat.role_display_name(BalanceCombat.ROLE_PIRATE)
	assert_false(civ.is_empty())
	assert_false(patrol.is_empty())
	assert_false(pirate.is_empty())
	assert_ne(civ, patrol)
	assert_ne(civ, pirate)
	assert_ne(patrol, pirate)


func test_traffic_lock_display_name_matches_role() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var civ: TrafficShip = _make_traffic(host, Vector3.ZERO, BalanceCombat.ROLE_CIVILIAN)
	var patrol: TrafficShip = _make_traffic(host, Vector3(5.0, 0.0, 0.0), BalanceCombat.ROLE_PATROL)
	assert_eq(civ.lock_display_name(), BalanceCombat.ROLE_DISPLAY_CIVILIAN)
	assert_eq(patrol.lock_display_name(), BalanceCombat.ROLE_DISPLAY_PATROL)


func test_hostile_lock_display_name_is_pirate() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var hostile: HostileNpc = HostileNpc.spawn_under(host, Vector3.ZERO)
	assert_eq(hostile.lock_display_name(), BalanceCombat.ROLE_DISPLAY_PIRATE)
	assert_true(hostile.is_in_group(BalanceCombat.GROUP_LOCKABLE))
	assert_true(hostile.is_in_group(BalanceCombat.GROUP_HOSTILE))


func test_lock_includes_traffic_in_range() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	var traffic: TrafficShip = _make_traffic(space, Vector3(0.0, 0.0, -40.0))
	await get_tree().process_frame
	assert_true(traffic.is_in_group(BalanceCombat.GROUP_LOCKABLE))
	assert_false(traffic.is_in_group(BalanceCombat.GROUP_HOSTILE))

	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), traffic, "Tab locks traffic in range")


func test_lock_cycles_traffic_and_hostile() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	var traffic: TrafficShip = _make_traffic(space, Vector3(0.0, 0.0, -30.0))
	var hostile: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -60.0))
	await get_tree().process_frame

	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), traffic, "nearest is traffic")
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), hostile, "next is hostile")
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), traffic, "wrap")


func test_bolt_damages_and_kills_traffic() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var traffic: TrafficShip = _make_traffic(space, Vector3.ZERO)
	await get_tree().process_frame
	assert_true(traffic.is_alive())
	var start_hp: float = traffic.remaining_hp()
	assert_gt(start_hp, 0.0)

	var bolt: PlayerProjectile = PlayerProjectile.new()
	space.add_child(bolt)
	await get_tree().process_frame
	bolt.try_hit(traffic)
	assert_almost_eq(
		traffic.remaining_hp(), start_hp - BalanceCombat.PLAYER_WEAPON_DAMAGE, TOLERANCE
	)

	# Finish off (civilian 80 HP → 2 hits of 40).
	traffic.take_damage(traffic.remaining_hp())
	assert_false(traffic.is_alive())
	await get_tree().process_frame
	assert_false(is_instance_valid(traffic) and traffic.is_inside_tree())


func test_patrolled_traffic_kill_attributes_to_controller() -> void:
	var host: FakeSystemWorld = FakeSystemWorld.new()
	host.system_id = SYSTEM_ALPHA
	add_child_autofree(host)
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	await get_tree().process_frame

	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	var traffic: TrafficShip = _make_traffic(host, Vector3(10.0, 0.0, 10.0))
	await get_tree().process_frame

	traffic.take_damage(traffic.hull_max())
	await get_tree().process_frame

	assert_eq(_hostile_killed.size(), 0, "traffic must not emit on_hostile_killed")
	assert_eq(_kill_attributed.size(), 1, "patrolled traffic kill attributes")
	assert_eq(_kill_attributed[0], SYSTEM_ALPHA)
	var after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(after, before + BalanceStanding.COMBAT_KILL_DELTA, TOLERANCE)
	assert_lt(after, before)


func test_lawless_traffic_kill_without_evidence_stays_quiet() -> void:
	var host: FakeSystemWorld = FakeSystemWorld.new()
	host.system_id = SYSTEM_GAMMA
	add_child_autofree(host)
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	await get_tree().process_frame

	var before_reach: float = StandingService.get_entity_standing(ENTITY_REACH)
	StandingService.set_entity_standing(&"entity_gamma_collective", -3.0)
	var before_gamma: float = StandingService.get_entity_standing(&"entity_gamma_collective")

	var traffic: TrafficShip = _make_traffic(host, Vector3(10.0, 0.0, 10.0))
	await get_tree().process_frame
	traffic.take_damage(traffic.hull_max())
	await get_tree().process_frame

	assert_eq(_kill_attributed.size(), 0, "lawless no-evidence must not attribute")
	assert_eq(_kill_unattributed.size(), 1)
	assert_eq(_kill_unattributed[0], SYSTEM_GAMMA)
	assert_almost_eq(
		StandingService.get_entity_standing(&"entity_gamma_collective"), before_gamma, TOLERANCE
	)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_REACH), before_reach, TOLERANCE)


func test_ram_kill_uses_same_death_and_attribution_path() -> void:
	# Impact and bolts both call take_damage → _die → AttributionService.
	var host: FakeSystemWorld = FakeSystemWorld.new()
	host.system_id = SYSTEM_ALPHA
	add_child_autofree(host)
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	await get_tree().process_frame

	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	var traffic: TrafficShip = _make_traffic(host, Vector3.ZERO)
	await get_tree().process_frame

	var ram_dmg: float = BalanceCombat.impact_damage(
		BalanceCombat.IMPACT_PLAYER_AS_MASS_CLASS, 28.0
	)
	assert_gt(ram_dmg, 0.0)
	# Apply enough impact-style damage to kill (same take_damage path as bolts).
	var left: float = traffic.remaining_hp()
	while left > 0.0 and traffic.is_alive():
		traffic.take_damage(ram_dmg)
		left = traffic.remaining_hp() if is_instance_valid(traffic) else 0.0
	await get_tree().process_frame

	assert_eq(_kill_attributed.size(), 1, "ram kill attributes in patrolled")
	var after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(after, before + BalanceStanding.COMBAT_KILL_DELTA, TOLERANCE)


func test_dead_traffic_removed_from_lock_list_tab_still_works() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	var near: TrafficShip = _make_traffic(space, Vector3(0.0, 0.0, -30.0))
	var far: TrafficShip = _make_traffic(space, Vector3(0.0, 0.0, -70.0))
	await get_tree().process_frame

	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), near)
	near.take_damage(near.hull_max())
	await get_tree().process_frame

	assert_eq(ship.locked_target(), null, "dead lock clears")
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), far, "Tab still cycles remaining traffic")
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), far, "single target re-locks / stays")


func test_npc_traffic_spawn_mix_patrolled_has_patrol() -> void:
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(SYSTEM_ALPHA)
	await get_tree().process_frame
	assert_gt(traffic.live_ship_count(), 0)
	var patrols: int = 0
	var civilians: int = 0
	for child: Node in traffic.get_children():
		if child is TrafficShip:
			var ts: TrafficShip = child as TrafficShip
			assert_true(ts.is_in_group(BalanceCombat.GROUP_LOCKABLE))
			assert_false(ts.is_in_group(BalanceCombat.GROUP_HOSTILE))
			if ts.role_id == BalanceCombat.ROLE_PATROL:
				patrols += 1
			else:
				civilians += 1
	assert_gt(patrols, 0, "patrolled systems spawn some patrol boats")
	assert_gt(civilians, 0, "patrolled systems still have civilians")


func test_npc_traffic_lawless_has_no_patrol() -> void:
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(SYSTEM_GAMMA)
	await get_tree().process_frame
	for child: Node in traffic.get_children():
		if child is TrafficShip:
			var ts: TrafficShip = child as TrafficShip
			assert_eq(ts.role_id, BalanceCombat.ROLE_CIVILIAN, "lawless traffic is civilian only")


func test_unregister_reduces_live_count_and_witnesses() -> void:
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(SYSTEM_ALPHA)
	await get_tree().process_frame
	var before: int = traffic.live_ship_count()
	assert_gt(before, 1)
	var victim: TrafficShip = null
	for child: Node in traffic.get_children():
		if child is TrafficShip:
			victim = child as TrafficShip
			break
	assert_ne(victim, null)
	victim.take_damage(victim.hull_max())
	await get_tree().process_frame
	assert_eq(traffic.live_ship_count(), before - 1)
