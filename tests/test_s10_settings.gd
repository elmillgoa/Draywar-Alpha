extends GutTest

## S10 options / a11y settings — FOV, sensitivity, volume, rebinds, persist.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10


func before_each() -> void:
	if FileAccess.file_exists(BalanceSettings.SETTINGS_PATH):
		DirAccess.remove_absolute(BalanceSettings.SETTINGS_PATH)
	SettingsService.reset_to_defaults()


func after_each() -> void:
	if FileAccess.file_exists(BalanceSettings.SETTINGS_PATH):
		DirAccess.remove_absolute(BalanceSettings.SETTINGS_PATH)
	SettingsService.reset_to_defaults()


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
