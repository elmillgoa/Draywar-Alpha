class_name DockingController
extends RefCounted

## Docking state machine — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Pure logic, no nodes. A world owner feeds range and calls request_dock /
## request_undock; EventBus emission stays with the owner.

enum State {
	UNDOCKED,
	IN_RANGE,
	DOCKED,
}

var state: State = State.UNDOCKED
var _docked_station_id: StringName = &""
var _in_range_station_id: StringName = &""


## Updates proximity while free-flying. No-op while docked.
func update_range(nearest_station_id: StringName, distance: float, interact_radius: float) -> void:
	if state == State.DOCKED:
		return

	if nearest_station_id != &"" and distance <= interact_radius:
		state = State.IN_RANGE
		_in_range_station_id = nearest_station_id
	else:
		state = State.UNDOCKED
		_in_range_station_id = &""


## Whether the player may press dock right now.
func can_dock() -> bool:
	return state == State.IN_RANGE and _in_range_station_id != &""


## Whether the player is currently docked.
func is_docked() -> bool:
	return state == State.DOCKED


## Station currently in interact range (empty if none).
func prompt_station_id() -> StringName:
	if state == State.IN_RANGE:
		return _in_range_station_id
	return &""


## Station currently docked at (empty if not docked).
func docked_station_id() -> StringName:
	if state == State.DOCKED:
		return _docked_station_id
	return &""


## Attempt dock. Returns the station id on success, empty on refusal.
func request_dock() -> StringName:
	if not can_dock():
		return &""
	_docked_station_id = _in_range_station_id
	state = State.DOCKED
	return _docked_station_id


## Attempt undock. Returns the station id left on success, empty on refusal.
func request_undock() -> StringName:
	if state != State.DOCKED:
		return &""
	var left: StringName = _docked_station_id
	state = State.UNDOCKED
	_docked_station_id = &""
	_in_range_station_id = &""
	return left
