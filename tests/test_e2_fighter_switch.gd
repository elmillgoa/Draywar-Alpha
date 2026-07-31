extends GutTest

## E2.5 — Fighter hull content, buy once, docked switch, cargo block, save.
##
## Implements: docs/BETA_E2_COMBAT_HULL.md E2.5
## Destination §6: Fighter = guns, negligible hold; Hauler worse in dogfight.

const StationHullUiScript = preload("res://src/ui/station/StationHullUi.gd")

const TOLERANCE: float = 0.0001
const HAULER_ID: StringName = BalanceFlight.PLAYER_HULL_ID
const FIGHTER_ID: StringName = BalanceFlight.FIGHTER_HULL_ID
const GRAIN_ID: StringName = &"commodity_grain"


class FakeDocking:
	extends Node

	var station_id: StringName = &"station_alpha_port"

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station_id


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_fighter_content_exists_with_combat_stats() -> void:
	assert_true(ContentLibrary.has_item(FIGHTER_ID), "hull_fighter missing")
	var item: ContentItem = ContentLibrary.item(FIGHTER_ID)
	assert_true(item is Hull)
	var hull: Hull = item as Hull
	assert_eq(hull.validation_errors().size(), 0, "fighter must validate")
	assert_eq(hull.display_name, "Fighter")
	assert_eq(hull.role, Hull.ROLE_FIGHTER)
	assert_lte(hull.cargo_capacity, BalanceCombat.FIGHTER_BASELINE_CARGO_CAPACITY)
	assert_almost_eq(hull.weapon_damage, BalanceCombat.FIGHTER_BASELINE_WEAPON_DAMAGE, TOLERANCE)
	assert_almost_eq(
		hull.weapon_cooldown, BalanceCombat.FIGHTER_BASELINE_WEAPON_COOLDOWN, TOLERANCE
	)
	assert_almost_eq(
		hull.projectile_speed, BalanceCombat.FIGHTER_BASELINE_PROJECTILE_SPEED, TOLERANCE
	)
	var hauler: Hull = ContentLibrary.item(HAULER_ID) as Hull
	assert_ne(hauler, null)
	assert_gt(hull.max_speed, hauler.max_speed, "Fighter faster than Hauler")
	assert_gt(hull.turn_rate, hauler.turn_rate, "Fighter turns harder than Hauler")


func test_hull_budget_exactly_two() -> void:
	var hull_ids: Array[StringName] = ContentLibrary.ids_in(&"hulls")
	assert_eq(hull_ids.size(), Balance.CONTENT_BUDGET[&"hulls"])
	assert_true(hull_ids.has(HAULER_ID))
	assert_true(hull_ids.has(FIGHTER_ID))


func test_new_game_owns_hauler_only() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	assert_eq(ships.active_hull_id(), HAULER_ID)
	assert_true(ships.owns(HAULER_ID))
	assert_false(ships.owns(FIGHTER_ID))
	assert_eq(ships.owned_hull_ids().size(), 1)


func test_buy_fighter_once_for_credits() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var dock: Node = FakeDocking.new()
	host.add_child(dock)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(BalanceEconomy.FIGHTER_PURCHASE_COST)
	assert_true(ships.can_buy_fighter())
	assert_true(ships.buy_fighter())
	assert_true(ships.owns(FIGHTER_ID))
	assert_eq(wallet.credits(), 0)
	assert_eq(ships.active_hull_id(), HAULER_ID, "buy does not auto-switch")
	assert_false(ships.can_buy_fighter(), "already owned")
	assert_false(ships.buy_fighter())


func test_buy_fighter_refuses_when_broke() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var dock: Node = FakeDocking.new()
	host.add_child(dock)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(BalanceEconomy.FIGHTER_PURCHASE_COST - 1)
	assert_false(ships.can_buy_fighter())
	assert_false(ships.buy_fighter())
	assert_false(ships.owns(FIGHTER_ID))


func test_switch_refuses_overweight_cargo() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var dock: Node = FakeDocking.new()
	host.add_child(dock)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	ships.reset()
	cargo.reset()
	# Grant Fighter ownership without spend path.
	(
		ships
		. apply_section(
			{
				BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(HAULER_ID),
				BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
			}
		)
	)
	assert_true(ships.owns(FIGHTER_ID))

	var fighter: Hull = ContentLibrary.item(FIGHTER_ID) as Hull
	assert_ne(fighter, null)
	var overload: int = fighter.cargo_capacity + 1
	assert_true(cargo.add(GRAIN_ID, overload))
	assert_gt(cargo.used_volume(), fighter.cargo_capacity)
	assert_false(ships.can_switch_to(FIGHTER_ID), "D2: cargo too heavy")
	assert_false(ships.switch_hull(FIGHTER_ID))
	assert_eq(ships.active_hull_id(), HAULER_ID)

	# Sell down to fit, then switch works.
	assert_true(cargo.remove(GRAIN_ID, cargo.used_volume() - fighter.cargo_capacity))
	assert_true(ships.can_switch_to(FIGHTER_ID))
	assert_true(ships.switch_hull(FIGHTER_ID))
	assert_eq(ships.active_hull_id(), FIGHTER_ID)
	assert_eq(cargo.capacity(), fighter.cargo_capacity)


func test_switch_applies_flight_and_weapon() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var dock: Node = FakeDocking.new()
	host.add_child(dock)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	ships.reset()
	(
		ships
		. apply_section(
			{
				BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(HAULER_ID),
				BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
			}
		)
	)

	var ship: PlayerShip = PlayerShip.new()
	ship.hull_id = HAULER_ID
	host.add_child(ship)
	await get_tree().process_frame

	var hauler: Hull = ContentLibrary.item(HAULER_ID) as Hull
	var fighter: Hull = ContentLibrary.item(FIGHTER_ID) as Hull
	assert_almost_eq(ship.weapon_damage(), hauler.weapon_damage, TOLERANCE)

	assert_true(ships.switch_hull(FIGHTER_ID))
	await get_tree().process_frame
	assert_eq(ship.hull_id, FIGHTER_ID)
	assert_almost_eq(ship.weapon_damage(), fighter.weapon_damage, TOLERANCE)
	assert_almost_eq(ship.weapon_cooldown(), fighter.weapon_cooldown, TOLERANCE)
	assert_almost_eq(ship.projectile_speed(), fighter.projectile_speed, TOLERANCE)
	assert_eq(cargo.capacity(), fighter.cargo_capacity)


func test_switch_changes_role_silhouette() -> void:
	# E2.5 AC5: mesh/role path differs after switch to Fighter.
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var dock: Node = FakeDocking.new()
	host.add_child(dock)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	ships.reset()
	(
		ships
		. apply_section(
			{
				BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(HAULER_ID),
				BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
			}
		)
	)

	var ship: PlayerShip = PlayerShip.new()
	ship.hull_id = HAULER_ID
	host.add_child(ship)
	await get_tree().process_frame

	assert_eq(ship.role_silhouette(), Hull.ROLE_HAULER)
	var hauler_body_color: Color = _first_mesh_albedo(ship)
	assert_eq(hauler_body_color, BalanceFlight.COLOR_SHIP)

	assert_true(ships.switch_hull(FIGHTER_ID))
	await get_tree().process_frame
	assert_eq(ship.role_silhouette(), Hull.ROLE_FIGHTER)
	var fighter_body_color: Color = _first_mesh_albedo(ship)
	assert_eq(fighter_body_color, BalanceFlight.COLOR_SHIP_FIGHTER)
	assert_ne(fighter_body_color, hauler_body_color, "Fighter body color must differ from Hauler")


func test_fighter_beats_hard_profile_hauler_worse() -> void:
	var hauler: Hull = ContentLibrary.item(HAULER_ID) as Hull
	var fighter: Hull = ContentLibrary.item(FIGHTER_ID) as Hull
	assert_ne(hauler, null)
	assert_ne(fighter, null)
	var gunboat_hp: float = BalanceCombat.profile_float(
		BalanceCombat.PROFILE_GUNBOAT, BalanceCombat.PROFILE_KEY_HP, 0.0
	)
	assert_gt(gunboat_hp, 0.0)

	var hauler_dps: float = BalanceCombat.weapon_dps(hauler.weapon_damage, hauler.weapon_cooldown)
	var fighter_dps: float = BalanceCombat.weapon_dps(
		fighter.weapon_damage, fighter.weapon_cooldown
	)
	assert_gt(fighter_dps, hauler_dps)

	var hauler_ttk: float = BalanceCombat.time_to_kill(
		gunboat_hp, hauler.weapon_damage, hauler.weapon_cooldown
	)
	var fighter_ttk: float = BalanceCombat.time_to_kill(
		gunboat_hp, fighter.weapon_damage, fighter.weapon_cooldown
	)
	assert_gt(hauler_ttk, fighter_ttk)

	var hauler_hits: int = BalanceCombat.player_hits_to_kill(
		BalanceCombat.PROFILE_GUNBOAT, hauler.weapon_damage
	)
	var fighter_hits: int = BalanceCombat.player_hits_to_kill(
		BalanceCombat.PROFILE_GUNBOAT, fighter.weapon_damage
	)
	assert_gt(hauler_hits, fighter_hits)


func test_fighter_cannot_load_grain_route_volume() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	ships.reset()
	ships.set_active_hull_id(FIGHTER_ID)
	cargo.reset()
	var fighter: Hull = ContentLibrary.item(FIGHTER_ID) as Hull
	var hauler: Hull = ContentLibrary.item(HAULER_ID) as Hull
	assert_eq(cargo.capacity(), fighter.cargo_capacity)
	assert_lt(fighter.cargo_capacity, hauler.cargo_capacity)
	# Meaningful grain route uses Hauler-scale hold; Fighter cannot.
	assert_false(cargo.can_add(GRAIN_ID, hauler.cargo_capacity))
	assert_true(cargo.can_add(GRAIN_ID, fighter.cargo_capacity))
	assert_true(cargo.add(GRAIN_ID, fighter.cargo_capacity))
	assert_false(cargo.can_add(GRAIN_ID, 1))


func test_ship_save_roundtrip() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	(
		ships
		. apply_section(
			{
				BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(FIGHTER_ID),
				BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
			}
		)
	)
	assert_eq(ships.active_hull_id(), FIGHTER_ID)
	assert_true(ships.owns(FIGHTER_ID))

	var section: Dictionary = ships.to_section()
	assert_true(section.has(BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID))
	assert_true(section.has(BalanceFlight.SAVE_KEY_OWNED_HULL_IDS))

	ships.reset()
	assert_eq(ships.active_hull_id(), HAULER_ID)
	assert_false(ships.owns(FIGHTER_ID))

	ships.apply_section(section)
	assert_eq(ships.active_hull_id(), FIGHTER_ID)
	assert_true(ships.owns(FIGHTER_ID))
	assert_true(ships.owns(HAULER_ID))


func test_missing_ship_section_means_hauler_only() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	(
		ships
		. apply_section(
			{
				BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(FIGHTER_ID),
				BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
			}
		)
	)
	assert_eq(ships.active_hull_id(), FIGHTER_ID)

	ships.apply_section(null)
	assert_eq(ships.active_hull_id(), HAULER_ID)
	assert_false(ships.owns(FIGHTER_ID))
	assert_true(ships.owns(HAULER_ID))


func test_career_save_includes_ship_section() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	await get_tree().process_frame

	ships.reset()
	(
		ships
		. apply_section(
			{
				BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(FIGHTER_ID),
				BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
			}
		)
	)
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceFlight.SAVE_SECTION_SHIP), "ship section present")
	var ship_sec: Dictionary = sections[BalanceFlight.SAVE_SECTION_SHIP]
	assert_eq(str(ship_sec[BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID]), String(FIGHTER_ID))

	ships.reset()
	assert_eq(ships.active_hull_id(), HAULER_ID)
	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_eq(ships.active_hull_id(), FIGHTER_ID)
	assert_true(ships.owns(FIGHTER_ID))


func test_captain_sheet_ship_name_uses_active_hull() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	var sheet: CaptainSheet = CaptainSheet.new()
	host.add_child(sheet)
	await get_tree().process_frame

	assert_eq(sheet._ship_display_name(), "Hauler")
	ships.set_active_hull_id(FIGHTER_ID)
	assert_eq(sheet._ship_display_name(), "Fighter")


func test_switch_requires_dock() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	(
		ships
		. apply_section(
			{
				BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(HAULER_ID),
				BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
			}
		)
	)
	# can_switch_to ignores dock; switch_hull requires dock.
	assert_true(ships.can_switch_to(FIGHTER_ID))
	assert_false(ships.switch_hull(FIGHTER_ID), "not docked")
	assert_eq(ships.active_hull_id(), HAULER_ID)


func test_station_services_buy_and_switch_path() -> void:
	# E2.5 AC3: Services desk (StationMenu + StationHullUi) buy/switch when docked.
	var host: Node = Node.new()
	add_child_autofree(host)
	var dock: Node = FakeDocking.new()
	host.add_child(dock)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	cargo.reset()
	wallet.set_credits(BalanceEconomy.FIGHTER_PURCHASE_COST)

	var menu: StationMenu = StationMenu.new()
	host.add_child(menu)
	await get_tree().process_frame
	EventBus.on_docked.emit(&"station_alpha_port")
	await get_tree().process_frame
	assert_true(menu.visible)

	# Buy Fighter via Services button path (EventBus → ShipService.buy_fighter).
	assert_false(ships.owns(FIGHTER_ID))
	assert_true(StationHullUiScript.can_buy_fighter(ships))
	menu._on_buy_fighter_pressed()
	await get_tree().process_frame
	assert_true(ships.owns(FIGHTER_ID), "Services buy must grant Fighter")
	assert_eq(wallet.credits(), 0)
	assert_eq(ships.active_hull_id(), HAULER_ID, "buy does not auto-switch")

	# Switch hull via Services button path (EventBus → ShipService.switch_hull).
	assert_true(StationHullUiScript.can_switch_to(ships, FIGHTER_ID))
	menu._on_switch_hull_pressed()
	await get_tree().process_frame
	assert_eq(ships.active_hull_id(), FIGHTER_ID, "Services switch must set Fighter active")
	assert_eq(
		StationHullUiScript.switch_target_hull_id(ships),
		HAULER_ID,
		"after switch, target flips back to Hauler"
	)

	EventBus.on_undocked.emit(&"station_alpha_port")


func test_apply_section_clamps_overweight_active_to_hauler() -> void:
	# D2 hole: load/apply must not leave Fighter active when cargo is too heavy.
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	await get_tree().process_frame

	ships.reset()
	cargo.reset()
	var fighter: Hull = ContentLibrary.item(FIGHTER_ID) as Hull
	assert_ne(fighter, null)
	var overload: int = fighter.cargo_capacity + 2
	assert_true(cargo.add(GRAIN_ID, overload))
	assert_gt(cargo.used_volume(), fighter.cargo_capacity)

	(
		ships
		. apply_section(
			{
				BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(FIGHTER_ID),
				BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
			}
		)
	)
	assert_true(ships.owns(FIGHTER_ID))
	assert_eq(
		ships.active_hull_id(),
		HAULER_ID,
		"overweight cargo forces active back to Hauler (largest fit)"
	)


func test_career_load_clamps_after_cargo_when_fighter_overweight() -> void:
	# Ship section applies before cargo; CareerSave must re-clamp after cargo.
	var host: Node = Node.new()
	add_child_autofree(host)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	var cargo: CargoService = CargoService.new()
	host.add_child(cargo)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	await get_tree().process_frame

	ships.reset()
	cargo.reset()
	wallet.reset()
	var fighter: Hull = ContentLibrary.item(FIGHTER_ID) as Hull
	var overload: int = fighter.cargo_capacity + 3
	var sections: Dictionary = {
		BalanceFlight.SAVE_SECTION_SHIP:
		{
			BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(FIGHTER_ID),
			BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
		},
		BalanceEconomy.SAVE_SECTION_CARGO: {String(GRAIN_ID): overload},
	}
	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_true(ships.owns(FIGHTER_ID))
	assert_eq(cargo.used_volume(), overload)
	assert_eq(
		ships.active_hull_id(),
		HAULER_ID,
		"post-cargo clamp must force Hauler when Fighter hold is too small"
	)


func _first_mesh_albedo(ship: Node3D) -> Color:
	for child: Node in ship.get_children():
		if child is MeshInstance3D:
			var mesh_node: MeshInstance3D = child as MeshInstance3D
			var mat: Material = mesh_node.material_override
			if mat is StandardMaterial3D:
				var std: StandardMaterial3D = mat as StandardMaterial3D
				return std.albedo_color
	return Color(0.0, 0.0, 0.0, 0.0)
