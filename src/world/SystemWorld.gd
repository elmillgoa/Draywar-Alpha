class_name SystemWorld
extends Node3D

## Gray-box star system scene — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Loads a system id from ContentLibrary and places station + gate meshes.
## Does not spawn the player (entities layer). Main composes the two.
## Gate is visual only (no jump for A1).

signal built(system_id: StringName)

var system_id: StringName = BalanceFlight.PLAYABLE_SYSTEM_ID

var station_world_positions: Dictionary[StringName, Vector3] = {}
var station_display_names: Dictionary[StringName, String] = {}
var _system_display_name: String = ""


## Builds the gray box for `system_id`. Safe to call once from Main.
func build() -> void:
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return
	_system_display_name = system.display_name
	_add_environment()
	_place_stations(system)
	_place_gates(system)
	built.emit(system_id)
	EventBus.on_system_entered.emit(system_id)


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


## Where the player should spawn relative to the station anchor.
func player_spawn_position() -> Vector3:
	return BalanceFlight.STATION_POSITION + BalanceFlight.PLAYER_SPAWN_OFFSET


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
	var gate_pos: Vector3 = BalanceFlight.GATE_POSITION
	add_child(_make_box(gate_pos, BalanceFlight.GATE_MESH_SIZE, BalanceFlight.COLOR_GATE))


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
