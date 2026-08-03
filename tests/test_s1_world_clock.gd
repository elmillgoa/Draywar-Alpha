extends GutTest

## WorldClock deterministic advance, categories, bulk bus — Steam S1.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S1

const TOLERANCE: float = 0.0001
const FRAME_SECONDS: float = 0.25
const FRAME_COUNT: int = 40


func before_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()


func after_each() -> void:
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()


func test_autoload_is_registered() -> void:
	var raw: Variant = ProjectSettings.get_setting("autoload/WorldClock", "")
	var value: String = str(raw)
	assert_gt(value.length(), 0, "project.godot must declare autoload/WorldClock")
	assert_eq(WorldClock.get_path(), NodePath("/root/WorldClock"))


func test_starts_at_zero_after_reset() -> void:
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)
	assert_almost_eq(WorldClock.elapsed_hours(), 0.0, TOLERANCE)


func test_advance_seconds_accumulates() -> void:
	WorldClock.advance_seconds(10.0)
	assert_almost_eq(WorldClock.elapsed_seconds(), 10.0, TOLERANCE)
	WorldClock.advance_seconds(5.0)
	assert_almost_eq(WorldClock.elapsed_seconds(), 15.0, TOLERANCE)


func test_advance_hours_uses_balance_seconds() -> void:
	WorldClock.advance_hours(2.0)
	var expected: float = 2.0 * BalanceWorldClock.SECONDS_PER_HOUR
	assert_almost_eq(WorldClock.elapsed_seconds(), expected, TOLERANCE)
	assert_almost_eq(WorldClock.elapsed_hours(), 2.0, TOLERANCE)


func test_multi_frame_matches_single_chunk_for_elapsed() -> void:
	## Multi small advances share _advance with one bulk chunk.
	var frame: float = FRAME_SECONDS
	var frames: int = FRAME_COUNT
	var total: float = frame * float(frames)

	WorldClockHelpers.reset_clock()
	for _i: int in frames:
		WorldClock.advance_seconds(frame)
	var multi: float = WorldClock.elapsed_seconds()

	WorldClockHelpers.reset_clock()
	WorldClock.advance_seconds(total)
	var chunk: float = WorldClock.elapsed_seconds()

	assert_almost_eq(multi, chunk, TOLERANCE)
	assert_almost_eq(multi, total, TOLERANCE)


func test_advance_days_helper() -> void:
	WorldClockHelpers.advance_days(1.0)
	var expected: float = BalanceWorldClock.HOURS_PER_DAY * BalanceWorldClock.SECONDS_PER_HOUR
	assert_almost_eq(WorldClock.elapsed_seconds(), expected, TOLERANCE)


func test_reset_clears_elapsed_not_timescale() -> void:
	assert_true(TimeScale.request_scale(4.0))
	WorldClock.advance_hours(1.0)
	WorldClock.reset()
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)
	assert_eq(TimeScale.effective_scale(), 4.0)


func test_to_section_and_apply_section_round_trip() -> void:
	WorldClock.advance_seconds(1234.5)
	var section: Dictionary = WorldClock.to_section()
	assert_true(section.has(BalanceWorldClock.SAVE_KEY_ELAPSED_SECONDS))
	var elapsed_raw: Variant = section[BalanceWorldClock.SAVE_KEY_ELAPSED_SECONDS]
	assert_eq(typeof(elapsed_raw), TYPE_FLOAT)
	var elapsed_value: float = elapsed_raw
	assert_almost_eq(elapsed_value, 1234.5, TOLERANCE)

	WorldClock.reset()
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)
	WorldClock.apply_section(section)
	assert_almost_eq(WorldClock.elapsed_seconds(), 1234.5, TOLERANCE)


func test_apply_section_missing_or_invalid_resets() -> void:
	WorldClock.advance_seconds(50.0)
	WorldClock.apply_section({})
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)

	WorldClock.advance_seconds(50.0)
	WorldClock.apply_section(null)
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)

	WorldClock.advance_seconds(50.0)
	WorldClock.apply_section({BalanceWorldClock.SAVE_KEY_ELAPSED_SECONDS: -1.0})
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)


func test_bulk_advance_emits_bus_once() -> void:
	var totals: Array[float] = []
	var deltas: Array[float] = []
	var on_advanced: Callable = func(total_elapsed: float, delta_seconds: float) -> void:
		totals.append(total_elapsed)
		deltas.append(delta_seconds)
	EventBus.on_world_time_advanced.connect(on_advanced)

	WorldClock.advance_seconds(3.0)
	assert_eq(totals.size(), 1)
	assert_almost_eq(deltas[0], 3.0, TOLERANCE)
	assert_almost_eq(totals[0], 3.0, TOLERANCE)

	EventBus.on_world_time_advanced.disconnect(on_advanced)


func test_category_subscribers_receive_delta_on_advance() -> void:
	var received: Array[float] = []
	var on_market: Callable = func(delta_seconds: float) -> void: received.append(delta_seconds)
	WorldClock.register_category_subscriber(BalanceWorldClock.CATEGORY_MARKET, on_market)

	WorldClock.advance_seconds(2.5)
	assert_eq(received.size(), 1)
	assert_almost_eq(received[0], 2.5, TOLERANCE)

	WorldClock.unregister_category_subscriber(BalanceWorldClock.CATEGORY_MARKET, on_market)


func test_zero_and_negative_advance_are_noops() -> void:
	WorldClock.advance_seconds(0.0)
	WorldClock.advance_seconds(-5.0)
	WorldClock.advance_hours(0.0)
	WorldClock.advance_hours(-1.0)
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)


func test_service_registry_includes_world_clock_reset() -> void:
	WorldClock.advance_seconds(99.0)
	assert_gt(ServiceRegistry.resetter_count(), 0)
	ServiceRegistry.reset_all()
	assert_almost_eq(WorldClock.elapsed_seconds(), 0.0, TOLERANCE)
