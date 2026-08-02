class_name CelestialSky
extends RefCounted

## Per-system celestial backdrop — E6.2 Package C.
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.2 / lock D7
##
## Places sun disc, 1–2 planets, optional moon, and optional belt rocks under
## a SystemWorld parent. Backdrop only: no landing, mining, or orbital motion.
## Belt rocks (when present) are StaticBody3D colliders with mass class rock
## on the STATICS layer so E6.1 soft-bump / impact applies.


## Build the sky root for `system_id` and parent it under `host`. Returns the root.
static func place_under(host: Node3D, system_id: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = String(BalanceFlight.CELESTIAL_ROOT_NAME)
	host.add_child(root)

	var layout: Dictionary = BalanceFlight.celestial_layout_for(system_id)
	_place_sun_disc(root, system_id, layout)
	_place_planets(root, layout)
	_place_moons(root, layout)
	if BalanceFlight.celestial_belt_enabled(layout):
		_place_belt(root, system_id, layout, host)
	return root


static func _place_sun_disc(root: Node3D, system_id: StringName, layout: Dictionary) -> void:
	var dir: Vector3 = BalanceFlight.CELESTIAL_DEFAULT_SUN_DIR
	if layout.has("sun_dir"):
		var dir_raw: Variant = layout["sun_dir"]
		if typeof(dir_raw) == TYPE_VECTOR3:
			dir = dir_raw
	if dir.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		dir = BalanceFlight.CELESTIAL_DEFAULT_SUN_DIR
	dir = dir.normalized()

	var distance: float = BalanceFlight.CELESTIAL_SUN_DISC_DISTANCE
	if layout.has("sun_distance"):
		var dist_raw: Variant = layout["sun_distance"]
		if typeof(dist_raw) == TYPE_FLOAT:
			var dist_f: float = dist_raw
			distance = dist_f
		elif typeof(dist_raw) == TYPE_INT:
			var dist_i: int = dist_raw
			distance = float(dist_i)

	var radius: float = BalanceFlight.CELESTIAL_SUN_DISC_RADIUS
	if layout.has("sun_radius"):
		var rad_raw: Variant = layout["sun_radius"]
		if typeof(rad_raw) == TYPE_FLOAT:
			var rad_f: float = rad_raw
			radius = rad_f
		elif typeof(rad_raw) == TYPE_INT:
			var rad_i: int = rad_raw
			radius = float(rad_i)

	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = String(BalanceFlight.CELESTIAL_SUN_DISC_NAME)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * BalanceFlight.CELESTIAL_SPHERE_HEIGHT_FACTOR
	sphere.radial_segments = BalanceFlight.CELESTIAL_PLANET_SEGMENTS
	sphere.rings = BalanceFlight.CELESTIAL_PLANET_RINGS
	disc.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = BalanceFlight.sun_disc_color_for(system_id)
	disc.material_override = material
	disc.position = dir * distance
	disc.set_meta(BalanceFlight.META_CELESTIAL_KIND, BalanceFlight.CELESTIAL_KIND_SUN)
	disc.set_meta(BalanceFlight.META_CELESTIAL_INDEX, 0)
	root.add_child(disc)


static func _place_planets(root: Node3D, layout: Dictionary) -> void:
	var planets: Array = BalanceFlight.celestial_planets(layout)
	var index: int = 0
	for entry_variant: Variant in planets:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var body: MeshInstance3D = _make_sphere_body(
			"Planet_%d" % index,
			_entry_position(entry),
			_entry_radius(entry, BalanceFlight.CELESTIAL_FALLBACK_PLANET_RADIUS),
			_entry_color(entry, BalanceFlight.COLOR_CELESTIAL_FALLBACK_PLANET),
			BalanceFlight.CELESTIAL_KIND_PLANET,
			index
		)
		root.add_child(body)
		index += 1


static func _place_moons(root: Node3D, layout: Dictionary) -> void:
	var moons: Array = BalanceFlight.celestial_moons(layout)
	var index: int = 0
	for entry_variant: Variant in moons:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var body: MeshInstance3D = _make_sphere_body(
			"Moon_%d" % index,
			_entry_position(entry),
			_entry_radius(entry, BalanceFlight.CELESTIAL_FALLBACK_MOON_RADIUS),
			_entry_color(entry, BalanceFlight.COLOR_CELESTIAL_FALLBACK_MOON),
			BalanceFlight.CELESTIAL_KIND_MOON,
			index
		)
		root.add_child(body)
		index += 1


static func _place_belt(
	root: Node3D, system_id: StringName, layout: Dictionary, host: Node3D
) -> void:
	var belt_root: Node3D = Node3D.new()
	belt_root.name = String(BalanceFlight.CELESTIAL_BELT_ROOT_NAME)
	root.add_child(belt_root)

	var center: Vector3 = Vector3.ZERO
	if layout.has("belt_center"):
		var center_raw: Variant = layout["belt_center"]
		if typeof(center_raw) == TYPE_VECTOR3:
			center = center_raw

	var belt_radius: float = BalanceFlight.CELESTIAL_FALLBACK_BELT_RADIUS
	if layout.has("belt_radius"):
		var br_raw: Variant = layout["belt_radius"]
		if typeof(br_raw) == TYPE_FLOAT:
			var br_f: float = br_raw
			belt_radius = br_f
		elif typeof(br_raw) == TYPE_INT:
			var br_i: int = br_raw
			belt_radius = float(br_i)

	var rock_count: int = BalanceFlight.celestial_rock_count(layout)
	if rock_count <= 0 or belt_radius <= 0.0:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# Stable rocks per system — same layout every visit.
	rng.seed = hash(String(system_id) + ":belt")

	var station_positions: Array[Vector3] = _collect_station_positions(host)
	var gate_positions: Array[Vector3] = _collect_gate_positions(host)

	var placed: int = 0
	var attempt: int = 0
	var max_attempts: int = rock_count * BalanceFlight.CELESTIAL_ROCK_ATTEMPT_MULT
	while placed < rock_count and attempt < max_attempts:
		attempt += 1
		var angle: float = (
			(float(placed) / float(rock_count)) * TAU
			+ rng.randf_range(
				-BalanceFlight.CELESTIAL_ROCK_ANGLE_JITTER,
				BalanceFlight.CELESTIAL_ROCK_ANGLE_JITTER
			)
		)
		var radial: float = (
			belt_radius
			* rng.randf_range(
				BalanceFlight.CELESTIAL_ROCK_RADIAL_MIN, BalanceFlight.CELESTIAL_ROCK_RADIAL_MAX
			)
		)
		var pos: Vector3 = (
			center
			+ Vector3(
				cos(angle) * radial,
				rng.randf_range(
					-BalanceFlight.CELESTIAL_BELT_Y_SPREAD, BalanceFlight.CELESTIAL_BELT_Y_SPREAD
				),
				sin(angle) * radial
			)
		)
		if not _rock_clears_play(pos, station_positions, gate_positions):
			continue
		var rock_radius: float = rng.randf_range(
			BalanceFlight.CELESTIAL_ROCK_RADIUS_MIN, BalanceFlight.CELESTIAL_ROCK_RADIUS_MAX
		)
		var rock: StaticBody3D = _make_rock_body(placed, pos, rock_radius)
		belt_root.add_child(rock)
		placed += 1


static func _entry_position(entry: Dictionary) -> Vector3:
	if not entry.has("position"):
		return Vector3.ZERO
	var raw: Variant = entry["position"]
	if typeof(raw) == TYPE_VECTOR3:
		var as_v: Vector3 = raw
		return as_v
	return Vector3.ZERO


static func _entry_radius(entry: Dictionary, fallback: float) -> float:
	if not entry.has("radius"):
		return fallback
	var raw: Variant = entry["radius"]
	if typeof(raw) == TYPE_FLOAT:
		var as_f: float = raw
		return as_f
	if typeof(raw) == TYPE_INT:
		var as_i: int = raw
		return float(as_i)
	return fallback


static func _entry_color(entry: Dictionary, fallback: Color) -> Color:
	if not entry.has("color"):
		return fallback
	var raw: Variant = entry["color"]
	if typeof(raw) == TYPE_COLOR:
		var as_c: Color = raw
		return as_c
	return fallback


static func _make_sphere_body(
	body_name: String, position: Vector3, radius: float, color: Color, kind: StringName, index: int
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = body_name
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * BalanceFlight.CELESTIAL_SPHERE_HEIGHT_FACTOR
	sphere.radial_segments = BalanceFlight.CELESTIAL_PLANET_SEGMENTS
	sphere.rings = BalanceFlight.CELESTIAL_PLANET_RINGS
	mesh_instance.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh_instance.material_override = material
	mesh_instance.position = position
	mesh_instance.set_meta(BalanceFlight.META_CELESTIAL_KIND, kind)
	mesh_instance.set_meta(BalanceFlight.META_CELESTIAL_INDEX, index)
	return mesh_instance


static func _make_rock_body(index: int, position: Vector3, radius: float) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "BeltRock_%d" % index
	body.position = position
	body.collision_layer = BalanceFlight.PHYSICS_LAYER_STATICS
	body.collision_mask = 0
	body.set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_ROCK)
	body.set_meta(BalanceFlight.META_CELESTIAL_KIND, BalanceFlight.CELESTIAL_KIND_ROCK)
	body.set_meta(BalanceFlight.META_CELESTIAL_INDEX, index)
	body.add_to_group(BalanceCombat.GROUP_IMPACT_BODY)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * BalanceFlight.CELESTIAL_SPHERE_HEIGHT_FACTOR
	sphere.radial_segments = BalanceFlight.CELESTIAL_ROCK_SEGMENTS
	sphere.rings = BalanceFlight.CELESTIAL_ROCK_RINGS
	mesh_instance.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = BalanceFlight.COLOR_CELESTIAL_ROCK
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	shape_node.shape = shape
	body.add_child(shape_node)
	return body


static func _collect_station_positions(host: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if host is SystemWorld:
		var world: SystemWorld = host as SystemWorld
		var stations: Dictionary[StringName, Vector3] = world.station_positions()
		for station_id: StringName in stations:
			out.append(stations[station_id])
	if out.is_empty():
		out.append(BalanceFlight.STATION_POSITION)
	return out


static func _collect_gate_positions(host: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if host is SystemWorld:
		var world: SystemWorld = host as SystemWorld
		var gates: Dictionary[StringName, Vector3] = world.gate_positions()
		for dest: StringName in gates:
			out.append(gates[dest])
	if out.is_empty():
		out.append(BalanceFlight.GATE_POSITION)
	return out


static func _rock_clears_play(
	pos: Vector3, stations: Array[Vector3], gates: Array[Vector3]
) -> bool:
	var clear: float = BalanceFlight.CELESTIAL_ROCK_PLAY_CLEARANCE
	for station: Vector3 in stations:
		if pos.distance_to(station) < clear:
			return false
	for gate: Vector3 in gates:
		if pos.distance_to(gate) < clear:
			return false
	return true
