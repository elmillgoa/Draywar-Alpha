extends GutTest

## B0 multi-system travel — discoverable gates, jump rebuild, nav readout.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B0

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const TOLERANCE: float = 0.001


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_three_systems_form_a_reachable_gate_graph() -> void:
	# Alpha → Beta → Gamma and back: every system has at least one gate out.
	var alpha: StarSystem = ContentLibrary.item(SYSTEM_ALPHA) as StarSystem
	var beta: StarSystem = ContentLibrary.item(SYSTEM_BETA) as StarSystem
	var gamma: StarSystem = ContentLibrary.item(SYSTEM_GAMMA) as StarSystem
	assert_ne(alpha, null)
	assert_ne(beta, null)
	assert_ne(gamma, null)
	assert_true(alpha.gate_destination_ids.has(SYSTEM_BETA))
	assert_true(beta.gate_destination_ids.has(SYSTEM_ALPHA))
	assert_true(beta.gate_destination_ids.has(SYSTEM_GAMMA))
	assert_true(gamma.gate_destination_ids.has(SYSTEM_BETA))


func test_system_world_rebuild_jumps_alpha_beta_gamma_and_back() -> void:
	# Simulated Main jump path: clear → set id → build; positions and names change.
	var world: SystemWorld = SystemWorld.new()
	add_child_autofree(world)

	world.system_id = SYSTEM_ALPHA
	world.build()
	assert_eq(world.system_id, SYSTEM_ALPHA)
	assert_eq(world.system_display_name(), "Alpha Reach")
	assert_true(world.gate_positions().has(SYSTEM_BETA))
	assert_gt(world.station_positions().size(), 0)
	var alpha_station: StringName = world.station_positions().keys()[0]

	await _jump_world(world, SYSTEM_BETA)
	assert_eq(world.system_id, SYSTEM_BETA)
	assert_eq(world.system_display_name(), "Beta Drift")
	assert_true(world.gate_positions().has(SYSTEM_ALPHA))
	assert_true(world.gate_positions().has(SYSTEM_GAMMA))
	var beta_station: StringName = world.station_positions().keys()[0]
	assert_ne(beta_station, alpha_station, "beta station id must differ")

	await _jump_world(world, SYSTEM_GAMMA)
	assert_eq(world.system_id, SYSTEM_GAMMA)
	assert_eq(world.system_display_name(), "Gamma Fringe")
	assert_true(world.gate_positions().has(SYSTEM_BETA))

	await _jump_world(world, SYSTEM_BETA)
	await _jump_world(world, SYSTEM_ALPHA)
	assert_eq(world.system_id, SYSTEM_ALPHA)
	assert_eq(world.system_display_name(), "Alpha Reach")


func test_gate_meshes_carry_world_labels_for_destination() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()

	var gate_node: Node = world.get_node_or_null("Gate_system_beta")
	assert_ne(gate_node, null, "named gate root must exist for discoverability")
	var found_label: bool = false
	for child: Node in gate_node.get_children():
		if child is Label3D:
			var label: Label3D = child as Label3D
			assert_true(label.text.contains("BETA") or label.text.contains("Beta"))
			found_label = true
	assert_true(found_label, "gate must show a world-space destination label")


func test_systems_use_distinct_backdrop_colours() -> void:
	var a: Color = BalanceFlight.space_color_for(SYSTEM_ALPHA)
	var b: Color = BalanceFlight.space_color_for(SYSTEM_BETA)
	var g: Color = BalanceFlight.space_color_for(SYSTEM_GAMMA)
	assert_false(a.is_equal_approx(b), "alpha vs beta space colour")
	assert_false(b.is_equal_approx(g), "beta vs gamma space colour")
	assert_false(a.is_equal_approx(g), "alpha vs gamma space colour")


func test_system_world_environment_tint_follows_system() -> void:
	var world: SystemWorld = SystemWorld.new()
	add_child_autofree(world)
	world.system_id = SYSTEM_ALPHA
	world.build()
	var env_a: WorldEnvironment = world.get_node("WorldEnvironment") as WorldEnvironment
	assert_ne(env_a, null)
	assert_true(env_a.environment.background_color.is_equal_approx(BalanceFlight.COLOR_SPACE_ALPHA))

	await _jump_world(world, SYSTEM_BETA)
	var env_b: WorldEnvironment = world.get_node("WorldEnvironment") as WorldEnvironment
	assert_ne(env_b, null)
	assert_true(env_b.environment.background_color.is_equal_approx(BalanceFlight.COLOR_SPACE_BETA))


func test_flight_hud_nav_lists_gates_for_current_system() -> void:
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame

	EventBus.on_system_entered.emit(SYSTEM_ALPHA)
	assert_true(hud.nav_here_text().contains("ALPHA"), "nav HERE must name alpha")
	var gates_alpha: String = hud.nav_gates_text()
	assert_true(gates_alpha.contains("GATES"))
	assert_true(
		gates_alpha.to_lower().contains("beta") or gates_alpha.contains("Beta"),
		"alpha nav must list beta gate"
	)

	EventBus.on_system_entered.emit(SYSTEM_BETA)
	assert_true(hud.nav_here_text().contains("BETA"))
	var gates_beta: String = hud.nav_gates_text().to_lower()
	assert_true(gates_beta.contains("alpha"), "beta nav lists return to alpha")
	assert_true(gates_beta.contains("gamma"), "beta nav lists gamma")


func test_wallet_fuel_blocks_jump_when_empty() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	# Drain fuel below jump cost.
	while wallet.can_jump():
		assert_true(wallet.try_spend_jump_fuel())
	assert_false(wallet.can_jump())
	assert_false(wallet.try_spend_jump_fuel())


func test_jump_arrival_places_ship_near_return_gate() -> void:
	var world: SystemWorld = SystemWorld.new()
	add_child_autofree(world)
	world.system_id = SYSTEM_BETA
	world.build()
	var arrival: Vector3 = world.jump_arrival_position(SYSTEM_ALPHA)
	var return_gate: Vector3 = world.gate_positions()[SYSTEM_ALPHA]
	assert_lt(
		arrival.distance_to(return_gate),
		BalanceEconomy.JUMP_ARRIVAL_OFFSET.length() + 1.0,
		"arrival should sit near the return gate"
	)
	assert_almost_eq(
		arrival.distance_to(return_gate + BalanceEconomy.JUMP_ARRIVAL_OFFSET), 0.0, TOLERANCE
	)


func _jump_world(world: SystemWorld, destination: StringName) -> void:
	world.clear_world()
	await get_tree().process_frame
	world.system_id = destination
	world.build()
