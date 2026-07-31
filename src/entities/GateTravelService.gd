class_name GateTravelService
extends Node

## Gate approach prompts and jump requests — Alpha A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5
##
## UI and ship only request; Main rebuilds the world on jump. Uses the same
## dock action (F) when a gate is in range and no station dock is available.

var _ship: PlayerShip = null
var _gate_positions: Dictionary[StringName, Vector3] = {}
var _console_open: bool = false
var _pause_open: bool = false
var _last_prompt_dest: StringName = &""
var _last_can_jump: bool = false
var _docking: DockingService = null


## Wire play session pieces. Call after each system rebuild.
func setup(
	ship: PlayerShip, gate_positions: Dictionary[StringName, Vector3], docking: DockingService
) -> void:
	_ship = ship
	_gate_positions = gate_positions.duplicate()
	_docking = docking
	if not EventBus.on_console_visibility_changed.is_connected(_on_console_visibility_changed):
		EventBus.on_console_visibility_changed.connect(_on_console_visibility_changed)
	if not EventBus.on_pause_changed.is_connected(_on_pause_changed):
		EventBus.on_pause_changed.connect(_on_pause_changed)


func _exit_tree() -> void:
	if EventBus.on_console_visibility_changed.is_connected(_on_console_visibility_changed):
		EventBus.on_console_visibility_changed.disconnect(_on_console_visibility_changed)
	if EventBus.on_pause_changed.is_connected(_on_pause_changed):
		EventBus.on_pause_changed.disconnect(_on_pause_changed)


func _physics_process(_delta: float) -> void:
	if _ship == null:
		return
	if _docking != null and _docking.controller().is_docked():
		_emit_prompt_if_changed(&"", false)
		return

	var dest_id: StringName = _nearest_gate_id(_ship.global_position)
	var distance: float = _distance_to(dest_id, _ship.global_position)

	var prompt_id: StringName = &""
	var in_interact: bool = false
	if dest_id != &"" and distance <= BalanceEconomy.GATE_INTERACT_RADIUS:
		prompt_id = dest_id
		in_interact = true
	elif dest_id != &"" and distance <= BalanceEconomy.GATE_APPROACH_RADIUS:
		prompt_id = dest_id

	var fuel_ok: bool = _wallet_can_jump()
	var can_jump: bool = in_interact and fuel_ok
	_emit_prompt_if_changed(prompt_id, can_jump)

	if _console_open or _pause_open:
		return
	# Prefer station dock: DockingService also listens for F. Only jump when
	# in gate interact range and not in station interact range.
	if Input.is_action_just_pressed(FlightInput.ACTION_DOCK) and in_interact:
		if _station_blocks_gate():
			return
		EventBus.on_jump_requested.emit(dest_id)


func _wallet_can_jump() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var wallet: Node = tree.get_first_node_in_group(&"wallet_service")
	if wallet == null or not wallet.has_method(&"can_jump"):
		return false
	return wallet.call(&"can_jump") == true


func _station_blocks_gate() -> bool:
	if _docking == null or _ship == null:
		return false
	if _docking.has_method(&"is_in_station_interact_range"):
		return _docking.is_in_station_interact_range()
	return false


func _emit_prompt_if_changed(dest_id: StringName, can_jump: bool) -> void:
	if dest_id == _last_prompt_dest and can_jump == _last_can_jump:
		return
	_last_prompt_dest = dest_id
	_last_can_jump = can_jump
	EventBus.on_gate_prompt_changed.emit(dest_id, can_jump)


func _nearest_gate_id(from: Vector3) -> StringName:
	var best_id: StringName = &""
	var best_dist: float = INF
	for dest_id: StringName in _gate_positions:
		var dist: float = from.distance_to(_gate_positions[dest_id])
		if dist < best_dist:
			best_dist = dist
			best_id = dest_id
	return best_id


func _distance_to(dest_id: StringName, from: Vector3) -> float:
	if dest_id == &"" or not _gate_positions.has(dest_id):
		return INF
	return from.distance_to(_gate_positions[dest_id])


func _on_console_visibility_changed(open: bool) -> void:
	_console_open = open


func _on_pause_changed(open: bool) -> void:
	_pause_open = open
