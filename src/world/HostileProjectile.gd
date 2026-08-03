class_name HostileProjectile
extends Area3D

## Hostile bolt — travels; hits the player ship on contact. No friendly fire.
##
## Mirrors PlayerProjectile. Lives in world with HostileNpc (layer boundary).

var _direction: Vector3 = Vector3(0.0, 0.0, -1.0)
var _speed: float = BalanceCombat.HOSTILE_PROJECTILE_SPEED
var _damage: float = BalanceCombat.HOSTILE_DAMAGE
var _life: float = BalanceCombat.HOSTILE_PROJECTILE_LIFETIME
var _spent: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	# PlayerShip / hostiles use collision_layer 1 (default CharacterBody3D).
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_build_mesh()


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
	global_position = global_position + _direction * _speed * dt
	# Teleport moves do not always emit body_entered; poll after each step.
	_try_overlap_hits()
	if _spent:
		return
	_life -= dt
	if _life <= 0.0:
		queue_free()


func _try_overlap_hits() -> void:
	force_update_transform()
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
