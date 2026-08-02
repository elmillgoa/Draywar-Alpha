extends GutTest

## E6.2 Package C — lived-in sky: sun, planets, distinct layouts, belt rocks.
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.2

const ALL_SYSTEMS: Array[StringName] = [
	&"system_alpha",
	&"system_beta",
	&"system_gamma",
	&"system_delta",
	&"system_epsilon",
	&"system_zeta",
]

const DISTINCT_PROBE: Array[StringName] = [
	&"system_alpha",
	&"system_zeta",
	&"system_epsilon",
]


func test_every_content_system_has_sun_and_planet() -> void:
	for system_id: StringName in ALL_SYSTEMS:
		var world: SystemWorld = SystemWorld.new()
		world.system_id = system_id
		add_child_autofree(world)
		world.build()
		await get_tree().process_frame

		var sun_light: Node = world.get_node_or_null("SystemSun")
		assert_ne(sun_light, null, "%s: DirectionalLight SystemSun cue" % String(system_id))
		assert_true(
			sun_light is DirectionalLight3D,
			"%s: SystemSun is DirectionalLight3D" % String(system_id)
		)

		var sky: Node = world.get_node_or_null(String(BalanceFlight.CELESTIAL_ROOT_NAME))
		assert_ne(sky, null, "%s: CelestialSky root" % String(system_id))

		var sun_disc: Node = sky.get_node_or_null(String(BalanceFlight.CELESTIAL_SUN_DISC_NAME))
		assert_ne(sun_disc, null, "%s: SunDisc mesh" % String(system_id))
		assert_true(sun_disc is MeshInstance3D)
		var disc_kind: StringName = StringName(
			str(sun_disc.get_meta(BalanceFlight.META_CELESTIAL_KIND, &""))
		)
		assert_eq(disc_kind, BalanceFlight.CELESTIAL_KIND_SUN)

		var planet_count: int = _count_kind(sky, BalanceFlight.CELESTIAL_KIND_PLANET)
		assert_gte(planet_count, 1, "%s: at least one planet-scale body" % String(system_id))

		# Backdrop far from pad so undock is not blocked by a planet mesh centre.
		for child: Node in sky.get_children():
			if not (child is Node3D):
				continue
			var n3: Node3D = child as Node3D
			if not n3.has_meta(BalanceFlight.META_CELESTIAL_KIND):
				continue
			var kind: StringName = StringName(str(n3.get_meta(BalanceFlight.META_CELESTIAL_KIND)))
			if (
				kind == BalanceFlight.CELESTIAL_KIND_PLANET
				or kind == BalanceFlight.CELESTIAL_KIND_SUN
			):
				assert_gte(
					n3.position.length(),
					BalanceFlight.CELESTIAL_MIN_DISTANCE * 0.9,
					(
						"%s %s too close to origin (%.0f)"
						% [String(system_id), String(kind), n3.position.length()]
					)
				)


func test_at_least_three_systems_differ_in_layout() -> void:
	var fingerprints: Array[Dictionary] = []
	for system_id: StringName in DISTINCT_PROBE:
		var world: SystemWorld = SystemWorld.new()
		world.system_id = system_id
		add_child_autofree(world)
		world.build()
		await get_tree().process_frame
		var sky: Node = world.get_node_or_null(String(BalanceFlight.CELESTIAL_ROOT_NAME))
		assert_ne(sky, null, "%s sky" % String(system_id))
		var scene_fp: Dictionary = {
			"planet_count": _count_kind(sky, BalanceFlight.CELESTIAL_KIND_PLANET),
			"moon_count": _count_kind(sky, BalanceFlight.CELESTIAL_KIND_MOON),
			"rock_count": _count_rocks(sky),
			"primary_color": _first_planet_color(sky),
		}
		var balance_fp: Dictionary = BalanceFlight.celestial_fingerprint(system_id)
		assert_eq(
			_dict_int(scene_fp, "planet_count"),
			_dict_int(balance_fp, "planet_count"),
			"%s planet count scene vs balance" % String(system_id)
		)
		assert_eq(
			_dict_int(scene_fp, "moon_count"),
			_dict_int(balance_fp, "moon_count"),
			"%s moon count scene vs balance" % String(system_id)
		)
		assert_eq(
			_dict_int(scene_fp, "rock_count"),
			_dict_int(balance_fp, "rock_count"),
			"%s rock count scene vs balance" % String(system_id)
		)
		fingerprints.append(scene_fp)

	# Alpha (2 planets + moon, 0 rocks) ≠ Zeta (1 planet, 0 rocks) ≠ Epsilon (1 + 12 rocks).
	assert_ne(
		_fp_key(fingerprints[0]), _fp_key(fingerprints[1]), "Alpha and Zeta layouts must differ"
	)
	assert_ne(
		_fp_key(fingerprints[0]), _fp_key(fingerprints[2]), "Alpha and Epsilon layouts must differ"
	)
	assert_ne(
		_fp_key(fingerprints[1]), _fp_key(fingerprints[2]), "Zeta and Epsilon layouts must differ"
	)

	assert_eq(_dict_int(fingerprints[0], "planet_count"), 2, "Alpha: two planets")
	assert_eq(_dict_int(fingerprints[0], "moon_count"), 1, "Alpha: one moon")
	assert_eq(_dict_int(fingerprints[1], "planet_count"), 1, "Zeta: one planet")
	assert_eq(_dict_int(fingerprints[1], "rock_count"), 0, "Zeta: no belt rocks")
	assert_eq(_dict_int(fingerprints[2], "rock_count"), 12, "Epsilon: belt rocks")
	assert_gt(_dict_int(fingerprints[2], "rock_count"), _dict_int(fingerprints[0], "rock_count"))


func test_belt_rocks_use_mass_class_rock_and_statics_layer() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_epsilon"
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	var sky: Node = world.get_node_or_null(String(BalanceFlight.CELESTIAL_ROOT_NAME))
	assert_ne(sky, null)
	var belt: Node = sky.get_node_or_null(String(BalanceFlight.CELESTIAL_BELT_ROOT_NAME))
	assert_ne(belt, null, "Epsilon has BeltBand")
	assert_gt(belt.get_child_count(), 0, "Epsilon belt has rocks")

	for child: Node in belt.get_children():
		assert_true(child is StaticBody3D, "rock is StaticBody3D")
		var body: StaticBody3D = child as StaticBody3D
		assert_eq(body.collision_layer, BalanceFlight.PHYSICS_LAYER_STATICS)
		assert_eq(body.collision_mask, 0)
		var mass_class: StringName = StringName(
			str(body.get_meta(BalanceCombat.META_MASS_CLASS, &""))
		)
		assert_eq(mass_class, BalanceCombat.MASS_CLASS_ROCK)
		assert_true(
			body.is_in_group(BalanceCombat.GROUP_IMPACT_BODY),
			"rock in impact body group for soft-bump path"
		)
		# Clear of pad and gates so undock / gate interact stay free.
		for station_id: StringName in world.station_positions():
			var dist: float = body.position.distance_to(world.station_positions()[station_id])
			assert_gte(
				dist,
				BalanceFlight.CELESTIAL_ROCK_PLAY_CLEARANCE * 0.95,
				"rock too close to station %s (%.0f)" % [String(station_id), dist]
			)
		for dest: StringName in world.gate_positions():
			var gdist: float = body.position.distance_to(world.gate_positions()[dest])
			assert_gte(
				gdist,
				BalanceFlight.CELESTIAL_ROCK_PLAY_CLEARANCE * 0.95,
				"rock too close to gate %s (%.0f)" % [String(dest), gdist]
			)


func test_celestials_do_not_break_dock_gate_or_status_moment() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_alpha"
	add_child_autofree(world)

	var entered: Array[StringName] = []
	var on_enter: Callable = func(sid: StringName) -> void: entered.append(sid)
	EventBus.on_system_entered.connect(on_enter)
	world.build()
	await get_tree().process_frame
	if EventBus.on_system_entered.is_connected(on_enter):
		EventBus.on_system_entered.disconnect(on_enter)

	assert_true(entered.size() >= 1, "status moment: on_system_entered still fires")
	assert_eq(entered[0], &"system_alpha")

	var stations: Dictionary[StringName, Vector3] = world.station_positions()
	var gates: Dictionary[StringName, Vector3] = world.gate_positions()
	assert_false(stations.is_empty(), "stations still placed with sky")
	assert_false(gates.is_empty(), "gates still placed with sky")

	# Dock interact centre (station pos) and gate centre still at layout anchors.
	for station_id: StringName in stations:
		assert_lt(
			stations[station_id].distance_to(
				BalanceFlight.STATION_POSITION + _station_offset(station_id)
			),
			1.0,
			"station %s position intact" % String(station_id)
		)
	for dest: StringName in gates:
		assert_gte(
			gates[dest].distance_to(BalanceFlight.STATION_POSITION),
			BalanceFlight.LAYOUT_MIN_STATION_GATE_SEPARATION - 1.0,
			"gate still at stretched layout"
		)

	# No rock colliders in Alpha (no belt).
	var sky: Node = world.get_node_or_null(String(BalanceFlight.CELESTIAL_ROOT_NAME))
	assert_eq(_count_rocks(sky), 0, "Alpha has no belt rocks blocking pad")


func test_sky_build_is_cheap_enough_for_smoke() -> void:
	# Empty-traffic sky path: six system rebuilds should complete without hang.
	# Not a frame-time probe (headless); guards that place_under does not explode.
	var i: int = 0
	while i < ALL_SYSTEMS.size():
		var world: SystemWorld = SystemWorld.new()
		world.system_id = ALL_SYSTEMS[i]
		add_child_autofree(world)
		world.build()
		await get_tree().process_frame
		var sky: Node = world.get_node_or_null(String(BalanceFlight.CELESTIAL_ROOT_NAME))
		assert_ne(sky, null, "sky on %s" % String(ALL_SYSTEMS[i]))
		world.clear_world()
		await get_tree().process_frame
		i += 1


func test_balance_fingerprints_cover_six_systems() -> void:
	# Data-level AC: every live content system has sun+planet in layout tables.
	for system_id: StringName in ALL_SYSTEMS:
		var layout: Dictionary = BalanceFlight.celestial_layout_for(system_id)
		var planets: Array = BalanceFlight.celestial_planets(layout)
		assert_gte(planets.size(), 1, "%s layout has planet" % String(system_id))
		var sun_dist: float = 0.0
		if layout.has("sun_distance"):
			var sd_raw: Variant = layout["sun_distance"]
			if typeof(sd_raw) == TYPE_FLOAT:
				var sd_f: float = sd_raw
				sun_dist = sd_f
			elif typeof(sd_raw) == TYPE_INT:
				var sd_i: int = sd_raw
				sun_dist = float(sd_i)
		assert_gt(sun_dist, 0.0, "%s has sun distance" % String(system_id))
		for planet_variant: Variant in planets:
			if typeof(planet_variant) != TYPE_DICTIONARY:
				continue
			var planet: Dictionary = planet_variant
			var pos: Vector3 = Vector3.ZERO
			if planet.has("position"):
				var pos_raw: Variant = planet["position"]
				if typeof(pos_raw) == TYPE_VECTOR3:
					pos = pos_raw
			assert_gte(
				pos.length(),
				BalanceFlight.CELESTIAL_MIN_DISTANCE * 0.9,
				"%s planet within play bubble" % String(system_id)
			)


func _dict_int(d: Dictionary, key: String, default_value: int = 0) -> int:
	if not d.has(key):
		return default_value
	var raw: Variant = d[key]
	if typeof(raw) == TYPE_INT:
		var as_i: int = raw
		return as_i
	if typeof(raw) == TYPE_FLOAT:
		var as_f: float = raw
		return int(as_f)
	return default_value


func _count_kind(sky: Node, kind: StringName) -> int:
	if sky == null:
		return 0
	var count: int = 0
	for child: Node in sky.get_children():
		if not child.has_meta(BalanceFlight.META_CELESTIAL_KIND):
			continue
		if StringName(str(child.get_meta(BalanceFlight.META_CELESTIAL_KIND))) == kind:
			count += 1
	return count


func _count_rocks(sky: Node) -> int:
	if sky == null:
		return 0
	var belt: Node = sky.get_node_or_null(String(BalanceFlight.CELESTIAL_BELT_ROOT_NAME))
	if belt == null:
		return 0
	return belt.get_child_count()


func _first_planet_color(sky: Node) -> Color:
	if sky == null:
		return Color.BLACK
	for child: Node in sky.get_children():
		if not child.has_meta(BalanceFlight.META_CELESTIAL_KIND):
			continue
		var child_kind: StringName = StringName(
			str(child.get_meta(BalanceFlight.META_CELESTIAL_KIND))
		)
		if child_kind != BalanceFlight.CELESTIAL_KIND_PLANET:
			continue
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mat: Material = mi.material_override
			if mat is StandardMaterial3D:
				return (mat as StandardMaterial3D).albedo_color
	return Color.BLACK


func _fp_key(fp: Dictionary) -> String:
	var c: Color = Color.BLACK
	if fp.has("primary_color"):
		var c_raw: Variant = fp["primary_color"]
		if typeof(c_raw) == TYPE_COLOR:
			c = c_raw
	return (
		"%d:%d:%d:%.2f,%.2f,%.2f"
		% [
			_dict_int(fp, "planet_count"),
			_dict_int(fp, "moon_count"),
			_dict_int(fp, "rock_count"),
			c.r,
			c.g,
			c.b,
		]
	)


func _station_offset(station_id: StringName) -> Vector3:
	if not ContentLibrary.has_item(station_id):
		return Vector3.ZERO
	var item: ContentItem = ContentLibrary.item(station_id)
	if item is Station:
		return (item as Station).position_offset
	return Vector3.ZERO
