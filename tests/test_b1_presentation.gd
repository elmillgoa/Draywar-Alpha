extends GutTest

## B1 presentation floor — backdrop, silhouettes, shared UI theme.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B1


func test_starfield_is_spawned_with_the_world() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_alpha"
	add_child_autofree(world)
	world.build()
	var stars: Node = world.get_node_or_null("Starfield")
	assert_ne(stars, null, "starfield root required — not pure black void")
	assert_eq(stars.get_child_count(), BalanceFlight.STARFIELD_COUNT)


func test_station_and_gate_use_distinct_mesh_roots() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = &"system_alpha"
	add_child_autofree(world)
	world.build()
	var station: Node = null
	var gate: Node = null
	for child: Node in world.get_children():
		if String(child.name).begins_with("Station_"):
			station = child
		if String(child.name).begins_with("Gate_"):
			gate = child
	assert_ne(station, null)
	assert_ne(gate, null)
	# Station body uses cylinders; gate uses torus + beacon — different child counts/shapes.
	assert_gt(station.get_child_count(), 0)
	assert_gt(gate.get_child_count(), 2, "gate ring, core, beacon, label")


func test_player_ship_is_not_a_lone_box() -> void:
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	await get_tree().process_frame
	var mesh_count: int = 0
	var has_prism: bool = false
	for child: Node in ship.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh is PrismMesh:
				has_prism = true
	assert_gte(mesh_count, 2, "hull + engine silhouette")
	assert_true(has_prism, "player freighter uses prism hull")


func test_npc_traffic_uses_capsule_silhouettes() -> void:
	var traffic: NpcTraffic = NpcTraffic.new()
	add_child_autofree(traffic)
	traffic.rebuild_for_system(&"system_alpha")
	assert_gt(traffic.get_child_count(), 0)
	var first: MeshInstance3D = traffic.get_child(0) as MeshInstance3D
	assert_ne(first, null)
	assert_true(first.mesh is CapsuleMesh, "NPC capsule distinct from boxes")


func test_draywar_theme_styles_panel_and_button() -> void:
	var theme: Theme = DraywarUiTheme.build()
	assert_ne(theme, null)
	assert_true(theme.has_stylebox("panel", "PanelContainer"))
	assert_true(theme.has_stylebox("normal", "Button"))
	assert_true(theme.has_color("font_color", "Label"))


func test_station_menu_applies_shared_theme() -> void:
	var menu: StationMenu = StationMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	var panel: PanelContainer = null
	for child: Node in menu.get_children():
		panel = _find_panel(child)
		if panel != null:
			break
	assert_ne(panel, null, "station menu panel")
	assert_ne(panel.theme, null, "theme must be applied (B1 surface)")
	assert_true(panel.theme.has_stylebox("panel", "PanelContainer"))


func test_flight_hud_uses_shared_theme() -> void:
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	var root: Control = null
	for child: Node in hud.get_children():
		if child is Control:
			root = child as Control
			break
	assert_ne(root, null)
	assert_ne(root.theme, null, "HUD is second themed surface")
	assert_true(root.theme.has_color("font_color", "Label"))


func _find_panel(node: Node) -> PanelContainer:
	if node is PanelContainer:
		return node as PanelContainer
	for child: Node in node.get_children():
		var found: PanelContainer = _find_panel(child)
		if found != null:
			return found
	return null
