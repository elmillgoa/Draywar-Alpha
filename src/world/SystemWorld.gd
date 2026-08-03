class_name SystemWorld
extends Node3D

## Playable star system scene — Path C B0/B1.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B0, B1
##
## Loads a system id from ContentLibrary and places station + gate meshes with
## distinct silhouettes, per-system lighting, starfield, celestial sky (E6.2),
## and world gate labels. Does not spawn the player (entities layer). Main
## composes the two. Gates are jump destinations (GateTravelService + Main rebuild).

signal built(system_id: StringName)

var system_id: StringName = BalanceFlight.PLAYABLE_SYSTEM_ID

var station_world_positions: Dictionary[StringName, Vector3] = {}
var station_display_names: Dictionary[StringName, String] = {}
## destination_system_id → world position of the gate mesh.
var gate_world_positions: Dictionary[StringName, Vector3] = {}
var _system_display_name: String = ""
var _npc_traffic: NpcTraffic = null


func _ready() -> void:
	EventBus.on_mission_accepted.connect(_on_mission_accepted_ensure_prey)
	EventBus.on_undocked.connect(_on_undocked_ensure_prey)
	EventBus.on_system_entered.connect(_on_system_entered_ensure_prey)
	EventBus.on_mission_accepted.connect(_on_mission_accepted_ensure_escort)
	EventBus.on_undocked.connect(_on_undocked_ensure_escort)
	EventBus.on_system_entered.connect(_on_system_entered_ensure_escort)


func _exit_tree() -> void:
	if EventBus.on_mission_accepted.is_connected(_on_mission_accepted_ensure_prey):
		EventBus.on_mission_accepted.disconnect(_on_mission_accepted_ensure_prey)
	if EventBus.on_undocked.is_connected(_on_undocked_ensure_prey):
		EventBus.on_undocked.disconnect(_on_undocked_ensure_prey)
	if EventBus.on_system_entered.is_connected(_on_system_entered_ensure_prey):
		EventBus.on_system_entered.disconnect(_on_system_entered_ensure_prey)
	if EventBus.on_mission_accepted.is_connected(_on_mission_accepted_ensure_escort):
		EventBus.on_mission_accepted.disconnect(_on_mission_accepted_ensure_escort)
	if EventBus.on_undocked.is_connected(_on_undocked_ensure_escort):
		EventBus.on_undocked.disconnect(_on_undocked_ensure_escort)
	if EventBus.on_system_entered.is_connected(_on_system_entered_ensure_escort):
		EventBus.on_system_entered.disconnect(_on_system_entered_ensure_escort)


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
	# Sky after stations/gates so belt rocks can clear pad and gate positions.
	CelestialSky.place_under(self, system_id)
	_spawn_npc_traffic()
	_spawn_hostile()
	built.emit(system_id)
	EventBus.on_system_entered.emit(system_id)
	# Bounty may already be active (save restore / accept before jump). If the
	# one-shot build spawn is gone or never ran, place prey near the player.
	_maybe_ensure_bounty_prey()
	_maybe_ensure_escort_freighter()


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


## Where the player should spawn: the current system's first station's real
## world position plus the spawn offset, so the player always starts near a
## dock now that no station sits on the system anchor (docs/economy_sim.md
## §3). Falls back to the anchor when the system has no stations.
func player_spawn_position() -> Vector3:
	var first_station_id: StringName = _first_station_id()
	if first_station_id != &"" and station_world_positions.has(first_station_id):
		return station_world_positions[first_station_id] + BalanceFlight.PLAYER_SPAWN_OFFSET
	return BalanceFlight.STATION_POSITION + BalanceFlight.PLAYER_SPAWN_OFFSET


## First station id declared by the current system, or empty if it has none.
func _first_station_id() -> StringName:
	var system: StarSystem = _load_system(system_id)
	if system == null or system.station_ids.is_empty():
		return &""
	return system.station_ids[0]


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


## Ambient combat hostiles near the station when security allows pirates.
## Patrolled government space stays safe on undock (count 0). Counts and offsets
## come from BalanceCombat (E2.2). Profile: contested → skirmisher, lawless → gunboat.
## Never exceeds MAX_CONCURRENT_HOSTILES. Positions are re-checked against every
## station safe radius (multi-station systems can sit offset under the old pad).
func _spawn_hostile() -> void:
	if not system_allows_hostiles(system_id):
		return
	var wanted: int = ambient_hostile_count(system_id)
	if wanted <= 0:
		return
	var profile: StringName = ambient_hostile_profile(system_id)
	var i: int = 0
	while i < wanted:
		if not can_spawn_hostile():
			return
		var pos: Vector3 = _ambient_world_position(i)
		HostileNpc.spawn_under(self, pos, profile)
		i += 1


## Balance offset from station anchor by policing ecology, pushed outside safe.
func _ambient_world_position(slot: int) -> Vector3:
	var policing: StringName = _system_policing()
	var candidate: Vector3 = (
		BalanceFlight.STATION_POSITION
		+ BalanceCombat.ambient_spawn_offset_for_policing(policing, slot)
	)
	if not _is_inside_any_station_safe(candidate):
		return candidate
	return _position_outside_station_safe(candidate)


## Policing tag for the loaded system (empty if unknown).
func _system_policing() -> StringName:
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return &""
	return system.policing


## Live combat hostiles under this world (GROUP_HOSTILE, valid, still alive).
func live_hostile_count() -> int:
	var count: int = 0
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if not is_instance_valid(node):
			continue
		if not is_ancestor_of(node):
			continue
		if node.has_method(&"is_alive") and node.call(&"is_alive") != true:
			continue
		count += 1
	return count


## True when another combat hostile may be placed under this world (under cap).
func can_spawn_hostile() -> bool:
	return live_hostile_count() < BalanceCombat.MAX_CONCURRENT_HOSTILES


## If this system allows hostiles and none are live in lock range of `near`,
## spawn one outside every station safe radius. No-op in patrolled space, when
## prey already sits in range, or when live hostiles already hit the concurrent
## cap. Bounty prey uses the softer skirmisher profile (Hauler-era completable).
func ensure_hostile_near(near: Vector3) -> void:
	if not system_allows_hostiles(system_id):
		return
	if live_hostile_within_range(near, BalanceCombat.TARGET_LOCK_RANGE):
		return
	if not can_spawn_hostile():
		return
	var pos: Vector3 = _position_outside_station_safe(near)
	HostileNpc.spawn_under(self, pos, BalanceCombat.BOUNTY_HOSTILE_PROFILE)


## True if a live hostile is within `range_m` of `near`.
func live_hostile_within_range(near: Vector3, range_m: float) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var range_sq: float = range_m * range_m
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if not is_instance_valid(node) or not is_ancestor_of(node):
			continue
		if node.has_method(&"is_alive") and node.call(&"is_alive") != true:
			continue
		if not (node is Node3D):
			continue
		var body: Node3D = node as Node3D
		if near.distance_squared_to(body.global_position) <= range_sq:
			return true
	return false


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


## Ambient profile for a system (contested skirmisher / lawless gunboat).
static func ambient_hostile_profile(for_system_id: StringName) -> StringName:
	if not ContentLibrary.has_item(for_system_id):
		return BalanceCombat.PROFILE_DEFAULT
	var item: ContentItem = ContentLibrary.item(for_system_id)
	if not (item is StarSystem):
		return BalanceCombat.PROFILE_DEFAULT
	var system: StarSystem = item as StarSystem
	return BalanceCombat.ambient_profile_for_policing(system.policing)


## Ambient combat hostile count for a system (E2.2). Patrolled = 0 from balance.
static func ambient_hostile_count(for_system_id: StringName) -> int:
	if not ContentLibrary.has_item(for_system_id):
		return BalanceCombat.AMBIENT_HOSTILE_COUNT_PATROLLED
	var item: ContentItem = ContentLibrary.item(for_system_id)
	if not (item is StarSystem):
		return BalanceCombat.AMBIENT_HOSTILE_COUNT_PATROLLED
	var system: StarSystem = item as StarSystem
	return BalanceCombat.ambient_count_for_policing(system.policing)


## Test / console helper: place a hostile under this world at an offset from station.
func spawn_hostile_at(
	offset: Vector3, for_profile_id: StringName = BalanceCombat.PROFILE_DEFAULT
) -> HostileNpc:
	return HostileNpc.spawn_under(self, BalanceFlight.STATION_POSITION + offset, for_profile_id)


func _on_mission_accepted_ensure_prey(
	_template_id: StringName, _offering_entity_id: StringName
) -> void:
	_maybe_ensure_bounty_prey()


func _on_undocked_ensure_prey(_station_id: StringName) -> void:
	_maybe_ensure_bounty_prey()


func _on_system_entered_ensure_prey(entered_id: StringName) -> void:
	if entered_id != system_id:
		return
	_maybe_ensure_bounty_prey()


func _on_mission_accepted_ensure_escort(
	_template_id: StringName, _offering_entity_id: StringName
) -> void:
	_maybe_ensure_escort_freighter()


func _on_undocked_ensure_escort(_station_id: StringName) -> void:
	_maybe_ensure_escort_freighter()


func _on_system_entered_ensure_escort(entered_id: StringName) -> void:
	if entered_id != system_id:
		return
	_maybe_ensure_escort_freighter()


## When an active bounty targets this system and the kill is still open, make
## sure a live hostile exists near the player (or a station). Does not invent
## standing rules; does not spawn after the objective is already ready.
func _maybe_ensure_bounty_prey() -> void:
	if not _bounty_needs_prey_here():
		return
	ensure_hostile_near(_bounty_near_position())


## Active escort: ensure a friendly freighter exists near the player (thin).
## Re-spawns after jumps; death fails the mission via MissionEscortShip.
## Public so headless tests can call the same path SystemWorld uses on accept /
## undock / system enter without a full Main scene.
func ensure_escort_freighter() -> void:
	_maybe_ensure_escort_freighter()


func _maybe_ensure_escort_freighter() -> void:
	if not _escort_needs_freighter():
		return
	if _live_escort_count() > 0:
		return
	_spawn_escort_freighter(_bounty_near_position() + BalanceBoard.ESCORT_SPAWN_OFFSET)


func _escort_needs_freighter() -> bool:
	var mission: Node = _mission_service_node()
	if mission == null or not mission.has_method(&"has_active"):
		return false
	if mission.call(&"has_active") != true:
		return false
	if not mission.has_method(&"active_kind"):
		return false
	var kind: StringName = StringName(str(mission.call(&"active_kind")))
	if kind != BalanceStanding.MISSION_KIND_ESCORT:
		return false
	if mission.has_method(&"is_escort_alive") and mission.call(&"is_escort_alive") != true:
		return false
	return true


func _live_escort_count() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(BalanceBoard.GROUP_MISSION_ESCORT):
		if not is_instance_valid(node):
			continue
		if node.has_method(&"is_alive") and node.call(&"is_alive") != true:
			continue
		count += 1
	return count


func _spawn_escort_freighter(at: Vector3) -> void:
	var ship: MissionEscortShip = MissionEscortShip.new()
	ship.name = "MissionEscortShip"
	ship.apply_role(BalanceCombat.ROLE_CIVILIAN)
	ship.max_hp = BalanceBoard.ESCORT_HULL_HP
	ship.hp = BalanceBoard.ESCORT_HULL_HP
	ship.build_visual(BalanceBoard.ESCORT_COLOR)
	ship.position = at
	add_child(ship)


## True when MissionService has an open bounty for this system and hostiles are allowed.
func _bounty_needs_prey_here() -> bool:
	if not system_allows_hostiles(system_id):
		return false
	var mission: Node = _mission_service_node()
	if mission == null or not mission.has_method(&"has_active"):
		return false
	if mission.call(&"has_active") != true:
		return false
	if not mission.has_method(&"active_kind") or not mission.has_method(&"active_target_system_id"):
		return false
	var kind: StringName = StringName(str(mission.call(&"active_kind")))
	var target: StringName = StringName(str(mission.call(&"active_target_system_id")))
	var objective_done: bool = (
		mission.has_method(&"is_objective_ready") and mission.call(&"is_objective_ready") == true
	)
	return (
		kind == BalanceStanding.MISSION_KIND_BOUNTY and target == system_id and not objective_done
	)


func _mission_service_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"mission_service")


func _bounty_near_position() -> Vector3:
	var tree: SceneTree = get_tree()
	if tree != null:
		var ship_node: Node = tree.get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP)
		if ship_node is Node3D:
			var ship: Node3D = ship_node as Node3D
			return ship.global_position
	if not station_world_positions.is_empty():
		var first_key: StringName = station_world_positions.keys()[0]
		return station_world_positions[first_key]
	return BalanceFlight.STATION_POSITION


## Place a spawn point near `near` that sits outside every known station safe
## radius (and the balance station anchor as fallback).
func _position_outside_station_safe(near: Vector3) -> Vector3:
	var offset: Vector3 = BalanceCombat.BOUNTY_SPAWN_OFFSET
	var candidates: Array[Vector3] = [
		near + offset,
		near - offset,
		near + Vector3(offset.z, offset.y, -offset.x),
		near + Vector3(-offset.z, offset.y, offset.x),
	]
	for candidate: Vector3 in candidates:
		if not _is_inside_any_station_safe(candidate):
			return candidate
	var anchor: Vector3 = _nearest_station_anchor(near)
	var dir: Vector3 = near - anchor
	if dir.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		dir = offset
	if dir.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		dir = Vector3(1.0, 0.0, 0.0)
	var push: float = BalanceCombat.STATION_SAFE_RADIUS + BalanceCombat.BOUNTY_SPAWN_SAFE_MARGIN
	return anchor + dir.normalized() * push


func _is_inside_any_station_safe(pos: Vector3) -> bool:
	if station_world_positions.is_empty():
		return pos.distance_to(BalanceFlight.STATION_POSITION) <= BalanceCombat.STATION_SAFE_RADIUS
	for station_id: StringName in station_world_positions:
		var anchor: Vector3 = station_world_positions[station_id]
		if pos.distance_to(anchor) <= BalanceCombat.STATION_SAFE_RADIUS:
			return true
	return false


func _nearest_station_anchor(from: Vector3) -> Vector3:
	if station_world_positions.is_empty():
		return BalanceFlight.STATION_POSITION
	var best: Vector3 = BalanceFlight.STATION_POSITION
	var best_dist: float = INF
	for station_id: StringName in station_world_positions:
		var anchor: Vector3 = station_world_positions[station_id]
		var dist: float = from.distance_to(anchor)
		if dist < best_dist:
			best_dist = dist
			best = anchor
	return best


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

	# E6.1 solid: StaticBody covering main disc + core (stations not destroyed).
	var collider: StaticBody3D = StaticBody3D.new()
	collider.name = "StationCollider"
	collider.collision_layer = BalanceFlight.PHYSICS_LAYER_STATICS
	collider.collision_mask = 0
	collider.set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_STATION)
	collider.add_to_group(BalanceCombat.GROUP_IMPACT_BODY)
	var station_shape: CollisionShape3D = CollisionShape3D.new()
	var station_cyl: CylinderShape3D = CylinderShape3D.new()
	station_cyl.radius = BalanceFlight.STATION_DISC_RADIUS
	station_cyl.height = BalanceFlight.STATION_CYLINDER_HEIGHT
	station_shape.shape = station_cyl
	collider.add_child(station_shape)
	root.add_child(collider)
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

	# E6.1 solid: upright cylinder approx of the ring (gates not destroyed).
	var collider: StaticBody3D = StaticBody3D.new()
	collider.name = "GateCollider"
	collider.collision_layer = BalanceFlight.PHYSICS_LAYER_STATICS
	collider.collision_mask = 0
	collider.set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_GATE)
	collider.add_to_group(BalanceCombat.GROUP_IMPACT_BODY)
	var gate_shape: CollisionShape3D = CollisionShape3D.new()
	var gate_cyl: CylinderShape3D = CylinderShape3D.new()
	gate_cyl.radius = BalanceFlight.GATE_RING_OUTER
	gate_cyl.height = BalanceFlight.GATE_RING_OUTER * BalanceFlight.GATE_COLLIDER_HEIGHT_FACTOR
	gate_shape.shape = gate_cyl
	# Match upright ring orientation (cylinder default is Y-up — correct for stand).
	collider.add_child(gate_shape)
	root.add_child(collider)
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
