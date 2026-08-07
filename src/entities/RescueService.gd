class_name RescueService
extends Node

## Emergency tow for a ship stranded with a dry tank — Job 10 (PT-11).
##
## Implements: the fuel-out half of Elliot's 2026-08-07 loss decision —
## "It is space, there really shouldn't be a boundary. If you run out of fuel
## you can try calling for a tow."
##
## Running dry is NOT losing a fight, so nothing here kills the run: a tug drags
## the ship to the nearest berth it will be let into and the career carries on.
## The fee is capped by what the pilot actually holds, because the strand that
## produced this job had zero credits and a rescue only the solvent can call is
## not a rescue.
##
## Lives beside DockingService in entities (same layer, same wiring shape: Main
## hands it the ship, the docking service and the station positions as plain
## data, so no world-layer type is referenced). Money and fuel are reached the
## sanctioned way, by group lookup — `wallet_service` and `fuel_service` both
## already list `entities` as a permitted consumer in docs/groups.md.
##
## `HullConditionService.can_fly()` stays the only answer to "can this ship
## fly": this asks it rather than keeping a second flag.

var _ship: PlayerShip = null
var _docking: DockingService = null
var _station_positions: Dictionary[StringName, Vector3] = {}
var _console_open: bool = false
var _pause_open: bool = false
var _last_available: bool = false
var _last_fee: int = -1


## Wire the play session pieces. Call after the world is built (and after jumps).
func setup(
	ship: PlayerShip, docking: DockingService, station_positions: Dictionary[StringName, Vector3]
) -> void:
	_ship = ship
	_docking = docking
	_station_positions = station_positions.duplicate()
	if not EventBus.on_console_visibility_changed.is_connected(_on_console_visibility_changed):
		EventBus.on_console_visibility_changed.connect(_on_console_visibility_changed)
	if not EventBus.on_pause_changed.is_connected(_on_pause_changed):
		EventBus.on_pause_changed.connect(_on_pause_changed)


func _exit_tree() -> void:
	if EventBus.on_console_visibility_changed.is_connected(_on_console_visibility_changed):
		EventBus.on_console_visibility_changed.disconnect(_on_console_visibility_changed)
	if EventBus.on_pause_changed.is_connected(_on_pause_changed):
		EventBus.on_pause_changed.disconnect(_on_pause_changed)
	# Clear a stale prompt so the HUD does not keep offering a tow after teardown.
	if _last_available:
		_last_available = false
		_last_fee = -1
		EventBus.on_tow_prompt_changed.emit(false, 0)


## True when a tug can be called: free-flying, tank dry, hull still whole enough
## to be worth towing, and somewhere in this system that will take the ship.
func is_available() -> bool:
	if _ship == null or _docking == null:
		return false
	if not String(_docking.docked_station_id()).is_empty():
		return false
	if _has_fuel():
		return false
	# A destroyed ship is the loss screen's business, not the tug's.
	if not _can_fly():
		return false
	return not String(destination_station_id()).is_empty()


## What the tug would actually take right now: the fee, or everything held when
## that is less. Never more than the pilot has, so zero credits is still a tow.
func fee_credits() -> int:
	return mini(BalanceEconomy.TOW_FEE_CREDITS, maxi(0, _wallet_credits()))


## Nearest station in this system that standing would let the ship dock at.
## Empty when there is none — a tug cannot force a berth open.
func destination_station_id() -> StringName:
	if _ship == null:
		return &""
	var best_id: StringName = &""
	var best_dist: float = INF
	var from: Vector3 = _ship.global_position
	for station_id: StringName in _station_positions:
		if not StandingService.can_dock_at_station(station_id):
			continue
		var dist: float = from.distance_to(_station_positions[station_id])
		if dist < best_dist:
			best_dist = dist
			best_id = station_id
	return best_id


## Call the tug. Charges what it can, then puts the ship in the berth using the
## same `begin_session_docked` a new career and a restored save use — no new
## rule about what a towed pilot may do. Returns true when the tow happened.
func request_tow() -> bool:
	if not is_available():
		return false
	var station_id: StringName = destination_station_id()
	if String(station_id).is_empty():
		return false

	var charged: int = fee_credits()
	if charged > 0 and not _try_spend(charged):
		charged = 0

	if not _docking.begin_session_docked(station_id):
		if charged > 0:
			_refund(charged)
		return false

	if charged > 0:
		_emit_money(BalanceTelemetry.REASON_TOW, -charged)
	_publish_prompt()
	return true


func _physics_process(_delta: float) -> void:
	_publish_prompt()
	if _console_open or _pause_open:
		return
	if not _last_available:
		return
	if Input.is_action_just_pressed(FlightInput.ACTION_TOW):
		request_tow()


## Tell the HUD whether a tow is on offer, and for how much. Only on a change.
func _publish_prompt() -> void:
	var available: bool = is_available()
	var fee: int = 0
	if available:
		fee = fee_credits()
	if available == _last_available and fee == _last_fee:
		return
	_last_available = available
	_last_fee = fee
	EventBus.on_tow_prompt_changed.emit(available, fee)


func _has_fuel() -> bool:
	var fuel: Node = _fuel_service()
	if fuel == null or not fuel.has_method(&"has_fuel"):
		# No fuel service (tests / bare scenes) means fuel is not the problem.
		return true
	return fuel.call(&"has_fuel") == true


func _can_fly() -> bool:
	var hull: Node = _hull_condition_service()
	if hull == null or not hull.has_method(&"can_fly"):
		return true
	return hull.call(&"can_fly") == true


func _wallet_credits() -> int:
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"credits"):
		return 0
	var raw: Variant = wallet.call(&"credits")
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	return 0


func _try_spend(amount: int) -> bool:
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"try_spend"):
		return false
	return wallet.call(&"try_spend", amount) == true


func _refund(amount: int) -> void:
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"add_credits"):
		return
	wallet.call(&"add_credits", amount)


func _emit_money(reason: StringName, delta: int) -> void:
	if delta == 0:
		return
	EventBus.on_money_event.emit(reason, delta, _wallet_credits(), {})


# Group names stay literal at the call site on purpose: a name passed through a
# wrapper is unreadable to scripts/check_groups.py and has to be registered as a
# dynamic site instead. Three one-line lookups cost less than that.


func _fuel_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"fuel_service")


func _hull_condition_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"hull_condition_service")


func _wallet_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"wallet_service")


func _on_console_visibility_changed(open: bool) -> void:
	_console_open = open


func _on_pause_changed(open: bool) -> void:
	_pause_open = open
