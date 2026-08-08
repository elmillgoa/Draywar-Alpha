extends GutTest

## REPAIR-11 (audit finding #48) — a bolt must hit what it flew through, at
## every shipped time scale.
##
## External audit baseline ee17eab5: bolts teleported a whole physics step and
## then polled for overlaps, so above 1x the step (18.7 m at 4x, 74.7 m at 16x)
## was far longer than the 0.9 m hit sphere and the bolt jumped clean over the
## target. Measured 9/9 hits at 1x, 0/7 at 4x, 0/6 at 16x — two of the three
## shipped time scales disabled the player's guns entirely.
##
## Method mirrors EVIDENCE/playtest-log.md addendum 1: the projectile is built
## in code, placed SHOT_RANGE m from the target on a dead-straight line through
## its centre, the target's hp is reset before every shot, and a 1x control run
## fires last to rule out state drift.
##
## This is the test whose absence shipped the bug: the old tests only ever
## called try_hit() directly and never flew a bolt into anything.

const SHOT_RANGE: float = 10.0
const SHOTS_1X: int = 9
const SHOTS_4X: int = 7
const SHOTS_16X: int = 6
## Enough physics frames for a 1x bolt to cross SHOT_RANGE (4.7 m per step).
const MAX_FLIGHT_FRAMES: int = 12
## Lateral offset that must miss: well past bolt hit sphere + traffic capsule.
const WIDE_MISS_OFFSET: float = 12.0
const TOLERANCE: float = 0.0001


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()


func _make_traffic(parent: Node3D, pos: Vector3) -> TrafficShip:
	var ship: TrafficShip = TrafficShip.new()
	ship.apply_role(BalanceCombat.ROLE_CIVILIAN)
	ship.build_visual(BalanceCombat.COLOR_TRAFFIC_CIVILIAN)
	parent.add_child(ship)
	ship.global_position = pos
	# Space queries read the physics server, not the node — push the move now.
	ship.force_update_transform()
	return ship


## One shot: hp reset, bolt built in code SHOT_RANGE m out, dead straight
## through the target centre. Returns true when the target lost hull.
func _fire_one(parent: Node3D, target: TrafficShip, lateral: float = 0.0) -> bool:
	target.hp = target.max_hp
	var start_hp: float = target.hp
	var direction: Vector3 = Vector3(0.0, 0.0, -1.0)
	var origin: Vector3 = target.global_position + Vector3(lateral, 0.0, SHOT_RANGE)

	var bolt: PlayerProjectile = PlayerProjectile.new()
	parent.add_child(bolt)
	bolt.global_position = origin
	bolt.launch(direction, BalanceCombat.PLAYER_WEAPON_DAMAGE, BalanceCombat.PROJECTILE_SPEED)

	var hit: bool = false
	for _frame: int in MAX_FLIGHT_FRAMES:
		await get_tree().physics_frame
		if target.hp < start_hp:
			hit = true
			break
		if not is_instance_valid(bolt):
			break
	if is_instance_valid(bolt):
		bolt.queue_free()
	target.hp = target.max_hp
	return hit


func _volley(parent: Node3D, target: TrafficShip, scale: float, shots: int) -> int:
	assert_true(TimeScale.request_scale(scale), "%.0fx is a shipped time scale" % scale)
	assert_almost_eq(TimeScale.effective_scale(), scale, TOLERANCE, "no combat lock in the way")
	var hits: int = 0
	for _shot: int in shots:
		var landed: bool = await _fire_one(parent, target)
		if landed:
			hits += 1
	return hits


func test_nine_of_nine_bolts_hit_at_1x() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var target: TrafficShip = _make_traffic(space, Vector3.ZERO)
	await get_tree().physics_frame

	var hits: int = await _volley(space, target, Balance.TIME_SCALE_NORMAL, SHOTS_1X)
	assert_eq(hits, SHOTS_1X, "1x: %d/%d bolts hit" % [hits, SHOTS_1X])


func test_seven_of_seven_bolts_hit_at_4x() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var target: TrafficShip = _make_traffic(space, Vector3.ZERO)
	await get_tree().physics_frame

	var hits: int = await _volley(space, target, Balance.TIME_SCALE_FAST, SHOTS_4X)
	assert_eq(hits, SHOTS_4X, "4x: %d/%d bolts hit" % [hits, SHOTS_4X])


func test_six_of_six_bolts_hit_at_16x() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var target: TrafficShip = _make_traffic(space, Vector3.ZERO)
	await get_tree().physics_frame

	var hits: int = await _volley(space, target, Balance.TIME_SCALE_FASTEST, SHOTS_16X)
	assert_eq(hits, SHOTS_16X, "16x: %d/%d bolts hit" % [hits, SHOTS_16X])


func test_control_volley_back_at_1x_after_16x_rules_out_drift() -> void:
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var target: TrafficShip = _make_traffic(space, Vector3.ZERO)
	await get_tree().physics_frame

	var fast: int = await _volley(space, target, Balance.TIME_SCALE_FASTEST, SHOTS_16X)
	assert_eq(fast, SHOTS_16X, "16x: %d/%d bolts hit" % [fast, SHOTS_16X])
	var control: int = await _volley(space, target, Balance.TIME_SCALE_NORMAL, SHOTS_1X)
	assert_eq(control, SHOTS_1X, "1x control after 16x: %d/%d bolts hit" % [control, SHOTS_1X])


func test_a_bolt_that_passes_wide_still_misses_at_16x() -> void:
	## The sweep must not turn every fast bolt into a hit — a lane 12 m to the
	## side of the target passes through nothing.
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var target: TrafficShip = _make_traffic(space, Vector3.ZERO)
	await get_tree().physics_frame

	assert_true(TimeScale.request_scale(Balance.TIME_SCALE_FASTEST))
	var landed: bool = await _fire_one(space, target, WIDE_MISS_OFFSET)
	assert_false(landed, "a bolt 12 m off the line must not damage the target")


func test_point_blank_hull_the_bolt_was_born_inside_is_not_hit() -> void:
	## REPAIR-8 closed this: a bolt spawns PROJECTILE_LENGTH ahead of the muzzle
	## and must not auto-hit an off-target hull it was born inside. The swept
	## test could re-open it, so it is asserted here at every shipped scale.
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var target: TrafficShip = _make_traffic(space, Vector3.ZERO)
	await get_tree().physics_frame

	for scale: float in Balance.TIME_SCALES:
		assert_true(TimeScale.request_scale(scale))
		target.hp = target.max_hp
		var start_hp: float = target.hp
		var bolt: PlayerProjectile = PlayerProjectile.new()
		space.add_child(bolt)
		# Born inside the hull, aimed away along +X — the player was not
		# shooting at this ship.
		bolt.global_position = target.global_position
		bolt.launch(Vector3(1.0, 0.0, 0.0))
		await get_tree().physics_frame
		if is_instance_valid(bolt):
			bolt.queue_free()
		await get_tree().physics_frame
		assert_almost_eq(
			target.hp,
			start_hp,
			TOLERANCE,
			"%.0fx: a bolt born inside an off-target hull must not hit it" % scale
		)
	target.hp = target.max_hp


func test_try_hit_stays_directly_callable() -> void:
	## Existing tests drive damage through try_hit(); the swept path must not
	## take that away.
	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var target: TrafficShip = _make_traffic(space, Vector3(0.0, 0.0, -200.0))
	await get_tree().physics_frame

	var bolt: PlayerProjectile = PlayerProjectile.new()
	space.add_child(bolt)
	# Far from anything so only the explicit call can damage the target.
	bolt.global_position = Vector3(500.0, 500.0, 500.0)
	await get_tree().physics_frame
	var start_hp: float = target.hp
	bolt.try_hit(target)
	assert_almost_eq(
		target.hp, start_hp - BalanceCombat.PLAYER_WEAPON_DAMAGE, TOLERANCE, "try_hit still damages"
	)


func test_hostile_bolt_hits_the_player_at_16x() -> void:
	## Symmetry: if player bolts collide along their path and hostile bolts do
	## not, speeding up time becomes an exploit in one direction or the other.
	var space: Node3D = Node3D.new()
	add_child_autofree(space)

	var hull: HullConditionService = HullConditionService.new()
	space.add_child(hull)
	await get_tree().physics_frame
	hull.reset()
	var start: float = hull.condition()

	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().physics_frame

	assert_true(TimeScale.request_scale(Balance.TIME_SCALE_FASTEST))
	assert_almost_eq(
		TimeScale.effective_scale(), Balance.TIME_SCALE_FASTEST, TOLERANCE, "16x actually applied"
	)

	var bolt: HostileProjectile = HostileProjectile.new()
	space.add_child(bolt)
	bolt.global_position = Vector3(0.0, 0.0, SHOT_RANGE)
	bolt.launch(Vector3(0.0, 0.0, -1.0))
	for _frame: int in MAX_FLIGHT_FRAMES:
		await get_tree().physics_frame
		if hull.condition() < start:
			break
		if not is_instance_valid(bolt):
			break
	if is_instance_valid(bolt):
		bolt.queue_free()
	assert_lt(hull.condition(), start, "a hostile bolt at 16x must still reach the player")
