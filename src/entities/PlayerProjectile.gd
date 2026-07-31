class_name PlayerProjectile
extends Area3D

## Player freighter bolt — travels; hits on contact. No auto-aim.
##
## Implements: beginner ship weapon (not a tracking turret).

var _direction: Vector3 = Vector3(0.0, 0.0, -1.0)
var _speed: float = BalanceCombat.PROJECTILE_SPEED
var _damage: float = BalanceCombat.PLAYER_WEAPON_DAMAGE
var _life: float = BalanceCombat.PROJECTILE_LIFETIME
var _spent: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_build_mesh()


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


## Apply damage if `node` (or a parent) is a live hostile. Tests may call this.
func try_hit(node: Node) -> void:
	if _spent or node == null:
		return
	var target: Node = _hostile_from(node)
	if target == null:
		return
	_spent = true
	if target.has_method(&"take_damage"):
		target.call(&"take_damage", _damage)
	queue_free()


func _hostile_from(node: Node) -> Node:
	var walk: Node = node
	while walk != null:
		if walk.is_in_group(BalanceCombat.GROUP_HOSTILE):
			if walk.has_method(&"is_alive") and walk.call(&"is_alive") != true:
				return null
			return walk
		walk = walk.get_parent()
	return null


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
