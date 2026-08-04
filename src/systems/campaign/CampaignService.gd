class_name CampaignService
extends Node

## Campaign acts, flags, spine offers, and Holding path — Steam S7–S8.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S7–S8
##
## Child of Main (not an autoload). Spine beats are ContractType rows with
## is_spine; they use MissionService (one active mission). Standing writes only
## via StandingService (Holding claim override + owner standing).

var _act: int = BalanceCampaign.ACT_I
## flag name string → true
var _flags: Dictionary = {}
## completed spine template id string → true
var _completed: Dictionary = {}
## Holding progress (S8): station_id, claimed, ignited, price_paid, prior_controller.
var _holding: Dictionary = {}


func _ready() -> void:
	add_to_group(BalanceCampaign.GROUP_CAMPAIGN_SERVICE)
	ServiceRegistry.register_resettable(reset)
	EventBus.on_mission_completed.connect(_on_mission_completed)
	EventBus.on_spine_accept_requested.connect(_on_spine_accept_requested)
	EventBus.on_holding_purchase_requested.connect(_on_holding_purchase_requested)


func _exit_tree() -> void:
	ServiceRegistry.unregister_resettable(reset)
	_disconnect(EventBus.on_mission_completed, _on_mission_completed)
	_disconnect(EventBus.on_spine_accept_requested, _on_spine_accept_requested)
	_disconnect(EventBus.on_holding_purchase_requested, _on_holding_purchase_requested)


func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_spine_accept_requested(template_id: StringName) -> void:
	try_accept_spine(template_id)


func _on_holding_purchase_requested(station_id: StringName) -> void:
	try_purchase_holding(station_id)


func _on_mission_completed(template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_handle_spine_complete(template_id)


# --- Public API -------------------------------------------------------------


## New career / missing save: Act I, clear flags/completed, empty holding.
func reset() -> void:
	_clear_holding_controller_override()
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
	# Re-apply Holding controller override after load.
	if is_holding_claimed():
		var station_id: StringName = claimed_station_id()
		if not String(station_id).is_empty():
			StandingService.set_station_controller_override(
				station_id, BalanceHolding.ENTITY_PLAYER_HOLDING
			)


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


# --- Holding (S8) -----------------------------------------------------------


## Copy of Holding progress dict (may be empty).
func holding_state() -> Dictionary:
	return _holding.duplicate(true)


func is_candidate_station(station_id: StringName) -> bool:
	return BalanceHolding.is_candidate_station(station_id)


## How many Holding milestone flags are set (0–5).
func milestone_count() -> int:
	var count: int = 0
	for flag: StringName in BalanceHolding.MILESTONE_FLAGS:
		if has_flag(flag):
			count += 1
	return count


func effective_holding_price() -> int:
	return BalanceHolding.price_for_milestone_count(milestone_count())


## Debt clear + all milestones + candidate + not claimed + can afford + docked there.
func can_purchase_holding(station_id: StringName) -> bool:
	var gates_ok: bool = (
		is_candidate_station(station_id)
		and not is_holding_claimed()
		and _debt_is_clear()
		and milestone_count() >= BalanceHolding.MILESTONE_COUNT
		and _docked_station_id() == station_id
	)
	if not gates_ok:
		return false
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"can_afford"):
		return false
	return wallet.call(&"can_afford", effective_holding_price()) == true


## Spend, claim Holding, set flag, controller override, owner standing, bus.
func try_purchase_holding(station_id: StringName) -> bool:
	if not can_purchase_holding(station_id):
		return false
	var price: int = effective_holding_price()
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"try_spend"):
		return false
	if wallet.call(&"try_spend", price) != true:
		return false
	_emit_money(BalanceHolding.REASON_HOLDING_PURCHASE, -price, station_id)
	var prior: StringName = prior_controller_for(station_id)
	_holding = {
		BalanceHolding.KEY_STATION_ID: station_id,
		BalanceHolding.KEY_CLAIMED: true,
		BalanceHolding.KEY_IGNITED: false,
		BalanceHolding.KEY_PRICE_PAID: price,
		BalanceHolding.KEY_PRIOR_CONTROLLER: prior,
	}
	_set_flag_internal(BalanceCampaign.FLAG_HOLDING_CLAIMED, true)
	StandingService.set_station_controller_override(
		station_id, BalanceHolding.ENTITY_PLAYER_HOLDING
	)
	StandingService.set_entity_standing(
		BalanceHolding.ENTITY_PLAYER_HOLDING, BalanceHolding.OWNER_STANDING
	)
	EventBus.on_holding_claimed.emit(station_id, price)
	return true


func is_holding_claimed() -> bool:
	if _holding.get(BalanceHolding.KEY_CLAIMED, false) == true:
		return true
	return has_flag(BalanceCampaign.FLAG_HOLDING_CLAIMED)


func is_holding_ignited() -> bool:
	return _holding.get(BalanceHolding.KEY_IGNITED, false) == true


func is_campaign_complete() -> bool:
	return has_flag(BalanceCampaign.FLAG_CAMPAIGN_COMPLETE) or is_holding_ignited()


func claimed_station_id() -> StringName:
	return _as_name(_holding.get(BalanceHolding.KEY_STATION_ID, &""))


## Empty until ignited; then peaceful/contested epitaph from standing vs prior.
func celebration_line() -> String:
	if not is_holding_ignited():
		return ""
	var station_id: StringName = claimed_station_id()
	var station_name: String = _content_display_name(station_id)
	var prior_id: StringName = _as_name(_holding.get(BalanceHolding.KEY_PRIOR_CONTROLLER, &""))
	var prior_name: String = _content_display_name(prior_id)
	if prior_name.is_empty():
		prior_name = "The prior holder"
	var prior_standing: float = StandingService.get_entity_standing(prior_id)
	if prior_standing >= BalanceHolding.EPITAPH_PEACEFUL_STANDING_MIN:
		return BalanceHolding.EPITAPH_PEACEFUL_FORMAT % [station_name, prior_name]
	return BalanceHolding.EPITAPH_CONTESTED_FORMAT % [station_name, prior_name]


## Content controller at claim time (Station.controller_entity_id).
func prior_controller_for(station_id: StringName) -> StringName:
	if not ContentLibrary.has_item(station_id):
		return Station.CONTROLLER_NOBODY
	var item: ContentItem = ContentLibrary.item(station_id)
	if item is Station:
		var station: Station = item as Station
		return station.controller_entity_id
	return Station.CONTROLLER_NOBODY


# --- Spine offers -----------------------------------------------------------


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
	_maybe_ignite_holding()


func _maybe_ignite_holding() -> void:
	if not has_flag(BalanceCampaign.FLAG_CAMPAIGN_COMPLETE):
		return
	if is_holding_ignited():
		return
	if not is_holding_claimed():
		return
	_holding[BalanceHolding.KEY_IGNITED] = true
	var station_id: StringName = claimed_station_id()
	EventBus.on_holding_ignited.emit(station_id)


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
		and _holding_station_ok(template)
		and _ignition_standoff_ok(template)
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
	var reason: String = BalanceCampaign.STATION_STORY_LOCKED_FORMAT % best.display_name
	if not _flags_ok(best):
		reason = BalanceCampaign.STATION_STORY_NEED_FLAGS
	elif not _lane_prerequisite_ok(best):
		reason = BalanceCampaign.STATION_STORY_NEED_LANE
	elif not _standing_ok(best):
		reason = BalanceCampaign.STATION_STORY_NEED_STANDING
	elif not _debt_ok(best):
		if best.requires_debt_clear:
			reason = BalanceCampaign.STATION_STORY_NEED_DEBT_CLEAR
		else:
			reason = BalanceCampaign.STATION_STORY_NEED_DEBT
	elif not _holding_station_ok(best):
		reason = BalanceCampaign.STATION_STORY_NEED_HOLDING_MATCH
	elif not _ignition_standoff_ok(best):
		reason = BalanceCampaign.STATION_STORY_NEED_STANDOFF
	elif _mission_busy():
		reason = BalanceCampaign.STATION_STORY_BUSY
	return reason


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


## requires_debt: need owed > 0. requires_debt_clear: need owed == 0.
func _debt_ok(template: ContractType) -> bool:
	if template.requires_debt_clear:
		return _debt_is_clear()
	if not template.requires_debt:
		return true
	var owed: int = _debt_owed()
	return owed > 0


## Ignition (and any debt-clear beat at a candidate): claimed station must match offer.
func _holding_station_ok(template: ContractType) -> bool:
	if not template.requires_debt_clear:
		return true
	if not is_holding_claimed():
		return false
	return claimed_station_id() == template.offer_station_id


## Standings resolve the standoff: papers if prior Neutral+, force if contested + backing.
func _ignition_standoff_ok(template: ContractType) -> bool:
	var template_id: StringName = template.id
	if not BalanceHolding.is_ignition_spine(template_id):
		return true
	if not is_holding_claimed():
		return false
	var prior_id: StringName = _as_name(_holding.get(BalanceHolding.KEY_PRIOR_CONTROLLER, &""))
	var prior_standing: float = StandingService.get_entity_standing(prior_id)
	var papers_ok: bool = prior_standing >= BalanceHolding.STANDOFF_PAPERS_STANDING_MIN
	if BalanceHolding.is_papers_ignition(template_id):
		return papers_ok
	if BalanceHolding.is_force_ignition(template_id):
		if papers_ok:
			return false
		return _has_standoff_backing()
	return true


func _has_standoff_backing() -> bool:
	for entity_id: StringName in BalanceHolding.STANDOFF_BACKING_ENTITY_IDS:
		var standing: float = StandingService.get_entity_standing(entity_id)
		if standing >= BalanceHolding.STANDOFF_BACKING_STANDING_MIN:
			return true
	return false


func _debt_is_clear() -> bool:
	return _debt_owed() == 0


func _debt_owed() -> int:
	var wallet: Node = _wallet_service()
	if wallet == null or not wallet.has_method(&"debt_state"):
		return 0
	var state_raw: Variant = wallet.call(&"debt_state")
	if typeof(state_raw) != TYPE_DICTIONARY:
		return 0
	var state: Dictionary = state_raw
	return _as_int(state.get(&"owed", 0))


func _docked_station_id() -> StringName:
	var tree: SceneTree = get_tree()
	if tree == null:
		return &""
	var docking: Node = tree.get_first_node_in_group(&"docking_service")
	if docking == null or not docking.has_method(&"docked_station_id"):
		return &""
	return _as_name(docking.call(&"docked_station_id"))


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


func _clear_holding_controller_override() -> void:
	if is_holding_claimed():
		var station_id: StringName = claimed_station_id()
		if not String(station_id).is_empty():
			StandingService.clear_station_controller_override(station_id)
	else:
		# Defensive: clear all Holding-related overrides if state is messy.
		StandingService.clear_all_station_controller_overrides()


func _emit_money(reason: StringName, delta: int, station_id: StringName) -> void:
	if delta == 0:
		return
	var credits_after: int = 0
	var wallet: Node = _wallet_service()
	if wallet != null and wallet.has_method(&"credits"):
		credits_after = _as_int(wallet.call(&"credits"))
	var detail: Dictionary = {
		BalanceTelemetry.DETAIL_KEY_STATION_ID: station_id,
	}
	EventBus.on_money_event.emit(reason, delta, credits_after, detail)


func _content_display_name(id: StringName) -> String:
	if String(id).is_empty():
		return ""
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


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
