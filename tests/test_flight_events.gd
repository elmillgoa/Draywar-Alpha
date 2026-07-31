extends GutTest

## EventBus flight signal catalogue presence — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Producer behaviour lives in test_a1_play_loop.gd. This file only proves the
## bus declares the A1 signals (boundaries also check docs/events.md).


func test_catalogued_flight_signals_exist_on_the_bus() -> void:
	assert_true(EventBus.has_signal("on_system_entered"))
	assert_true(EventBus.has_signal("on_dock_requested"))
	assert_true(EventBus.has_signal("on_docked"))
	assert_true(EventBus.has_signal("on_undock_requested"))
	assert_true(EventBus.has_signal("on_undocked"))
	assert_true(EventBus.has_signal("on_dock_prompt_changed"))
	assert_true(EventBus.has_signal("on_player_speed_changed"))
	assert_true(EventBus.has_signal("on_player_throttle_changed"))
