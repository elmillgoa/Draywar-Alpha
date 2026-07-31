extends GutTest

## The time-scale service — Alpha A0.

const FRAME_DELTA: float = 0.25
const TOLERANCE: float = 0.0001

var _scale_events: Array[float] = []
var _lock_events: Array[bool] = []
var _console: ConsoleService = null
var _output: PackedStringArray = []


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	_scale_events = []
	_lock_events = []
	_output = []
	_console = ConsoleService.new()
	EventBus.on_time_scale_changed.connect(_record_scale)
	EventBus.on_combat_lock_changed.connect(_record_lock)
	EventBus.on_console_output.connect(_record_output)


func after_each() -> void:
	EventBus.on_time_scale_changed.disconnect(_record_scale)
	EventBus.on_combat_lock_changed.disconnect(_record_lock)
	EventBus.on_console_output.disconnect(_record_output)
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	_console = null


func test_the_service_is_registered_as_a_singleton_autoload() -> void:
	var raw: Variant = ProjectSettings.get_setting("autoload/TimeScale", "")
	var value: String = str(raw)
	assert_gt(value.length(), 0, "project.godot must declare autoload/TimeScale")
	assert_true(value.begins_with("*"), "the autoload must be a singleton")
	assert_file_exists(value.trim_prefix("*"))
	assert_eq(TimeScale.get_path(), NodePath("/root/TimeScale"))


func test_the_game_starts_at_normal_speed_with_the_lock_open() -> void:
	assert_eq(TimeScale.effective_scale(), 1.0)
	assert_eq(TimeScale.requested_scale(), 1.0)
	assert_false(TimeScale.is_combat_locked())


func test_scaled_delta_is_the_frame_delta_times_the_effective_rate() -> void:
	assert_almost_eq(TimeScale.scaled_delta(FRAME_DELTA), 0.25, TOLERANCE)

	assert_true(TimeScale.request_scale(16.0))
	assert_almost_eq(TimeScale.scaled_delta(FRAME_DELTA), 4.0, TOLERANCE)


func test_request_scale_accepts_all_three_speeds() -> void:
	for scale: float in [1.0, 4.0, 16.0]:
		assert_true(TimeScale.request_scale(scale), "%sx must be accepted" % scale)
		assert_eq(TimeScale.effective_scale(), scale)


func test_the_combat_lock_forces_normal_speed_and_gives_the_speed_back() -> void:
	assert_true(TimeScale.request_scale(16.0))
	assert_eq(TimeScale.effective_scale(), 16.0)

	TimeScale.set_combat_lock(true)
	assert_true(TimeScale.is_combat_locked())
	assert_eq(TimeScale.effective_scale(), 1.0)
	assert_eq(TimeScale.requested_scale(), 16.0)

	TimeScale.set_combat_lock(false)
	assert_eq(TimeScale.effective_scale(), 16.0)


func test_a_speed_chosen_during_combat_is_held_until_the_lock_opens() -> void:
	TimeScale.set_combat_lock(true)

	assert_true(TimeScale.request_scale(4.0))
	assert_eq(TimeScale.effective_scale(), 1.0)
	assert_eq(TimeScale.requested_scale(), 4.0)

	TimeScale.set_combat_lock(false)
	assert_eq(TimeScale.effective_scale(), 4.0)


func test_a_speed_that_is_not_one_of_the_three_is_refused_and_changes_nothing() -> void:
	assert_true(TimeScale.request_scale(4.0))
	_scale_events = []

	for rejected: float in [2.0, 8.0, 16.1, 0.5, 0.0, -4.0]:
		assert_false(TimeScale.request_scale(rejected), "%s is not an allowed speed" % rejected)
		assert_eq(TimeScale.requested_scale(), 4.0)
		assert_eq(TimeScale.effective_scale(), 4.0)

	assert_eq(_scale_events.size(), 0)


func test_the_scale_signal_carries_the_effective_rate_when_a_speed_is_chosen() -> void:
	assert_true(TimeScale.request_scale(4.0))
	assert_eq(_scale_events.size(), 1)
	assert_eq(_scale_event(0), 4.0)

	assert_true(TimeScale.request_scale(4.0))
	assert_eq(_scale_events.size(), 1, "asking for the speed already running announces nothing")


func test_closing_and_opening_the_lock_announces_the_rate() -> void:
	assert_true(TimeScale.request_scale(16.0))
	_scale_events = []

	TimeScale.set_combat_lock(true)
	assert_eq(_scale_events.size(), 1)
	assert_eq(_scale_event(0), 1.0)

	TimeScale.set_combat_lock(false)
	assert_eq(_scale_events.size(), 2)
	assert_eq(_scale_event(1), 16.0)


func test_the_lock_signal_fires_on_a_change_and_not_on_a_no_op() -> void:
	TimeScale.set_combat_lock(false)
	assert_eq(_lock_events.size(), 0)

	TimeScale.set_combat_lock(true)
	assert_eq(_lock_events.size(), 1)
	assert_true(_lock_events[0])

	TimeScale.set_combat_lock(true)
	assert_eq(_lock_events.size(), 1)

	TimeScale.set_combat_lock(false)
	assert_eq(_lock_events.size(), 2)
	assert_false(_lock_events[1])


func test_reset_returns_to_normal_speed_and_leaves_the_lock_alone() -> void:
	assert_true(TimeScale.request_scale(16.0))
	TimeScale.set_combat_lock(true)
	_scale_events = []
	_lock_events = []

	TimeScale.reset()

	assert_eq(TimeScale.requested_scale(), 1.0)
	assert_true(TimeScale.is_combat_locked())
	assert_eq(_lock_events.size(), 0)


func test_console_time_command_sets_the_scale() -> void:
	_console.start()
	_output = []

	_console.submit("time 4")

	assert_eq(TimeScale.effective_scale(), 4.0, "time 4 must change TimeScale")
	assert_string_contains("\n".join(_output), "4x")

	_console.submit("time 16")
	assert_eq(TimeScale.effective_scale(), 16.0, "time 16 must change TimeScale")


func _record_scale(scale: float) -> void:
	_scale_events.append(scale)


func _record_lock(locked: bool) -> void:
	_lock_events.append(locked)


func _record_output(line: String) -> void:
	_output.append(line)


func _scale_event(index: int) -> float:
	if index < 0 or index >= _scale_events.size():
		return NAN
	return _scale_events[index]
