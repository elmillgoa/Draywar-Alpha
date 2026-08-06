extends GutTest

## Loading a save returns the game to 1x — Alpha A0.

const SaveCodecScript = preload("res://src/systems/save/SaveCodec.gd")

const FIXTURE_PATH: String = "user://a0_time_reset.sav"
const IMPOSTOR_PATH: String = "user://a0_time_reset_impostor.sav"
const ABSENT_PATH: String = "user://a0_time_reset_no_such_file.sav"

var _service: SaveService = null
var _scale_events: Array[float] = []
var _loaded_paths: PackedStringArray = []


func before_each() -> void:
	_service = SaveService.new()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	_scale_events = []
	_loaded_paths = []
	EventBus.on_time_scale_changed.connect(_record_scale)
	EventBus.on_save_loaded.connect(_record_loaded)


func after_each() -> void:
	EventBus.on_time_scale_changed.disconnect(_record_scale)
	EventBus.on_save_loaded.disconnect(_record_loaded)
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	for path: String in [FIXTURE_PATH, IMPOSTOR_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_loading_a_save_while_running_at_four_times_speed_returns_to_normal() -> void:
	_assert_a_real_load_from(4.0)


func test_loading_a_save_while_running_at_sixteen_times_speed_returns_to_normal() -> void:
	_assert_a_real_load_from(16.0)


func test_the_return_to_normal_speed_is_announced_on_the_bus() -> void:
	_write_a_save()
	assert_true(TimeScale.request_scale(16.0))
	_scale_events = []

	assert_true(_service.load_from(FIXTURE_PATH).ok())

	assert_eq(_scale_events.size(), 1)
	assert_eq(_scale_event(0), 1.0)


func test_a_load_at_normal_speed_announces_nothing_about_the_rate() -> void:
	_write_a_save()
	_scale_events = []

	assert_true(_service.load_from(FIXTURE_PATH).ok())

	assert_eq(TimeScale.effective_scale(), 1.0)
	assert_eq(_scale_events.size(), 0)


func test_the_load_announcement_carries_the_file_that_was_read() -> void:
	_write_a_save()

	assert_true(_service.load_from(FIXTURE_PATH).ok())

	assert_eq(_loaded_paths.size(), 1)
	assert_eq("\n".join(_loaded_paths), FIXTURE_PATH)


func test_a_missing_file_announces_nothing_and_leaves_the_speed_alone() -> void:
	assert_true(TimeScale.request_scale(16.0))
	_scale_events = []

	var result: SaveResult = _service.load_from(ABSENT_PATH)

	assert_false(result.ok())
	assert_eq(_loaded_paths.size(), 0)
	assert_eq(TimeScale.effective_scale(), 16.0)
	assert_eq(_scale_events.size(), 0)


func test_a_file_that_is_not_a_draywar_save_announces_nothing() -> void:
	var impostor: Dictionary = {&"format": &"some_other_game", &"schema_version": 1}
	_write_bytes(IMPOSTOR_PATH, SaveCodecScript.encode(impostor).bytes)

	assert_true(TimeScale.request_scale(4.0))
	_scale_events = []

	var result: SaveResult = _service.load_from(IMPOSTOR_PATH)

	assert_false(result.ok())
	assert_eq(_loaded_paths.size(), 0)
	assert_eq(TimeScale.effective_scale(), 4.0)
	assert_eq(_scale_events.size(), 0)


func _assert_a_real_load_from(scale: float) -> void:
	_write_a_save()

	assert_true(TimeScale.request_scale(scale))
	assert_eq(TimeScale.effective_scale(), scale)

	var loaded: SaveResult = _service.load_from(FIXTURE_PATH)
	assert_true(loaded.ok(), "the save should load: %s" % loaded.summary())

	assert_eq(TimeScale.effective_scale(), 1.0)
	assert_eq(TimeScale.requested_scale(), 1.0)


func _write_a_save() -> void:
	var written: SaveResult = _service.save_to(
		FIXTURE_PATH, SaveService.envelope({&"probe": {&"value": 0.5}}, "Reset Probe")
	)
	assert_true(written.ok(), "the fixture save should be written: %s" % written.summary())


func _write_bytes(path: String, raw: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_buffer(raw)
	file.close()


func _record_scale(scale: float) -> void:
	_scale_events.append(scale)


func _record_loaded(path: String) -> void:
	_loaded_paths.append(path)


func _scale_event(index: int) -> float:
	if index < 0 or index >= _scale_events.size():
		return NAN
	return _scale_events[index]
