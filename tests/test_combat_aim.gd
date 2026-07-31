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


func test_lead_point_works_at_projectile_speed() -> void:
	var shooter: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3(10.0, 0.0, -100.0)
	var vel: Vector3 = Vector3(20.0, 0.0, 0.0)
	var lead: Vector3 = CombatReticleScript.lead_point(
		shooter, target, vel, BalanceCombat.PROJECTILE_SPEED
	)
	assert_gt(lead.x, target.x, "lead ahead of lateral motion at bolt speed")


func test_mouse_aim_uses_target_plane_when_locked() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var cam: Camera3D = Camera3D.new()
	space.add_child(cam)
	cam.global_position = Vector3(0.0, 10.0, 20.0)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.current = true

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	ship.set_aim_camera(cam)
	await get_tree().process_frame

	var hostile: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, -80.0))
	await get_tree().process_frame
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), hostile)

	# Stationary lock: lead == target, so aim plane depth tracks target.
	var aim: Vector3 = ship._mouse_aim_point()
	var ship_dist: float = absf(aim.z - ship.global_position.z)
	var target_dist: float = absf(aim.z - hostile.global_position.z)
	assert_lt(target_dist, ship_dist + 1.0, "locked aim depth should track target plane")


func test_mouse_aim_plane_uses_lead_when_locked_target_moves() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var cam: Camera3D = Camera3D.new()
	space.add_child(cam)
	cam.global_position = Vector3(0.0, 10.0, 20.0)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.current = true

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	ship.set_aim_camera(cam)
	await get_tree().process_frame

	# Lateral + receding so lead depth differs from current target (pure lateral
	# leaves plane equation unchanged for this camera).
	var target_pos: Vector3 = Vector3(0.0, 0.0, -80.0)
	var target_vel: Vector3 = Vector3(40.0, 0.0, -30.0)
	var hostile: HostileNpc = HostileNpc.spawn_under(space, target_pos)
	await get_tree().process_frame
	hostile.velocity = target_vel
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), hostile)

	var lead: Vector3 = FlightMath.lead_point(
		ship.global_position, target_pos, target_vel, BalanceCombat.PROJECTILE_SPEED
	)
	assert_gt(lead.x, target_pos.x, "lead sits ahead of lateral motion")
	assert_lt(lead.z, target_pos.z - 1.0, "lead depth differs from current target")

	# Aim plane is through lead: mouse-ray hit must lie on the lead plane (not the
	# target plane). Screen-center aim is rarely near the lead pip itself.
	var aim: Vector3 = ship._mouse_aim_point()
	var plane_n: Vector3 = cam.global_transform.basis.z.normalized()
	var dist_to_lead_plane: float = absf((aim - lead).dot(plane_n))
	var dist_to_target_plane: float = absf((aim - target_pos).dot(plane_n))
	assert_lt(dist_to_lead_plane, 0.5, "locked aim must lie on the lead plane")
	assert_gt(
		dist_to_target_plane,
		dist_to_lead_plane + 0.5,
		"aim plane must track lead, not current target position"
	)


func test_mouse_aim_uses_camera_ray_when_unlocked() -> void:
	## Unlocked free-fire aim is a point ON the camera mouse ray (reticle line),
	## not a plane at ship-forward combat depth (chase cam makes that wrong).
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var cam: Camera3D = Camera3D.new()
	space.add_child(cam)
	cam.global_position = Vector3(0.0, 10.0, 20.0)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.current = true

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	ship.set_aim_camera(cam)
	await get_tree().process_frame

	assert_eq(ship.locked_target(), null)

	var viewport: Viewport = ship.get_viewport()
	var mouse: Vector2 = viewport.get_mouse_position()
	var ray_origin: Vector3 = cam.project_ray_origin(mouse)
	var ray_dir: Vector3 = cam.project_ray_normal(mouse)
	var expected: Vector3 = ray_origin + ray_dir * BalanceFlight.MOUSE_AIM_FALLBACK_DISTANCE
	var aim: Vector3 = ship._mouse_aim_point()
	assert_almost_eq(aim.x, expected.x, 0.01)
	assert_almost_eq(aim.y, expected.y, 0.01)
	assert_almost_eq(aim.z, expected.z, 0.01)
	# Point sits on the camera ray (cross product ≈ 0).
	var off_ray: float = (aim - ray_origin).cross(ray_dir).length()
	assert_lt(off_ray, 0.05, "unlocked aim must lie on the camera mouse ray")
	assert_gt(
		aim.distance_to(ship.global_position),
		50.0,
		"free aim point must sit well ahead of the ship"
	)


func test_free_fire_hits_hostile_without_lock() -> void:
	## Reticle aim alone must be enough: no Tab lock required to score a hit.
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var cam: Camera3D = Camera3D.new()
	space.add_child(cam)
	cam.global_position = Vector3(0.0, 10.0, 20.0)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.current = true

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	ship.set_aim_camera(cam)
	await get_tree().process_frame

	assert_eq(ship.locked_target(), null, "must hit without lock")
	var aim: Vector3 = ship._mouse_aim_point()
	var aim_dir: Vector3 = aim - ship.global_position
	assert_gt(
		aim_dir.length(),
		50.0,
		"free aim must reach combat depth (regression: ship-plane free-fire)"
	)
	aim_dir = aim_dir.normalized()

	# Sit on the free-fire aim ray inside bolt travel range; freeze AI so it stays put.
	var range_m: float = 40.0
	var hostile: HostileNpc = HostileNpc.spawn_under(
		space, ship.global_position + aim_dir * range_m
	)
	hostile.set_physics_process(false)
	await get_tree().process_frame
	assert_eq(ship.locked_target(), null)

	var before: float = hostile.remaining_hp()
	assert_true(ship.try_fire())
	# Travel time: 40 m / 280 m/s ≈ 0.14 s; wait with margin.
	var waited: float = 0.0
	while waited < 0.6 and is_instance_valid(hostile) and hostile.remaining_hp() >= before:
		await get_tree().physics_frame
		waited += get_tree().root.get_physics_process_delta_time()
	assert_true(is_instance_valid(hostile), "hostile should still exist after free-fire")
	assert_lt(
		hostile.remaining_hp(),
		before,
		"free-fire bolt along reticle must damage a target on the aim ray without lock"
	)
