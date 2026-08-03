extends GutTest

## S5 — weapons/equipment content, install/remove, sinks, career ladder.

const HAULER_ID: StringName = BalanceFlight.PLAYER_HULL_ID
const FIGHTER_ID: StringName = BalanceFlight.FIGHTER_HULL_ID
const TOLERANCE: float = 0.0001

const WEAPON_LIGHT: StringName = &"weapon_light_cannon"
const WEAPON_FIGHTER_INTERCEPTOR: StringName = &"weapon_fighter_interceptor"
const WEAPON_FIGHTER_STOCK: StringName = &"weapon_fighter_stock"
const WEAPON_FIGHTER_PULSE: StringName = &"weapon_fighter_pulse"
const WEAPON_ENDGAME: StringName = &"weapon_endgame_lance"
const EQUIP_CARGO_LARGE: StringName = &"equip_cargo_rack_large"
const EQUIP_CARGO_STRAPS: StringName = &"equip_cargo_straps"
const EQUIP_ARMOR_PLATE: StringName = &"equip_armor_plate"


class FakeDocking:
	extends Node

	var station_id: StringName = &"station_alpha_port"

	func _ready() -> void:
		add_to_group(&"docking_service")

	func docked_station_id() -> StringName:
		return station_id


func after_each() -> void:
	TimeScale.set_combat_lock(false)


func test_weapon_and_equipment_budgets_full() -> void:
	var weapon_ids: Array[StringName] = ContentLibrary.ids_in(&"weapons")
	var equip_ids: Array[StringName] = ContentLibrary.ids_in(&"equipment")
	assert_eq(weapon_ids.size(), Balance.CONTENT_BUDGET[&"weapons"])
	assert_eq(equip_ids.size(), Balance.CONTENT_BUDGET[&"equipment"])
	assert_eq(weapon_ids.size(), 12)
	assert_eq(equip_ids.size(), 10)
	for id: StringName in weapon_ids:
		var item: ContentItem = ContentLibrary.item(id)
		assert_true(item is Weapon, "weapon id %s" % String(id))
		assert_eq((item as Weapon).validation_errors().size(), 0, String(id))
	for id: StringName in equip_ids:
		var eitem: ContentItem = ContentLibrary.item(id)
		assert_true(eitem is Equipment, "equipment id %s" % String(id))
		assert_eq((eitem as Equipment).validation_errors().size(), 0, String(id))


func test_install_weapon_changes_stats_and_refunds() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	host.add_child(FakeDocking.new())
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(5000)
	var base_dmg: float = ships.effective_weapon_damage()
	assert_true(ships.can_install(WEAPON_LIGHT))
	assert_true(ships.install_weapon(WEAPON_LIGHT))
	var weapon: Weapon = ContentLibrary.item(WEAPON_LIGHT) as Weapon
	assert_almost_eq(ships.effective_weapon_damage(), weapon.damage, TOLERANCE)
	assert_gt(ships.effective_weapon_damage(), base_dmg)
	assert_eq(wallet.credits(), 5000 - weapon.buy_price)

	var weapons: Array[StringName] = ships.installed_weapons()
	assert_eq(weapons[0], WEAPON_LIGHT)
	assert_true(ships.uninstall_weapon(0))
	var expected: int = 5000 - weapon.buy_price + BalanceOutfit.sell_refund(weapon.buy_price)
	assert_eq(wallet.credits(), expected)
	assert_almost_eq(ships.effective_weapon_damage(), base_dmg, TOLERANCE)


func test_role_gate_fighter_only_weapon_on_hauler() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	host.add_child(FakeDocking.new())
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(10000)
	assert_false(ships.can_install(WEAPON_FIGHTER_INTERCEPTOR))
	assert_false(ships.install_weapon(WEAPON_FIGHTER_INTERCEPTOR))
	assert_eq(ships.installed_weapons()[0], BalanceOutfit.EMPTY_SLOT)


func test_cargo_equipment_raises_capacity() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	host.add_child(FakeDocking.new())
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(10000)
	var base_cap: int = ships.active_cargo_capacity()
	assert_true(ships.install_equipment(EQUIP_CARGO_LARGE))
	var equip: Equipment = ContentLibrary.item(EQUIP_CARGO_LARGE) as Equipment
	assert_eq(ships.active_cargo_capacity(), base_cap + int(equip.effect_value))


func test_armor_mult_reduces_apply_damage() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	host.add_child(FakeDocking.new())
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(10000)
	assert_true(ships.install_equipment(EQUIP_ARMOR_PLATE))
	var mult: float = ships.damage_taken_multiplier()
	var armor: Equipment = ContentLibrary.item(EQUIP_ARMOR_PLATE) as Equipment
	assert_almost_eq(mult, armor.effect_value, TOLERANCE)
	var hit: float = 40.0
	var applied: float = wallet.apply_damage(hit)
	assert_almost_eq(applied, hit * mult, TOLERANCE)


func test_loadout_save_round_trip() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	host.add_child(FakeDocking.new())
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(10000)
	assert_true(ships.install_weapon(WEAPON_LIGHT))
	assert_true(ships.install_equipment(EQUIP_CARGO_STRAPS))
	var section: Dictionary = ships.to_section()
	assert_true(section.has(BalanceFlight.SAVE_KEY_LOADOUTS))
	var light: Weapon = ContentLibrary.item(WEAPON_LIGHT) as Weapon
	var armed_damage: float = ships.effective_weapon_damage()
	assert_almost_eq(armed_damage, light.damage, TOLERANCE)

	ships.reset()
	assert_eq(ships.installed_weapons()[0], BalanceOutfit.EMPTY_SLOT)
	var baseline_after_reset: float = ships.effective_weapon_damage()
	assert_ne(baseline_after_reset, armed_damage)

	var loadout_signals: Array = []
	EventBus.on_loadout_changed.connect(
		func(hull_id: StringName) -> void: loadout_signals.append(hull_id)
	)
	ships.apply_section(section)
	assert_eq(ships.installed_weapons()[0], WEAPON_LIGHT)
	assert_true(ships.installed_equipment().has(EQUIP_CARGO_STRAPS))
	# Same active hull id must still re-arm effective fire stats after load.
	assert_almost_eq(ships.effective_weapon_damage(), light.damage, TOLERANCE)
	assert_gt(loadout_signals.size(), 0, "apply_section must emit on_loadout_changed")


func test_fighter_weapon_ladder_three_tiers() -> void:
	var stock: Weapon = ContentLibrary.item(WEAPON_FIGHTER_STOCK) as Weapon
	var pulse: Weapon = ContentLibrary.item(WEAPON_FIGHTER_PULSE) as Weapon
	var interceptor: Weapon = ContentLibrary.item(WEAPON_FIGHTER_INTERCEPTOR) as Weapon
	assert_ne(stock, null)
	assert_ne(pulse, null)
	assert_ne(interceptor, null)
	var dps_stock: float = BalanceCombat.weapon_dps(stock.damage, stock.cooldown)
	var dps_pulse: float = BalanceCombat.weapon_dps(pulse.damage, pulse.cooldown)
	var dps_int: float = BalanceCombat.weapon_dps(interceptor.damage, interceptor.cooldown)
	assert_gt(dps_pulse, dps_stock)
	assert_gt(dps_int, dps_pulse)


func test_money_sink_fighter_plus_top_weapon() -> void:
	var endgame: Weapon = ContentLibrary.item(WEAPON_ENDGAME) as Weapon
	assert_ne(endgame, null)
	var total: int = BalanceEconomy.FIGHTER_PURCHASE_COST + endgame.buy_price
	assert_gt(total, BalanceEconomy.STARTING_CREDITS * 4)
	assert_gt(endgame.buy_price, BalanceEconomy.STARTING_CREDITS)

	var host: Node = Node.new()
	add_child_autofree(host)
	host.add_child(FakeDocking.new())
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(BalanceEconomy.STARTING_CREDITS)
	assert_false(
		ships.can_install(WEAPON_ENDGAME),
		"starter wallet must not afford endgame gun alone as free mid-game"
	)
	wallet.set_credits(total + 500)
	assert_true(ships.buy_fighter())
	assert_true(ships.switch_hull(FIGHTER_ID))
	var before: int = wallet.credits()
	assert_true(ships.install_weapon(WEAPON_ENDGAME))
	assert_lt(wallet.credits(), before)
	assert_eq(wallet.credits(), before - endgame.buy_price)


func test_hauler_cargo_career_beats_fighter_hold() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	host.add_child(FakeDocking.new())
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(20000)
	assert_true(ships.install_equipment(EQUIP_CARGO_LARGE))
	var hauler_cap: int = ships.active_cargo_capacity()

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
	# Fighter can take small straps only for cargo among fighter-ok cargo gear.
	if ships.can_install(EQUIP_CARGO_STRAPS):
		ships.install_equipment(EQUIP_CARGO_STRAPS)
	var fighter_cap: int = ships.active_cargo_capacity()
	assert_gt(hauler_cap, fighter_cap, "hauler with racks holds more than fighter")


func test_fighter_top_weapon_beats_stock_hauler_dps() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	host.add_child(FakeDocking.new())
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	ships.reset()
	wallet.reset()
	wallet.set_credits(20000)
	var hauler_dps: float = BalanceCombat.weapon_dps(
		ships.effective_weapon_damage(), ships.effective_weapon_cooldown()
	)

	(
		ships
		. apply_section(
			{
				BalanceFlight.SAVE_KEY_ACTIVE_HULL_ID: String(FIGHTER_ID),
				BalanceFlight.SAVE_KEY_OWNED_HULL_IDS: [String(HAULER_ID), String(FIGHTER_ID)],
			}
		)
	)
	assert_true(ships.install_weapon(WEAPON_FIGHTER_INTERCEPTOR))
	var fighter_dps: float = BalanceCombat.weapon_dps(
		ships.effective_weapon_damage(), ships.effective_weapon_cooldown()
	)
	assert_gt(fighter_dps, hauler_dps)


func test_outfit_money_events_emit() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	host.add_child(FakeDocking.new())
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ships: ShipService = ShipService.new()
	host.add_child(ships)
	await get_tree().process_frame

	var reasons: Array[StringName] = []
	var on_money: Callable = func(
		reason: StringName, _delta: int, _after: int, _detail: Dictionary
	) -> void:
		reasons.append(reason)
	EventBus.on_money_event.connect(on_money)

	ships.reset()
	wallet.reset()
	wallet.set_credits(5000)
	assert_true(ships.install_weapon(WEAPON_LIGHT))
	assert_true(ships.uninstall_weapon(0))
	EventBus.on_money_event.disconnect(on_money)

	assert_true(reasons.has(BalanceTelemetry.REASON_OUTFIT_BUY))
	assert_true(reasons.has(BalanceTelemetry.REASON_OUTFIT_SELL))
