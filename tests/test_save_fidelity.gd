extends GutTest

## Everything the player earned or owed survives a reload — repair Job 3.
##
## Elliot's ruling, 2026-08-07: full round-trip fidelity, and pin the save
## folder now. Each test below names the thing the player used to lose.
##
## Also covers the two ordering bugs that close with the same work: the load
## was announced before the state existed (`#35`), and the HUD kept showing the
## pre-load standing tier when the save was made in the system you were already
## in (`W13`, Major).

const SaveMigrationsScript = preload("res://src/systems/save/SaveMigrations.gd")

const ENTITY_REACH: StringName = &"entity_reach_authority"
const PERSON_MENDI: StringName = &"person_ra_mendi"
const CHAIN_MENDI: StringName = &"recovery_reach_mendi"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const SYSTEM_BETA: StringName = &"system_beta"
const STATION_ALPHA_PORT: StringName = &"station_alpha_port"
const CONTRACT_BOUNTY_BETA: StringName = &"contract_bounty_beta_spit"
const SYSTEM_BETA_TARGET: StringName = &"system_beta"

const FIXTURE_PATH: String = "user://job3_save_fidelity.sav"

## Deep enough into the Hostile band that the HUD prints the word.
const HOSTILE_STANDING: float = -55.0
## Comfortably inside the Friendly band that gates a recovery offer.
const FRIENDLY_MARGIN: float = 5.0

## Security steps to run the world clock forward before touching cooldowns.
const COOLDOWN_FIXTURE_STEPS: int = 10
## A part-credit of upkeep: below one whole credit, so nothing is charged yet.
const PART_CREDIT_SECONDS: float = 0.25

## Where `user://` is pinned. Set in `project.godot` as
## `application/config/custom_user_dir_name`. It is deliberately the path Godot
## already derived from the product name, so pinning moved nothing.
const PINNED_USER_DIR: String = "Godot/app_userdata/Draywar"
const RENAMED_PRODUCT: String = "Draywar Renamed Later"

var _loaded_paths: PackedStringArray = []
var _standing_when_told_loaded: Array[float] = []
var _status_kinds: Array[StringName] = []
var _status_places: Array[StringName] = []


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	MarketService.reset()
	BoardService.reset()
	IncidentService.reset()
	EnforcementService.reset()
	StandingService.reset_to_defaults()
	CareerPathState.reset()
	_loaded_paths = []
	_standing_when_told_loaded = []
	_status_kinds = []
	_status_places = []


func after_each() -> void:
	if EventBus.on_save_loaded.is_connected(_record_loaded):
		EventBus.on_save_loaded.disconnect(_record_loaded)
	if EventBus.on_status_moment.is_connected(_record_status_moment):
		EventBus.on_status_moment.disconnect(_record_status_moment)
	IncidentService.reset()
	EnforcementService.reset()
	BoardService.reset()
	MarketService.reset()
	StandingService.reset_to_defaults()
	CareerPathState.reset()
	WorldClockHelpers.reset_clock()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)


# --- The berth you saved in ---------------------------------------------------


func test_a_save_written_docked_names_the_berth_in_the_file() -> void:
	# What this covers and what it does NOT. It covers the codec: a save taken
	# at a station writes the berth id and reads it back off a real file. It
	# does not cover the restore — `Main._apply_world_section()` is what puts
	# the player back in the berth, and this rig never calls it. The name used
	# to claim otherwise, which is how a reverted fix stayed green here.
	# `tests/test_docked_restore.gd` boots the real session and covers that.
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	ship.add_to_group(BalanceSession.GROUP_PLAYER_SHIP)
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	world.add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)
	add_child_autofree(world)
	var docking: DockingService = DockingService.new()
	add_child_autofree(docking)
	docking.setup(ship, {STATION_ALPHA_PORT: Vector3.ZERO})
	await get_tree().process_frame

	assert_true(docking.begin_session_docked(STATION_ALPHA_PORT), "fixture must start docked")

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	var through_disk: Dictionary = _sections_through_a_real_file(sections)
	var world_data: Dictionary = CareerSave.world_from_sections(through_disk)
	assert_eq(
		CareerSave.docked_station_from_world(world_data),
		STATION_ALPHA_PORT,
		"the save file must name the berth the player was sitting in"
	)

	# And that the berth id the file carries is one `DockingService` will take:
	# the same call `Main` makes on restore, made here against the service
	# alone. That the restore reaches this call at all is proved elsewhere.
	EventBus.on_undock_requested.emit(STATION_ALPHA_PORT)
	assert_false(docking.controller().is_docked(), "fixture must be free-flying before restore")

	var restored: StringName = CareerSave.docked_station_from_world(world_data)
	assert_true(docking.begin_session_docked(restored), "restore must dock again")
	assert_true(docking.controller().is_docked())
	assert_eq(docking.docked_station_id(), STATION_ALPHA_PORT)
	assert_false(ship.visible, "a docked ship is parked, not flying")


func test_a_save_written_free_flying_reads_as_free_flying() -> void:
	var world_data: Dictionary = CareerSave.make_world_section(SYSTEM_ALPHA, Vector3.ZERO)
	assert_eq(CareerSave.docked_station_from_world(world_data), &"")
	# A save from before the berth was ever written has no key at all.
	assert_eq(CareerSave.docked_station_from_world({}), &"")


# --- The recovery job you were on --------------------------------------------


func test_the_recovery_job_you_were_running_is_still_running_after_a_reload() -> void:
	# Before: an accepted recovery step vanished on load, uncompletable.
	var recovery: RecoveryService = RecoveryService.new()
	add_child_autofree(recovery)
	recovery.reset()
	await get_tree().process_frame
	StandingService.set_person_standing(
		PERSON_MENDI, BalanceStanding.TIER_FRIENDLY_MIN + FRIENDLY_MARGIN
	)
	assert_true(recovery.accept(PERSON_MENDI), "fixture must have a step running")
	var chain_id: StringName = recovery.active_chain_id()
	var step_id: StringName = recovery.active_step_id()
	assert_eq(chain_id, CHAIN_MENDI)

	var through_disk: Dictionary = _sections_through_a_real_file(
		CareerSave.gather_sections(get_tree())
	)
	recovery.reset()
	assert_false(recovery.has_active(), "fixture must be idle before the restore")

	CareerSave.apply_meta_sections(get_tree(), through_disk, FIXTURE_PATH)

	assert_true(recovery.has_active(), "the step the player accepted must come back")
	assert_eq(recovery.active_chain_id(), chain_id)
	assert_eq(recovery.active_step_id(), step_id)


func test_a_save_with_no_running_recovery_step_restores_none() -> void:
	var recovery: RecoveryService = RecoveryService.new()
	add_child_autofree(recovery)
	recovery.reset()
	await get_tree().process_frame

	recovery.apply_active_section({})
	assert_false(recovery.has_active(), "an empty active block means nothing was running")

	var gone: Dictionary = {
		BalanceStanding.RECOVERY_ACTIVE_KEY_CHAIN_ID: "recovery_that_is_gone",
		BalanceStanding.RECOVERY_ACTIVE_KEY_STEP_ID: "step_that_is_gone",
	}
	recovery.apply_active_section(gone)
	assert_false(recovery.has_active(), "a chain the build no longer ships restores nothing")


# --- Cooldowns ----------------------------------------------------------------


func test_a_forced_hunt_patrol_cannot_fire_again_just_because_you_reloaded() -> void:
	# Before: reloading cleared the hunt cooldown, so the same forced patrol
	# could be triggered again the moment the save came up.
	var step: int = _run_the_clock_forward()
	EnforcementService.record_hunt_spawn(SYSTEM_ALPHA, step)
	assert_false(EnforcementService.hunt_cooldown_ok(SYSTEM_ALPHA, step), "fixture on cooldown")

	var section: Dictionary = EnforcementService.to_section()
	EnforcementService.reset()
	assert_true(EnforcementService.hunt_cooldown_ok(SYSTEM_ALPHA, step), "reset clears cooldowns")

	EnforcementService.apply_section(section)

	assert_false(
		EnforcementService.hunt_cooldown_ok(SYSTEM_ALPHA, step),
		"the hunt cooldown must survive the reload"
	)
	assert_true(
		EnforcementService.hunt_cooldown_ok(
			SYSTEM_ALPHA, step + BalanceEnforcement.HUNT_COOLDOWN_STEPS
		),
		"and it must still expire on schedule afterwards"
	)


func test_an_incident_kind_cannot_repeat_immediately_just_because_you_reloaded() -> void:
	# Before: the "this kind already happened here" cooldown reset on load.
	var step: int = _run_the_clock_forward()
	IncidentService._record_kind_step(SYSTEM_ALPHA, BalanceIncident.KIND_DISTRESS, step)
	assert_false(
		IncidentService._cooldown_ok(SYSTEM_ALPHA, BalanceIncident.KIND_DISTRESS, step),
		"fixture on cooldown"
	)

	var section: Dictionary = IncidentService.to_section()
	IncidentService.reset()
	assert_true(
		IncidentService._cooldown_ok(SYSTEM_ALPHA, BalanceIncident.KIND_DISTRESS, step),
		"reset clears cooldowns"
	)

	IncidentService.apply_section(section)

	assert_false(
		IncidentService._cooldown_ok(SYSTEM_ALPHA, BalanceIncident.KIND_DISTRESS, step),
		"the incident cooldown must survive the reload"
	)
	assert_true(
		IncidentService._cooldown_ok(SYSTEM_ALPHA, BalanceIncident.KIND_INTERCEPT, step),
		"a different kind was never on cooldown and must not be put on one"
	)


# --- Bounty progress ----------------------------------------------------------


func test_kills_already_banked_on_a_bounty_are_still_banked_after_a_reload() -> void:
	# Before: the save only recorded "objective met", so anything short of the
	# last kill was thrown away and the hunt started over.
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	await get_tree().process_frame
	assert_true(mission.accept(CONTRACT_BOUNTY_BETA), "fixture must have a bounty running")

	var fresh: Dictionary = mission.to_section()
	assert_true(
		fresh.has(BalanceSession.MISSION_KEY_BOUNTY_KILLS),
		"a bounty save must carry the kill count, not just whether it is finished"
	)
	assert_eq(_as_int(fresh[BalanceSession.MISSION_KEY_BOUNTY_KILLS]), 0)

	EventBus.on_hostile_killed.emit(SYSTEM_BETA_TARGET, ENTITY_REACH)
	var banked: Dictionary = mission.to_section()
	assert_eq(
		_as_int(banked[BalanceSession.MISSION_KEY_BOUNTY_KILLS]),
		BalanceStanding.BOUNTY_KILLS_REQUIRED,
		"the kill must be recorded in the section"
	)

	mission.reset()
	mission.apply_section(banked)
	assert_eq(
		_as_int(mission.to_section()[BalanceSession.MISSION_KEY_BOUNTY_KILLS]),
		BalanceStanding.BOUNTY_KILLS_REQUIRED,
		"the banked kill must come back exactly"
	)
	assert_true(mission.is_objective_ready(), "and the job must still be ready to turn in")

	mission.reset()
	mission.apply_section(fresh)
	assert_eq(
		_as_int(mission.to_section()[BalanceSession.MISSION_KEY_BOUNTY_KILLS]),
		0,
		"a bounty with no kills yet must not be handed any"
	)
	assert_false(mission.is_objective_ready())


func test_an_old_bounty_save_still_restores_from_the_finished_flag_alone() -> void:
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	await get_tree().process_frame

	# Exactly what a build before this change wrote for a finished bounty.
	(
		mission
		. apply_section(
			{
				BalanceSession.MISSION_KEY_TEMPLATE_ID: String(CONTRACT_BOUNTY_BETA),
				BalanceSession.MISSION_KEY_OBJECTIVE_MET: true,
			}
		)
	)
	assert_true(mission.has_active(), "the old save must still load")
	assert_true(mission.is_objective_ready(), "and must still read as finished")


# --- Owed upkeep --------------------------------------------------------------


func test_the_part_credit_of_upkeep_already_owed_is_not_forgiven_by_reloading() -> void:
	# Before: the fractional upkeep run up since the last whole credit was
	# wiped on load, so reloading often was free money.
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	await get_tree().process_frame

	assert_eq(wallet.tick_upkeep(PART_CREDIT_SECONDS, false), 0, "no whole credit owed yet")
	var section: Dictionary = wallet.to_section()
	var owed: float = _as_float(section[BalanceEconomy.SAVE_KEY_UPKEEP_DEBT])
	assert_gt(owed, 0.0, "a part-credit must have built up")
	assert_lt(owed, 1.0, "and must still be less than a whole credit")

	wallet.reset()
	assert_eq(
		_as_float(wallet.to_section()[BalanceEconomy.SAVE_KEY_UPKEEP_DEBT]),
		0.0,
		"reset clears what is owed"
	)

	wallet.apply_section(section)
	assert_almost_eq(
		_as_float(wallet.to_section()[BalanceEconomy.SAVE_KEY_UPKEEP_DEBT]),
		owed,
		0.0001,
		"the part-credit must come back"
	)


func test_an_old_wallet_save_with_no_upkeep_key_owes_nothing() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	await get_tree().process_frame
	assert_eq(wallet.tick_upkeep(PART_CREDIT_SECONDS, false), 0)

	# A wallet section exactly as an older build wrote it.
	wallet.apply_section({BalanceEconomy.SAVE_KEY_CREDITS: 500})

	assert_eq(wallet.credits(), 500)
	assert_eq(
		_as_float(wallet.to_section()[BalanceEconomy.SAVE_KEY_UPKEEP_DEBT]),
		0.0,
		"an old save carried no part-credit, so none is owed"
	)


# --- Old files still load -----------------------------------------------------


func test_a_save_written_before_any_of_this_still_loads_with_no_migration_step() -> void:
	assert_eq(
		SaveService.CURRENT_SCHEMA_VERSION, 1, "none of these fields bumped the envelope version"
	)
	var steps: Dictionary[int, Callable] = SaveMigrationsScript.registered_steps()
	assert_eq(steps.size(), 0, "old files carry the same envelope, so no migration step is needed")

	# Hand-built to match what the previous build wrote: none of the new keys.
	var old_sections: Dictionary = {
		BalanceStanding.SAVE_SECTION_KEY:
		{
			BalanceStanding.SAVE_KEY_ENTITIES: {String(ENTITY_REACH): HOSTILE_STANDING},
			BalanceStanding.SAVE_KEY_RECOVERY_PROGRESS: {},
		},
		BalanceEconomy.SAVE_SECTION_KEY: {BalanceEconomy.SAVE_KEY_CREDITS: 1234},
		BalanceEnforcement.SAVE_SECTION_KEY: {BalanceEnforcement.SAVE_KEY_STEPS: 0},
		BalanceIncident.SAVE_SECTION_KEY: {BalanceIncident.SAVE_KEY_STEPS: 0},
	}
	var through_disk: Dictionary = _sections_through_a_real_file(old_sections)

	var recovery: RecoveryService = RecoveryService.new()
	add_child_autofree(recovery)
	recovery.reset()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	await get_tree().process_frame

	CareerSave.apply_meta_sections(get_tree(), through_disk, FIXTURE_PATH)

	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		HOSTILE_STANDING,
		0.0001,
		"an old save's standing must still restore"
	)
	assert_eq(wallet.credits(), 1234, "and its money")
	assert_false(recovery.has_active(), "it recorded no running step, so none is restored")
	assert_eq(
		_as_float(wallet.to_section()[BalanceEconomy.SAVE_KEY_UPKEEP_DEBT]),
		0.0,
		"it recorded no part-credit, so nothing is owed"
	)
	assert_true(
		EnforcementService.hunt_cooldown_ok(SYSTEM_ALPHA, 0),
		"it recorded no hunt cooldown, so nothing blocks one"
	)


# --- #35: the load is announced only once the state is real -------------------


func test_the_load_is_announced_only_after_the_restored_state_is_in_place() -> void:
	# Before: SaveService announced the load as soon as the file was decoded,
	# so every listener read the state the load was about to replace.
	StandingService.set_entity_standing(ENTITY_REACH, 0.0)
	var sections: Dictionary = {
		BalanceStanding.SAVE_SECTION_KEY:
		{BalanceStanding.SAVE_KEY_ENTITIES: {String(ENTITY_REACH): HOSTILE_STANDING}}
	}
	var through_disk: Dictionary = _sections_through_a_real_file(sections)

	EventBus.on_save_loaded.connect(_record_loaded)
	CareerSave.apply_meta_sections(get_tree(), through_disk, FIXTURE_PATH)

	assert_eq(_loaded_paths.size(), 1, "a successful load is announced exactly once")
	assert_eq(_loaded_paths[0], FIXTURE_PATH, "and it names the file that was read")
	assert_eq(_standing_when_told_loaded.size(), 1)
	assert_almost_eq(
		_standing_when_told_loaded[0],
		HOSTILE_STANDING,
		0.0001,
		"a listener must read the restored standing, not the one it replaced"
	)


func test_reading_a_save_file_on_its_own_announces_nothing() -> void:
	var service: SaveService = SaveService.new()
	assert_true(service.save_to(FIXTURE_PATH, SaveService.envelope({}, "Probe")).ok())

	EventBus.on_save_loaded.connect(_record_loaded)
	assert_true(service.load_from(FIXTURE_PATH).ok())

	assert_eq(
		_loaded_paths.size(),
		0,
		"decoding a file is not loading a career; nothing has been applied yet"
	)


# --- W13: the status line after a load into the system you are already in -----


func test_the_hud_shows_the_saved_standing_tier_after_a_load_in_the_same_system() -> void:
	# Before (W13, Major): the status line was written on system entry, which
	# on a load into the system you were already in had happened long before
	# the save's standing was applied — so the HUD kept the old tier.
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	world.add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)
	add_child_autofree(world)
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame

	EventBus.on_system_entered.emit(SYSTEM_ALPHA)
	assert_null(
		_label_containing(hud, "HOSTILE"),
		"fixture must start on good terms, or the test proves nothing"
	)

	var sections: Dictionary = {
		BalanceStanding.SAVE_SECTION_KEY:
		{BalanceStanding.SAVE_KEY_ENTITIES: {String(ENTITY_REACH): HOSTILE_STANDING}}
	}
	CareerSave.apply_meta_sections(get_tree(), sections, FIXTURE_PATH)

	var label: Label = _label_containing(hud, "HOSTILE")
	assert_not_null(label, "the status line must show the standing the save was made with")
	if label != null:
		assert_string_contains(label.text.to_upper(), "REACH AUTHORITY")


func test_the_status_moment_after_a_load_still_comes_from_standing_service() -> void:
	# The protected status moment must stay a StandingService emit — the load
	# asks it to re-fire, it does not announce standing on its service's behalf.
	var world: SystemWorld = SystemWorld.new()
	world.system_id = SYSTEM_ALPHA
	world.add_to_group(BalanceSession.GROUP_SYSTEM_WORLD)
	add_child_autofree(world)
	EventBus.on_status_moment.connect(_record_status_moment)

	CareerSave.apply_meta_sections(get_tree(), {}, FIXTURE_PATH)

	EventBus.on_status_moment.disconnect(_record_status_moment)
	assert_eq(_status_kinds.size(), 1, "a load re-shows the status moment exactly once")
	if _status_kinds.size() == 1:
		assert_eq(_status_kinds[0], BalanceStanding.STATUS_KIND_SYSTEM)
		assert_eq(_status_places[0], SYSTEM_ALPHA)


# --- Where the saves live -----------------------------------------------------


func test_the_save_folder_is_pinned_and_did_not_move() -> void:
	var pinned: bool = _as_bool(
		ProjectSettings.get_setting("application/config/use_custom_user_dir", false)
	)
	assert_true(pinned, "the save folder must be pinned, not derived from the product name")
	assert_eq(
		str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")),
		PINNED_USER_DIR,
		"the pin must name the folder saves already live in, so nothing moved"
	)
	assert_string_ends_with(OS.get_user_data_dir(), PINNED_USER_DIR)


func test_renaming_the_product_can_no_longer_hide_the_saves() -> void:
	# This is the failure RA-8 filed: renaming "Draywar Alpha" to "Draywar"
	# moved user:// and left the old saves somewhere nothing looks.
	var real_name: Variant = ProjectSettings.get_setting("application/config/name", "")
	var before: String = OS.get_user_data_dir()

	ProjectSettings.set_setting("application/config/name", RENAMED_PRODUCT)
	var after_rename: String = OS.get_user_data_dir()

	ProjectSettings.set_setting("application/config/use_custom_user_dir", false)
	var without_the_pin: String = OS.get_user_data_dir()

	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/name", real_name)

	assert_eq(
		after_rename, before, "with the pin, renaming the product must not move the save folder"
	)
	assert_ne(
		without_the_pin,
		before,
		"and without it the rename would move the folder — which is the bug being fixed"
	)
	assert_eq(OS.get_user_data_dir(), before, "the test must leave the folder where it found it")


# --- helpers ------------------------------------------------------------------


## Push sections through a real save file so the assertions are about what
## survives the codec, not what survives a dictionary copy.
func _sections_through_a_real_file(sections: Dictionary) -> Dictionary:
	var service: SaveService = SaveService.new()
	var written: SaveResult = service.save_to(FIXTURE_PATH, SaveService.envelope(sections, "Job 3"))
	assert_true(written.ok(), "the fixture save was refused: %s" % written.summary())
	var loaded: SaveResult = service.load_from(FIXTURE_PATH)
	assert_true(loaded.ok(), "the fixture save would not load: %s" % loaded.summary())
	if not loaded.ok():
		return {}
	var raw: Variant = loaded.envelope[SaveService.KEY_SECTIONS]
	if typeof(raw) != TYPE_DICTIONARY:
		assert_true(false, "the reloaded envelope has no sections")
		return {}
	var out: Dictionary = raw
	return out


## Run the world clock far enough forward that security steps exist to hang a
## cooldown on, and return the step number now current.
func _run_the_clock_forward() -> int:
	WorldClockHelpers.advance_seconds(
		BalanceIncident.INCIDENT_STEP_SECONDS * float(COOLDOWN_FIXTURE_STEPS)
	)
	IncidentService.catch_up()
	EnforcementService.catch_up()
	return COOLDOWN_FIXTURE_STEPS


func _label_containing(root: Node, needle: String) -> Label:
	if root is Label:
		var label: Label = root as Label
		if label.text.to_upper().contains(needle.to_upper()):
			return label
	for child: Node in root.get_children():
		var found: Label = _label_containing(child, needle)
		if found != null:
			return found
	return null


func _record_loaded(path: String) -> void:
	_loaded_paths.append(path)
	_standing_when_told_loaded.append(StandingService.get_entity_standing(ENTITY_REACH))


func _record_status_moment(
	kind: StringName,
	place_id: StringName,
	_entity_id: StringName,
	_standing: float,
	_tier: StringName
) -> void:
	_status_kinds.append(kind)
	_status_places.append(place_id)


func _as_bool(value: Variant) -> bool:
	if typeof(value) == TYPE_BOOL:
		var as_bool: bool = value
		return as_bool
	return false


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _as_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return as_float
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	return 0.0
