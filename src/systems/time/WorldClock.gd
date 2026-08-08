extends Node

## Accumulated game time and sim tick categories — Steam S1.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S1
##
## Autoload named `WorldClock`. Owns elapsed game seconds independent of the
## player ship's physics step. Live ticks use TimeScale.scaled_delta; combat
## lock only caps rate to 1x — the clock always advances while processing.
## Category subscribers (market, board, security, wallet_upkeep) share the same
## path for live frames and bulk advance_hours / advance_seconds.
##
## EventBus.on_world_time_advanced fires only on public bulk advance_* (not
## every frame — no per-frame bus traffic).

## Elapsed game time in seconds since career start / last reset.
var _elapsed_seconds: float = 0.0
## Parallel arrays: category[i] listens via callback[i] (delta_seconds).
var _sub_categories: Array[StringName] = []
var _sub_callbacks: Array[Callable] = []
## > 0 while inside public advance_seconds / advance_hours (bulk path).
var _bulk_depth: int = 0


func _ready() -> void:
	# REPAIR-5: must stop when the SceneTree is paused (fuel/upkeep/market).
	# Was ALWAYS, so world time kept advancing under the pause menu.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(true)
	ServiceRegistry.register_resettable(reset)
	register_category_subscriber(BalanceWorldClock.CATEGORY_WALLET_UPKEEP, _tick_wallet_upkeep)


func _process(delta: float) -> void:
	var scaled: float = TimeScale.scaled_delta(delta)
	_advance(scaled)


## Total elapsed game seconds.
func elapsed_seconds() -> float:
	return _elapsed_seconds


## Total elapsed game hours (seconds / SECONDS_PER_HOUR).
func elapsed_hours() -> float:
	return _elapsed_seconds / BalanceWorldClock.SECONDS_PER_HOUR


## Advance by an explicit number of game seconds (same path as live ticks).
## Emits on_world_time_advanced when seconds > 0.
func advance_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_bulk_depth += 1
	_advance(seconds)
	_bulk_depth -= 1
	EventBus.on_world_time_advanced.emit(_elapsed_seconds, seconds)


## Advance by game hours (converted via BalanceWorldClock.SECONDS_PER_HOUR).
func advance_hours(hours: float) -> void:
	if hours <= 0.0:
		return
	advance_seconds(hours * BalanceWorldClock.SECONDS_PER_HOUR)


## Clear elapsed time. Does not touch TimeScale. Subscribers are not notified.
func reset() -> void:
	_elapsed_seconds = 0.0


## Optional save section body for CareerSave.
func to_section() -> Dictionary:
	return {
		BalanceWorldClock.SAVE_KEY_ELAPSED_SECONDS: _elapsed_seconds,
	}


## Restore from save. Missing / invalid section → reset to zero.
## Does not emit bulk advance signals (load is not away-time).
func apply_section(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		reset()
		return
	var data: Dictionary = raw
	if not data.has(BalanceWorldClock.SAVE_KEY_ELAPSED_SECONDS):
		reset()
		return
	var value: float = _variant_to_float(data[BalanceWorldClock.SAVE_KEY_ELAPSED_SECONDS])
	if value < 0.0 or is_nan(value) or is_inf(value):
		reset()
		return
	_elapsed_seconds = value


## Register a category subscriber. callback receives (delta_seconds: float).
func register_category_subscriber(category: StringName, callback: Callable) -> void:
	if not callback.is_valid():
		return
	var count: int = _sub_categories.size()
	for i: int in count:
		if _sub_categories[i] == category and _sub_callbacks[i] == callback:
			return
	_sub_categories.append(category)
	_sub_callbacks.append(callback)


## Remove a previously registered category subscriber.
func unregister_category_subscriber(category: StringName, callback: Callable) -> void:
	var next_cats: Array[StringName] = []
	var next_cbs: Array[Callable] = []
	var count: int = _sub_categories.size()
	for i: int in count:
		if _sub_categories[i] == category and _sub_callbacks[i] == callback:
			continue
		next_cats.append(_sub_categories[i])
		next_cbs.append(_sub_callbacks[i])
	_sub_categories = next_cats
	_sub_callbacks = next_cbs


## Shared path for live frames and bulk advance: accumulate + notify categories.
func _advance(delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return
	_elapsed_seconds += delta_seconds
	_notify_subscribers(delta_seconds)


func _notify_subscribers(delta_seconds: float) -> void:
	var count: int = _sub_callbacks.size()
	for i: int in count:
		var callback: Callable = _sub_callbacks[i]
		if callback.is_valid():
			callback.call(delta_seconds)


## Wallet life-support upkeep on the world clock (E3.1 moved off PlayerShip).
## Live frames only drain while a player ship is in the tree so bare wallet unit
## tests that await frames are not taxed. Bulk advance_* always runs this path
## when a wallet exists (jump away-time, multi-frame equivalence tests).
func _tick_wallet_upkeep(delta_seconds: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if _bulk_depth <= 0:
		if tree.get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP) == null:
			return
	var wallet: Node = tree.get_first_node_in_group(&"wallet_service")
	if wallet == null or not wallet.has_method(&"tick_upkeep"):
		return
	var is_docked: bool = _is_player_docked(tree)
	wallet.call(&"tick_upkeep", delta_seconds, is_docked)


func _is_player_docked(tree: SceneTree) -> bool:
	var docking: Node = tree.get_first_node_in_group(&"docking_service")
	if docking == null:
		return false
	if docking.has_method(&"docked_station_id"):
		var station_raw: Variant = docking.call(&"docked_station_id")
		if typeof(station_raw) == TYPE_STRING_NAME:
			var as_name: StringName = station_raw
			return as_name != &""
		if typeof(station_raw) == TYPE_STRING:
			var as_text: String = station_raw
			return not as_text.is_empty()
	if docking.has_method(&"controller"):
		var controller_raw: Variant = docking.call(&"controller")
		if typeof(controller_raw) == TYPE_OBJECT:
			var controller: Object = controller_raw
			if controller != null and controller.has_method(&"is_docked"):
				return controller.call(&"is_docked") == true
	return false


func _variant_to_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return as_float
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		if as_text.is_valid_float():
			return as_text.to_float()
	return 0.0
