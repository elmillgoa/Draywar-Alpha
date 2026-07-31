extends GutTest

## E1.1 presentation floor 2 — system contrast, silhouettes, kill/dock FX.
##
## Implements: docs/BETA_E1_LEGIBLE_SECTOR.md E1.1


func test_system_space_colors_are_distinct() -> void:
	var alpha: Color = BalanceFlight.space_color_for(&"system_alpha")
	var beta: Color = BalanceFlight.space_color_for(&"system_beta")
	var gamma: Color = BalanceFlight.space_color_for(&"system_gamma")
	assert_true(_colors_far(alpha, beta), "alpha navy vs beta amber/rust")
	assert_true(_colors_far(alpha, gamma), "alpha navy vs gamma teal/green")
	assert_true(_colors_far(beta, gamma), "beta warm vs gamma sickly")
	# Channel dominance: alpha cool blue, beta warm red, gamma green/teal.
	assert_gt(alpha.b, alpha.r, "alpha is cool-dominant")
	assert_gt(beta.r, beta.b, "beta is warm-dominant")
	assert_gt(gamma.g, gamma.r, "gamma is green/teal-dominant")


func test_system_ambient_colors_are_distinct() -> void:
	var alpha: Color = BalanceFlight.ambient_color_for(&"system_alpha")
	var beta: Color = BalanceFlight.ambient_color_for(&"system_beta")
	var gamma: Color = BalanceFlight.ambient_color_for(&"system_gamma")
	assert_true(_colors_far(alpha, beta), "ambient alpha vs beta")
	assert_true(_colors_far(beta, gamma), "ambient beta vs gamma")
	assert_ne(
		BalanceFlight.ambient_energy_for(&"system_alpha"),
		BalanceFlight.ambient_energy_for(&"system_beta")
	)


func test_world_environment_uses_per_system_bg() -> void:
	for system_id: StringName in [&"system_alpha", &"system_beta", &"system_gamma"]:
		var world: SystemWorld = SystemWorld.new()
		world.system_id = system_id
		add_child_autofree(world)
		world.build()
		var env_node: Node = world.get_node_or_null("WorldEnvironment")
		assert_ne(env_node, null, "WorldEnvironment for %s" % system_id)
		var world_env: WorldEnvironment = env_node as WorldEnvironment
		assert_ne(world_env.environment, null)
		assert_eq(
			world_env.environment.background_color,
			BalanceFlight.space_color_for(system_id),
			"BG color matches balance for %s" % system_id
		)
		assert_eq(
			world_env.environment.ambient_light_color, BalanceFlight.ambient_color_for(system_id)
		)
		var stars: Node = world.get_node_or_null("Starfield")
		assert_ne(stars, null)
		assert_eq(stars.get_child_count(), BalanceFlight.starfield_count_for(system_id))


func test_player_ship_has_freighter_detail_meshes() -> void:
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	await get_tree().process_frame
	var mesh_count: int = 0
	var has_prism: bool = false
	var has_box: bool = false
	for child: Node in ship.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh is PrismMesh:
				has_prism = true
			if mi.mesh is BoxMesh:
				has_box = true
	assert_gte(mesh_count, 3, "hull + engine + canopy/wings")
	assert_true(has_prism)
	assert_true(has_box, "engine/canopy/wings use boxes")


func test_station_body_has_at_least_three_meshes() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_alpha"
	add_child_autofree(world)
	world.build()
	var station: Node = null
	for child: Node in world.get_children():
		if String(child.name).begins_with("Station_"):
			station = child
			break
	assert_ne(station, null)
	var mesh_count: int = 0
	for child: Node in station.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	assert_gte(mesh_count, 3, "core + disc + spoke/tower")


func test_hostile_has_threat_silhouette_and_kill_flash_constants() -> void:
	assert_gt(BalanceCombat.KILL_FLASH_DURATION, 0.0)
	assert_gt(BalanceCombat.KILL_FLASH_END_SCALE, 1.0)
	assert_gt(BalanceCombat.KILL_FLASH_RADIUS, 0.0)
	assert_gt(BalanceCombat.HOSTILE_FIN_SIZE.x, BalanceEconomy.NPC_FIN_SIZE.x)

	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var hostile: HostileNpc = HostileNpc.spawn_under(parent, Vector3.ZERO)
	await get_tree().process_frame
	var mesh_count: int = 0
	for child: Node in hostile.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	assert_gte(mesh_count, 3, "body + nose + fins")

	hostile.take_damage(BalanceCombat.HOSTILE_HP)
	await get_tree().process_frame
	var flash: Node = parent.get_node_or_null("KillFlash")
	assert_ne(flash, null, "kill spawns expanding flash before free")
	assert_true(flash is MeshInstance3D)


func test_traffic_root_has_fin_detail() -> void:
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(&"system_alpha")
	assert_gt(traffic.get_child_count(), 0)
	var first: Node = traffic.get_child(0)
	assert_gte(first.get_child_count(), 2, "capsule hull + dorsal fin")


func test_dock_fade_constants_and_hud_overlay() -> void:
	assert_gt(BalanceUi.DOCK_FADE_DURATION, 0.0)
	assert_gt(BalanceUi.DOCK_FADE_PEAK_ALPHA, 0.0)
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	var fade: Node = null
	for child: Node in hud.get_children():
		fade = child.get_node_or_null("DockFade")
		if fade != null:
			break
	assert_ne(fade, null, "HUD hosts dock/undock ColorRect")
	assert_true(fade is ColorRect)


func test_star_tints_differ_by_system() -> void:
	var a: Color = BalanceFlight.star_color_cool_for(&"system_alpha")
	var b: Color = BalanceFlight.star_color_cool_for(&"system_beta")
	var g: Color = BalanceFlight.star_color_cool_for(&"system_gamma")
	assert_true(_colors_far(a, b) or _colors_far(a, g), "star cool tints diverge")
	var count_alpha: int = BalanceFlight.starfield_count_for(&"system_alpha")
	var count_beta: int = BalanceFlight.starfield_count_for(&"system_beta")
	assert_ne(count_alpha, count_beta)


func _colors_far(a: Color, b: Color) -> bool:
	var dr: float = absf(a.r - b.r)
	var dg: float = absf(a.g - b.g)
	var db: float = absf(a.b - b.b)
	return (dr + dg + db) >= 0.08
