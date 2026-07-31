class_name NpcTraffic
extends Node3D

## Gray-box NPC traffic that reflects local policing — Alpha A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5
##
## Spawns simple orbiting ships; count and colour come from system.policing.
## Display only — no combat AI. Parent under SystemWorld after build.

var _ships: Array[MeshInstance3D] = []
var _angles: Array[float] = []
var _radii: Array[float] = []
var _heights: Array[float] = []
var _omegas: Array[float] = []


## Clear previous traffic and spawn for this system.
func rebuild_for_system(system_id: StringName) -> void:
	_clear()
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return
	var count: int = _count_for_policing(system.policing)
	var color: Color = _color_for_policing(system.policing)
	for i: int in count:
		var mesh: MeshInstance3D = _make_npc(color)
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
		mesh.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
		add_child(mesh)
		_ships.append(mesh)
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
		var ship: MeshInstance3D = _ships[i]
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
	for ship: MeshInstance3D in _ships:
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
	match policing:
		StarSystem.POLICED_BY_PATROLS:
			return BalanceEconomy.NPC_COUNT_PATROLLED
		StarSystem.POLICED_BY_CONTESTED:
			return BalanceEconomy.NPC_COUNT_CONTESTED
		StarSystem.POLICED_BY_NOBODY:
			return BalanceEconomy.NPC_COUNT_LAWLESS
		_:
			return BalanceEconomy.NPC_COUNT_CONTESTED


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


func _make_npc(color: Color) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = BalanceEconomy.NPC_MESH_SIZE
	mesh_instance.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh_instance.material_override = material
	return mesh_instance
