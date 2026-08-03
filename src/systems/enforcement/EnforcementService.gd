extends Node

## Per-Entity heat / patrol pressure — Steam S4.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S4
## Law: docs/reputation_and_standing.md — **no standing writes from this service**.
##
## Autoload named `EnforcementService`, deliberately with **no `class_name`**:
## same pattern as IncidentService. Heat is Dictionary entity_id → float
## (0..HEAT_MAX). The Entity keyed is the one that would enforce (system
## controller on crime). Decay rides the same security-step cadence as
## IncidentService (`INCIDENT_STEP_SECONDS`).

## entity_id string → heat float.
var _heat: Dictionary = {}
## Security steps applied for decay (independent of IncidentService).
var _steps_done: int = 0
## system_id string → last security step a hunt patrol response was forced.
var _last_hunt_step: Dictionary = {}
var _catching_up: bool = false


func _ready() -> void:
	ServiceRegistry.register_resettable(reset)
	WorldClock.register_category_subscriber(BalanceWorldClock.CATEGORY_SECURITY, _on_world_tick)
	EventBus.on_kill_attributed.connect(_on_kill_attributed)
	EventBus.on_contraband_seized.connect(_on_contraband_seized)


func _exit_tree() -> void:
	ServiceRegistry.unregister_resettable(reset)
	if EventBus.on_kill_attributed.is_connected(_on_kill_attributed):
		EventBus.on_kill_attributed.disconnect(_on_kill_attributed)
	if EventBus.on_contraband_seized.is_connected(_on_contraband_seized):
		EventBus.on_contraband_seized.disconnect(_on_contraband_seized)


## Clear all heat and step state for a new career.
func reset() -> void:
	_heat.clear()
	_steps_done = 0
	_last_hunt_step.clear()


## Run security steps WorldClock says are owed (decay). Idempotent.
func catch_up() -> void:
	if _catching_up:
		return
	var elapsed: float = WorldClock.elapsed_seconds()
	if not is_finite(elapsed) or elapsed < 0.0:
		return
	var step_secs: float = BalanceIncident.INCIDENT_STEP_SECONDS
	var wanted: int = floori(elapsed / step_secs)
	if wanted <= _steps_done:
		return
	_catching_up = true
	var steps: int = wanted - _steps_done
	_steps_done = wanted
	_decay_steps(steps)
	_catching_up = false


## Security steps applied for decay since career start.
func steps_done() -> int:
	catch_up()
	return _steps_done


## Current heat for an Entity (0 if unknown / empty).
func get_heat(entity_id: StringName) -> float:
	catch_up()
	if String(entity_id).is_empty():
		return BalanceEnforcement.HEAT_MIN
	var key: String = String(entity_id)
	if not _heat.has(key):
		return BalanceEnforcement.HEAT_MIN
	return _clamp_heat(_variant_to_float(_heat[key]))


## Heat for the controller of this system (0 if uncontrolled).
func heat_for_system(system_id: StringName) -> float:
	var controller: StringName = _controller_for_system(system_id)
	if String(controller).is_empty() or controller == StarSystem.HELD_BY_NOBODY:
		return BalanceEnforcement.HEAT_MIN
	return get_heat(controller)


## True when heat is high enough for more intercept pressure **and** the
## system is patrolled. Contested / lawless never pressure from heat.
func is_pressure(system_id: StringName) -> bool:
	if not _is_patrolled(system_id):
		return false
	return heat_for_system(system_id) >= BalanceEnforcement.HEAT_THRESHOLD_PRESSURE


## True when heat is high enough for a forced patrol response **and** the
## system is patrolled.
func is_hunt(system_id: StringName) -> bool:
	if not _is_patrolled(system_id):
		return false
	return heat_for_system(system_id) >= BalanceEnforcement.HEAT_THRESHOLD_HUNT


## Add (or subtract via negative amount) heat for an Entity. Clamped 0..MAX.
## Emits on_heat_changed when the value moves. Does **not** write standing.
func add_heat(entity_id: StringName, amount: float, reason: StringName) -> float:
	if String(entity_id).is_empty():
		return BalanceEnforcement.HEAT_MIN
	if not is_finite(amount) or amount == 0.0:
		return get_heat(entity_id)
	catch_up()
	var key: String = String(entity_id)
	var before: float = BalanceEnforcement.HEAT_MIN
	if _heat.has(key):
		before = _clamp_heat(_variant_to_float(_heat[key]))
	var after: float = _clamp_heat(before + amount)
	if is_equal_approx(before, after):
		if after <= BalanceEnforcement.HEAT_MIN:
			_heat.erase(key)
		return after
	if after <= BalanceEnforcement.HEAT_MIN:
		_heat.erase(key)
		after = BalanceEnforcement.HEAT_MIN
	else:
		_heat[key] = after
	EventBus.on_heat_changed.emit(entity_id, after, reason)
	return after


## Test / console helper: set absolute heat.
func set_heat(entity_id: StringName, value: float) -> float:
	if String(entity_id).is_empty():
		return BalanceEnforcement.HEAT_MIN
	catch_up()
	var key: String = String(entity_id)
	var before: float = get_heat(entity_id)
	var after: float = _clamp_heat(value)
	if is_equal_approx(before, after):
		return after
	if after <= BalanceEnforcement.HEAT_MIN:
		_heat.erase(key)
		after = BalanceEnforcement.HEAT_MIN
	else:
		_heat[key] = after
	var set_reason: StringName = BalanceEnforcement.REASON_HEAT_SET
	EventBus.on_heat_changed.emit(entity_id, after, set_reason)
	return after


## True when a forced hunt spawn is allowed this security step for the system.
func hunt_cooldown_ok(system_id: StringName, step: int) -> bool:
	if String(system_id).is_empty():
		return false
	var key: String = String(system_id)
	if not _last_hunt_step.has(key):
		return true
	var last: int = _variant_to_int(_last_hunt_step[key])
	return step - last >= BalanceEnforcement.HUNT_COOLDOWN_STEPS


## Record that a hunt patrol response was forced at this step.
func record_hunt_spawn(system_id: StringName, step: int) -> void:
	if String(system_id).is_empty():
		return
	_last_hunt_step[String(system_id)] = step


## Optional save section — heat map + decay step counter.
func to_section() -> Dictionary:
	catch_up()
	var heat_out: Dictionary = {}
	var keys: Array = _heat.keys()
	keys.sort()
	for key: Variant in keys:
		var k: String = str(key)
		heat_out[k] = _clamp_heat(_variant_to_float(_heat[key]))
	return {
		BalanceEnforcement.SAVE_KEY_HEAT: heat_out,
		BalanceEnforcement.SAVE_KEY_STEPS: _steps_done,
	}


## Restore heat; missing keys mean zero. No envelope version bump.
func apply_section(raw: Variant) -> void:
	reset()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	_steps_done = _restored_steps(data)
	if not data.has(BalanceEnforcement.SAVE_KEY_HEAT):
		return
	var raw_heat: Variant = data[BalanceEnforcement.SAVE_KEY_HEAT]
	if typeof(raw_heat) != TYPE_DICTIONARY:
		return
	var heat_map: Dictionary = raw_heat
	for key: Variant in heat_map:
		var entity_key: String = str(key)
		if entity_key.is_empty():
			continue
		var value: float = _clamp_heat(_variant_to_float(heat_map[key]))
		if value > BalanceEnforcement.HEAT_MIN:
			_heat[entity_key] = value


func _restored_steps(data: Dictionary) -> int:
	if not data.has(BalanceEnforcement.SAVE_KEY_STEPS):
		return 0
	var raw_steps: Variant = data[BalanceEnforcement.SAVE_KEY_STEPS]
	var saved: int = _variant_to_int(raw_steps)
	var elapsed: float = WorldClock.elapsed_seconds()
	var ceiling: int = 0
	if is_finite(elapsed) and elapsed > 0.0:
		var step_secs: float = BalanceIncident.INCIDENT_STEP_SECONDS
		ceiling = floori(elapsed / step_secs)
	return clampi(saved, 0, ceiling)


func _on_world_tick(_delta_seconds: float) -> void:
	catch_up()


func _on_kill_attributed(
	system_id: StringName, entity_id: StringName, _delta: float, _reason: StringName
) -> void:
	# Heat lands on the enforcing Entity (attribution target = local controller).
	var amount: float = _kill_heat_for_system(system_id)
	if amount <= 0.0:
		return
	var kill_reason: StringName = BalanceEnforcement.REASON_HEAT_KILL
	add_heat(entity_id, amount, kill_reason)


func _on_contraband_seized(
	station_id: StringName,
	entity_id: StringName,
	_commodity_ids: PackedStringArray,
	_fine_paid: int,
	_standing_delta: float
) -> void:
	var system_id: StringName = _system_for_station(station_id)
	var amount: float = _contraband_heat_for_system(system_id)
	if amount <= 0.0:
		return
	var contraband_reason: StringName = BalanceEnforcement.REASON_HEAT_CONTRABAND
	add_heat(entity_id, amount, contraband_reason)


func _decay_steps(count: int) -> void:
	if count <= 0 or _heat.is_empty():
		return
	var per_step: float = BalanceEnforcement.HEAT_DECAY_PER_SECURITY_STEP
	var total_decay: float = per_step * float(count)
	if total_decay <= 0.0:
		return
	# Snapshot keys so we can mutate during iteration.
	var keys: Array = _heat.keys()
	var decay_reason: StringName = BalanceEnforcement.REASON_HEAT_DECAY
	for key: Variant in keys:
		var entity_id: StringName = StringName(str(key))
		add_heat(entity_id, -total_decay, decay_reason)


func _kill_heat_for_system(system_id: StringName) -> float:
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return 0.0
	var policing: StringName = system.policing
	return BalanceEnforcement.kill_heat_for_policing(policing)


func _contraband_heat_for_system(system_id: StringName) -> float:
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return 0.0
	var policing: StringName = system.policing
	return BalanceEnforcement.contraband_heat_for_policing(policing)


func _is_patrolled(system_id: StringName) -> bool:
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return false
	return system.policing == StarSystem.POLICED_BY_PATROLS


func _controller_for_system(system_id: StringName) -> StringName:
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return &""
	if String(system.held_by).is_empty() or system.held_by == StarSystem.HELD_BY_NOBODY:
		return &""
	return system.held_by


func _system_for_station(station_id: StringName) -> StringName:
	if String(station_id).is_empty() or not ContentLibrary.has_item(station_id):
		return &""
	var item: ContentItem = ContentLibrary.item(station_id)
	if item is Station:
		var st: Station = item as Station
		return st.system_id
	return &""


func _load_system(system_id: StringName) -> StarSystem:
	if String(system_id).is_empty() or not ContentLibrary.has_item(system_id):
		return null
	var item: ContentItem = ContentLibrary.item(system_id)
	if item is StarSystem:
		return item as StarSystem
	return null


func _clamp_heat(value: float) -> float:
	var heat_min: float = BalanceEnforcement.HEAT_MIN
	var heat_max: float = BalanceEnforcement.HEAT_MAX
	if not is_finite(value):
		return heat_min
	return clampf(value, heat_min, heat_max)


func _variant_to_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return as_float
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return float(as_int)
	return 0.0


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0
