extends GutTest

## Mission turn-in at destination - play path (EventBus + try_complete_at).
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A3/A5, station Turn In button.

const CONTRACT_ALPHA: StringName = &"contract_courier_alpha"
const STATION_ALPHA: StringName = &"station_alpha_port"
const STATION_BETA: StringName = &"station_beta_hub"
const PAY: int = 120


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_real_path_accept_dock_beta_turn_in() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var ship: PlayerShip = PlayerShip.new()
	host.add_child(ship)
	var docking: DockingService = DockingService.new()
	host.add_child(docking)
	await get_tree().process_frame

	mission.reset()
	wallet.reset()
	assert_true(mission.accept(CONTRACT_ALPHA))
	docking.setup(ship, {STATION_BETA: Vector3.ZERO})
	assert_true(docking.begin_session_docked(STATION_BETA))
	assert_eq(docking.docked_station_id(), STATION_BETA)
	assert_true(mission.can_complete_at_station(STATION_BETA))
	assert_true(mission.has_active())

	var credits_before: int = wallet.credits()
	var standing_before: float = StandingService.get_entity_standing(&"entity_reach_authority")
	EventBus.on_mission_complete_requested.emit()
	await get_tree().process_frame

	assert_false(mission.has_active(), "mission should complete via EventBus when docked at dest")
	assert_eq(wallet.credits(), credits_before + PAY)
	assert_gt(StandingService.get_entity_standing(&"entity_reach_authority"), standing_before)


func test_try_complete_at_beta_pays_and_closes_job() -> void:
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	await get_tree().process_frame
	mission.reset()
	wallet.reset()
	assert_true(mission.accept(CONTRACT_ALPHA))
	var credits_before: int = wallet.credits()
	var wrong: Dictionary = mission.try_complete_at(STATION_ALPHA)
	var wrong_ok: bool = wrong[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	assert_false(wrong_ok, "wrong station must not complete")
	assert_true(mission.has_active())
	var right: Dictionary = mission.try_complete_at(STATION_BETA)
	var right_ok: bool = right[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	assert_true(right_ok, "beta hub is the destination")
	assert_false(mission.has_active())
	assert_eq(wallet.credits(), credits_before + PAY)
	assert_true(right.has(&"pay_credits"))
	var pay: int = _as_int(right[&"pay_credits"])
	assert_eq(pay, PAY)


func test_station_menu_turn_in_button_completes_at_docked_station() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var mission: MissionService = MissionService.new()
	host.add_child(mission)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	await get_tree().process_frame
	mission.reset()
	wallet.reset()
	assert_true(mission.accept(CONTRACT_ALPHA))

	var menu: StationMenu = StationMenu.new()
	host.add_child(menu)
	await get_tree().process_frame
	EventBus.on_docked.emit(STATION_BETA)
	assert_true(menu.visible)
	var credits_before: int = wallet.credits()
	menu._on_turn_in_job_pressed()
	await get_tree().process_frame
	assert_false(mission.has_active(), "station Turn In must close the Alpha to Beta courier")
	assert_eq(wallet.credits(), credits_before + PAY)


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0
