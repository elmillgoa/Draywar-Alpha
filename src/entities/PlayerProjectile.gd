class_name PlayerProjectile
extends Area3D

## Player freighter bolt — travels; hits the first thing on the line it crossed.
## No auto-aim.
##
## Implements: beginner ship weapon (not a tracking turret).
##
## A bolt teleports its whole step every physics tick — 4.7 m at 1x but 74.7 m
## at 16x — so asking "what am I overlapping now?" after the move found nothing
## above 1x and the player's guns were dead at two of the three shipped time
## scales (REPAIR-11 / audit #48). Each tick now shape-casts the segment the
## bolt actually crossed and takes the nearest target on it: one physics query
## per bolt per tick, the same cost at 16x as at 1x.

var _direction: Vector3 = Vector3(0.0, 0.0, -1.0)
var _speed: float = BalanceCombat.PROJECTILE_SPEED
var _damage: float = BalanceCombat.PLAYER_WEAPON_DAMAGE
var _life: float = BalanceCombat.PROJECTILE_LIFETIME
var _spent: bool = false
## Metres flown since spawn. Hit checks start after
## BalanceCombat.PROJECTILE_SPAWN_GRACE_DISTANCE so a bolt placed at
## PROJECTILE_LENGTH ahead of the muzzle does not hit a point-blank off-target
## hull it was born inside (REPAIR-8). It is a distance and not a tick count on
## purpose: one tick of grace is 4.7 m at 1x and 74.7 m at 16x, which would
## re-break the thing above.
var _travelled: float = 0.0
var _hit_cast: ShapeCast3D = null


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_build_mesh()
	_build_hit_cast()


## Launch along `direction` (normalized) from current global_position.
## Optional damage / speed override active Hull weapon fields (E2.4).
func launch(direction: Vector3, damage: float = -1.0, speed: float = -1.0) -> void:
	if direction.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		_direction = Vector3(0.0, 0.0, -1.0)
	else:
		_direction = direction.normalized()
	if damage > 0.0:
		_damage = damage
	if speed > 0.0:
		_speed = speed
	look_at(global_position + _direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var dt: float = TimeScale.scaled_delta(delta)
	var step: float = _speed * dt
	var from_position: Vector3 = global_position
	global_position = from_position + _direction * step
	_try_path_hits(from_position, step)
	if _spent:
		return
	_travelled += step
	_life -= dt
	if _life <= 0.0:
		queue_free()


## Everything the bolt crossed this step, spawn grace removed.
func _try_path_hits(from_position: Vector3, step: float) -> void:
	force_update_transform()
	var grace: float = BalanceCombat.PROJECTILE_SPAWN_GRACE_DISTANCE
	if _travelled + step <= grace:
		return
	# Skip the part of this step that is still inside the spawn grace.
	var skip: float = maxf(0.0, grace - _travelled)
	_sweep_hits(from_position + _direction * skip, global_position)
	if _spent:
		return
	# Belt and braces: a target that moved onto the landing point this frame.
	_try_overlap_hits()


## Shape-cast the flight segment and damage the nearest lockable ship on it.
func _sweep_hits(from_position: Vector3, to_position: Vector3) -> void:
	if _hit_cast == null:
		return
	var motion: Vector3 = to_position - from_position
	if motion.length_squared() <= 0.0:
		return
	_hit_cast.global_position = from_position
	_hit_cast.target_position = motion
	_hit_cast.force_shapecast_update()
	for node: Node in _cast_hits_nearest_first(from_position):
		try_hit(node)
		if _spent:
			return


## Colliders the last cast reported, ordered by how far along the flight path
## they sit — a fast bolt can cross two ships in one step and must hit the near
## one. Insertion sort: the list is capped at PROJECTILE_SWEEP_MAX_HITS.
func _cast_hits_nearest_first(from_position: Vector3) -> Array[Node]:
	var nodes: Array[Node] = []
	var along: Array[float] = []
	for index: int in _hit_cast.get_collision_count():
		var collider: Object = _hit_cast.get_collider(index)
		if not (collider is Node):
			continue
		var point: Vector3 = _hit_cast.get_collision_point(index)
		var distance: float = (point - from_position).dot(_direction)
		var slot: int = nodes.size()
		while slot > 0 and along[slot - 1] > distance:
			slot -= 1
		nodes.insert(slot, collider as Node)
		along.insert(slot, distance)
	return nodes


func _try_overlap_hits() -> void:
	for body: Node3D in get_overlapping_bodies():
		try_hit(body)
		if _spent:
			return
	for area: Area3D in get_overlapping_areas():
		try_hit(area)
		if _spent:
			return


func _on_body_entered(body: Node) -> void:
	if _travelled < BalanceCombat.PROJECTILE_SPAWN_GRACE_DISTANCE:
		return
	try_hit(body)


func _on_area_entered(area: Area3D) -> void:
	if _travelled < BalanceCombat.PROJECTILE_SPAWN_GRACE_DISTANCE:
		return
	try_hit(area)


## Apply damage if `node` (or a parent) is a live lockable ship. Tests may call this.
func try_hit(node: Node) -> void:
	if _spent or node == null:
		return
	var target: Node = _lockable_from(node)
	if target == null:
		return
	_spent = true
	if target.has_method(&"take_damage"):
		target.call(&"take_damage", _damage)
	queue_free()


func _lockable_from(node: Node) -> Node:
	var walk: Node = node
	while walk != null:
		if walk.is_in_group(BalanceCombat.GROUP_LOCKABLE):
			if walk.has_method(&"is_alive") and walk.call(&"is_alive") != true:
				return null
			return walk
		walk = walk.get_parent()
	return null


## Swept hit volume. `top_level` so its transform is the flight segment and not
## the bolt's own nose-forward basis; `enabled = false` because it is driven by
## force_shapecast_update() once a tick rather than polled by the engine.
func _build_hit_cast() -> void:
	_hit_cast = ShapeCast3D.new()
	_hit_cast.name = "BoltSweep"
	_hit_cast.enabled = false
	_hit_cast.top_level = true
	_hit_cast.exclude_parent = true
	_hit_cast.collide_with_bodies = true
	_hit_cast.collide_with_areas = true
	_hit_cast.collision_mask = collision_mask
	_hit_cast.max_results = BalanceCombat.PROJECTILE_SWEEP_MAX_HITS
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = BalanceCombat.PROJECTILE_RADIUS * BalanceCombat.PROJECTILE_HIT_RADIUS_SCALE
	_hit_cast.shape = sphere
	add_child(_hit_cast)


func _build_mesh() -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = BalanceCombat.PROJECTILE_RADIUS
	capsule.height = BalanceCombat.PROJECTILE_LENGTH
	mesh_inst.mesh = capsule
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = BalanceCombat.COLOR_PROJECTILE
	mat.emission_enabled = true
	mat.emission = BalanceCombat.COLOR_PROJECTILE
	mesh_inst.material_override = mat
	mesh_inst.rotation_degrees = Vector3(BalanceFlight.SHIP_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(mesh_inst)

	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = BalanceCombat.PROJECTILE_RADIUS * BalanceCombat.PROJECTILE_HIT_RADIUS_SCALE
	shape.shape = sphere
	add_child(shape)
