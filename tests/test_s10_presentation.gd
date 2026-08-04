extends GutTest

## S10 presentation floor — lit materials, audio, steam stub.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10 §11


func test_hull_material_is_shaded_with_emission() -> void:
	var mat: StandardMaterial3D = BalancePresentation.hull_material(Color(1, 0.5, 0.2))
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	assert_true(mat.emission_enabled)


func test_engine_material_emits() -> void:
	var mat: StandardMaterial3D = BalancePresentation.engine_material(Color(0.2, 0.6, 1.0))
	assert_true(mat.emission_enabled)
	assert_gt(mat.emission_energy_multiplier, 1.0)


func test_vfx_material_stays_unshaded() -> void:
	var mat: StandardMaterial3D = BalancePresentation.vfx_material(Color.YELLOW)
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_true(mat.emission_enabled)


func test_player_ship_uses_shaded_hull() -> void:
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	await get_tree().process_frame
	var found_shaded: bool = false
	for child: Node in ship.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi == null or mi.material_override == null:
			continue
		var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D
		if mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			found_shaded = true
			break
	assert_true(found_shaded, "player hull parts should use per-pixel shading")


func test_station_material_helper_is_shaded() -> void:
	var mat: StandardMaterial3D = BalancePresentation.station_material(Color(0.5, 0.5, 0.6))
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL)


func test_steam_stub_unavailable_without_sdk() -> void:
	assert_false(SteamService.is_steam_available())
	assert_eq(SteamService.app_id(), 0)
	assert_false(SteamService.unlock_achievement(&"test_ach"))
	assert_true(SteamService.is_achievement_marked(&"test_ach"))
	SteamService.clear_debug_marks()
	assert_false(SteamService.is_achievement_marked(&"test_ach"))


func test_steam_presence_tracks_string() -> void:
	SteamService.set_presence(BalanceSettings.STEAM_PRESENCE_FLIGHT)
	assert_eq(SteamService.presence(), BalanceSettings.STEAM_PRESENCE_FLIGHT)
	SteamService.set_presence("")
	assert_eq(SteamService.presence(), BalanceSettings.STEAM_PRESENCE_MENU)


func test_audio_service_can_build_tone() -> void:
	## Ensure procedural tone path does not crash (stream not null).
	var stream: AudioStreamWAV = AudioService.make_tone(440.0, 0.02, 0.1)
	assert_ne(stream, null)
	assert_gt(stream.data.size(), 0)


func test_ship_budget_unchanged() -> void:
	assert_eq(BalanceEconomy.PERF_BUDGET_SHIPS, 20)
