extends GutTest

## E2.1 — two hostile fight shapes (skirmisher / gunboat).
##
## Implements: docs/BETA_E2_COMBAT_HULL.md E2.1

const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const TOLERANCE: float = 0.0001


class FakeSystemWorld:
	extends Node3D
	var system_id: StringName = SYSTEM_BETA

	func _ready() -> void:
		add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_at_least_two_hostile_profiles_registered() -> void:
	var ids: Array[StringName] = BalanceCombat.hostile_profile_ids()
	assert_gte(ids.size(), 2, "E2.1 requires at least two hostile profile ids")
	assert_true(
		BalanceCombat.has_hostile_profile(BalanceCombat.PROFILE_SKIRMISHER), "skirmisher registered"
	)
	assert_true(
		BalanceCombat.has_hostile_profile(BalanceCombat.PROFILE_GUNBOAT), "gunboat registered"
	)


func test_profiles_differ_in_hp_damage_speed_engage_or_cooldown() -> void:
	var a: StringName = BalanceCombat.PROFILE_SKIRMISHER
	var b: StringName = BalanceCombat.PROFILE_GUNBOAT
	var hp_a: float = BalanceCombat.profile_float(a, BalanceCombat.PROFILE_KEY_HP, 0.0)
	var hp_b: float = BalanceCombat.profile_float(b, BalanceCombat.PROFILE_KEY_HP, 0.0)
	var dmg_a: float = BalanceCombat.profile_float(a, BalanceCombat.PROFILE_KEY_DAMAGE, 0.0)
	var dmg_b: float = BalanceCombat.profile_float(b, BalanceCombat.PROFILE_KEY_DAMAGE, 0.0)
	var spd_a: float = BalanceCombat.profile_float(a, BalanceCombat.PROFILE_KEY_MOVE_SPEED, 0.0)
	var spd_b: float = BalanceCombat.profile_float(b, BalanceCombat.PROFILE_KEY_MOVE_SPEED, 0.0)
	var eng_a: float = BalanceCombat.profile_float(a, BalanceCombat.PROFILE_KEY_ENGAGE_RANGE, 0.0)
	var eng_b: float = BalanceCombat.profile_float(b, BalanceCombat.PROFILE_KEY_ENGAGE_RANGE, 0.0)
	var cd_a: float = BalanceCombat.profile_float(a, BalanceCombat.PROFILE_KEY_FIRE_COOLDOWN, 0.0)
	var cd_b: float = BalanceCombat.profile_float(b, BalanceCombat.PROFILE_KEY_FIRE_COOLDOWN, 0.0)
	var diffs: int = 0
	if not is_equal_approx(hp_a, hp_b):
		diffs += 1
	if not is_equal_approx(dmg_a, dmg_b):
		diffs += 1
	if not is_equal_approx(spd_a, spd_b):
		diffs += 1
	if not is_equal_approx(eng_a, eng_b):
		diffs += 1
	if not is_equal_approx(cd_a, cd_b):
		diffs += 1
	assert_gte(diffs, 2, "profiles must differ on multiple combat axes")
	# Explicit shape intent: gunboat is tougher and meaner; skirmisher is faster.
	assert_gt(hp_b, hp_a, "gunboat higher HP")
	assert_gt(dmg_b, dmg_a, "gunboat higher damage")
	assert_gt(spd_a, spd_b, "skirmisher faster")
	assert_gt(eng_b, eng_a, "gunboat longer engage")
	assert_gt(cd_b, cd_a, "gunboat slower fire (higher cooldown)")


func test_legacy_hostile_constants_match_default_skirmisher() -> void:
	var id: StringName = BalanceCombat.PROFILE_DEFAULT
	assert_eq(id, BalanceCombat.PROFILE_SKIRMISHER)
	assert_almost_eq(
		BalanceCombat.profile_float(id, BalanceCombat.PROFILE_KEY_HP, -1.0),
		BalanceCombat.HOSTILE_HP,
		TOLERANCE
	)
	assert_almost_eq(
		BalanceCombat.profile_float(id, BalanceCombat.PROFILE_KEY_DAMAGE, -1.0),
		BalanceCombat.HOSTILE_DAMAGE,
		TOLERANCE
	)
	assert_almost_eq(
		BalanceCombat.profile_float(id, BalanceCombat.PROFILE_KEY_FIRE_COOLDOWN, -1.0),
		BalanceCombat.HOSTILE_FIRE_COOLDOWN,
		TOLERANCE
	)
	assert_almost_eq(
		BalanceCombat.profile_float(id, BalanceCombat.PROFILE_KEY_ENGAGE_RANGE, -1.0),
		BalanceCombat.ENGAGE_RANGE,
		TOLERANCE
	)
	assert_almost_eq(
		BalanceCombat.profile_float(id, BalanceCombat.PROFILE_KEY_MOVE_SPEED, -1.0),
		BalanceCombat.HOSTILE_MOVE_SPEED,
		TOLERANCE
	)


func test_skirmisher_dies_in_n_player_hits_from_balance() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var profile: StringName = BalanceCombat.PROFILE_SKIRMISHER
	var hits: int = BalanceCombat.player_hits_to_kill(profile)
	assert_gt(hits, 0, "hits_to_kill must be positive")
	var hostile: HostileNpc = HostileNpc.spawn_under(host, Vector3.ZERO, profile)
	assert_almost_eq(
		hostile.remaining_hp(),
		BalanceCombat.profile_float(profile, BalanceCombat.PROFILE_KEY_HP, 0.0),
		TOLERANCE
	)
	var i: int = 0
	while i < hits - 1:
		hostile.take_damage(BalanceCombat.PLAYER_WEAPON_DAMAGE)
		assert_true(hostile.is_alive(), "still alive before final hit %d/%d" % [i + 1, hits])
		i += 1
	hostile.take_damage(BalanceCombat.PLAYER_WEAPON_DAMAGE)
	assert_false(hostile.is_alive(), "profile A dies on hit N from balance")
	await get_tree().process_frame


func test_gunboat_survives_skirmisher_kill_count_then_dies_later() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var soft: StringName = BalanceCombat.PROFILE_SKIRMISHER
	var hard: StringName = BalanceCombat.PROFILE_GUNBOAT
	var hits_soft: int = BalanceCombat.player_hits_to_kill(soft)
	var hits_hard: int = BalanceCombat.player_hits_to_kill(hard)
	assert_gt(hits_hard, hits_soft, "gunboat takes more player hits than skirmisher")

	var gunboat: HostileNpc = HostileNpc.spawn_under(host, Vector3.ZERO, hard)
	var i: int = 0
	while i < hits_soft:
		gunboat.take_damage(BalanceCombat.PLAYER_WEAPON_DAMAGE)
		i += 1
	assert_true(
		gunboat.is_alive(),
		"gunboat still alive after skirmisher's kill-count of fixed player damage"
	)
	assert_gt(gunboat.remaining_hp(), 0.0)

	while gunboat.is_alive() and i < hits_hard + 2:
		gunboat.take_damage(BalanceCombat.PLAYER_WEAPON_DAMAGE)
		i += 1
	assert_false(gunboat.is_alive(), "gunboat dies at its own balance hit count")
	assert_eq(i, hits_hard, "exact hard profile hits_to_kill from balance")
	await get_tree().process_frame


func test_lock_display_name_distinct_per_profile() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var sk: HostileNpc = HostileNpc.spawn_under(
		host, Vector3.ZERO, BalanceCombat.PROFILE_SKIRMISHER
	)
	var gb: HostileNpc = HostileNpc.spawn_under(
		host, Vector3(10.0, 0.0, 0.0), BalanceCombat.PROFILE_GUNBOAT
	)
	var name_sk: String = sk.lock_display_name()
	var name_gb: String = gb.lock_display_name()
	assert_false(name_sk.is_empty(), "skirmisher lock name")
	assert_false(name_gb.is_empty(), "gunboat lock name")
	assert_ne(name_sk, name_gb, "lock HUD names must differ per profile")
	assert_eq(name_sk, BalanceCombat.profile_display_name(BalanceCombat.PROFILE_SKIRMISHER))
	assert_eq(name_gb, BalanceCombat.profile_display_name(BalanceCombat.PROFILE_GUNBOAT))


func test_contested_and_lawless_ambient_profiles_cover_both_shapes() -> void:
	var contested: StringName = SystemWorld.ambient_hostile_profile(SYSTEM_BETA)
	var lawless: StringName = SystemWorld.ambient_hostile_profile(SYSTEM_GAMMA)
	assert_eq(contested, BalanceCombat.AMBIENT_PROFILE_CONTESTED)
	assert_eq(lawless, BalanceCombat.AMBIENT_PROFILE_LAWLESS)
	assert_ne(contested, lawless, "one session visiting beta+gamma meets both shapes")
	assert_true(BalanceCombat.has_hostile_profile(contested))
	assert_true(BalanceCombat.has_hostile_profile(lawless))


func test_ambient_spawn_applies_profile_for_system() -> void:
	var beta: SystemWorld = SystemWorld.new()
	beta.system_id = SYSTEM_BETA
	add_child_autofree(beta)
	beta.build()
	await get_tree().process_frame
	assert_gt(beta.live_hostile_count(), 0, "contested beta places ambient hostile")
	var h_beta: HostileNpc = _first_hostile(beta)
	assert_ne(h_beta, null)
	assert_eq(h_beta.profile_id, BalanceCombat.AMBIENT_PROFILE_CONTESTED)

	var gamma: SystemWorld = SystemWorld.new()
	gamma.system_id = SYSTEM_GAMMA
	add_child_autofree(gamma)
	gamma.build()
	await get_tree().process_frame
	assert_gt(gamma.live_hostile_count(), 0, "lawless gamma places ambient hostile")
	var h_gamma: HostileNpc = _first_hostile(gamma)
	assert_ne(h_gamma, null)
	assert_eq(h_gamma.profile_id, BalanceCombat.AMBIENT_PROFILE_LAWLESS)


func test_bounty_ensure_uses_skirmisher_outside_safe_within_lock() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_BETA
	add_child_autofree(world)
	world.build()
	_free_all_hostiles(world)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 0)

	var near: Vector3 = Vector3(-160.0, 0.0, 90.0)
	world.ensure_hostile_near(near)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 1, "ensure places prey when empty")
	var hostile: HostileNpc = _first_hostile(world)
	assert_ne(hostile, null)
	assert_eq(
		hostile.profile_id,
		BalanceCombat.BOUNTY_HOSTILE_PROFILE,
		"bounty ensure uses softer skirmisher profile"
	)
	assert_false(
		_hostile_inside_any_station_safe(world, hostile.global_position),
		"bounty spawn outside every station safe radius"
	)
	assert_lte(
		near.distance_to(hostile.global_position),
		BalanceCombat.TARGET_LOCK_RANGE,
		"bounty ensure places prey within lock range of request point"
	)


func test_patrolled_never_ambient_or_ensure() -> void:
	assert_false(SystemWorld.system_allows_hostiles(SYSTEM_ALPHA))
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	assert_eq(world.live_hostile_count(), 0)
	world.ensure_hostile_near(Vector3.ZERO)
	await get_tree().process_frame
	assert_eq(world.live_hostile_count(), 0)


func test_kill_still_reports_via_attribution_only() -> void:
	## No new standing rules — death still goes through AttributionService.report_kill.
	StandingService.reset_to_defaults()
	var host: FakeSystemWorld = FakeSystemWorld.new()
	host.system_id = SYSTEM_ALPHA
	add_child_autofree(host)
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	await get_tree().process_frame

	var attributed: Array[StringName] = []
	var reported: Array[StringName] = []
	var on_attr: Callable = func(
		system_id: StringName, _entity_id: StringName, _delta: float, _reason: StringName
	) -> void:
		attributed.append(system_id)
	var on_report: Callable = func(
		system_id: StringName, _victim: StringName, _w: int, _e: bool
	) -> void:
		reported.append(system_id)
	EventBus.on_kill_attributed.connect(on_attr)
	EventBus.on_kill_reported.connect(on_report)

	var hostile: HostileNpc = HostileNpc.spawn_under(
		host, Vector3(20.0, 0.0, 20.0), BalanceCombat.PROFILE_GUNBOAT
	)
	hostile.take_damage(hostile.hull_max())
	await get_tree().process_frame

	assert_eq(reported.size(), 1, "kill must call AttributionService.report_kill")
	assert_eq(reported[0], SYSTEM_ALPHA)
	assert_eq(attributed.size(), 1, "patrolled kill still attributes (no new standing rules)")
	assert_eq(attributed[0], SYSTEM_ALPHA)
	if EventBus.on_kill_attributed.is_connected(on_attr):
		EventBus.on_kill_attributed.disconnect(on_attr)
	if EventBus.on_kill_reported.is_connected(on_report):
		EventBus.on_kill_reported.disconnect(on_report)


func test_hull_percent_uses_profile_max() -> void:
	var soft_hp: float = BalanceCombat.profile_float(
		BalanceCombat.PROFILE_SKIRMISHER, BalanceCombat.PROFILE_KEY_HP, 0.0
	)
	var hard_hp: float = BalanceCombat.profile_float(
		BalanceCombat.PROFILE_GUNBOAT, BalanceCombat.PROFILE_KEY_HP, 0.0
	)
	assert_eq(BalanceCombat.hostile_hull_percent(soft_hp, soft_hp), 100)
	assert_eq(BalanceCombat.hostile_hull_percent(hard_hp * 0.5, hard_hp), 50)
	# Same remaining absolute HP is a different percent on different max.
	var remaining: float = soft_hp
	var pct_soft: int = BalanceCombat.hostile_hull_percent(remaining, soft_hp)
	var pct_hard: int = BalanceCombat.hostile_hull_percent(remaining, hard_hp)
	assert_eq(pct_soft, 100)
	assert_lt(pct_hard, pct_soft, "same absolute HP is lower percent on tougher profile")


func test_spawn_default_profile_is_skirmisher() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var hostile: HostileNpc = HostileNpc.spawn_under(host, Vector3.ZERO)
	assert_eq(hostile.profile_id, BalanceCombat.PROFILE_DEFAULT)
	assert_eq(hostile.profile_id, BalanceCombat.PROFILE_SKIRMISHER)
	assert_almost_eq(hostile.hull_max(), BalanceCombat.HOSTILE_HP, TOLERANCE)


func _free_all_hostiles(world: SystemWorld) -> void:
	var tree: SceneTree = world.get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if is_instance_valid(node) and world.is_ancestor_of(node):
			node.free()


func _first_hostile(world: SystemWorld) -> HostileNpc:
	var tree: SceneTree = world.get_tree()
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if is_instance_valid(node) and world.is_ancestor_of(node) and node is HostileNpc:
			return node as HostileNpc
	return null


func _hostile_inside_any_station_safe(world: SystemWorld, pos: Vector3) -> bool:
	var positions: Dictionary[StringName, Vector3] = world.station_positions()
	if positions.is_empty():
		return pos.distance_to(BalanceFlight.STATION_POSITION) <= BalanceCombat.STATION_SAFE_RADIUS
	for station_id: StringName in positions:
		if pos.distance_to(positions[station_id]) <= BalanceCombat.STATION_SAFE_RADIUS:
			return true
	return false
