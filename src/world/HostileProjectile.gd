class_name HostileProjectile
extends Area3D

## Hostile bolt — travels; hits the player ship on contact. No friendly fire.
##
## Mirrors PlayerProjectile. Lives in world with HostileNpc (layer boundary).
##
## Swept the same way as the player's bolt (REPAIR-11 / audit #48): the step is
## 3.7 m at 1x and 58.7 m at 16x, so sampling only the landing point meant a
## sped-up hostile could not hit the player either. Leaving one side unswept
## would have made time scale an exploit in whichever direction was fixed.
##
## No spawn grace here, unlike PlayerProjectile: a hostile bolt is born ahead of
## the hostile's own nose and can only ever damage the player, so there is no
## "born inside an off-target hull" case to protect against, and a point-blank
## hostile shot landing is the behaviour that already shipped.

var _direction: Vector3 = Vector3(0.0, 0.0, -1.0)
var _speed: float = BalanceCombat.HOSTILE_PROJECTILE_SPEED
var _damage: float = BalanceCombat.HOSTILE_DAMAGE
var _life: float = BalanceCombat.HOSTILE_PROJECTILE_LIFETIME
var _spent: bool = false
var _hit_cast: ShapeCast3D = null


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	# PlayerShip / hostiles use collision_layer 1 (default CharacterBody3D).
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_build_mesh()
	_build_hit_cast()


## Launch along `direction` (normalized) from current global_position.
## Optional `damage` overrides the default HOSTILE_DAMAGE (profile bolts).
func launch(direction: Vector3, damage: float = -1.0) -> void:
	if direction.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		_direction = Vector3(0.0, 0.0, -1.0)
	else:
		_direction = direction.normalized()
	if damage > 0.0:
		_damage = damage
	look_at(global_position + _direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var dt: float = TimeScale.scaled_delta(delta)
	var from_position: Vector3 = global_position
	global_position = from_position + _direction * _speed * dt
	_try_path_hits(from_position)
	if _spent:
		return
	_life -= dt
	if _life <= 0.0:
		queue_free()


## Everything the bolt crossed this step, not just where it landed.
func _try_path_hits(from_position: Vector3) -> void:
	force_update_transform()
	_sweep_hits(from_position, global_position)
	if _spent:
		return
	# Belt and braces: a player that moved onto the landing point this frame.
	_try_overlap_hits()


## Shape-cast the flight segment and damage the player if it is on it.
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


## Colliders the last cast reported, nearest along the flight path first.
## Insertion sort: the list is capped at PROJECTILE_SWEEP_MAX_HITS.
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
	try_hit(body)


func _on_area_entered(area: Area3D) -> void:
	try_hit(area)


## Apply damage if `node` (or a parent) is the player ship. Tests may call this.
func try_hit(node: Node) -> void:
	if _spent or node == null:
		return
	var ship: Node = _player_from(node)
	if ship == null:
		return
	_spent = true
	_apply_player_damage(_damage)
	queue_free()


func _player_from(node: Node) -> Node:
	var walk: Node = node
	while walk != null:
		if walk.is_in_group(BalanceSession.GROUP_PLAYER_SHIP):
			return walk
		walk = walk.get_parent()
	return null


func _apply_player_damage(amount: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var hull: Node = tree.get_first_node_in_group(&"hull_condition_service")
	if hull != null and hull.has_method(&"apply_damage"):
		hull.call(&"apply_damage", amount)


## Lead intercept so a bolt at `shot_speed` meets a moving target.
## Shared pure solver (same math as FlightMath.lead_point) — world must not ref ui/entities.
static func lead_point(
	shooter_pos: Vector3, target_pos: Vector3, target_vel: Vector3, shot_speed: float
) -> Vector3:
	return BalanceCombat.lead_point(shooter_pos, target_pos, target_vel, shot_speed)


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
	sphere.radius = (
		BalanceCombat.HOSTILE_PROJECTILE_RADIUS * BalanceCombat.HOSTILE_PROJECTILE_HIT_RADIUS_SCALE
	)
	_hit_cast.shape = sphere
	add_child(_hit_cast)


func _build_mesh() -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = BalanceCombat.HOSTILE_PROJECTILE_RADIUS
	capsule.height = BalanceCombat.HOSTILE_PROJECTILE_LENGTH
	mesh_inst.mesh = capsule
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = BalanceCombat.COLOR_HOSTILE_PROJECTILE
	mat.emission_enabled = true
	mat.emission = BalanceCombat.COLOR_HOSTILE_PROJECTILE
	mesh_inst.material_override = mat
	mesh_inst.rotation_degrees = Vector3(BalanceFlight.SHIP_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(mesh_inst)

	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = (
		BalanceCombat.HOSTILE_PROJECTILE_RADIUS * BalanceCombat.HOSTILE_PROJECTILE_HIT_RADIUS_SCALE
	)
	shape.shape = sphere
	add_child(shape)
