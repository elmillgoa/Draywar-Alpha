class_name DockingService
extends Node

## Owns docking state and emits EventBus dock signals — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## UI and ship only request; this node is the single writer for dock state.
## Lives in entities with the ship (same layer). Station positions arrive as
## data from Main — no world-layer type reference.

var _ship: PlayerShip = null
var _station_positions: Dictionary[StringName, Vector3] = {}
var _controller: DockingController = DockingController.new()
var _console_open: bool = false
var _last_prompt_id: StringName = &""
var _last_can_dock: bool = false


## Wire the play session pieces. Call once after the world is built.
func setup(ship: PlayerShip, station_positions: Dictionary[StringName, Vector3]) -> void:
	_ship = ship
	_station_positions = station_positions.duplicate()
	EventBus.on_console_visibility_changed.connect(_on_console_visibility_changed)
	EventBus.on_dock_requested.connect(_on_dock_requested)
	EventBus.on_undock_requested.connect(_on_undock_requested)


func _exit_tree() -> void:
	if EventBus.on_console_visibility_changed.is_connected(_on_console_visibility_changed):
		EventBus.on_console_visibility_changed.disconnect(_on_console_visibility_changed)
	if EventBus.on_dock_requested.is_connected(_on_dock_requested):
		EventBus.on_dock_requested.disconnect(_on_dock_requested)
	if EventBus.on_undock_requested.is_connected(_on_undock_requested):
		EventBus.on_undock_requested.disconnect(_on_undock_requested)


## Current pure state machine (for tests).
func controller() -> DockingController:
	return _controller


func _physics_process(_delta: float) -> void:
	if _ship == null:
		return
	if _controller.is_docked():
		_emit_prompt_if_changed(&"", false)
		return

	var station_id: StringName = _nearest_station_id(_ship.global_position)
	var distance: float = _distance_to(station_id, _ship.global_position)
	_controller.update_range(station_id, distance, BalanceFlight.DOCK_INTERACT_RADIUS)

	var range_ok: bool = _controller.can_dock()
	var prompt_id: StringName = &""
	if range_ok:
		prompt_id = _controller.prompt_station_id()
	elif station_id != &"" and distance <= BalanceFlight.DOCK_APPROACH_RADIUS:
		prompt_id = station_id

	var standing_ok: bool = true
	if prompt_id != &"":
		standing_ok = StandingService.can_dock_at_station(prompt_id)
	var can_dock: bool = range_ok and standing_ok
	_emit_prompt_if_changed(prompt_id, can_dock)

	if _console_open:
		return
	if Input.is_action_just_pressed(FlightInput.ACTION_DOCK) and range_ok:
		EventBus.on_dock_requested.emit(_controller.prompt_station_id())


func _emit_prompt_if_changed(station_id: StringName, can_dock: bool) -> void:
	if station_id == _last_prompt_id and can_dock == _last_can_dock:
		return
	_last_prompt_id = station_id
	_last_can_dock = can_dock
	EventBus.on_dock_prompt_changed.emit(station_id, can_dock)


func _nearest_station_id(from: Vector3) -> StringName:
	var best_id: StringName = &""
	var best_dist: float = INF
	for station_id: StringName in _station_positions:
		var dist: float = from.distance_to(_station_positions[station_id])
		if dist < best_dist:
			best_dist = dist
			best_id = station_id
	return best_id


func _distance_to(station_id: StringName, from: Vector3) -> float:
	if station_id == &"" or not _station_positions.has(station_id):
		return INF
	return from.distance_to(_station_positions[station_id])


func _station_anchor(station_id: StringName) -> Vector3:
	if _station_positions.has(station_id):
		return _station_positions[station_id]
	return BalanceFlight.STATION_POSITION


func _on_dock_requested(station_id: StringName) -> void:
	if _ship == null or _controller.is_docked():
		return
	if _controller.prompt_station_id() != station_id:
		var near_id: StringName = _nearest_station_id(_ship.global_position)
		var distance: float = _distance_to(near_id, _ship.global_position)
		_controller.update_range(near_id, distance, BalanceFlight.DOCK_INTERACT_RADIUS)
		if _controller.prompt_station_id() != station_id:
			return

	if not StandingService.can_dock_at_station(station_id):
		_emit_dock_refused(station_id)
		return

	var docked_id: StringName = _controller.request_dock()
	if docked_id == &"":
		return
	_ship.set_flight_enabled(false)
	_ship.velocity = Vector3.ZERO
	_ship.visible = false
	_emit_prompt_if_changed(&"", false)
	EventBus.on_docked.emit(docked_id)


func _emit_dock_refused(station_id: StringName) -> void:
	var status: Dictionary = StandingService.status_for_station(station_id)
	var entity_id: StringName = status[StandingService.STATUS_KEY_ENTITY_ID]
	var standing: float = status[StandingService.STATUS_KEY_STANDING]
	var tier: StringName = status[StandingService.STATUS_KEY_TIER]
	EventBus.on_dock_refused.emit(station_id, entity_id, standing, tier)


func _on_undock_requested(station_id: StringName) -> void:
	if _ship == null or not _controller.is_docked():
		return
	var current: StringName = _controller.docked_station_id()
	if station_id != &"" and station_id != current:
		return

	var left: StringName = _controller.request_undock()
	if left == &"":
		return

	_ship.global_position = _station_anchor(left) + BalanceFlight.UNDOCK_OFFSET
	_ship.velocity = Vector3.ZERO
	_ship.set_throttle(BalanceFlight.UNDOCK_THROTTLE)
	_ship.visible = true
	_ship.set_flight_enabled(true)
	EventBus.on_undocked.emit(left)


func _on_console_visibility_changed(open: bool) -> void:
	_console_open = open
