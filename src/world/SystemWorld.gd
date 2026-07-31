class_name SystemWorld
extends Node3D

## Playable star system scene — Path C B0/B1.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B0, B1
##
## Loads a system id from ContentLibrary and places station + gate meshes with
## distinct silhouettes, per-system lighting, starfield, and world gate labels.
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
	_spawn_hostile()
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
	environment.background_color = BalanceFlight.space_color_for(system_id)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = BalanceFlight.ambient_color_for(system_id)
	environment.ambient_light_energy = BalanceFlight.ambient_energy_for(system_id)
	world_env.environment = environment
	world_env.name = "WorldEnvironment"
	add_child(world_env)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "SystemSun"
	sun.rotation_degrees = Vector3(BalanceFlight.sun_pitch_for(system_id), 0.0, 0.0)
	add_child(sun)

	_add_starfield()


func _add_starfield() -> void:
	var stars_root: Node3D = Node3D.new()
	stars_root.name = "Starfield"
	add_child(stars_root)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# Stable field per system so jumps don't reshuffle stars every visit.
	rng.seed = hash(system_id)
	var cool: Color = BalanceFlight.star_color_cool_for(system_id)
	var warm: Color = BalanceFlight.star_color_warm_for(system_id)
	var count: int = BalanceFlight.starfield_count_for(system_id)
	for i: int in count:
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = (
			BalanceFlight.STARFIELD_STAR_SIZE * BalanceFlight.STARFIELD_SPHERE_RADIUS_FACTOR
		)
		sphere.height = BalanceFlight.STARFIELD_STAR_SIZE
		sphere.radial_segments = BalanceFlight.STARFIELD_RADIAL_SEGMENTS
		sphere.rings = BalanceFlight.STARFIELD_RINGS
		mesh_instance.mesh = sphere
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = cool if i % BalanceFlight.STARFIELD_WARM_EVERY != 0 else warm
		mesh_instance.material_override = material
		var dir: Vector3 = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-BalanceFlight.STARFIELD_Y_SPREAD, BalanceFlight.STARFIELD_Y_SPREAD),
			rng.randf_range(-1.0, 1.0)
		)
		if dir.length_squared() < BalanceFlight.DIRECTION_EPSILON:
			dir = Vector3.FORWARD
		dir = dir.normalized()
		var radius: float = rng.randf_range(
			BalanceFlight.STARFIELD_RADIUS_MIN, BalanceFlight.STARFIELD_RADIUS_MAX
		)
		mesh_instance.position = dir * radius
		stars_root.add_child(mesh_instance)


func _place_stations(system: StarSystem) -> void:
	var station_color: Color = BalanceFlight.station_color_for(system_id)
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
		var body: Node3D = _make_station_body(pos, station_color)
		body.name = "Station_%s" % String(station_id)
		add_child(body)
		var name_label: Label3D = _make_world_label(
			label.to_upper(), BalanceFlight.GATE_LABEL_FONT_SIZE
		)
		name_label.position = (
			pos
			+ Vector3(
				0.0,
				BalanceFlight.STATION_CYLINDER_HEIGHT * BalanceFlight.STATION_LABEL_HEIGHT_FACTOR,
				0.0
			)
		)
		add_child(name_label)


func _place_gates(system: StarSystem) -> void:
	if system.gate_destination_ids.is_empty():
		return
	var count: int = system.gate_destination_ids.size()
	for index: int in count:
		var dest_id: StringName = system.gate_destination_ids[index]
		var pos: Vector3 = _gate_position_for_index(index, count)
		gate_world_positions[dest_id] = pos
		var gate_root: Node3D = _make_gate_body(pos, dest_id)
		gate_root.name = "Gate_%s" % String(dest_id)
		add_child(gate_root)


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


## One combat hostile near the station when the system security allows pirates.
## Patrolled government space stays safe on undock (no free kill at Alpha).
func _spawn_hostile() -> void:
	if not system_allows_hostiles(system_id):
		return
	var pos: Vector3 = BalanceFlight.STATION_POSITION + BalanceCombat.SPAWN_OFFSET
	HostileNpc.spawn_under(self, pos)


## Whether this system places a combat hostile (not ambient traffic).
static func system_allows_hostiles(for_system_id: StringName) -> bool:
	if not ContentLibrary.has_item(for_system_id):
		return false
	var item: ContentItem = ContentLibrary.item(for_system_id)
	if not (item is StarSystem):
		return false
	var system: StarSystem = item as StarSystem
	match system.policing:
		StarSystem.POLICED_BY_PATROLS:
			return BalanceCombat.SPAWN_IN_PATROLLED
		StarSystem.POLICED_BY_CONTESTED:
			return BalanceCombat.SPAWN_IN_CONTESTED
		StarSystem.POLICED_BY_NOBODY:
			return BalanceCombat.SPAWN_IN_LAWLESS
		_:
			return false


## Test / console helper: place a hostile under this world at an offset from station.
func spawn_hostile_at(offset: Vector3) -> HostileNpc:
	return HostileNpc.spawn_under(self, BalanceFlight.STATION_POSITION + offset)


func _make_station_body(pos: Vector3, color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos

	var core: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = BalanceFlight.STATION_CYLINDER_RADIUS
	cylinder.bottom_radius = BalanceFlight.STATION_CYLINDER_RADIUS
	cylinder.height = BalanceFlight.STATION_CYLINDER_HEIGHT
	cylinder.radial_segments = BalanceFlight.STATION_CYLINDER_SEGMENTS
	core.mesh = cylinder
	core.material_override = _unshaded(color)
	root.add_child(core)

	var disc: MeshInstance3D = MeshInstance3D.new()
	var disc_mesh: CylinderMesh = CylinderMesh.new()
	disc_mesh.top_radius = BalanceFlight.STATION_DISC_RADIUS
	disc_mesh.bottom_radius = BalanceFlight.STATION_DISC_RADIUS
	disc_mesh.height = BalanceFlight.STATION_DISC_HEIGHT
	disc_mesh.radial_segments = BalanceFlight.STATION_DISC_SEGMENTS
	disc.mesh = disc_mesh
	disc.material_override = _unshaded(color.lightened(BalanceFlight.STATION_DISC_LIGHTEN))
	disc.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(disc)

	# Horizontal spoke — station reads as a structure, not a plain barrel.
	var spoke: MeshInstance3D = MeshInstance3D.new()
	var spoke_mesh: BoxMesh = BoxMesh.new()
	spoke_mesh.size = BalanceFlight.STATION_SPOKE_SIZE
	spoke.mesh = spoke_mesh
	spoke.material_override = _unshaded(color.lightened(BalanceFlight.STATION_SPOKE_LIGHTEN))
	root.add_child(spoke)

	# Antenna tower on top of the core cylinder.
	var tower: MeshInstance3D = MeshInstance3D.new()
	var tower_mesh: CylinderMesh = CylinderMesh.new()
	tower_mesh.top_radius = (
		BalanceFlight.STATION_TOWER_RADIUS * BalanceFlight.STATION_TOWER_TOP_RADIUS_FACTOR
	)
	tower_mesh.bottom_radius = BalanceFlight.STATION_TOWER_RADIUS
	tower_mesh.height = BalanceFlight.STATION_TOWER_HEIGHT
	tower_mesh.radial_segments = BalanceFlight.STATION_CYLINDER_SEGMENTS
	tower.mesh = tower_mesh
	tower.material_override = _unshaded(color.lightened(BalanceFlight.STATION_TOWER_LIGHTEN))
	tower.position = Vector3(0.0, BalanceFlight.STATION_TOWER_Y, 0.0)
	root.add_child(tower)
	return root


func _make_gate_body(pos: Vector3, dest_id: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos

	# Ring silhouette (torus) — distinct from station cylinders and ship prisms.
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = BalanceFlight.GATE_RING_INNER
	torus.outer_radius = BalanceFlight.GATE_RING_OUTER
	torus.rings = BalanceFlight.GATE_RING_SEGMENTS
	torus.ring_segments = BalanceFlight.GATE_RING_RING_SEGMENTS
	ring.mesh = torus
	ring.material_override = _unshaded(BalanceFlight.COLOR_GATE)
	# Stand the ring upright so it reads as a jump aperture from approach.
	ring.rotation_degrees = Vector3(BalanceFlight.GATE_RING_PITCH_DEGREES, 0.0, 0.0)
	root.add_child(ring)

	var core: MeshInstance3D = MeshInstance3D.new()
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = BalanceFlight.GATE_RING_INNER * BalanceFlight.GATE_CORE_RADIUS_FACTOR
	core_mesh.height = BalanceFlight.GATE_RING_INNER * BalanceFlight.GATE_CORE_HEIGHT_FACTOR
	core.mesh = core_mesh
	core.material_override = _unshaded(BalanceFlight.COLOR_GATE_CORE)
	root.add_child(core)

	var beacon: MeshInstance3D = MeshInstance3D.new()
	var beacon_mesh: CylinderMesh = CylinderMesh.new()
	beacon_mesh.top_radius = BalanceFlight.GATE_BEACON_RADIUS
	beacon_mesh.bottom_radius = BalanceFlight.GATE_BEACON_RADIUS
	beacon_mesh.height = BalanceFlight.GATE_BEACON_HEIGHT
	beacon.mesh = beacon_mesh
	beacon.material_override = _unshaded(
		BalanceFlight.COLOR_GATE.lightened(BalanceFlight.GATE_BEACON_LIGHTEN)
	)
	beacon.position = Vector3(
		0.0, BalanceFlight.GATE_BEACON_HEIGHT * BalanceFlight.GATE_BEACON_Y_FACTOR, 0.0
	)
	root.add_child(beacon)

	var dest_name: String = _content_display_name(dest_id)
	var label: Label3D = _make_world_label(
		BalanceEconomy.GATE_WORLD_LABEL_FORMAT % dest_name.to_upper(),
		BalanceFlight.GATE_LABEL_FONT_SIZE
	)
	label.position = Vector3(0.0, BalanceFlight.GATE_LABEL_HEIGHT, 0.0)
	root.add_child(label)
	return root


func _make_world_label(text: String, font_size: int) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = BalanceFlight.GATE_LABEL_PIXEL_SIZE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = BalanceFlight.COLOR_GATE_CORE
	label.outline_modulate = Color(0.0, 0.0, 0.0, BalanceFlight.GATE_LABEL_OUTLINE_ALPHA)
	label.outline_size = BalanceFlight.GATE_LABEL_OUTLINE_SIZE
	label.no_depth_test = true
	return label


func _content_display_name(id: StringName) -> String:
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
