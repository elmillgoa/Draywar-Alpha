extends Node

## Opportunistic space incidents — Steam S3b.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3b
##
## Autoload named `IncidentService`, deliberately with **no `class_name`**: same
## pattern as BoardService / MarketService. Incidents are lightweight prompts
## **separate** from MissionService's one-active-mission slot. Accepting help
## on distress **may** promote into a short runtime mission when the slot is
## free; when a mission is already active, help pays a small wallet reward and
## resolves without promote.
##
## Steps derive from WorldClock security category:
## `wanted = floor(elapsed / INCIDENT_STEP_SECONDS)`. Deterministic — no RNG.
## Ship budget: refuse spawn when player + traffic + hostiles + escorts +
## incident ships would exceed BalanceEconomy.PERF_BUDGET_SHIPS.
##
## Save policy: offered incidents **expire on load** (documented in
## save_schema.md). Only steps_done is restored for news continuity.

## Security steps applied since career start.
var _steps_done: int = 0
## incident_id string → offer Dictionary (offered only).
var _offered: Dictionary = {}
## Recent news echo lines (newest last), capped.
var _news_echoes: Array[String] = []
## Last kind offered per system_id string → step (cooldown).
var _last_kind_step: Dictionary = {}
## Optional headless override for live ship count (-1 = count from tree).
var _ship_count_override: int = -1
## When true, next fee-charging dock skips contraband inspect (same-trip customs).
var _customs_cleared_this_trip: bool = false
## Player location (system) for evaluation — set by world events / tests.
var _player_system_id: StringName = &""
var _catching_up: bool = false


func _ready() -> void:
	ServiceRegistry.register_resettable(reset)
	WorldClock.register_category_subscriber(BalanceWorldClock.CATEGORY_SECURITY, _on_world_tick)
	EventBus.on_system_entered.connect(_on_system_entered)
	EventBus.on_undocked.connect(_on_undocked)
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_incident_respond_requested.connect(_on_respond_requested)


func _exit_tree() -> void:
	ServiceRegistry.unregister_resettable(reset)
	if EventBus.on_system_entered.is_connected(_on_system_entered):
		EventBus.on_system_entered.disconnect(_on_system_entered)
	if EventBus.on_undocked.is_connected(_on_undocked):
		EventBus.on_undocked.disconnect(_on_undocked)
	if EventBus.on_docked.is_connected(_on_docked):
		EventBus.on_docked.disconnect(_on_docked)
	if EventBus.on_incident_respond_requested.is_connected(_on_respond_requested):
		EventBus.on_incident_respond_requested.disconnect(_on_respond_requested)


func _on_respond_requested(incident_id: StringName, choice: StringName) -> void:
	respond(incident_id, choice)


## Clear all incident state for a new career.
func reset() -> void:
	_steps_done = 0
	_offered.clear()
	_news_echoes.clear()
	_last_kind_step.clear()
	_ship_count_override = -1
	_customs_cleared_this_trip = false
	_player_system_id = &""


## Run security steps WorldClock says are owed. Idempotent.
func catch_up() -> void:
	if _catching_up:
		return
	var elapsed: float = WorldClock.elapsed_seconds()
	if not is_finite(elapsed) or elapsed < 0.0:
		return
	var step_secs: float = BalanceIncident.INCIDENT_STEP_SECONDS
	var wanted: int = floori(elapsed / step_secs)
	if wanted <= _steps_done:
		_expire_stale()
		return
	_catching_up = true
	var from_step: int = _steps_done + 1
	_steps_done = wanted
	_expire_stale()
	if not String(_player_system_id).is_empty():
		for step: int in range(from_step, wanted + 1):
			_try_spawn_for_system(_player_system_id, step)
	_catching_up = false


## Security steps applied since career start.
func steps_done() -> int:
	catch_up()
	return _steps_done


## Offered incident ids (sorted for determinism).
func offered_ids() -> Array[StringName]:
	catch_up()
	var keys: Array = _offered.keys()
	keys.sort()
	var out: Array[StringName] = []
	for k: Variant in keys:
		out.append(StringName(str(k)))
	return out


## Snapshot of one offered incident, or empty.
func get_offer(incident_id: StringName) -> Dictionary:
	catch_up()
	var key: String = String(incident_id)
	if not _offered.has(key):
		return {}
	var offer: Dictionary = _offered[key]
	return offer.duplicate(true)


## How many offered incidents are live.
func offered_count() -> int:
	catch_up()
	return _offered.size()


## Recent news echo lines (copy).
func news_echoes() -> Array[String]:
	var out: Array[String] = []
	for line: String in _news_echoes:
		out.append(line)
	return out


## True when dock should skip contraband inspect (space customs already ran).
func should_skip_dock_inspect() -> bool:
	return _customs_cleared_this_trip


## Clear the same-trip customs skip (call after dock inspect path consumes it).
func consume_dock_inspect_skip() -> bool:
	var was: bool = _customs_cleared_this_trip
	_customs_cleared_this_trip = false
	return was


## Headless / test override for live ship count (-1 restores tree count).
func set_ship_count_override(count: int) -> void:
	_ship_count_override = count


## Force-evaluate a system at the current step (tests / system enter).
func evaluate_system(system_id: StringName) -> void:
	if String(system_id).is_empty():
		return
	_player_system_id = system_id
	catch_up()
	_try_spawn_for_system(system_id, _steps_done)


## Pure builder for tests: offer dict that would fire for kind at step.
func build_offer_for_kind(kind: StringName, system_id: StringName, step: int) -> Dictionary:
	return _build_offer(kind, system_id, step)


## Force-offer a kind now if rules allow (tests). Returns incident id or empty.
func force_offer(kind: StringName, system_id: StringName) -> StringName:
	catch_up()
	if String(system_id).is_empty():
		return &""
	_player_system_id = system_id
	return _spawn_kind(kind, system_id, _steps_done, true)


## Respond to an offered incident. Returns result dictionary.
func respond(incident_id: StringName, choice: StringName) -> Dictionary:
	catch_up()
	var empty: Dictionary = {
		&"ok": false,
		&"outcome": &"",
		&"promoted": false,
		&"pay_credits": 0,
		&"incident_id": incident_id,
	}
	var key: String = String(incident_id)
	if not _offered.has(key):
		return empty
	var offer: Dictionary = _offered[key]
	var kind: StringName = StringName(str(offer.get(BalanceIncident.KEY_KIND, &"")))
	var result: Dictionary = empty.duplicate(true)
	result[&"ok"] = true
	result[&"incident_id"] = incident_id

	if kind == BalanceIncident.KIND_DISTRESS:
		result = _resolve_distress(offer, choice, result)
	elif kind == BalanceIncident.KIND_INTERCEPT:
		result = _resolve_intercept(offer, choice, result)
	elif kind == BalanceIncident.KIND_CUSTOMS:
		result = _resolve_customs(offer, choice, result)
	else:
		result[&"ok"] = false
		return result

	_finish_offer(key, result)
	return result


## Estimate live ships in the current system (budget math).
func estimate_live_ships() -> int:
	if _ship_count_override >= 0:
		return _ship_count_override
	var total: int = BalanceEconomy.PERF_BUDGET_PLAYER_COUNT
	var tree: SceneTree = get_tree()
	if tree == null:
		return total + _offered_ship_slots()
	for node: Node in tree.get_nodes_in_group(BalanceEconomy.GROUP_NPC_TRAFFIC):
		if node != null and node.has_method(&"live_ship_count"):
			total += _variant_to_int(node.call(&"live_ship_count"))
	var world: Node = tree.get_first_node_in_group(BalanceSession.GROUP_SYSTEM_WORLD)
	if world != null and world.has_method(&"live_hostile_count"):
		total += _variant_to_int(world.call(&"live_hostile_count"))
	for escort: Node in tree.get_nodes_in_group(BalanceBoard.GROUP_MISSION_ESCORT):
		if is_instance_valid(escort):
			total += 1
	total += _offered_ship_slots()
	return total


## True when adding `extra_ships` would exceed PERF_BUDGET_SHIPS.
func would_exceed_ship_budget(extra_ships: int) -> bool:
	if extra_ships <= 0:
		return false
	return estimate_live_ships() + extra_ships > BalanceEconomy.PERF_BUDGET_SHIPS


## Optional save section — steps + per-kind cooldowns. The offered list is
## still intentionally empty on load (policy; see save_schema.md).
func to_section() -> Dictionary:
	catch_up()
	var kind_out: Dictionary = {}
	var kind_keys: Array = _last_kind_step.keys()
	kind_keys.sort()
	for key: Variant in kind_keys:
		var map_key: String = str(key)
		if map_key.is_empty():
			continue
		kind_out[map_key] = _variant_to_int(_last_kind_step[key])
	return {
		BalanceIncident.SAVE_KEY_KIND_STEPS: kind_out,
		BalanceIncident.SAVE_KEY_STEPS: _steps_done,
	}


## Restore steps and per-kind cooldowns; offered incidents expire (policy).
func apply_section(raw: Variant) -> void:
	reset()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	_steps_done = _restored_steps(data)
	_apply_kind_steps(data)
	# Offered incidents do not survive load — mid-flight props are gone.


## Restore the "this kind already fired here recently" map, keyed
## "system_id|kind". A save written before this key existed has none, which is
## the old behaviour: the same incident kind could re-fire straight after a
## load. A step later than the restored step counter cannot have happened, so
## it is clamped rather than trusted.
func _apply_kind_steps(data: Dictionary) -> void:
	if not data.has(BalanceIncident.SAVE_KEY_KIND_STEPS):
		return
	var raw_kinds: Variant = data[BalanceIncident.SAVE_KEY_KIND_STEPS]
	if typeof(raw_kinds) != TYPE_DICTIONARY:
		return
	var kind_map: Dictionary = raw_kinds
	for key: Variant in kind_map:
		var map_key: String = str(key)
		if map_key.is_empty():
			continue
		_last_kind_step[map_key] = clampi(_variant_to_int(kind_map[key]), 0, _steps_done)


func _restored_steps(data: Dictionary) -> int:
	if not data.has(BalanceIncident.SAVE_KEY_STEPS):
		return 0
	var raw_steps: Variant = data[BalanceIncident.SAVE_KEY_STEPS]
	var saved: int = 0
	if typeof(raw_steps) == TYPE_INT:
		saved = raw_steps
	elif typeof(raw_steps) == TYPE_FLOAT:
		var as_float: float = raw_steps
		if is_finite(as_float):
			saved = int(as_float)
	var elapsed: float = WorldClock.elapsed_seconds()
	var ceiling: int = 0
	if is_finite(elapsed) and elapsed > 0.0:
		var step_secs: float = BalanceIncident.INCIDENT_STEP_SECONDS
		ceiling = floori(elapsed / step_secs)
	return clampi(saved, 0, ceiling)


func _on_world_tick(_delta_seconds: float) -> void:
	catch_up()


func _on_system_entered(system_id: StringName) -> void:
	_player_system_id = system_id
	_customs_cleared_this_trip = false
	evaluate_system(system_id)


func _on_undocked(_station_id: StringName) -> void:
	_customs_cleared_this_trip = false
	if String(_player_system_id).is_empty():
		_player_system_id = BalanceFlight.PLAYABLE_SYSTEM_ID
	evaluate_system(_player_system_id)


func _on_docked(_station_id: StringName) -> void:
	# Dock ends free-flight offers; expire unacted prompts cleanly.
	_expire_all_offered(&"dock")


func _try_spawn_for_system(system_id: StringName, step: int) -> void:
	if String(system_id).is_empty() or step < 0:
		return
	if _offered.size() >= BalanceIncident.MAX_OFFERED:
		return
	# Order is fixed so determinism does not depend on dictionary hash order.
	var kinds: Array[StringName] = [
		BalanceIncident.KIND_DISTRESS,
		BalanceIncident.KIND_INTERCEPT,
		BalanceIncident.KIND_CUSTOMS,
	]
	for kind: StringName in kinds:
		if _offered.size() >= BalanceIncident.MAX_OFFERED:
			return
		if not _kind_should_fire(kind, system_id, step):
			continue
		if not _cooldown_ok(system_id, kind, step):
			continue
		if not _kind_allowed_in_system(kind, system_id):
			continue
		_spawn_kind(kind, system_id, step, false)
	# S4: high heat in patrolled space can force a patrol-response intercept.
	_try_hunt_patrol_response(system_id, step)


## S4: when hunt heat is high in a patrolled system, force one intercept with
## patrol-response copy (respects MAX_OFFERED, ship budget, hunt cooldown).
func _try_hunt_patrol_response(system_id: StringName, step: int) -> void:
	if not EnforcementService.is_hunt(system_id):
		return
	if not EnforcementService.hunt_cooldown_ok(system_id, step):
		return
	if _offered.size() >= BalanceIncident.MAX_OFFERED:
		return
	if not _kind_allowed_in_system(BalanceIncident.KIND_INTERCEPT, system_id):
		return
	var id: StringName = _spawn_kind(BalanceIncident.KIND_INTERCEPT, system_id, step, true, true)
	if not String(id).is_empty():
		EnforcementService.record_hunt_spawn(system_id, step)


## Fire rules: base mix modulus, or pressure-boosted intercept frequency.
func _kind_should_fire(kind: StringName, system_id: StringName, step: int) -> bool:
	if kind == BalanceIncident.KIND_INTERCEPT and EnforcementService.is_pressure(system_id):
		var salt: int = BalanceIncident.SALT_INTERCEPT
		var pressure_mod: int = BalanceEnforcement.FIRE_MOD_INTERCEPT_PRESSURE
		var mod_n: int = maxi(1, pressure_mod)
		var mix: int = BalanceIncident.mix4(String(system_id).hash(), step, salt, 0)
		return (mix % mod_n) == 0
	return BalanceIncident.kind_fires(kind, system_id, step)


func _spawn_kind(
	kind: StringName, system_id: StringName, step: int, force: bool, patrol_response: bool = false
) -> StringName:
	if not force and not _kind_should_fire(kind, system_id, step):
		return &""
	if not _kind_allowed_in_system(kind, system_id):
		return &""
	var offer: Dictionary = _build_offer(kind, system_id, step, patrol_response)
	if offer.is_empty():
		return &""
	var slots: int = _dict_int(offer, BalanceIncident.KEY_SHIP_SLOTS, 0)
	if would_exceed_ship_budget(slots):
		return &""
	var id_raw: String = _resolve_offer_id(offer, system_id, step, patrol_response)
	if id_raw.is_empty():
		return &""
	offer[BalanceIncident.KEY_ID] = id_raw
	_offered[id_raw] = offer
	_record_kind_step(system_id, kind, step)
	_push_news_echo(kind, system_id)
	var prompt: String = str(offer.get(BalanceIncident.KEY_PROMPT, ""))
	EventBus.on_incident_prompt.emit(StringName(id_raw), kind, prompt)
	return StringName(id_raw)


## Pick a free offer id (retags hunt responses if a natural id collides).
func _resolve_offer_id(
	offer: Dictionary, system_id: StringName, step: int, patrol_response: bool
) -> String:
	var id_raw: String = str(offer.get(BalanceIncident.KEY_ID, ""))
	if id_raw.is_empty():
		return ""
	if not _offered.has(id_raw):
		return id_raw
	if not patrol_response:
		return ""
	var alt: String = "inc_patrol_%s_%d" % [String(system_id), step]
	if _offered.has(alt):
		return ""
	return alt


func _build_offer(
	kind: StringName, system_id: StringName, step: int, patrol_response: bool = false
) -> Dictionary:
	if String(system_id).is_empty():
		return {}
	var id_str: String = "inc_%s_%s_%d" % [String(kind), String(system_id), step]
	if patrol_response:
		id_str = "inc_patrol_%s_%d" % [String(system_id), step]
	var slots: int = BalanceIncident.SHIPS_CUSTOMS
	var label: String = BalanceIncident.LABEL_CUSTOMS
	var prompt: String = BalanceIncident.PROMPT_CUSTOMS
	if kind == BalanceIncident.KIND_DISTRESS:
		slots = BalanceIncident.SHIPS_DISTRESS
		label = BalanceIncident.LABEL_DISTRESS
		prompt = BalanceIncident.PROMPT_DISTRESS
	elif kind == BalanceIncident.KIND_INTERCEPT:
		slots = BalanceIncident.SHIPS_INTERCEPT
		if patrol_response:
			label = BalanceEnforcement.LABEL_PATROL_RESPONSE
			prompt = BalanceEnforcement.PROMPT_PATROL_RESPONSE
		else:
			label = BalanceIncident.LABEL_INTERCEPT
			prompt = BalanceIncident.PROMPT_INTERCEPT

	prompt = BalanceEnforcement.prompt_with_controls(kind, prompt)

	var dest: StringName = _pick_destination(system_id, step)
	var entity: StringName = _controller_for_system(system_id)
	var pay: int = BalanceIncident.DISTRESS_PROMOTE_PAY
	if kind == BalanceIncident.KIND_INTERCEPT:
		pay = BalanceIncident.INTERCEPT_RESIST_PAY

	return {
		BalanceIncident.KEY_ID: id_str,
		BalanceIncident.KEY_KIND: kind,
		BalanceIncident.KEY_STATE: BalanceIncident.STATE_OFFERED,
		BalanceIncident.KEY_SYSTEM: system_id,
		BalanceIncident.KEY_STEP: step,
		BalanceIncident.KEY_EXPIRE_STEP: step + BalanceIncident.OFFER_TTL_STEPS,
		BalanceIncident.KEY_LABEL: label,
		BalanceIncident.KEY_PROMPT: prompt,
		BalanceIncident.KEY_SHIP_SLOTS: slots,
		BalanceIncident.KEY_DESTINATION: dest,
		BalanceIncident.KEY_OFFERING_ENTITY: entity,
		BalanceIncident.KEY_PAY: pay,
		BalanceEnforcement.KEY_PATROL_RESPONSE: patrol_response,
	}


func _resolve_distress(offer: Dictionary, choice: StringName, result: Dictionary) -> Dictionary:
	if choice == BalanceIncident.CHOICE_IGNORE:
		result[&"outcome"] = BalanceIncident.STATE_RESOLVED
		result[&"promoted"] = false
		result[&"pay_credits"] = 0
		return result
	if choice != BalanceIncident.CHOICE_HELP:
		result[&"ok"] = false
		return result

	var mission: Node = _mission_service()
	var has_mission: bool = false
	if mission != null and mission.has_method(&"has_active"):
		has_mission = mission.call(&"has_active") == true
	if has_mission:
		# Locked rule: help without promote when mission slot full — wallet only.
		var pay: int = BalanceIncident.DISTRESS_HELP_PAY_ACTIVE_MISSION
		_pay_wallet(pay)
		result[&"outcome"] = BalanceIncident.STATE_RESOLVED
		result[&"promoted"] = false
		result[&"pay_credits"] = pay
		return result

	# Promote to short delivery mission via MissionService runtime path.
	var mission_offer: Dictionary = _distress_to_mission_offer(offer)
	var accepted: bool = false
	if mission != null and mission.has_method(&"accept_runtime_offer"):
		accepted = mission.call(&"accept_runtime_offer", mission_offer, false) == true
	if not accepted:
		# No mission service / accept failed — still pay small help reward.
		var fallback: int = BalanceIncident.DISTRESS_HELP_PAY_ACTIVE_MISSION
		_pay_wallet(fallback)
		result[&"outcome"] = BalanceIncident.STATE_RESOLVED
		result[&"promoted"] = false
		result[&"pay_credits"] = fallback
		return result
	result[&"outcome"] = BalanceIncident.STATE_PROMOTED
	result[&"promoted"] = true
	result[&"pay_credits"] = 0
	return result


func _resolve_intercept(offer: Dictionary, choice: StringName, result: Dictionary) -> Dictionary:
	if choice == BalanceIncident.CHOICE_IGNORE or choice == BalanceIncident.CHOICE_SUBMIT:
		# REPAIR-22: charge only what the wallet can cover; report that figure.
		# try_spend is all-or-nothing and would leave a broke player uncharged
		# while pay_credits still claimed the full nominal loss.
		var loss: int = BalanceIncident.INTERCEPT_SUBMIT_PAY_LOSS
		var charged: int = _charge_wallet(loss)
		result[&"outcome"] = BalanceIncident.STATE_RESOLVED
		result[&"promoted"] = false
		result[&"pay_credits"] = -charged
		return result
	if choice == BalanceIncident.CHOICE_RESIST or choice == BalanceIncident.CHOICE_HELP:
		var pay: int = _dict_int(
			offer, BalanceIncident.KEY_PAY, BalanceIncident.INTERCEPT_RESIST_PAY
		)
		_pay_wallet(pay)
		result[&"outcome"] = BalanceIncident.STATE_RESOLVED
		result[&"promoted"] = false
		result[&"pay_credits"] = pay
		return result
	result[&"ok"] = false
	return result


func _resolve_customs(offer: Dictionary, choice: StringName, result: Dictionary) -> Dictionary:
	if choice == BalanceIncident.CHOICE_FLEE or choice == BalanceIncident.CHOICE_IGNORE:
		# S4: fleeing customs raises heat on the offering (enforcing) Entity.
		var flee_entity: StringName = StringName(
			str(offer.get(BalanceIncident.KEY_OFFERING_ENTITY, &""))
		)
		if not String(flee_entity).is_empty():
			var flee_heat: float = BalanceEnforcement.HEAT_CUSTOMS_FLEE
			var flee_reason: StringName = BalanceEnforcement.REASON_HEAT_CUSTOMS_FLEE
			EnforcementService.add_heat(flee_entity, flee_heat, flee_reason)
		result[&"outcome"] = BalanceIncident.STATE_RESOLVED
		result[&"promoted"] = false
		result[&"pay_credits"] = 0
		return result
	if choice != BalanceIncident.CHOICE_COOPERATE and choice != BalanceIncident.CHOICE_SUBMIT:
		result[&"ok"] = false
		return result

	var entity: StringName = StringName(str(offer.get(BalanceIncident.KEY_OFFERING_ENTITY, &"")))
	var system_id: StringName = StringName(str(offer.get(BalanceIncident.KEY_SYSTEM, &"")))
	var station_guess: StringName = _first_station_in_system(system_id)
	var cargo: Node = _cargo_service()
	var fine: int = 0
	if cargo != null and cargo.has_method(&"inspect_for_controller"):
		var rep: Variant = cargo.call(&"inspect_for_controller", entity, station_guess)
		if typeof(rep) == TYPE_DICTIONARY:
			var rep_dict: Dictionary = rep
			fine = _dict_int(rep_dict, &"fine_paid", 0)
	# Same-trip rule: cooperate already ran the restricted-cargo path.
	_customs_cleared_this_trip = true
	result[&"outcome"] = BalanceIncident.STATE_RESOLVED
	result[&"promoted"] = false
	result[&"pay_credits"] = -fine
	return result


func _distress_to_mission_offer(offer: Dictionary) -> Dictionary:
	var id_str: String = "inc_mission_%s" % str(offer.get(BalanceIncident.KEY_ID, "x"))
	var dest: StringName = StringName(str(offer.get(BalanceIncident.KEY_DESTINATION, &"")))
	var entity: StringName = StringName(str(offer.get(BalanceIncident.KEY_OFFERING_ENTITY, &"")))
	var dest_name: String = _content_name(dest)
	if dest_name.is_empty():
		dest_name = String(dest)
	return {
		BalanceBoard.OFFER_KEY_ID: id_str,
		BalanceBoard.OFFER_KEY_BOARD_STATION: &"",
		BalanceBoard.OFFER_KEY_KIND: BalanceIncident.PROMOTE_KIND,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: entity,
		BalanceBoard.OFFER_KEY_PAY: BalanceIncident.DISTRESS_PROMOTE_PAY,
		BalanceBoard.OFFER_KEY_STANDING_COMPLETE: BalanceStanding.MISSION_COMPLETE_DELTA,
		BalanceBoard.OFFER_KEY_STANDING_FAIL: BalanceStanding.MISSION_FAIL_DELTA,
		BalanceBoard.OFFER_KEY_STANDING_ABANDON: BalanceStanding.MISSION_ABANDON_DELTA,
		BalanceBoard.OFFER_KEY_DESTINATION: dest,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: &"",
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: &"",
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: 0,
		BalanceBoard.OFFER_KEY_LABEL: BalanceIncident.LABEL_DISTRESS_MISSION % dest_name,
		BalanceBoard.OFFER_KEY_SOURCE: &"incident",
	}


func _finish_offer(key: String, result: Dictionary) -> void:
	if not _offered.has(key):
		return
	var offer: Dictionary = _offered[key]
	var kind: StringName = StringName(str(offer.get(BalanceIncident.KEY_KIND, &"")))
	var system_id: StringName = StringName(str(offer.get(BalanceIncident.KEY_SYSTEM, &"")))
	var outcome: StringName = StringName(
		str(result.get(&"outcome", BalanceIncident.STATE_RESOLVED))
	)
	var promoted: bool = result.get(&"promoted", false) == true
	_offered.erase(key)
	EventBus.on_incident_resolved.emit(StringName(key), kind, system_id, outcome, promoted)


func _expire_stale() -> void:
	var to_drop: Array[String] = []
	for key: Variant in _offered.keys():
		var offer: Dictionary = _offered[key]
		var expire_at: int = _dict_int(offer, BalanceIncident.KEY_EXPIRE_STEP, 0)
		if _steps_done >= expire_at:
			to_drop.append(str(key))
	for key: String in to_drop:
		var offer: Dictionary = _offered[key]
		var kind: StringName = StringName(str(offer.get(BalanceIncident.KEY_KIND, &"")))
		var system_id: StringName = StringName(str(offer.get(BalanceIncident.KEY_SYSTEM, &"")))
		_offered.erase(key)
		EventBus.on_incident_resolved.emit(
			StringName(key), kind, system_id, BalanceIncident.STATE_EXPIRED, false
		)


func _expire_all_offered(_reason: StringName) -> void:
	var keys: Array = _offered.keys()
	for key: Variant in keys:
		var k: String = str(key)
		var offer: Dictionary = _offered[k]
		var kind: StringName = StringName(str(offer.get(BalanceIncident.KEY_KIND, &"")))
		var system_id: StringName = StringName(str(offer.get(BalanceIncident.KEY_SYSTEM, &"")))
		_offered.erase(k)
		EventBus.on_incident_resolved.emit(
			StringName(k), kind, system_id, BalanceIncident.STATE_EXPIRED, false
		)


func _kind_allowed_in_system(kind: StringName, system_id: StringName) -> bool:
	if kind == BalanceIncident.KIND_INTERCEPT or kind == BalanceIncident.KIND_DISTRESS:
		return true
	if kind != BalanceIncident.KIND_CUSTOMS:
		return false
	# Customs light only in patrolled space with a real controller + restricted hold.
	var system: StarSystem = _load_system(system_id)
	if system == null or system.policing != StarSystem.POLICED_BY_PATROLS:
		return false
	var entity: StringName = _controller_for_system(system_id)
	if String(entity).is_empty() or entity == Station.CONTROLLER_NOBODY:
		return false
	return _hold_has_restricted_for(entity)


func _hold_has_restricted_for(controller: StringName) -> bool:
	var cargo: Node = _cargo_service()
	if cargo == null:
		return false
	if cargo.has_method(&"has_restricted_for_controller"):
		return cargo.call(&"has_restricted_for_controller", controller) == true
	return false


func _cooldown_ok(system_id: StringName, kind: StringName, step: int) -> bool:
	var map_key: String = "%s|%s" % [String(system_id), String(kind)]
	if not _last_kind_step.has(map_key):
		return true
	var last: int = _variant_to_int(_last_kind_step[map_key])
	return step - last >= BalanceIncident.COOLDOWN_STEPS_SAME_KIND


func _record_kind_step(system_id: StringName, kind: StringName, step: int) -> void:
	var map_key: String = "%s|%s" % [String(system_id), String(kind)]
	_last_kind_step[map_key] = step


func _push_news_echo(kind: StringName, system_id: StringName) -> void:
	var place: String = _content_name(system_id)
	if place.is_empty():
		place = String(system_id)
	var line: String = BalanceIncident.NEWS_INCIDENT_QUIET
	if kind == BalanceIncident.KIND_DISTRESS:
		line = BalanceIncident.NEWS_DISTRESS_ECHO % place
	elif kind == BalanceIncident.KIND_INTERCEPT:
		line = BalanceIncident.NEWS_INTERCEPT_ECHO % place
	elif kind == BalanceIncident.KIND_CUSTOMS:
		line = BalanceIncident.NEWS_CUSTOMS_ECHO % place
	_news_echoes.append(line)
	while _news_echoes.size() > BalanceIncident.NEWS_ECHO_CAP:
		_news_echoes.remove_at(0)
	# Thicken the shared feed when something real happened.
	EventBus.on_market_news.emit(line)


func _offered_ship_slots() -> int:
	var total: int = 0
	for key: Variant in _offered.keys():
		var offer: Dictionary = _offered[key]
		total += _dict_int(offer, BalanceIncident.KEY_SHIP_SLOTS, 0)
	return total


func _pick_destination(system_id: StringName, step: int) -> StringName:
	var stations: Array[StringName] = []
	for sid: StringName in ContentLibrary.ids_in(&"stations"):
		if not ContentLibrary.has_item(sid):
			continue
		var item: ContentItem = ContentLibrary.item(sid)
		if item is Station:
			var st: Station = item as Station
			if st.system_id != system_id and st.controller_entity_id != Station.CONTROLLER_NOBODY:
				stations.append(sid)
	if stations.is_empty():
		for sid: StringName in ContentLibrary.ids_in(&"stations"):
			stations.append(sid)
	if stations.is_empty():
		return &""
	stations.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var idx: int = BalanceIncident.pick_index(
		stations.size(), String(system_id).hash(), step, BalanceIncident.SALT_DEST, 0
	)
	return stations[idx]


func _controller_for_system(system_id: StringName) -> StringName:
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return &""
	if String(system.held_by).is_empty() or system.held_by == StarSystem.HELD_BY_NOBODY:
		# Fall back to first controlled station in system.
		return _first_station_controller(system_id)
	return system.held_by


func _first_station_controller(system_id: StringName) -> StringName:
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return &""
	for sid: StringName in system.station_ids:
		if not ContentLibrary.has_item(sid):
			continue
		var item: ContentItem = ContentLibrary.item(sid)
		if item is Station:
			var st: Station = item as Station
			if st.controller_entity_id != Station.CONTROLLER_NOBODY:
				return st.controller_entity_id
	return &""


func _first_station_in_system(system_id: StringName) -> StringName:
	var system: StarSystem = _load_system(system_id)
	if system == null or system.station_ids.is_empty():
		return &""
	return system.station_ids[0]


func _load_system(system_id: StringName) -> StarSystem:
	if not ContentLibrary.has_item(system_id):
		return null
	var item: ContentItem = ContentLibrary.item(system_id)
	if item is StarSystem:
		return item as StarSystem
	return null


func _content_name(id: StringName) -> String:
	if String(id).is_empty() or not ContentLibrary.has_item(id):
		return ""
	var item: ContentItem = ContentLibrary.item(id)
	if item != null and not item.display_name.is_empty():
		return item.display_name
	return String(id)


func _mission_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"mission_service")


func _cargo_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"cargo_service")


func _wallet() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"wallet_service")


func _pay_wallet(amount: int) -> void:
	if amount <= 0:
		return
	var wallet: Node = _wallet()
	if wallet == null:
		return
	if wallet.has_method(&"add_credits"):
		wallet.call(&"add_credits", amount)


## Take up to `amount` from the wallet. Returns credits actually removed
## (0 when broke / no wallet / non-positive amount). Uses add_credits so a
## partial balance is taken rather than try_spend's all-or-nothing refuse.
func _charge_wallet(amount: int) -> int:
	var charged: int = 0
	if amount <= 0:
		return charged
	var wallet: Node = _wallet()
	if wallet == null:
		return charged
	if wallet.has_method(&"add_credits"):
		var applied: Variant = wallet.call(&"add_credits", -amount)
		var delta: int = _variant_to_int(applied)
		# add_credits returns the applied delta (negative when spending).
		if delta < 0:
			charged = -delta
	elif wallet.has_method(&"try_spend") and wallet.call(&"try_spend", amount) == true:
		charged = amount
	return charged


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _dict_int(data: Dictionary, key: StringName, default_value: int) -> int:
	if not data.has(key):
		return default_value
	return _variant_to_int(data[key])
