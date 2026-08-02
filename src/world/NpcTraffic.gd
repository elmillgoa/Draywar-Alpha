class_name NpcTraffic
extends Node3D

## Gray-box NPC traffic that reflects local policing — Alpha A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5
##
## Spawns simple orbiting ships; count and colour come from system.policing.
## Display only — no combat AI. Parent under SystemWorld after build.
## Live ship count feeds combat kill witness_count (E2.3).

var _ships: Array[Node3D] = []
var _angles: Array[float] = []
var _radii: Array[float] = []
var _heights: Array[float] = []
var _omegas: Array[float] = []


func _enter_tree() -> void:
	add_to_group(BalanceEconomy.GROUP_NPC_TRAFFIC)


## How many ambient traffic ships are currently alive (attribution witnesses).
func live_ship_count() -> int:
	var count: int = 0
	for ship: Node3D in _ships:
		if ship != null and is_instance_valid(ship):
			count += 1
	return count


## Clear previous traffic and spawn for this system.
func rebuild_for_system(system_id: StringName) -> void:
	_clear()
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return
	var count: int = _count_for_policing(system.policing)
	var color: Color = _color_for_policing(system.policing)
	for i: int in count:
		var ship: Node3D = _make_npc(color)
		var t: float = float(i) / float(maxi(count, 1))
		var angle: float = t * TAU
		var radius: float = lerpf(BalanceEconomy.NPC_ORBIT_MIN, BalanceEconomy.NPC_ORBIT_MAX, t)
		var height: float = lerpf(
			-BalanceEconomy.NPC_HEIGHT_SPREAD, BalanceEconomy.NPC_HEIGHT_SPREAD, t
		)
		var omega: float = (
			BalanceEconomy.NPC_ORBIT_OMEGA * (1.0 + t * BalanceEconomy.NPC_ORBIT_OMEGA_SPREAD)
		)
		if i % BalanceEconomy.NPC_ORBIT_REVERSE_EVERY == 1:
			omega = -omega
		ship.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
		add_child(ship)
		_ships.append(ship)
		_angles.append(angle)
		_radii.append(radius)
		_heights.append(height)
		_omegas.append(omega)


func _process(delta: float) -> void:
	var dt: float = TimeScale.scaled_delta(delta)
	for i: int in _ships.size():
		_angles[i] = _angles[i] + _omegas[i] * dt
		var angle: float = _angles[i]
		var radius: float = _radii[i]
		var height: float = _heights[i]
		var ship: Node3D = _ships[i]
		if ship == null or not is_instance_valid(ship):
			continue
		ship.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
		# Face along orbit tangent.
		var tangent: Vector3 = Vector3(-sin(angle), 0.0, cos(angle))
		if _omegas[i] < 0.0:
			tangent = -tangent
		if tangent.length_squared() > BalanceFlight.DIRECTION_EPSILON:
			ship.look_at(ship.position + tangent, Vector3.UP)


func _clear() -> void:
	for ship: Node3D in _ships:
		if ship != null and is_instance_valid(ship):
			remove_child(ship)
			ship.free()
	_ships.clear()
	_angles.clear()
	_radii.clear()
	_heights.clear()
	_omegas.clear()


func _load_system(id: StringName) -> StarSystem:
	if not ContentLibrary.has_item(id):
		return null
	var item: ContentItem = ContentLibrary.item(id)
	return item as StarSystem


func _count_for_policing(policing: StringName) -> int:
	# BalanceEconomy.npc_count_for_policing is the single source for density.
	return BalanceEconomy.npc_count_for_policing(policing)


func _color_for_policing(policing: StringName) -> Color:
	match policing:
		StarSystem.POLICED_BY_PATROLS:
			return BalanceEconomy.NPC_COLOR_PATROLLED
		StarSystem.POLICED_BY_CONTESTED:
			return BalanceEconomy.NPC_COLOR_CONTESTED
		StarSystem.POLICED_BY_NOBODY:
			return BalanceEconomy.NPC_COLOR_LAWLESS
		_:
			return BalanceEconomy.NPC_COLOR_DEFAULT


func _make_npc(color: Color) -> Node3D:
	# Capsule hull + small dorsal fin — traffic, not combat fighter.
	# AnimatableBody3D so orbiting ships are solid bumps (E6.1); lock/kill is E6.3.
	var root: AnimatableBody3D = AnimatableBody3D.new()
	root.collision_layer = BalanceFlight.PHYSICS_LAYER_SHIPS
	root.collision_mask = 0
	root.set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_TRAFFIC_LIGHT)
	root.add_to_group(BalanceCombat.GROUP_IMPACT_BODY)

	var hull: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = BalanceEconomy.NPC_MESH_SIZE.x * BalanceEconomy.NPC_CAPSULE_RADIUS_FACTOR
	capsule.height = BalanceEconomy.NPC_MESH_SIZE.z
	capsule.radial_segments = BalanceEconomy.NPC_CAPSULE_RADIAL_SEGMENTS
	hull.mesh = capsule
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	hull.material_override = material
	# Capsule long axis is Y; lay along flight forward.
	hull.rotation_degrees = Vector3(BalanceEconomy.NPC_MESH_PITCH_DEGREES, 0.0, 0.0)
	root.add_child(hull)

	var fin: MeshInstance3D = MeshInstance3D.new()
	var fin_box: BoxMesh = BoxMesh.new()
	fin_box.size = BalanceEconomy.NPC_FIN_SIZE
	fin.mesh = fin_box
	var fin_mat: StandardMaterial3D = StandardMaterial3D.new()
	fin_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fin_mat.albedo_color = color.lightened(BalanceEconomy.NPC_FIN_LIGHTEN)
	fin.material_override = fin_mat
	fin.position = BalanceEconomy.NPC_FIN_OFFSET
	root.add_child(fin)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "TrafficCollider"
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = BalanceEconomy.NPC_MESH_SIZE.x * BalanceEconomy.NPC_CAPSULE_RADIUS_FACTOR
	shape.height = BalanceEconomy.NPC_MESH_SIZE.z
	collision.shape = shape
	collision.rotation_degrees = Vector3(BalanceEconomy.NPC_MESH_PITCH_DEGREES, 0.0, 0.0)
	root.add_child(collision)
	return root
