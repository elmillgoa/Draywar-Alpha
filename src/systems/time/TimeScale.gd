extends Node

## The single authority on how fast game time runs — Alpha A0.
##
## Autoload named `TimeScale`. Ask, do not remember: clocks call
## `effective_scale()` / `scaled_delta()` every tick.
##
## Combat lock forces 1x while remembering the requested speed.
## Load always resets to 1x via `EventBus.on_save_loaded`.

const TimeConsoleCommands = preload("res://src/systems/time/TimeConsoleCommands.gd")

var _requested: float = Balance.TIME_SCALE_NORMAL
var _combat_locked: bool = false
var _console_commands: TimeConsoleCommands = null


func _ready() -> void:
	EventBus.on_save_loaded.connect(_on_save_loaded)
	EventBus.on_combat_lock_requested.connect(_on_combat_lock_requested)
	_console_commands = TimeConsoleCommands.new()


func _on_combat_lock_requested(locked: bool) -> void:
	set_combat_lock(locked)


## The speed the player asked for, whether or not the lock is honouring it.
func requested_scale() -> float:
	return _requested


## The rate game time is actually running at, after the combat lock is applied.
func effective_scale() -> float:
	if _combat_locked:
		return Balance.TIME_SCALE_NORMAL
	return _requested


## Whether the combat lock is currently holding time at normal speed.
func is_combat_locked() -> bool:
	return _combat_locked


## How much game time `real_delta` seconds of frame time is worth right now.
func scaled_delta(real_delta: float) -> float:
	return real_delta * effective_scale()


## Asks for a new speed. Returns false if `scale` is not in `Balance.TIME_SCALES`.
func request_scale(scale: float) -> bool:
	if not Balance.TIME_SCALES.has(scale):
		return false

	var before: float = effective_scale()
	_requested = scale
	_announce_scale_after(before)
	return true


## Opens or closes the combat lock. A no-op set announces nothing.
func set_combat_lock(locked: bool) -> void:
	if locked == _combat_locked:
		return

	var before: float = effective_scale()
	_combat_locked = locked
	EventBus.on_combat_lock_changed.emit(locked)
	_announce_scale_after(before)


## Back to normal speed, remembering nothing. Leaves the combat lock alone.
func reset() -> void:
	var before: float = effective_scale()
	_requested = Balance.TIME_SCALE_NORMAL
	_announce_scale_after(before)


func _announce_scale_after(before: float) -> void:
	var after: float = effective_scale()
	if after != before:
		EventBus.on_time_scale_changed.emit(after)


func _on_save_loaded(_path: String) -> void:
	reset()
