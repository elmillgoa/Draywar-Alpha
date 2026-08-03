extends GutTest

## CareerSave world_clock section round-trip — Steam S1.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S1

const TOLERANCE: float = 0.0001
const FIXTURE_PATH: String = "user://s1_world_clock_save.sav"


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)


func test_gather_sections_always_includes_world_clock() -> void:
	WorldClock.advance_seconds(42.0)
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceWorldClock.SAVE_SECTION_KEY))
	var raw: Variant = sections[BalanceWorldClock.SAVE_SECTION_KEY]
	assert_eq(typeof(raw), TYPE_DICTIONARY)
	var body: Dictionary = raw
	var elapsed_raw: Variant = body[BalanceWorldClock.SAVE_KEY_ELAPSED_SECONDS]
	assert_eq(typeof(elapsed_raw), TYPE_FLOAT)
	var elapsed_value: float = elapsed_raw
	assert_almost_eq(elapsed_value, 42.0, TOLERANCE)


func test_apply_meta_restores_elapsed() -> void:
	WorldClock.advance_seconds(777.0)
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	WorldClockHelpers.reset_clock()
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)

	CareerSave.apply_meta_sections(get_tree(), sections)
	assert_almost_eq(WorldClock.elapsed_seconds(), 777.0, TOLERANCE)


func test_apply_meta_missing_world_clock_resets() -> void:
	WorldClock.advance_seconds(50.0)
	CareerSave.apply_meta_sections(get_tree(), {})
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)


func test_save_load_envelope_round_trips_world_clock() -> void:
	WorldClock.advance_seconds(3600.0)
	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	var service: SaveService = SaveService.new()
	var written: SaveResult = service.save_to(
		FIXTURE_PATH, SaveService.envelope(sections, "S1 Clock Probe")
	)
	assert_true(written.ok(), written.summary())

	WorldClockHelpers.reset_clock()
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)

	var loaded: SaveResult = service.load_from(FIXTURE_PATH)
	assert_true(loaded.ok(), loaded.summary())
	var envelope: Dictionary = loaded.envelope
	assert_true(envelope.has(SaveService.KEY_SECTIONS))
	var loaded_sections: Dictionary = envelope[SaveService.KEY_SECTIONS]
	CareerSave.apply_meta_sections(get_tree(), loaded_sections)
	assert_almost_eq(WorldClock.elapsed_seconds(), 3600.0, TOLERANCE)
	# TimeScale still resets on load; clock elapsed is restored, not wiped by bus.
	assert_eq(TimeScale.effective_scale(), 1.0)


func test_service_registry_reset_does_not_require_main_name_list() -> void:
	## A fresh resettable registers without Main knowing its string name.
	var probe: _ResetProbe = _ResetProbe.new()
	add_child_autofree(probe)
	probe.register_self()
	assert_false(probe.was_reset)
	ServiceRegistry.reset_all()
	assert_true(probe.was_reset)


class _ResetProbe:
	extends Node

	var was_reset: bool = false

	func register_self() -> void:
		ServiceRegistry.register_resettable(_on_reset)

	func _on_reset() -> void:
		was_reset = true

	func _exit_tree() -> void:
		ServiceRegistry.unregister_resettable(_on_reset)
