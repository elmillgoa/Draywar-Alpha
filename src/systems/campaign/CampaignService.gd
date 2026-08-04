class_name CampaignService
extends Node

## Campaign acts, flags, and spine offers — Steam S7.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S7
##
## Child of Main (not an autoload). Spine beats are ContractType rows with
## is_spine; they use MissionService (one active mission). Never writes standing.

var _act: int = BalanceCampaign.ACT_I
## flag name string → true
var _flags: Dictionary = {}
## completed spine template id string → true
var _completed: Dictionary = {}
## Holding stub for S8 (opaque dict).
var _holding: Dictionary = {}


func _ready() -> void:
	add_to_group(BalanceCampaign.GROUP_CAMPAIGN_SERVICE)
	ServiceRegistry.register_resettable(reset)
	EventBus.on_mission_completed.connect(_on_mission_completed)
	EventBus.on_spine_accept_requested.connect(_on_spine_accept_requested)


func _exit_tree() -> void:
	ServiceRegistry.unregister_resettable(reset)
	_disconnect(EventBus.on_mission_completed, _on_mission_completed)
	_disconnect(EventBus.on_spine_accept_requested, _on_spine_accept_requested)


func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_spine_accept_requested(template_id: StringName) -> void:
	try_accept_spine(template_id)


func _on_mission_completed(template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_handle_spine_complete(template_id)


# --- Public API -------------------------------------------------------------


## New career / missing save: Act I, clear flags/completed, empty holding.
func reset() -> void:
	_act = BalanceCampaign.ACT_I
	_flags.clear()
	_completed.clear()
	_holding.clear()
	_set_flag_internal(BalanceCampaign.FLAG_ACT1_STARTED, false)


## Optional `campaign` save section body.
func to_section() -> Dictionary:
	var flags_out: Dictionary = {}
	for key: Variant in _flags.keys():
		if _flags[key] == true:
			flags_out[str(key)] = true
	var completed_out: Array = []
	for key: Variant in _completed.keys():
		if _completed[key] == true:
			completed_out.append(str(key))
	completed_out.sort()
	return {
		BalanceCampaign.KEY_ACT: _act,
		BalanceCampaign.KEY_FLAGS: flags_out,
		BalanceCampaign.KEY_COMPLETED_SPINE: completed_out,
		BalanceCampaign.KEY_HOLDING: _holding.duplicate(true),
	}


## Restore from save. Missing / invalid → reset.
func apply_section(raw: Variant) -> void:
	reset()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	if data.has(BalanceCampaign.KEY_ACT):
		_act = _as_int(data[BalanceCampaign.KEY_ACT])
		if _act < BalanceCampaign.ACT_NONE:
			_act = BalanceCampaign.ACT_I
	if data.has(BalanceCampaign.KEY_FLAGS):
		_apply_flags(data[BalanceCampaign.KEY_FLAGS])
	if data.has(BalanceCampaign.KEY_COMPLETED_SPINE):
		_apply_completed(data[BalanceCampaign.KEY_COMPLETED_SPINE])
	if data.has(BalanceCampaign.KEY_HOLDING):
		var holding_raw: Variant = data[BalanceCampaign.KEY_HOLDING]
		if typeof(holding_raw) == TYPE_DICTIONARY:
			var holding: Dictionary = holding_raw
			_holding = holding.duplicate(true)
	# Guarantee Act I started flag when act is at least I.
	if _act >= BalanceCampaign.ACT_I and not has_flag(BalanceCampaign.FLAG_ACT1_STARTED):
		_flags[String(BalanceCampaign.FLAG_ACT1_STARTED)] = true


func current_act() -> int:
	return _act


func has_flag(flag_name: StringName) -> bool:
	var key: String = String(flag_name)
	if key.is_empty():
		return false
	return _flags.get(key, false) == true


func completed_spine_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _completed.keys():
		if _completed[key] == true:
			out.append(_as_name(key))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func is_spine_completed(template_id: StringName) -> bool:
	return _completed.get(String(template_id), false) == true


func get_flag_map() -> Dictionary:
	return _flags.duplicate(true)


## Spine template ids offered at this station that pass all gates.
func available_spine_ids_at(station_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if String(station_id).is_empty():
		return out
	for id: StringName in _all_spine_ids_sorted():
		if not _is_available_at(id, station_id):
			continue
		out.append(id)
	return out


## True when the player can accept this spine via try_accept_spine.
func can_accept_spine(template_id: StringName) -> bool:
	var template: ContractType = _spine_template(template_id)
	if template == null or is_spine_completed(template_id):
		return false
	if not _gates_pass(template):
		return false
	if String(template.offer_station_id).is_empty():
		return false
	return not _mission_busy()


## Accept spine into MissionService (library path). False if refuse.
func try_accept_spine(template_id: StringName) -> bool:
	if not can_accept_spine(template_id):
		return false
	var mission: Node = _mission_service()
	if mission == null or not mission.has_method(&"accept"):
		return false
	return mission.call(&"accept", template_id) == true


## Journal rows for UI: title, blurb, status open/done/locked.
func journal_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for id: StringName in _all_spine_ids_sorted():
		var template: ContractType = _spine_template(id)
		if template == null:
			continue
		var status: StringName = BalanceCampaign.JOURNAL_STATUS_LOCKED
		if is_spine_completed(id):
			status = BalanceCampaign.JOURNAL_STATUS_DONE
		elif _is_available_anywhere(id):
			status = BalanceCampaign.JOURNAL_STATUS_OPEN
		(
			lines
			. append(
				{
					BalanceCampaign.JOURNAL_KEY_ID: id,
					BalanceCampaign.JOURNAL_KEY_TITLE: template.display_name,
					BalanceCampaign.JOURNAL_KEY_BLURB: template.journal_blurb,
					BalanceCampaign.JOURNAL_KEY_STATUS: status,
					BalanceCampaign.JOURNAL_KEY_ACT: template.spine_act,
					BalanceCampaign.JOURNAL_KEY_SORT: template.sort_index,
				}
			)
		)
	return lines


## First open spine display name for captain sheet, or empty.
func next_open_spine_title() -> String:
	for id: StringName in _all_spine_ids_sorted():
		if is_spine_completed(id):
			continue
		if _is_available_anywhere(id):
			var template: ContractType = _spine_template(id)
			if template != null:
				return template.display_name
	return ""


## Locked reason for a nearly-next spine at a station (simple UI helper).
## Returns empty when nothing useful to show.
func locked_hint_at(station_id: StringName) -> String:
	if String(station_id).is_empty() or not available_spine_ids_at(station_id).is_empty():
		return ""
	var best: ContractType = _first_locked_candidate(station_id)
	if best == null:
		return ""
	return _locked_reason_for(best)


# --- Internals --------------------------------------------------------------


func _handle_spine_complete(template_id: StringName) -> void:
	var template: ContractType = _spine_template(template_id)
	if template == null:
		return
	if is_spine_completed(template_id):
		return
	_completed[String(template_id)] = true
	for flag: String in template.sets_flags:
		var flag_name: StringName = StringName(flag.strip_edges())
		if String(flag_name).is_empty():
			continue
		_set_flag_internal(flag_name, true)
	EventBus.on_spine_completed.emit(template_id)
	_maybe_advance_act()


func _maybe_advance_act() -> void:
	if has_flag(BalanceCampaign.FLAG_ACT2_DONE) and _act < BalanceCampaign.ACT_III:
		_set_act(BalanceCampaign.ACT_III)
	elif has_flag(BalanceCampaign.FLAG_ACT1_DONE) and _act < BalanceCampaign.ACT_II:
		_set_act(BalanceCampaign.ACT_II)


func _set_act(new_act: int) -> void:
	if new_act == _act:
		return
	_act = new_act
	EventBus.on_campaign_act_changed.emit(_act)


func _set_flag_internal(flag_name: StringName, emit_bus: bool) -> void:
	var key: String = String(flag_name)
	if key.is_empty():
		return
	if _flags.get(key, false) == true:
		return
	_flags[key] = true
	if emit_bus:
		EventBus.on_campaign_flag_set.emit(flag_name)


func _is_available_at(template_id: StringName, station_id: StringName) -> bool:
	var template: ContractType = _spine_template(template_id)
	if template == null or is_spine_completed(template_id):
		return false
	if template.offer_station_id != station_id:
		return false
	return _gates_pass(template)


func _gates_pass(template: ContractType) -> bool:
	return (
		_act_ok(template)
		and _flags_ok(template)
		and _lane_prerequisite_ok(template)
		and _standing_ok(template)
		and _debt_ok(template)
		and not _lane_blocked(template)
	)


func _mission_busy() -> bool:
	var mission: Node = _mission_service()
	return (
		mission != null
		and mission.has_method(&"has_active")
		and mission.call(&"has_active") == true
	)


func _first_locked_candidate(station_id: StringName) -> ContractType:
	for id: StringName in _all_spine_ids_sorted():
		var template: ContractType = _spine_template(id)
		if template == null or is_spine_completed(id):
			continue
		if template.offer_station_id != station_id:
			continue
		if not _act_ok(template) or _lane_blocked(template):
			continue
		return template
	return null


func _locked_reason_for(best: ContractType) -> String:
	if not _flags_ok(best):
		return BalanceCampaign.STATION_STORY_NEED_FLAGS
	if not _lane_prerequisite_ok(best):
		return BalanceCampaign.STATION_STORY_NEED_LANE
	if not _standing_ok(best):
		return BalanceCampaign.STATION_STORY_NEED_STANDING
	if not _debt_ok(best):
		return BalanceCampaign.STATION_STORY_NEED_DEBT
	if _mission_busy():
		return BalanceCampaign.STATION_STORY_BUSY
	return BalanceCampaign.STATION_STORY_LOCKED_FORMAT % best.display_name


func _is_available_anywhere(template_id: StringName) -> bool:
	var template: ContractType = _spine_template(template_id)
	if template == null:
		return false
	return _is_available_at(template_id, template.offer_station_id)


func _act_ok(template: ContractType) -> bool:
	# Available when the beat's act is at or before current career act.
	return template.spine_act > 0 and template.spine_act <= _act


func _flags_ok(template: ContractType) -> bool:
	for flag: String in template.requires_flags:
		var flag_name: StringName = StringName(flag.strip_edges())
		if String(flag_name).is_empty():
			continue
		if not has_flag(flag_name):
			return false
	return true


## Beats that set FLAG_OPS_INTRO need any lane flag first (Act II gate).
func _lane_prerequisite_ok(template: ContractType) -> bool:
	var needs_lane: bool = false
	for flag: String in template.sets_flags:
		if StringName(flag.strip_edges()) == BalanceCampaign.FLAG_OPS_INTRO:
			needs_lane = true
			break
	if not needs_lane:
		return true
	return _has_any_lane()


func _has_any_lane() -> bool:
	for lane: StringName in BalanceCampaign.LANE_FLAGS:
		if has_flag(lane):
			return true
	return false


func _standing_ok(template: ContractType) -> bool:
	if template.min_entity_standing <= BalanceCampaign.STANDING_NO_FLOOR:
		return true
	var standing: float = StandingService.get_entity_standing(template.offering_entity_id)
	return standing >= template.min_entity_standing


func _debt_ok(template: ContractType) -> bool:
	if not template.requires_debt:
		return true
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"debt_state"):
		return false
	var state_raw: Variant = wallet.call(&"debt_state")
	if typeof(state_raw) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = state_raw
	var owed: int = _as_int(state.get(&"owed", 0))
	return owed > 0


func _lane_blocked(template: ContractType) -> bool:
	if not BalanceCampaign.sets_flags_include_lane(template.sets_flags):
		return false
	var any_lane: bool = false
	for lane: StringName in BalanceCampaign.LANE_FLAGS:
		if has_flag(lane):
			any_lane = true
			break
	if not any_lane:
		return false
	# Hide this lane choice if it sets a lane flag the player does not already hold.
	for flag: String in template.sets_flags:
		var flag_name: StringName = StringName(flag.strip_edges())
		if not BalanceCampaign.is_lane_flag(flag_name):
			continue
		if not has_flag(flag_name):
			return true
	return false


func _all_spine_ids_sorted() -> Array[StringName]:
	var rows: Array[Dictionary] = []
	for id: StringName in ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY):
		var template: ContractType = _spine_template(id)
		if template == null:
			continue
		(
			rows
			. append(
				{
					&"id": id,
					&"act": template.spine_act,
					&"sort": template.sort_index,
					&"name": String(id),
				}
			)
		)
	rows.sort_custom(_spine_row_less)
	var out: Array[StringName] = []
	for row: Dictionary in rows:
		out.append(_as_name(row[&"id"]))
	return out


func _spine_row_less(a: Dictionary, b: Dictionary) -> bool:
	var act_a: int = _as_int(a.get(&"act", 0))
	var act_b: int = _as_int(b.get(&"act", 0))
	if act_a != act_b:
		return act_a < act_b
	var sort_a: int = _as_int(a.get(&"sort", 0))
	var sort_b: int = _as_int(b.get(&"sort", 0))
	if sort_a != sort_b:
		return sort_a < sort_b
	return str(a.get(&"name", "")) < str(b.get(&"name", ""))


func _spine_template(template_id: StringName) -> ContractType:
	if not ContentLibrary.has_item(template_id):
		return null
	var item: ContentItem = ContentLibrary.item(template_id)
	if item == null or not (item is ContractType):
		return null
	var template: ContractType = item as ContractType
	if not template.is_spine:
		return null
	return template


func _apply_flags(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	for key: Variant in data.keys():
		if data[key] == true:
			_flags[str(key)] = true


func _apply_completed(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var rows: Array = raw
	for entry: Variant in rows:
		var id_text: String = str(entry).strip_edges()
		if not id_text.is_empty():
			_completed[id_text] = true


func _mission_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"mission_service")


func _wallet_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"wallet_service")


func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return StringName(str(value))


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float_val: float = value
		return int(as_float_val)
	return 0
