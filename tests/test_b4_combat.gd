extends GutTest

## Thin combat — Path C B4.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B4
##
## Hostile damage/death, attribution standing, player damage/cripple/repair,
## hitscan fire, and world spawn under SystemWorld.

const ENTITY_REACH: StringName = &"entity_reach_authority"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const TOLERANCE: float = 0.0001


class FakeSystemWorld:
	extends Node3D
	## Minimal stand-in so HostileNpc can resolve current system_id.
	var system_id: StringName = SYSTEM_ALPHA

	func _ready() -> void:
		add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)


class FakeDockedService:
	extends Node
	## Reports always-docked so hostiles must not fire.

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return &"station_alpha_port"


var _crippled_count: int = 0
var _repaired_count: int = 0
var _hostile_damaged: Array[float] = []
var _hostile_killed: Array[StringName] = []
var _kill_attributed: Array[StringName] = []
var _player_damaged: Array[float] = []
var _weapon_fired: int = 0


func before_each() -> void:
	FlightInput.ensure_actions()
	StandingService.reset_to_defaults()
	TimeScale.set_combat_lock(false)
	_crippled_count = 0
	_repaired_count = 0
	_hostile_damaged = []
	_hostile_killed = []
	_kill_attributed = []
	_player_damaged = []
	_weapon_fired = 0
	EventBus.on_player_crippled.connect(_on_crippled)
	EventBus.on_player_repaired_from_cripple.connect(_on_repaired)
	EventBus.on_hostile_damaged.connect(_on_hostile_damaged)
	EventBus.on_hostile_killed.connect(_on_hostile_killed)
	EventBus.on_kill_attributed.connect(_on_kill_attributed)
	EventBus.on_player_damaged.connect(_on_player_damaged)
	EventBus.on_weapon_fired.connect(_on_weapon_fired)


func after_each() -> void:
	if EventBus.on_player_crippled.is_connected(_on_crippled):
		EventBus.on_player_crippled.disconnect(_on_crippled)
	if EventBus.on_player_repaired_from_cripple.is_connected(_on_repaired):
		EventBus.on_player_repaired_from_cripple.disconnect(_on_repaired)
	if EventBus.on_hostile_damaged.is_connected(_on_hostile_damaged):
		EventBus.on_hostile_damaged.disconnect(_on_hostile_damaged)
	if EventBus.on_hostile_killed.is_connected(_on_hostile_killed):
		EventBus.on_hostile_killed.disconnect(_on_hostile_killed)
	if EventBus.on_kill_attributed.is_connected(_on_kill_attributed):
		EventBus.on_kill_attributed.disconnect(_on_kill_attributed)
	if EventBus.on_player_damaged.is_connected(_on_player_damaged):
		EventBus.on_player_damaged.disconnect(_on_player_damaged)
	if EventBus.on_weapon_fired.is_connected(_on_weapon_fired):
		EventBus.on_weapon_fired.disconnect(_on_weapon_fired)
	# Kill FX outlives the hostile for a short tween; free leftovers so GUT stays clean.
	_free_kill_flashes(self)
	StandingService.reset_to_defaults()
	TimeScale.set_combat_lock(false)


func _free_kill_flashes(node: Node) -> void:
	var to_free: Array[Node] = []
	for child: Node in node.get_children():
		if child.name == "KillFlash":
			to_free.append(child)
		else:
			_free_kill_flashes(child)
	for flash: Node in to_free:
		if is_instance_valid(flash):
			flash.free()


func _on_crippled() -> void:
	_crippled_count += 1


func _on_repaired() -> void:
	_repaired_count += 1


func _on_hostile_damaged(remaining_hp: float) -> void:
	_hostile_damaged.append(remaining_hp)


func _on_hostile_killed(system_id: StringName, _victim: StringName) -> void:
	_hostile_killed.append(system_id)


func _on_kill_attributed(
	system_id: StringName, _entity_id: StringName, _delta: float, _reason: StringName
) -> void:
	_kill_attributed.append(system_id)


func _on_player_damaged(condition: float) -> void:
	_player_damaged.append(condition)


func _on_weapon_fired() -> void:
	_weapon_fired += 1


func test_hostile_takes_damage_and_dies_at_zero_hp() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var hostile: HostileNpc = HostileNpc.spawn_under(host, Vector3.ZERO)
	assert_almost_eq(hostile.remaining_hp(), BalanceCombat.HOSTILE_HP, TOLERANCE)
	assert_true(hostile.is_alive())

	hostile.take_damage(BalanceCombat.PLAYER_WEAPON_DAMAGE)
	assert_eq(_hostile_damaged.size(), 1)
	assert_almost_eq(
		hostile.remaining_hp(),
		BalanceCombat.HOSTILE_HP - BalanceCombat.PLAYER_WEAPON_DAMAGE,
		TOLERANCE
	)

	# Finish it off.
	hostile.take_damage(BalanceCombat.HOSTILE_HP)
	assert_false(hostile.is_alive())
	assert_eq(_hostile_killed.size(), 1)
	await get_tree().process_frame
	assert_false(is_instance_valid(hostile) and hostile.is_inside_tree())


func test_kill_in_patrolled_alpha_drops_reach_standing() -> void:
	var host: FakeSystemWorld = FakeSystemWorld.new()
	host.system_id = SYSTEM_ALPHA
	add_child_autofree(host)

	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	await get_tree().process_frame

	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	var hostile: HostileNpc = HostileNpc.spawn_under(host, Vector3(10.0, 0.0, 10.0))
	assert_eq(hostile.victim_entity_id, BalanceCombat.VICTIM_ENTITY_ID)

	hostile.take_damage(BalanceCombat.HOSTILE_HP)
	await get_tree().process_frame

	assert_eq(_hostile_killed.size(), 1)
	assert_eq(_hostile_killed[0], SYSTEM_ALPHA)
	assert_eq(_kill_attributed.size(), 1, "patrolled kill must attribute via report_kill")
	var after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(after, before + BalanceStanding.COMBAT_KILL_DELTA, TOLERANCE)
	assert_lt(after, before)


func test_player_condition_drops_on_apply_damage() -> void:
	var hull: HullConditionService = HullConditionService.new()
	add_child_autofree(hull)
	await get_tree().process_frame
	hull.reset()
	var start: float = hull.condition()
	var applied: float = hull.apply_damage(BalanceCombat.HOSTILE_DAMAGE)
	assert_almost_eq(applied, BalanceCombat.HOSTILE_DAMAGE, TOLERANCE)
	assert_almost_eq(hull.condition(), start - BalanceCombat.HOSTILE_DAMAGE, TOLERANCE)
	assert_eq(_player_damaged.size(), 1)
	assert_almost_eq(_player_damaged[0], hull.condition(), TOLERANCE)


func test_crippled_at_zero_disables_flight() -> void:
	var hull: HullConditionService = HullConditionService.new()
	add_child_autofree(hull)
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	await get_tree().process_frame
	hull.reset()
	assert_true(ship.is_flight_enabled())

	hull.apply_damage(BalanceEconomy.CONDITION_MAX)
	assert_almost_eq(hull.condition(), BalanceEconomy.CONDITION_MIN, TOLERANCE)
	assert_eq(_crippled_count, 1)
	assert_true(ship.is_crippled())
	assert_false(ship.is_flight_enabled())
	assert_false(hull.can_fly())


func test_repair_restores_condition_and_can_reenable_flight() -> void:
	var wallet: WalletService = WalletService.new()
	var hull: HullConditionService = HullConditionService.new()
	add_child_autofree(wallet)
	add_child_autofree(hull)
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	await get_tree().process_frame
	wallet.reset()
	hull.reset()

	hull.apply_damage(BalanceEconomy.CONDITION_MAX)
	assert_true(ship.is_crippled())
	assert_false(ship.is_flight_enabled())

	wallet.set_credits(BalanceEconomy.STARTING_CREDITS + BalanceEconomy.REPAIR_FULL_COST)
	assert_true(hull.repair_full())
	assert_almost_eq(hull.condition(), BalanceEconomy.CONDITION_MAX, TOLERANCE)
	assert_eq(_repaired_count, 1)
	assert_false(ship.is_crippled())
	assert_true(ship.is_flight_enabled())
	assert_true(hull.can_fly())


func test_bolt_fire_spawns_projectile_along_aim() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)

	var ship: PlayerShip = PlayerShip.new()
	host.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	var before_children: int = host.get_child_count()
	assert_true(ship.try_fire(), "free-flying ship should fire a bolt")
	assert_eq(_weapon_fired, 1)
	assert_gt(host.get_child_count(), before_children, "bolt parented under world/ship parent")
	var found_bolt: bool = false
	for child: Node in host.get_children():
		if child.get_script() != null:
			var path: String = str(child.get_script().resource_path)
			if path.ends_with("PlayerProjectile.gd"):
				found_bolt = true
				break
	assert_true(found_bolt, "PlayerProjectile spawned")


func test_patrolled_alpha_does_not_spawn_hostile() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	assert_false(SystemWorld.system_allows_hostiles(SYSTEM_ALPHA))
	var found: int = 0
	for child: Node in world.get_children():
		if child is HostileNpc:
			found += 1
	assert_eq(found, 0, "government / patrolled Alpha must not spawn combat hostiles")


func test_contested_or_lawless_spawns_hostile() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_beta"
	add_child_autofree(world)
	world.build()
	assert_true(SystemWorld.system_allows_hostiles(&"system_beta"))
	var found: int = 0
	for child: Node in world.get_children():
		if child is HostileNpc:
			found += 1
	assert_eq(found, 1, "contested Beta should place one pirate for combat vetting")

	var extra: HostileNpc = world.spawn_hostile_at(Vector3(5.0, 1.0, 5.0))
	assert_eq(extra.get_parent(), world)
	assert_true(extra.is_in_group(BalanceCombat.GROUP_HOSTILE))
	var expected: Vector3 = BalanceFlight.STATION_POSITION + Vector3(5.0, 1.0, 5.0)
	assert_almost_eq(extra.global_position.x, expected.x, TOLERANCE)
	assert_almost_eq(extra.global_position.y, expected.y, TOLERANCE)
	assert_almost_eq(extra.global_position.z, expected.z, TOLERANCE)


func test_hostile_does_not_fire_while_player_docked() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var fake_dock: FakeDockedService = FakeDockedService.new()
	space.add_child(fake_dock)

	var hull: HullConditionService = HullConditionService.new()
	space.add_child(hull)
	await get_tree().process_frame
	hull.reset()
	var start: float = hull.condition()

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	# Outside station safe radius so only the docked flag is protecting us.
	ship.global_position = Vector3(0.0, 0.0, BalanceCombat.STATION_SAFE_RADIUS + 40.0)

	var hostile: HostileNpc = HostileNpc.spawn_under(
		space, ship.global_position + Vector3(0.0, 0.0, -20.0)
	)
	EventBus.on_docked.emit(&"station_beta_hub")
	await get_tree().process_frame
	var bolts_before: int = _count_hostile_bolts(space)
	for _i: int in 5:
		hostile._physics_process(0.5)
	assert_eq(hull.condition(), start, "docked player must not take combat fire")
	assert_eq(_count_hostile_bolts(space), bolts_before, "docked: hostile must not spawn bolts")


func test_station_safe_zone_blocks_fire_when_undocked_near_station() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var hull: HullConditionService = HullConditionService.new()
	space.add_child(hull)
	await get_tree().process_frame
	hull.reset()
	var start: float = hull.condition()

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = BalanceFlight.STATION_POSITION + Vector3(0.0, 5.0, 40.0)

	var hostile: HostileNpc = HostileNpc.spawn_under(
		space, ship.global_position + Vector3(10.0, 0.0, 10.0)
	)
	EventBus.on_undocked.emit(&"station_beta_hub")
	# Skip undock grace so only the safe radius is tested.
	hostile._undock_grace = 0.0
	await get_tree().process_frame
	var bolts_before: int = _count_hostile_bolts(space)
	for _i: int in 5:
		hostile._physics_process(0.5)
	assert_eq(hull.condition(), start, "station airspace must stay peaceful on undock")
	assert_eq(_count_hostile_bolts(space), bolts_before, "safe zone: hostile must not spawn bolts")


func _count_hostile_bolts(parent: Node) -> int:
	var n: int = 0
	for child: Node in parent.get_children():
		if child.get_script() == null:
			continue
		var path: String = str(child.get_script().resource_path)
		if path.ends_with("HostileProjectile.gd"):
			n += 1
	return n


func test_pirate_spawn_offset_is_outside_station_safe_radius() -> void:
	var dist: float = BalanceCombat.SPAWN_OFFSET.length()
	assert_gt(dist, BalanceCombat.STATION_SAFE_RADIUS, "pirates must not camp the undock pad")
	var bounty_dist: float = BalanceCombat.BOUNTY_SPAWN_OFFSET.length()
	assert_gt(
		bounty_dist,
		BalanceCombat.STATION_SAFE_RADIUS,
		"bounty restock spawn must not camp the undock pad"
	)


func test_player_can_fire_while_crippled_if_free_flying() -> void:
	# Parent under a host so the bolt (parented to ship parent) is freed with autofree.
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var ship: PlayerShip = PlayerShip.new()
	host.add_child(ship)
	await get_tree().process_frame
	ship.set_flight_enabled(false)
	ship._crippled = true
	assert_true(ship.try_fire(), "crippled free-flying ship can still shoot back")
