extends GutTest

## S10 options / a11y settings — FOV, sensitivity, volume, rebinds, persist.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10


func before_each() -> void:
	_clear_settings_files()
	SettingsService.settings_path_override = ""
	SettingsService.settings_tmp_path_override = ""
	SettingsService.reset_to_defaults()


func after_each() -> void:
	SettingsService.settings_path_override = ""
	SettingsService.settings_tmp_path_override = ""
	_clear_settings_files()
	SettingsService.reset_to_defaults()


func _clear_settings_files() -> void:
	for path: String in [
		BalanceSettings.SETTINGS_PATH,
		BalanceSettings.SETTINGS_TMP_PATH,
		BalanceSettings.SETTINGS_BAK_PATH,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_defaults_match_balance() -> void:
	assert_almost_eq(SettingsService.fov(), BalanceSettings.DEFAULT_FOV, 0.001)
	assert_almost_eq(SettingsService.sensitivity(), BalanceSettings.DEFAULT_SENSITIVITY, 0.001)
	assert_almost_eq(SettingsService.master_volume(), BalanceSettings.DEFAULT_MASTER_VOLUME, 0.001)
	assert_false(SettingsService.fullscreen())
	assert_false(BalanceSettings.CONTROLLER_SUPPORT_1_0, "1.0 is keyboard+mouse only")


func test_fov_clamps_and_emits() -> void:
	SettingsService.set_fov(200.0)
	assert_almost_eq(SettingsService.fov(), BalanceSettings.FOV_MAX, 0.001)
	SettingsService.set_fov(10.0)
	assert_almost_eq(SettingsService.fov(), BalanceSettings.FOV_MIN, 0.001)


func test_sensitivity_clamps() -> void:
	SettingsService.set_sensitivity(9.0)
	assert_almost_eq(SettingsService.sensitivity(), BalanceSettings.SENSITIVITY_MAX, 0.001)
	SettingsService.set_sensitivity(0.01)
	assert_almost_eq(SettingsService.sensitivity(), BalanceSettings.SENSITIVITY_MIN, 0.001)


func test_volume_clamps() -> void:
	SettingsService.set_master_volume(2.0)
	assert_almost_eq(SettingsService.master_volume(), BalanceSettings.VOLUME_MAX, 0.001)
	SettingsService.set_master_volume(-1.0)
	assert_almost_eq(SettingsService.master_volume(), BalanceSettings.VOLUME_MIN, 0.001)


func test_settings_round_trip_disk() -> void:
	SettingsService.set_fov(72.0)
	SettingsService.set_sensitivity(1.25)
	SettingsService.set_master_volume(0.4)
	SettingsService.set_ui_volume(0.5)
	SettingsService.set_sfx_volume(0.6)
	SettingsService.set_fullscreen(true)
	SettingsService.set_bind(&"dock", KEY_G)
	SettingsService.save_to_disk()

	## Wipe memory without writing (reset_to_defaults also saves and would clobber disk).
	SettingsService.set_fov(BalanceSettings.DEFAULT_FOV)
	SettingsService.set_sensitivity(BalanceSettings.DEFAULT_SENSITIVITY)
	SettingsService.set_master_volume(BalanceSettings.DEFAULT_MASTER_VOLUME)
	SettingsService.set_ui_volume(BalanceSettings.DEFAULT_UI_VOLUME)
	SettingsService.set_sfx_volume(BalanceSettings.DEFAULT_SFX_VOLUME)
	SettingsService.set_fullscreen(BalanceSettings.DEFAULT_FULLSCREEN)
	assert_almost_eq(SettingsService.fov(), BalanceSettings.DEFAULT_FOV, 0.001)

	SettingsService.load_from_disk()
	SettingsService.apply_all()
	assert_almost_eq(SettingsService.fov(), 72.0, 0.001)
	assert_almost_eq(SettingsService.sensitivity(), 1.25, 0.001)
	assert_almost_eq(SettingsService.master_volume(), 0.4, 0.001)
	assert_almost_eq(SettingsService.ui_volume(), 0.5, 0.001)
	assert_almost_eq(SettingsService.sfx_volume(), 0.6, 0.001)
	assert_true(SettingsService.fullscreen())
	assert_eq(SettingsService.bind_keycode(&"dock"), int(KEY_G))


func test_rebind_updates_input_map() -> void:
	FlightInput.ensure_actions()
	SettingsService.set_bind(&"throttle_up", KEY_I)
	SettingsService.apply_all()
	var found: bool = false
	for event: InputEvent in InputMap.action_get_events(&"throttle_up"):
		var key: InputEventKey = event as InputEventKey
		if key != null and key.physical_keycode == KEY_I:
			found = true
	assert_true(found, "throttle_up rebind must land in InputMap")


func test_escape_not_stored_as_bind() -> void:
	SettingsService.set_bind(&"dock", KEY_ESCAPE)
	assert_ne(SettingsService.bind_keycode(&"dock"), int(KEY_ESCAPE))


func test_product_name_not_alpha() -> void:
	assert_eq(BalanceSettings.PRODUCT_NAME, "Draywar")
	assert_false(BalanceSettings.PRODUCT_NAME.contains("Alpha"))


func _cfg_float(cfg: ConfigFile, section: String, key: String) -> float:
	var value: Variant = cfg.get_value(section, key, 0.0)
	match typeof(value):
		TYPE_FLOAT:
			var as_f: float = value
			return as_f
		TYPE_INT:
			var as_i: int = value
			return float(as_i)
		_:
			return 0.0


func _cfg_int(cfg: ConfigFile, section: String, key: String) -> int:
	var value: Variant = cfg.get_value(section, key, 0)
	match typeof(value):
		TYPE_INT:
			var as_i: int = value
			return as_i
		TYPE_FLOAT:
			var as_f: float = value
			return int(as_f)
		_:
			return 0


## REPAIR-23: a failed save must not wipe a known-good settings.cfg.
## Forces the temp write to an unwritable path; original file must still parse.
func test_failed_save_preserves_existing_settings() -> void:
	SettingsService.set_fov(72.0)
	SettingsService.set_sensitivity(1.25)
	SettingsService.set_master_volume(0.4)
	SettingsService.set_bind(&"dock", KEY_G)
	SettingsService.save_to_disk()
	assert_true(
		FileAccess.file_exists(BalanceSettings.SETTINGS_PATH),
		"known-good settings.cfg must exist before the forced failure"
	)

	## Temp sibling under a missing directory — ConfigFile.save cannot create it.
	SettingsService.settings_tmp_path_override = "user://__repair23_missing_dir__/settings.cfg.tmp"
	SettingsService.set_fov(55.0)
	SettingsService.set_sensitivity(0.5)
	SettingsService.set_master_volume(0.1)
	SettingsService.save_to_disk()

	assert_true(
		FileAccess.file_exists(BalanceSettings.SETTINGS_PATH),
		"failed save must leave the original settings.cfg in place"
	)
	var on_disk: ConfigFile = ConfigFile.new()
	assert_eq(on_disk.load(BalanceSettings.SETTINGS_PATH), OK, "original must still parse")
	assert_almost_eq(
		_cfg_float(on_disk, BalanceSettings.CFG_SECTION, BalanceSettings.KEY_FOV), 72.0, 0.001
	)
	assert_almost_eq(
		_cfg_float(on_disk, BalanceSettings.CFG_SECTION, BalanceSettings.KEY_SENSITIVITY),
		1.25,
		0.001
	)
	assert_almost_eq(
		_cfg_float(on_disk, BalanceSettings.CFG_SECTION, BalanceSettings.KEY_MASTER_VOLUME),
		0.4,
		0.001
	)
	assert_eq(_cfg_int(on_disk, BalanceSettings.CFG_SECTION_BINDS, "dock"), int(KEY_G))

	SettingsService.settings_tmp_path_override = ""
	SettingsService.load_from_disk()
	assert_almost_eq(SettingsService.fov(), 72.0, 0.001)
	assert_almost_eq(SettingsService.sensitivity(), 1.25, 0.001)
	assert_almost_eq(SettingsService.master_volume(), 0.4, 0.001)
	assert_eq(SettingsService.bind_keycode(&"dock"), int(KEY_G))


## REPAIR-23: normal atomic save round-trips and leaves no .tmp behind.
## Second save keeps the previous good file as settings.cfg.bak.
func test_atomic_save_round_trips_and_leaves_bak() -> void:
	SettingsService.set_fov(80.0)
	SettingsService.set_sensitivity(1.5)
	SettingsService.set_master_volume(0.55)
	SettingsService.set_fullscreen(true)
	SettingsService.set_bind(&"sector_map", KEY_N)
	SettingsService.save_to_disk()

	assert_true(FileAccess.file_exists(BalanceSettings.SETTINGS_PATH))
	assert_false(
		FileAccess.file_exists(BalanceSettings.SETTINGS_TMP_PATH),
		"successful save must not leave settings.cfg.tmp behind"
	)

	SettingsService.set_fov(70.0)
	SettingsService.set_sensitivity(0.9)
	SettingsService.save_to_disk()
	assert_false(FileAccess.file_exists(BalanceSettings.SETTINGS_TMP_PATH))
	assert_true(
		FileAccess.file_exists(BalanceSettings.SETTINGS_BAK_PATH),
		"replacing a good file should leave settings.cfg.bak"
	)

	var bak: ConfigFile = ConfigFile.new()
	assert_eq(bak.load(BalanceSettings.SETTINGS_BAK_PATH), OK)
	assert_almost_eq(
		_cfg_float(bak, BalanceSettings.CFG_SECTION, BalanceSettings.KEY_FOV), 80.0, 0.001
	)
	assert_almost_eq(
		_cfg_float(bak, BalanceSettings.CFG_SECTION, BalanceSettings.KEY_SENSITIVITY), 1.5, 0.001
	)

	## Wipe memory without writing, then reload primary file.
	SettingsService.set_fov(BalanceSettings.DEFAULT_FOV)
	SettingsService.set_sensitivity(BalanceSettings.DEFAULT_SENSITIVITY)
	SettingsService.set_master_volume(BalanceSettings.DEFAULT_MASTER_VOLUME)
	SettingsService.set_fullscreen(BalanceSettings.DEFAULT_FULLSCREEN)
	SettingsService.load_from_disk()
	assert_almost_eq(SettingsService.fov(), 70.0, 0.001)
	assert_almost_eq(SettingsService.sensitivity(), 0.9, 0.001)
	assert_almost_eq(SettingsService.master_volume(), 0.55, 0.001)
	assert_true(SettingsService.fullscreen())
	assert_eq(SettingsService.bind_keycode(&"sector_map"), int(KEY_N))
