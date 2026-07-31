class_name SystemWorld
extends Node3D

## Gray-box star system scene — Alpha A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1, A5
##
## Loads a system id from ContentLibrary and places station + gate meshes.
## Does not spawn the player (entities layer). Main composes the two.
## Gates are jump destinations (GateTravelService + Main rebuild).

signal built(system_id: StringName)

var system_id: StringName = BalanceFlight.PLAYABLE_SYSTEM_ID

var station_world_positions: Dictionary[StringName, Vector3] = {}
var station_display_names: Dictionary[StringName, String] = {}
## destination_system_id → world position of the gate mesh.
var gate_world_positions: Dictionary[StringName, Vector3] = {}
var _system_display_name: String = ""
var _npc_traffic: NpcTraffic = null


## Builds the gray box for `system_id`. Safe to call once; call `clear_world`
## first when reusing the node for a jump.
func build() -> void:
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return
	_system_display_name = system.display_name
	_add_environment()
	_place_stations(system)
	_place_gates(system)
	_spawn_npc_traffic()
	built.emit(system_id)
	EventBus.on_system_entered.emit(system_id)


## Remove placed meshes and traffic so `build()` can run for another system.
func clear_world() -> void:
	for child: Node in get_children():
		# Keep play entities parented under the world (named by Main).
		if child.name == "PlayerShip" or child.name == "ChaseCamera":
			continue
		child.queue_free()
	station_world_positions.clear()
	station_display_names.clear()
	gate_world_positions.clear()
	_system_display_name = ""
	_npc_traffic = null


## Display name for HUD / menus (via ContentLibrary if callers prefer).
func system_display_name() -> String:
	return _system_display_name


## World position of a station, or the balance station anchor if unknown.
func station_position(station_id: StringName) -> Vector3:
	if station_world_positions.has(station_id):
		return station_world_positions[station_id]
	return BalanceFlight.STATION_POSITION


## Display name for a station id.
func station_name(station_id: StringName) -> String:
	if station_display_names.has(station_id):
		return station_display_names[station_id]
	return String(station_id)


## Copy of station id → world position for docking setup.
func station_positions() -> Dictionary[StringName, Vector3]:
	return station_world_positions.duplicate()


## Copy of destination system id → gate world position.
func gate_positions() -> Dictionary[StringName, Vector3]:
	return gate_world_positions.duplicate()


## Where the player should spawn relative to the station anchor.
func player_spawn_position() -> Vector3:
	return BalanceFlight.STATION_POSITION + BalanceFlight.PLAYER_SPAWN_OFFSET


## Arrival pose after a jump into this system (near the return gate if any).
func jump_arrival_position(from_system_id: StringName) -> Vector3:
	if gate_world_positions.has(from_system_id):
		return gate_world_positions[from_system_id] + BalanceEconomy.JUMP_ARRIVAL_OFFSET
	if not gate_world_positions.is_empty():
		var first_dest: StringName = gate_world_positions.keys()[0]
		return gate_world_positions[first_dest] + BalanceEconomy.JUMP_ARRIVAL_OFFSET
	return player_spawn_position()


## Nearest station id from a world point (empty if none).
func nearest_station_id(from: Vector3) -> StringName:
	var best_id: StringName = &""
	var best_dist: float = INF
	for station_id: StringName in station_world_positions:
		var dist: float = from.distance_to(station_world_positions[station_id])
		if dist < best_dist:
			best_dist = dist
			best_id = station_id
	return best_id


## Distance to a station id, or INF if unknown.
func distance_to_station(from: Vector3, station_id: StringName) -> float:
	if not station_world_positions.has(station_id):
		return INF
	return from.distance_to(station_world_positions[station_id])


func _load_system(id: StringName) -> StarSystem:
	if not ContentLibrary.has_item(id):
		push_error("SystemWorld: unknown system id '%s'" % id)
		return null
	var item: ContentItem = ContentLibrary.item(id)
	var system: StarSystem = item as StarSystem
	if system == null:
		push_error("SystemWorld: '%s' is not a StarSystem" % id)
		return null
	return system


func _add_environment() -> void:
	var world_env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BalanceFlight.COLOR_SPACE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = BalanceFlight.COLOR_AMBIENT
	world_env.environment = environment
	add_child(world_env)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(BalanceFlight.SUN_PITCH_DEGREES, 0.0, 0.0)
	add_child(sun)


func _place_stations(system: StarSystem) -> void:
	for station_id: StringName in system.station_ids:
		var offset: Vector3 = Vector3.ZERO
		var label: String = String(station_id)
		if ContentLibrary.has_item(station_id):
			var item: ContentItem = ContentLibrary.item(station_id)
			var station: Station = item as Station
			if station != null:
				offset = station.position_offset
				label = station.display_name
		var pos: Vector3 = BalanceFlight.STATION_POSITION + offset
		station_world_positions[station_id] = pos
		station_display_names[station_id] = label
		add_child(_make_box(pos, BalanceFlight.STATION_MESH_SIZE, BalanceFlight.COLOR_STATION))


func _place_gates(system: StarSystem) -> void:
	if system.gate_destination_ids.is_empty():
		return
	var count: int = system.gate_destination_ids.size()
	for index: int in count:
		var dest_id: StringName = system.gate_destination_ids[index]
		var pos: Vector3 = _gate_position_for_index(index, count)
		gate_world_positions[dest_id] = pos
		add_child(_make_box(pos, BalanceFlight.GATE_MESH_SIZE, BalanceFlight.COLOR_GATE))


func _gate_position_for_index(index: int, count: int) -> Vector3:
	if count <= 1:
		return BalanceFlight.GATE_POSITION
	var mid: float = float(count - 1) * BalanceEconomy.GATE_ARC_MID_HALF
	var step: float = BalanceEconomy.GATE_ARC_STEP_DEGREES
	var angle_deg: float = (float(index) - mid) * step
	var angle_rad: float = deg_to_rad(angle_deg)
	var offset: Vector3 = Vector3(
		sin(angle_rad) * BalanceEconomy.GATE_ARC_RADIUS,
		0.0,
		cos(angle_rad) * BalanceEconomy.GATE_ARC_RADIUS
	)
	return BalanceFlight.GATE_POSITION + offset


func _spawn_npc_traffic() -> void:
	_npc_traffic = NpcTraffic.new()
	_npc_traffic.name = "NpcTraffic"
	add_child(_npc_traffic)
	_npc_traffic.rebuild_for_system(system_id)


func _make_box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh_instance.material_override = material
	mesh_instance.position = pos
	return mesh_instance
