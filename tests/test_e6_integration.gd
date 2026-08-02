extends GutTest

## E6.5 Integration / balance / perf — cold career path + impact retune.
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.5 acceptance 1–6

const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const SYSTEM_GAMMA: StringName = &"system_gamma"
const STATION_ALPHA: StringName = &"station_alpha_port"
const ENTITY_REACH: StringName = &"entity_reach_authority"
const FIXTURE_PATH: String = "user://gut_e6_integration_career.sav"
const TOLERANCE: float = 0.0001
const LAYOUT_TOLERANCE: float = 0.5
const RAM_CLOSING: float = 40.0


class FakeSystemWorld:
	extends Node3D
	var system_id: StringName = SYSTEM_ALPHA

	func _ready() -> void:
		add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)


var _kill_attributed: Array[StringName] = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	_kill_attributed = []


func after_each() -> void:
	if EventBus.on_kill_attributed.is_connected(_on_kill_attributed):
		EventBus.on_kill_attributed.disconnect(_on_kill_attributed)
	StandingService.reset_to_defaults()
	CareerStart.reset()
	TimeScale.set_combat_lock(false)
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)


func _on_kill_attributed(
	system_id: StringName, _entity_id: StringName, _delta: float, _reason: StringName
) -> void:
	_kill_attributed.append(system_id)


func _find_traffic(world: SystemWorld) -> NpcTraffic:
	for child: Node in world.get_children():
		if child is NpcTraffic:
			return child as NpcTraffic
	return null


func _find_named_descendant(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_named_descendant(child, node_name)
		if found != null:
			return found
	return null


func _ceil_credits(amount: float) -> int:
	if amount <= 0.0:
		return 0
	return int(ceilf(amount))


func _fuel_credit_cost(units: float) -> int:
	return _ceil_credits(units * BalanceEconomy.REFUEL_CREDITS_PER_UNIT)


## AC: undock cruise must be soft-bump only (casual leave does not cripple).
func test_undock_speed_below_impact_threshold() -> void:
	var undock_speed: float = BalanceFlight.UNDOCK_THROTTLE * BalanceFlight.SHIP_MAX_SPEED
	assert_gt(undock_speed, 0.0)
	assert_lt(
		undock_speed,
		BalanceCombat.IMPACT_SPEED_THRESHOLD,
		(
			"undock cruise %.2f must be < IMPACT_SPEED_THRESHOLD %.2f"
			% [undock_speed, BalanceCombat.IMPACT_SPEED_THRESHOLD]
		)
	)
	assert_eq(
		BalanceCombat.impact_damage(BalanceCombat.MASS_CLASS_STATION, undock_speed),
		0.0,
		"undock-speed scrape on station = bump only"
	)
	# Slow dock approach at half undock throttle also safe.
	var approach: float = undock_speed * 0.5
	assert_eq(
		BalanceCombat.impact_damage(BalanceCombat.MASS_CLASS_GATE, approach),
		0.0,
		"slow approach = bump only"
	)


## Deliberate high-speed ram still damages (and station > light traffic).
func test_deliberate_ram_still_damages() -> void:
	assert_gt(RAM_CLOSING, BalanceCombat.IMPACT_SPEED_THRESHOLD)
	var vs_station: float = BalanceCombat.impact_damage(
		BalanceCombat.MASS_CLASS_STATION, RAM_CLOSING
	)
	var vs_light: float = BalanceCombat.impact_damage(
		BalanceCombat.MASS_CLASS_TRAFFIC_LIGHT, RAM_CLOSING
	)
	assert_gt(vs_station, 0.0, "deliberate ram vs station deals damage")
	assert_gt(vs_light, 0.0, "deliberate ram vs traffic deals damage")
	assert_gt(vs_station, vs_light, "station mass class still hurts more")
	# Full-throttle head-on is well above threshold.
	var full_speed: float = BalanceFlight.SHIP_MAX_SPEED
	assert_gt(
		BalanceCombat.impact_damage(BalanceCombat.MASS_CLASS_STATION, full_speed),
		vs_station,
		"full speed ram hurts more than moderate ram"
	)


## Cold path: Alpha world build → sky → layout → traffic density → lockable.
func test_cold_path_alpha_world_sky_layout_traffic() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	add_child_autofree(world)
	world.build()
	await get_tree().process_frame

	# Sky present (sun + planet).
	var sun_light: Node = world.get_node_or_null("SystemSun")
	assert_ne(sun_light, null, "SystemSun cue")
	assert_true(sun_light is DirectionalLight3D)
	var sky: Node = world.get_node_or_null(String(BalanceFlight.CELESTIAL_ROOT_NAME))
	assert_ne(sky, null, "CelestialSky root")
	var sun_disc: Node = sky.get_node_or_null(String(BalanceFlight.CELESTIAL_SUN_DISC_NAME))
	assert_ne(sun_disc, null, "SunDisc")
	var planet_count: int = 0
	for child: Node in sky.get_children():
		if child is Node3D and child.has_meta(BalanceFlight.META_CELESTIAL_KIND):
			var kind: StringName = StringName(
				str(child.get_meta(BalanceFlight.META_CELESTIAL_KIND))
			)
			if kind == BalanceFlight.CELESTIAL_KIND_PLANET:
				planet_count += 1
	assert_gte(planet_count, 1, "Alpha has ≥1 planet-scale body")

	# Layout distances.
	var stations: Dictionary[StringName, Vector3] = world.station_positions()
	var gates: Dictionary[StringName, Vector3] = world.gate_positions()
	assert_false(stations.is_empty())
	assert_false(gates.is_empty())
	for station_id: StringName in stations:
		var nearest: float = INF
		for dest: StringName in gates:
			var d: float = stations[station_id].distance_to(gates[dest])
			if d < nearest:
				nearest = d
		assert_gte(
			nearest,
			BalanceFlight.LAYOUT_MIN_STATION_GATE_SEPARATION - LAYOUT_TOLERANCE,
			"%s → gate" % String(station_id)
		)

	# Station/gate colliders (dock/undock path still has solids).
	var station_col: Node = _find_named_descendant(world, "StationCollider")
	var gate_col: Node = _find_named_descendant(world, "GateCollider")
	assert_ne(station_col, null)
	assert_ne(gate_col, null)
	assert_true(station_col is StaticBody3D)
	assert_true(gate_col is StaticBody3D)

	# Traffic density floor + lockable.
	var traffic: NpcTraffic = _find_traffic(world)
	assert_not_null(traffic)
	assert_gte(
		traffic.live_ship_count(),
		BalanceEconomy.DENSITY_FLOOR_PATROLLED_NON_PLAYER,
		"patrolled density floor"
	)
	assert_eq(traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_PATROLLED)

	var lockable_traffic: int = 0
	for child: Node in traffic.get_children():
		if child is TrafficShip:
			var ship: TrafficShip = child as TrafficShip
			assert_true(ship.is_in_group(BalanceCombat.GROUP_LOCKABLE), "traffic lockable")
			assert_true(ship.is_alive())
			lockable_traffic += 1
	assert_eq(lockable_traffic, BalanceEconomy.NPC_COUNT_PATROLLED)

	# Patrolled: zero ambient combat hostiles on build.
	assert_eq(world.live_hostile_count(), 0, "patrolled Alpha has no pad pirates")
	assert_eq(BalanceEconomy.max_hostiles_for_policing(&"patrolled"), 0)


## Dock / undock radii still coherent with undock clear of station disc.
func test_dock_undock_radii_and_collider_clearance() -> void:
	assert_gt(BalanceFlight.DOCK_APPROACH_RADIUS, BalanceFlight.DOCK_INTERACT_RADIUS)
	assert_gt(BalanceFlight.DOCK_INTERACT_RADIUS, 0.0)
	assert_gt(
		BalanceFlight.UNDOCK_OFFSET.z,
		BalanceFlight.STATION_DISC_RADIUS + BalanceCombat.PLAYER_HURTBOX_RADIUS,
		"undock pad outside station collider"
	)
	# Interact radius still usable with colliders present (F dock/gate).
	assert_gt(BalanceEconomy.GATE_INTERACT_RADIUS, 0.0)
	var dock: DockingController = DockingController.new()
	var in_range: float = BalanceFlight.DOCK_INTERACT_RADIUS * 0.5
	dock.update_range(STATION_ALPHA, in_range, BalanceFlight.DOCK_INTERACT_RADIUS)
	assert_true(dock.can_dock())
	var docked: StringName = dock.request_dock()
	assert_eq(docked, STATION_ALPHA)
	var left: StringName = dock.request_undock()
	assert_eq(left, STATION_ALPHA)
	assert_false(dock.is_docked())


## Traffic kill standing path (patrolled) still uses AttributionService only.
func test_traffic_kill_standing_path_patrolled() -> void:
	var host: FakeSystemWorld = FakeSystemWorld.new()
	host.system_id = SYSTEM_ALPHA
	add_child_autofree(host)
	var attribution: AttributionService = AttributionService.new()
	add_child_autofree(attribution)
	EventBus.on_kill_attributed.connect(_on_kill_attributed)
	await get_tree().process_frame

	var before: float = StandingService.get_entity_standing(ENTITY_REACH)
	var traffic: TrafficShip = TrafficShip.new()
	traffic.apply_role(BalanceCombat.ROLE_CIVILIAN)
	traffic.build_visual(BalanceCombat.COLOR_TRAFFIC_CIVILIAN)
	host.add_child(traffic)
	traffic.global_position = Vector3(10.0, 0.0, 10.0)
	await get_tree().process_frame

	traffic.take_damage(traffic.hull_max())
	await get_tree().process_frame

	assert_eq(_kill_attributed.size(), 1, "patrolled traffic kill attributes")
	assert_eq(_kill_attributed[0], SYSTEM_ALPHA)
	var after: float = StandingService.get_entity_standing(ENTITY_REACH)
	assert_almost_eq(after, before + BalanceStanding.COMBAT_KILL_DELTA, TOLERANCE)
	assert_lt(after, before)


## Contested vs lawless ecology still differs (cold multi-system hop).
func test_ecology_contested_vs_lawless_differs() -> void:
	assert_eq(BalanceEconomy.max_hostiles_for_policing(&"patrolled"), 0)
	assert_gt(BalanceEconomy.max_hostiles_for_policing(&"contested"), 0)
	assert_eq(
		BalanceEconomy.max_hostiles_for_policing(&"lawless"), BalanceCombat.MAX_CONCURRENT_HOSTILES
	)
	assert_lt(BalanceEconomy.NPC_COUNT_LAWLESS, BalanceEconomy.NPC_COUNT_PATROLLED)

	var beta: SystemWorld = SystemWorld.new()
	beta.system_id = SYSTEM_BETA
	add_child_autofree(beta)
	beta.build()
	await get_tree().process_frame
	var beta_traffic: NpcTraffic = _find_traffic(beta)
	assert_not_null(beta_traffic)
	assert_eq(beta_traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_CONTESTED)

	var gamma: SystemWorld = SystemWorld.new()
	gamma.system_id = SYSTEM_GAMMA
	add_child_autofree(gamma)
	gamma.build()
	await get_tree().process_frame
	var gamma_traffic: NpcTraffic = _find_traffic(gamma)
	assert_not_null(gamma_traffic)
	assert_eq(gamma_traffic.live_ship_count(), BalanceEconomy.NPC_COUNT_LAWLESS)
	assert_lt(gamma_traffic.live_ship_count(), beta_traffic.live_ship_count())


## Save/load smoke with opening complete + world position (Continue path).
func test_save_load_smoke_with_opening_complete() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	await get_tree().process_frame
	wallet.reset()
	cargo.reset()
	ships.reset()
	mission.reset()
	CareerStart.reset()
	CareerStart.apply_default(wallet)
	CareerStart.mark_opening_complete()
	assert_true(CareerStart.opening_complete)
	assert_true(CareerStart.has_path())

	var world: SystemWorld = SystemWorld.new()
	host.add_child(world)
	world.system_id = SYSTEM_ALPHA
	world.build()
	await get_tree().process_frame

	var credits_before: int = wallet.credits()
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	sections[BalanceSession.SAVE_SECTION_WORLD] = CareerSave.make_world_section(
		SYSTEM_ALPHA, Vector3(20.0, 0.0, -15.0), &""
	)
	var service: SaveService = SaveService.new()
	var envelope: Dictionary = SaveService.envelope(sections, "e6_integration")
	var written: SaveResult = service.save_to(FIXTURE_PATH, envelope)
	assert_true(written.ok(), written.summary())

	CareerStart.reset()
	mission.reset()
	wallet.reset()
	StandingService.reset_to_defaults()
	assert_false(CareerStart.opening_complete)

	var loaded: SaveResult = CareerSave.load_envelope(FIXTURE_PATH)
	assert_true(loaded.ok(), loaded.summary())
	var loaded_sections: Dictionary = {}
	if loaded.envelope.has(SaveService.KEY_SECTIONS):
		var raw: Variant = loaded.envelope[SaveService.KEY_SECTIONS]
		if typeof(raw) == TYPE_DICTIONARY:
			loaded_sections = raw
	CareerSave.apply_meta_sections(get_tree(), loaded_sections)
	var world_fields: Dictionary = CareerSave.world_from_sections(loaded_sections)
	var loaded_system: StringName = StringName(
		str(world_fields.get(BalanceSession.WORLD_KEY_SYSTEM_ID, ""))
	)
	assert_eq(loaded_system, SYSTEM_ALPHA)
	assert_true(CareerStart.opening_complete, "Continue skip: opening stays complete")
	assert_true(CareerStart.has_path())
	assert_eq(wallet.credits(), credits_before)


## Opening cast + default path still hold after E6 packages.
func test_opening_cast_and_default_path_hold() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.reset()
	CareerStart.apply_default(wallet)
	assert_true(CareerStart.has_path())
	assert_false(CareerStart.opening_complete)
	CareerStart.mark_opening_complete()
	assert_true(CareerStart.opening_complete)
	assert_gt(wallet.credits(), 0)
	assert_true(StandingService.can_dock_at_station(STATION_ALPHA))
	var offers: Array = StationDockQueries.offered_templates(STATION_ALPHA)
	assert_gte(offers.size(), 1, "Alpha board still stocks jobs")


## E3 money teeth: idle multi-system travel outspends one courier.
func test_e3_money_teeth_still_hold() -> void:
	var jump_fuel: float = (
		BalanceEconomy.JUMP_FUEL_COST * float(BalanceEconomy.SCENARIO_PRESSURE_JUMP_COUNT)
	)
	var jump_fuel_credits: int = _fuel_credit_cost(jump_fuel)
	var free_fly_s: float = BalanceEconomy.SCENARIO_FREE_FLY_SLICE_SECONDS
	var upkeep_credits: int = int(floorf(BalanceEconomy.UPKEEP_CREDITS_PER_SECOND * free_fly_s))
	var free_fly_fuel: float = BalanceEconomy.FUEL_BURN_PER_SECOND_AT_FULL * free_fly_s
	var free_fly_fuel_credits: int = _fuel_credit_cost(free_fly_fuel)
	var never_earn_cost: int = jump_fuel_credits + upkeep_credits + free_fly_fuel_credits

	var courier_pay: int = BalanceEconomy.MISSION_PAY_DEFAULT
	if ContentLibrary.has_item(&"contract_courier_alpha"):
		var item: ContentItem = ContentLibrary.item(&"contract_courier_alpha")
		if item is ContractType:
			var contract: ContractType = item as ContractType
			courier_pay = maxi(0, contract.pay_credits)

	assert_gt(never_earn_cost, courier_pay, "never-earn slice still exceeds one courier")
	assert_gt(upkeep_credits + jump_fuel_credits, courier_pay)


## E2 combat fairness: lead pip + bolts do not auto-hit lock.
func test_e2_combat_fairness_lead_and_bolts_hold() -> void:
	var shooter: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3(0.0, 0.0, -100.0)
	var vel: Vector3 = Vector3(40.0, 0.0, 0.0)
	var lead: Vector3 = BalanceCombat.lead_point(shooter, target, vel, 200.0)
	assert_gt(lead.x, target.x, "lead sits ahead of lateral motion")

	var space: Node3D = Node3D.new()
	add_child_autofree(space)
	var ship: PlayerShip = PlayerShip.new()
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	space.add_child(ship)
	ship.global_position = Vector3.ZERO
	await get_tree().process_frame

	# Target behind ship; bolt along nose must not auto-damage lock.
	var hostile: HostileNpc = HostileNpc.spawn_under(space, Vector3(0.0, 0.0, 50.0))
	await get_tree().process_frame
	ship.cycle_target_lock()
	assert_eq(ship.locked_target(), hostile)
	var before: float = hostile.remaining_hp()
	assert_true(ship.try_fire())
	await get_tree().process_frame
	assert_eq(hostile.remaining_hp(), before, "lock must not auto-damage without aim")


## Perf budget still 20; densest layout fits; no Ops/Holding content IDs.
func test_perf_budget_and_no_ops_holding_creep() -> void:
	assert_eq(BalanceEconomy.PERF_BUDGET_SHIPS, 20)
	assert_lte(BalanceEconomy.densest_ships_layout(), BalanceEconomy.PERF_BUDGET_SHIPS)
	assert_eq(BalanceCombat.MAX_CONCURRENT_HOSTILES, 3)
	# Content library must not grow Ops/Holding job kinds this phase.
	assert_false(ContentLibrary.has_item(&"contract_ops"), "no Ops contract creep")
	assert_false(ContentLibrary.has_item(&"contract_holding"), "no Holding contract creep")
	assert_false(ContentLibrary.has_item(&"system_ops"), "no Ops system creep")
	assert_false(ContentLibrary.has_item(&"holding_slot"), "no Holding slot creep")
