extends GutTest

## Lead intercept + no auto-hit bolts.
##
## Implements: beginner freighter combat aim (lead pip + projectiles).

const CombatReticleScript = preload("res://src/ui/hud/CombatReticle.gd")
const PlayerProjectileScript = preload("res://src/entities/PlayerProjectile.gd")


func test_lead_stationary_target_is_target_itself() -> void:
	var shooter: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3(0.0, 0.0, -100.0)
	var lead: Vector3 = CombatReticleScript.lead_point(shooter, target, Vector3.ZERO, 200.0)
	assert_almost_eq(lead.x, target.x, 0.001)
	assert_almost_eq(lead.y, target.y, 0.001)
	assert_almost_eq(lead.z, target.z, 0.001)


func test_lead_moves_ahead_of_crossing_target() -> void:
	var shooter: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3(0.0, 0.0, -100.0)
	var vel: Vector3 = Vector3(40.0, 0.0, 0.0)
	var lead: Vector3 = CombatReticleScript.lead_point(shooter, target, vel, 200.0)
	assert_gt(lead.x, target.x, "lead pip sits ahead of lateral motion")
	assert_almost_eq(lead.z, target.z, 5.0)


func test_try_fire_does_not_auto_hit_lock() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	# Target behind the ship; bolt goes along default nose (-Z), not auto-lock.
	var hostile: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, 50.0))
	await get_tree().process_frame
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), hostile)
	var before: float = hostile.remaining_hp()
	assert_true(ship.try_fire())
	await get_tree().process_frame
	assert_eq(hostile.remaining_hp(), before, "lock must not auto-damage without aim")


func test_projectile_damages_hostile_on_contact() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var hostile: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -20.0))
	await get_tree().process_frame
	var before: float = hostile.remaining_hp()
	var bolt: Node = PlayerProjectileScript.new()
	space.add_child(bolt)
	await get_tree().process_frame
	assert_true(bolt.has_method(&"try_hit"))
	bolt.call(&"try_hit", hostile)
	assert_lt(hostile.remaining_hp(), before, "bolt contact damages hostile")
	assert_almost_eq(hostile.remaining_hp(), before - BalanceCombat.PLAYER_WEAPON_DAMAGE, 0.001)
