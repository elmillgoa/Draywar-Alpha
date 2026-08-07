extends GutTest

## Job 10 — losing a fight ends the run, autosave gives it somewhere to end at,
## and a dry tank far from a berth can call a tow instead of being a dead end.
##
## Implements: Elliot's 2026-08-07 loss decision (DECISION_loss-and-autosave.md)
## and playtest findings PT-7 (Blocker) and PT-11.
##
## The numbers are the measured ones: the strand was 12,460 m from the nearest
## station with 0 credits, and one hostile removes a full hull in seconds.

const MainScene: PackedScene = preload("res://src/Main.tscn")

const AUTOSAVE_FIXTURE: String = "job10_autosave_fixture"
const STATION_ID: StringName = &"station_beta_hub"
const STATION_POS: Vector3 = Vector3(0.0, 0.0, 0.0)
## The measured strand distance from the playtest log (PT-11).
const STRANDED_POS: Vector3 = Vector3(12460.0, 0.0, 0.0)
const CREDITS_MARK: int = 777
## More than a full hull, so one call is a kill however damage scales.
const LETHAL_DAMAGE: float = 10000.0

var _wallet: WalletService = null
var _fuel: FuelService = null
var _hull: HullConditionService = null
var _ship: PlayerShip = null
var _docking: DockingService = null
var _rescue: RescueService = null


func before_each() -> void:
	_wallet = null
	_fuel = null
	_hull = null
	_ship = null
	_docking = null
	_rescue = null


func after_each() -> void:
	# The live session test resets every registered service on its way through
	# New Game; put the shared autoloads back so nothing after it inherits that.
	ServiceRegistry.reset_all()
	StandingService.reset_to_defaults()
	CareerStart.reset()
	var path: String = SaveService.path_for(AUTOSAVE_FIXTURE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


# --- Losing a fight --------------------------------------------------------


func test_zero_hull_away_from_a_station_ends_the_run() -> void:
	# PT-7, measured: at zero hull the ship froze 434 m from a station with
	# "DOCK FOR REPAIR" on screen, no death screen and nothing to reload.
	var hull: HullConditionService = HullConditionService.new()
	add_child_autofree(hull)
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	var docking: DockingService = DockingService.new()
	add_child_autofree(docking)
	var loss: LossScreen = LossScreen.new()
	add_child_autofree(loss)
	await get_tree().process_frame

	hull.reset()
	ship.global_position = STRANDED_POS
	docking.setup(ship, _stations())
	loss.set_armed(true)

	# Away from a station, and alive, before anything is done to it.
	assert_false(docking.is_in_station_interact_range(), "starts out of dock range")
	assert_true(hull.can_fly(), "starts flyable")
	assert_false(loss.is_showing(), "no loss screen while alive")

	hull.apply_damage(LETHAL_DAMAGE)

	# The chosen outcome: the run ends explicitly and says so.
	assert_false(hull.can_fly(), "hull is finished")
	assert_false(ship.is_flight_enabled(), "the wreck does not fly")
	assert_false(docking.is_in_station_interact_range(), "still nowhere near a berth")
	assert_true(loss.is_showing(), "the run ends on screen, not in silence")


func test_a_save_written_at_zero_hull_does_not_open_the_loss_screen() -> void:
	# Applying a save re-emits on_player_crippled when the wallet section lands.
	# Disarmed is how Main stops a load opening the loss screen over itself.
	var hull: HullConditionService = HullConditionService.new()
	add_child_autofree(hull)
	var loss: LossScreen = LossScreen.new()
	add_child_autofree(loss)
	await get_tree().process_frame

	hull.reset()
	loss.set_armed(false)
	hull.apply_damage(LETHAL_DAMAGE)

	assert_false(hull.can_fly(), "hull still reads as finished")
	assert_false(loss.is_showing(), "a load is not a death")


func test_disarming_the_loss_screen_takes_it_off_the_screen() -> void:
	var loss: LossScreen = LossScreen.new()
	add_child_autofree(loss)
	await get_tree().process_frame

	loss.set_armed(true)
	loss.show_loss()
	assert_true(loss.is_showing())

	loss.set_armed(false)
	assert_false(loss.is_showing(), "teardown clears the run's ending")


# --- Autosave --------------------------------------------------------------


func test_first_dock_of_a_career_autosaves_with_the_dock_origin() -> void:
	# The whole point: a captain who has never touched Save has a restart point
	# from the moment the storyboard dock happens.
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	var autosave: AutosaveService = AutosaveService.new()
	autosave.save_name = AUTOSAVE_FIXTURE
	host.add_child(autosave)
	await get_tree().process_frame
	wallet.set_credits(CREDITS_MARK)

	autosave.set_armed(true)
	EventBus.on_docked.emit(STATION_ID)
	await get_tree().process_frame
	await get_tree().process_frame

	var path: String = SaveService.path_for(AUTOSAVE_FIXTURE)
	assert_true(FileAccess.file_exists(path), "an autosave file exists")

	# Round-trips through the existing codec, with the origin the schema
	# already declared and nothing ever called.
	var service: SaveService = SaveService.new()
	var read_back: SaveResult = service.load_from(path)
	assert_true(read_back.ok(), "autosave decodes: %s" % read_back.summary())
	assert_eq(read_back.schema_version, SaveService.CURRENT_SCHEMA_VERSION, "no version bump")
	var origin: StringName = read_back.envelope[SaveService.KEY_ORIGIN]
	assert_eq(origin, SaveService.ORIGIN_AUTOSAVE_DOCK, "dock origin")

	var sections: Dictionary = read_back.envelope[SaveService.KEY_SECTIONS]
	assert_true(sections.has(BalanceEconomy.SAVE_SECTION_KEY), "autosave holds the wallet section")
	var wallet_section: Dictionary = sections[BalanceEconomy.SAVE_SECTION_KEY]
	assert_eq(
		_as_int(wallet_section[BalanceEconomy.SAVE_KEY_CREDITS]),
		CREDITS_MARK,
		"autosave holds what a manual save holds"
	)


func test_entering_a_system_autosaves_with_the_entry_origin() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var autosave: AutosaveService = AutosaveService.new()
	autosave.save_name = AUTOSAVE_FIXTURE
	host.add_child(autosave)
	await get_tree().process_frame

	autosave.set_armed(true)
	EventBus.on_system_entered.emit(BalanceFlight.PLAYABLE_SYSTEM_ID)
	await get_tree().process_frame
	await get_tree().process_frame

	var service: SaveService = SaveService.new()
	var read_back: SaveResult = service.load_from(SaveService.path_for(AUTOSAVE_FIXTURE))
	assert_true(read_back.ok(), "autosave decodes: %s" % read_back.summary())
	var origin: StringName = read_back.envelope[SaveService.KEY_ORIGIN]
	assert_eq(origin, SaveService.ORIGIN_AUTOSAVE_ENTRY, "entry origin")


func test_a_brand_new_career_has_a_restart_point_before_it_ever_undocks() -> void:
	# The clause this whole job hangs on: a captain who has never pressed Save
	# must still have something to come back to. Nothing else in the suite boots
	# the real session shell, and the arming point (just before the storyboard
	# dock) is exactly the kind of ordering an isolated rig would not catch.
	var main: Node = MainScene.instantiate()
	add_child_autofree(main)
	await _frames(4)

	EventBus.on_new_game_requested.emit()
	await _frames(12)

	# The session is booted by now, so the autosave node exists and can be
	# pointed at a fixture slot — a test may not tread on a real autosave.
	var autosave: AutosaveService = main.get_node("AutosaveService")
	autosave.save_name = AUTOSAVE_FIXTURE
	var path: String = SaveService.path_for(AUTOSAVE_FIXTURE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	EventBus.on_life_path_confirmed.emit(&"origin_core", &"trade_navy", &"mark_clean")
	await _frames(6)
	assert_false(FileAccess.file_exists(path), "nothing is written while the opening is still up")

	EventBus.on_annexation_continue_requested.emit()
	await _frames(8)

	assert_true(FileAccess.file_exists(path), "the storyboard dock wrote an autosave")
	var service: SaveService = SaveService.new()
	var read_back: SaveResult = service.load_from(path)
	assert_true(read_back.ok(), "it decodes: %s" % read_back.summary())
	var origin: StringName = read_back.envelope[SaveService.KEY_ORIGIN]
	assert_eq(origin, SaveService.ORIGIN_AUTOSAVE_DOCK, "written as a dock autosave")

	var sections: Dictionary = read_back.envelope[SaveService.KEY_SECTIONS]
	assert_true(sections.has(BalanceSession.SAVE_SECTION_WORLD), "it knows where the player is")
	var world_section: Dictionary = sections[BalanceSession.SAVE_SECTION_WORLD]
	var berth: String = str(world_section[BalanceSession.WORLD_KEY_DOCKED_STATION_ID])
	assert_false(berth.is_empty(), "and that they are in a berth")

	# Close the career down the way the game does, so the session's queue_free
	# calls flush inside the test instead of leaving orphans behind it.
	EventBus.on_quit_to_menu_requested.emit()
	await _frames(6)


func test_a_disarmed_autosave_writes_nothing() -> void:
	# on_system_entered fires part-way through session boot, when there is no
	# ship yet, and again while a load is being applied. Neither may write.
	var host: Node = Node.new()
	add_child_autofree(host)
	var autosave: AutosaveService = AutosaveService.new()
	autosave.save_name = AUTOSAVE_FIXTURE
	host.add_child(autosave)
	await get_tree().process_frame

	assert_false(autosave.is_armed(), "a new autosave starts disarmed")
	EventBus.on_system_entered.emit(BalanceFlight.PLAYABLE_SYSTEM_ID)
	EventBus.on_docked.emit(STATION_ID)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(
		FileAccess.file_exists(SaveService.path_for(AUTOSAVE_FIXTURE)),
		"a disarmed autosave writes no file"
	)


# --- Running out of fuel ---------------------------------------------------


func test_broke_and_dry_far_from_a_station_can_still_call_a_tow() -> void:
	# The measured PT-11 strand: fuel 0, credits 0, 12,460 m from the nearest
	# station. A rescue only the solvent can call is not a rescue.
	await _build_stranded_rig(0)

	assert_true(_rescue.is_available(), "a tow is on offer when the tank is dry")
	assert_eq(_rescue.fee_credits(), 0, "the tug takes nothing from an empty purse")
	assert_eq(_rescue.destination_station_id(), STATION_ID, "nearest berth that will take them")

	assert_true(_rescue.request_tow(), "the tow happens")
	assert_eq(_docking.docked_station_id(), STATION_ID, "the ship ends up in a berth")
	assert_eq(_wallet.credits(), 0, "still broke, but no longer stranded")
	assert_false(_rescue.is_available(), "no second tow while docked")


func test_the_tow_takes_the_full_fee_when_it_can_be_paid() -> void:
	await _build_stranded_rig(BalanceEconomy.STARTING_CREDITS)

	assert_eq(_rescue.fee_credits(), BalanceEconomy.TOW_FEE_CREDITS, "full fee when affordable")
	assert_true(_rescue.request_tow())
	assert_eq(
		_wallet.credits(),
		BalanceEconomy.STARTING_CREDITS - BalanceEconomy.TOW_FEE_CREDITS,
		"the fee is actually charged"
	)


func test_the_tow_never_charges_more_than_is_held() -> void:
	var short_purse: int = BalanceEconomy.TOW_FEE_CREDITS - 1
	await _build_stranded_rig(short_purse)

	assert_eq(_rescue.fee_credits(), short_purse, "fee is capped by what is held")
	assert_true(_rescue.request_tow())
	assert_eq(_wallet.credits(), 0, "the tug takes what there is and writes off the rest")


func test_no_tow_offer_while_the_tank_still_has_fuel() -> void:
	await _build_stranded_rig(0)

	_fuel.reset()
	assert_true(_fuel.has_fuel(), "tank refilled for this check")
	assert_false(_rescue.is_available(), "a tow is for a dry tank, not a long trip")


func test_a_destroyed_ship_gets_the_loss_screen_not_a_tow() -> void:
	# Running dry and losing a fight are different failures with different
	# outcomes. `HullConditionService.can_fly()` is what tells them apart.
	await _build_stranded_rig(0)

	assert_true(_rescue.is_available(), "a tow is on offer while the hull holds")
	_hull.apply_damage(LETHAL_DAMAGE)
	assert_false(_hull.can_fly())
	assert_false(_rescue.is_available(), "a wreck is the loss screen's business")


func test_the_tow_offer_and_its_fee_reach_the_hud() -> void:
	# Discoverability: the offer announces itself, so the prompt line can name
	# the key and the price without the player knowing the feature exists.
	var heard_available: Array[bool] = []
	var heard_fee: Array[int] = []
	var listener := func(available: bool, fee_credits: int) -> void:
		heard_available.append(available)
		heard_fee.append(fee_credits)
	EventBus.on_tow_prompt_changed.connect(listener)

	await _build_stranded_rig(BalanceEconomy.STARTING_CREDITS)
	await get_tree().physics_frame
	await get_tree().physics_frame
	EventBus.on_tow_prompt_changed.disconnect(listener)

	assert_true(heard_available.has(true), "the offer is announced")
	assert_true(heard_fee.has(BalanceEconomy.TOW_FEE_CREDITS), "with the fee that will be charged")
	assert_true(_rescue.is_available(), "and it is still on offer")


# --- Rig -------------------------------------------------------------------


func _stations() -> Dictionary[StringName, Vector3]:
	var positions: Dictionary[StringName, Vector3] = {}
	positions[STATION_ID] = STATION_POS
	return positions


## A ship stranded with a dry tank at the measured distance from one station.
func _build_stranded_rig(credits: int) -> void:
	var host: Node = Node.new()
	add_child_autofree(host)

	_wallet = WalletService.new()
	host.add_child(_wallet)
	_fuel = FuelService.new()
	host.add_child(_fuel)
	_hull = HullConditionService.new()
	host.add_child(_hull)
	_ship = PlayerShip.new()
	host.add_child(_ship)
	_docking = DockingService.new()
	host.add_child(_docking)
	_rescue = RescueService.new()
	host.add_child(_rescue)
	await get_tree().process_frame

	_wallet.set_credits(credits)
	_hull.reset()
	_fuel.apply_section({BalanceEconomy.SAVE_KEY_FUEL: 0.0})
	_ship.global_position = STRANDED_POS
	_docking.setup(_ship, _stations())
	_rescue.setup(_ship, _docking, _stations())
	await get_tree().process_frame


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0
