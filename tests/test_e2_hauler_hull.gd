extends GutTest

## E2.4 — Hauler hull law data (cargo/weapon fields, capacity, combat math).
##
## Implements: docs/BETA_E2_COMBAT_HULL.md E2.4
## Destination §6: Hauler = cargo/endurance; cannot win dogfight vs Fighter.

const TOLERANCE: float = 0.0001
const STARTER_HULL_ID: StringName = BalanceFlight.PLAYER_HULL_ID


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_starter_hull_is_hauler_with_trade_capacity() -> void:
	assert_true(ContentLibrary.has_item(STARTER_HULL_ID), "starter hull missing")
	var item: ContentItem = ContentLibrary.item(STARTER_HULL_ID)
	assert_true(item is Hull)
	var hull: Hull = item as Hull
	assert_eq(hull.validation_errors().size(), 0, "starter hull must validate")
	assert_eq(hull.display_name, "Hauler", "D3: display Hauler, id hull_courier")
	assert_eq(hull.role, Hull.ROLE_HAULER)
	assert_gte(
		hull.cargo_capacity,
		BalanceEconomy.CARGO_CAPACITY,
		"Hauler capacity must support grain/scrap trade loop"
	)
	assert_gt(hull.weapon_damage, 0.0)
	assert_gt(hull.weapon_cooldown, 0.0)
	assert_gt(hull.projectile_speed, 0.0)


func test_hull_content_budget_at_most_two() -> void:
	var hull_ids: Array[StringName] = ContentLibrary.ids_in(&"hulls")
	assert_lte(hull_ids.size(), Balance.CONTENT_BUDGET[&"hulls"], "E2 hull budget ≤ 2")
	assert_eq(hull_ids.size(), 2, "E2.5: Hauler + Fighter content hulls")


func test_hull_validation_rejects_invalid_play_fields() -> void:
	var hull: Hull = Hull.new()
	hull.id = &"fixture_hauler_bad"
	hull.display_name = "Bad"
	hull.max_speed = BalanceFlight.SHIP_MAX_SPEED
	hull.acceleration = BalanceFlight.SHIP_ACCELERATION
	hull.turn_rate = BalanceFlight.SHIP_TURN_RATE
	hull.strafe_speed = BalanceFlight.SHIP_STRAFE_SPEED
	hull.afterburner_multiplier = BalanceFlight.SHIP_AFTERBURNER_MULTIPLIER
	hull.drag = BalanceFlight.SHIP_DRAG
	# Missing cargo/weapon/role → invalid.
	var problems: PackedStringArray = hull.validation_errors()
	assert_gt(problems.size(), 0)
	var joined: String = "\n".join(problems)
	assert_string_contains(joined, "weapon_damage")
	assert_string_contains(joined, "role")

	hull.cargo_capacity = 0
	hull.weapon_damage = BalanceCombat.PLAYER_WEAPON_DAMAGE
	hull.weapon_cooldown = BalanceCombat.PLAYER_FIRE_COOLDOWN
	hull.projectile_speed = BalanceCombat.PROJECTILE_SPEED
	hull.role = Hull.ROLE_HAULER
	joined = "\n".join(hull.validation_errors())
	assert_string_contains(joined, "cargo_capacity")

	hull.cargo_capacity = BalanceEconomy.CARGO_CAPACITY
	hull.role = &"not_a_role"
	joined = "\n".join(hull.validation_errors())
	assert_string_contains(joined, "role")

	hull.role = Hull.ROLE_HAULER
	hull.weapon_damage = 0.0
	joined = "\n".join(hull.validation_errors())
	assert_string_contains(joined, "weapon_damage")

	hull.weapon_damage = BalanceCombat.PLAYER_WEAPON_DAMAGE
	hull.weapon_cooldown = 0.0
	joined = "\n".join(hull.validation_errors())
	assert_string_contains(joined, "weapon_cooldown")

	hull.weapon_cooldown = BalanceCombat.PLAYER_FIRE_COOLDOWN
	hull.projectile_speed = -1.0
	joined = "\n".join(hull.validation_errors())
	assert_string_contains(joined, "projectile_speed")

	hull.projectile_speed = BalanceCombat.PROJECTILE_SPEED
	assert_eq(hull.validation_errors().size(), 0)


func test_cargo_service_uses_active_hull_capacity() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	ships.reset()
	cargo.reset()
	assert_eq(ships.active_hull_id(), STARTER_HULL_ID)
	var hull: Hull = ships.active_hull()
	assert_ne(hull, null)
	assert_eq(cargo.capacity(), hull.cargo_capacity)
	assert_eq(cargo.free_volume(), hull.cargo_capacity)

	# Fill to hull capacity (volume 1 commodities if present).
	var fill_id: StringName = &"commodity_grain"
	if not ContentLibrary.has_item(fill_id):
		assert_true(false, "commodity_grain required for capacity test")
		return
	assert_true(cargo.add(fill_id, hull.cargo_capacity))
	assert_eq(cargo.free_volume(), 0)
	assert_false(cargo.can_add(fill_id, 1))


func test_cargo_capacity_falls_back_without_ship_service() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame
	cargo.reset()
	assert_eq(cargo.capacity(), BalanceEconomy.CARGO_CAPACITY)
	assert_eq(cargo.free_volume(), BalanceEconomy.CARGO_CAPACITY)


func test_hauler_worse_than_fighter_baseline_vs_gunboat() -> void:
	var hauler: Hull = ContentLibrary.item(STARTER_HULL_ID) as Hull
	assert_ne(hauler, null)
	var gunboat_hp: float = BalanceCombat.profile_float(
		BalanceCombat.PROFILE_GUNBOAT, BalanceCombat.PROFILE_KEY_HP, 0.0
	)
	assert_gt(gunboat_hp, 0.0)

	var hauler_dps: float = BalanceCombat.weapon_dps(hauler.weapon_damage, hauler.weapon_cooldown)
	var fighter_dps: float = BalanceCombat.weapon_dps(
		BalanceCombat.FIGHTER_BASELINE_WEAPON_DAMAGE, BalanceCombat.FIGHTER_BASELINE_WEAPON_COOLDOWN
	)
	assert_gt(hauler_dps, 0.0)
	assert_gt(fighter_dps, hauler_dps, "Fighter baseline DPS must beat Hauler")

	var hauler_ttk: float = BalanceCombat.time_to_kill(
		gunboat_hp, hauler.weapon_damage, hauler.weapon_cooldown
	)
	var fighter_ttk: float = BalanceCombat.time_to_kill(
		gunboat_hp,
		BalanceCombat.FIGHTER_BASELINE_WEAPON_DAMAGE,
		BalanceCombat.FIGHTER_BASELINE_WEAPON_COOLDOWN
	)
	assert_gt(hauler_ttk, fighter_ttk, "Hauler TTK vs gunboat must be worse (higher) than Fighter")

	var hauler_hits: int = BalanceCombat.player_hits_to_kill(
		BalanceCombat.PROFILE_GUNBOAT, hauler.weapon_damage
	)
	var fighter_hits: int = BalanceCombat.player_hits_to_kill(
		BalanceCombat.PROFILE_GUNBOAT, BalanceCombat.FIGHTER_BASELINE_WEAPON_DAMAGE
	)
	assert_gt(hauler_hits, fighter_hits, "Hauler needs more hits on hard profile")


func test_player_ship_reads_hauler_weapon_stats() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var ship: PlayerShip = PlayerShip.new()
	ship.hull_id = STARTER_HULL_ID
	host.add_child(ship)
	await get_tree().process_frame

	var hull: Hull = ContentLibrary.item(STARTER_HULL_ID) as Hull
	assert_ne(hull, null)
	assert_almost_eq(ship.weapon_damage(), hull.weapon_damage, TOLERANCE)
	assert_almost_eq(ship.weapon_cooldown(), hull.weapon_cooldown, TOLERANCE)
	assert_almost_eq(ship.projectile_speed(), hull.projectile_speed, TOLERANCE)


func test_cargo_save_roundtrip_still_works_with_ship_service() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	ships.reset()
	cargo.reset()
	var grain: StringName = &"commodity_grain"
	assert_true(cargo.add(grain, 3))
	var section: Dictionary = cargo.to_section()
	assert_true(section.has(String(grain)))

	cargo.reset()
	assert_eq(cargo.quantity(grain), 0)
	cargo.apply_section(section)
	assert_eq(cargo.quantity(grain), 3)
	# Active hull remains session-default Hauler (not in cargo section).
	assert_eq(ships.active_hull_id(), STARTER_HULL_ID)


func test_ship_service_is_single_writer_default_hauler() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	assert_eq(ships.active_hull_id(), STARTER_HULL_ID)
	assert_false(ships.set_active_hull_id(&""))
	assert_false(ships.set_active_hull_id(&"not_a_hull"))
	assert_eq(ships.active_hull_id(), STARTER_HULL_ID)
	assert_true(ships.set_active_hull_id(STARTER_HULL_ID))
	assert_eq(ships.active_cargo_capacity(), ships.active_hull().cargo_capacity)
