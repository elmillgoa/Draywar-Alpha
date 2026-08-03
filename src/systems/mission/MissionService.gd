class_name MissionService
extends Node

## One active mission max; outcomes move Entity standing — Alpha A3 / E1.3 / E3.4 / S3a.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A3, docs/BETA_E1_LEGIBLE_SECTOR.md E1.3
## E3.4 smuggle: docs/BETA_E3_ECONOMY.md. S3a radiant/escort: STEAM_PHASE_PLAN S3a.
## Law: docs/reputation_and_standing.md §7
##
## Not a standing writer. Completes/fails/abandons call StandingService.
## Child of Main (not an autoload). Optional save section `mission` (B2).
## Delivery: turn in at destination. Bounty: kill in target system, then turn in.
## Smuggle: accept loads cargo; complete needs dest + cargo still held; abandon
## leaves cargo. Escort: freighter survives until dest turn-in (S3a).
## Accept works for ContentLibrary template ids **and** BoardService runtime
## offer ids (radiant/hand board rows). One active mission preserved.
## Console: `mission list|accept|complete|fail|abandon|status`.

const MISSION: StringName = &"mission"
const ACTION_LIST: String = "list"
const ACTION_ACCEPT: String = "accept"
const ACTION_COMPLETE: String = "complete"
const ACTION_FAIL: String = "fail"
const ACTION_ABANDON: String = "abandon"
const ACTION_STATUS: String = "status"

const STATE_NONE: StringName = &"none"
const STATE_ACTIVE: StringName = &"active"

const OUTCOME_COMPLETED: StringName = &"completed"
const OUTCOME_FAILED: StringName = &"failed"
const OUTCOME_ABANDONED: StringName = &"abandoned"

var _active_template_id: StringName = &""
var _state: StringName = STATE_NONE
## Bounty kill progress toward BalanceStanding.BOUNTY_KILLS_REQUIRED.
var _bounty_kills: int = 0
## Last station from on_docked — backup if group docking lookup fails mid-frame.
var _last_docked_station_id: StringName = &""
## Runtime/radiant snapshot when the active job is not a ContentLibrary id.
var _runtime_offer: Dictionary = {}
## Escort freighter still alive (only meaningful for escort kind).
var _escort_alive: bool = true


func _ready() -> void:
	add_to_group(&"mission_service")
	ServiceRegistry.register_resettable(reset)
	EventBus.on_mission_accept_requested.connect(_on_accept_requested)
	EventBus.on_mission_complete_requested.connect(_on_complete_requested)
	EventBus.on_mission_abandon_requested.connect(_on_abandon_requested)
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_undocked.connect(_on_undocked)
	EventBus.on_hostile_killed.connect(_on_hostile_killed)
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)


func _exit_tree() -> void:
	ServiceRegistry.unregister_resettable(reset)
	if EventBus.on_mission_accept_requested.is_connected(_on_accept_requested):
		EventBus.on_mission_accept_requested.disconnect(_on_accept_requested)
	if EventBus.on_mission_complete_requested.is_connected(_on_complete_requested):
		EventBus.on_mission_complete_requested.disconnect(_on_complete_requested)
	if EventBus.on_mission_abandon_requested.is_connected(_on_abandon_requested):
		EventBus.on_mission_abandon_requested.disconnect(_on_abandon_requested)
	if EventBus.on_docked.is_connected(_on_docked):
		EventBus.on_docked.disconnect(_on_docked)
	if EventBus.on_undocked.is_connected(_on_undocked):
		EventBus.on_undocked.disconnect(_on_undocked)
	if EventBus.on_hostile_killed.is_connected(_on_hostile_killed):
		EventBus.on_hostile_killed.disconnect(_on_hostile_killed)
	if EventBus.on_console_commands_requested.is_connected(_on_commands_requested):
		EventBus.on_console_commands_requested.disconnect(_on_commands_requested)
	if EventBus.on_console_command_invoked.is_connected(_on_command_invoked):
		EventBus.on_console_command_invoked.disconnect(_on_command_invoked)


func _on_docked(station_id: StringName) -> void:
	_last_docked_station_id = _normalize_id(station_id)


func _on_undocked(_station_id: StringName) -> void:
	_last_docked_station_id = &""


func _on_hostile_killed(system_id: StringName, _victim_entity_id: StringName) -> void:
	if not has_active():
		return
	if is_objective_ready():
		return
	var template: ContractType = _active_contract()
	if template == null or template.kind != BalanceStanding.MISSION_KIND_BOUNTY:
		return
	var target: StringName = _normalize_id(template.target_system_id)
	var here: StringName = _normalize_id(system_id)
	if String(target).is_empty() or target != here:
		return
	_bounty_kills += 1
	if _bounty_kills > BalanceStanding.BOUNTY_KILLS_REQUIRED:
		_bounty_kills = BalanceStanding.BOUNTY_KILLS_REQUIRED


## Whether a mission is currently active.
func has_active() -> bool:
	return _state == STATE_ACTIVE and not String(_active_template_id).is_empty()


## Active template / offer id, or empty.
func active_template_id() -> StringName:
	return _active_template_id


## True when the active job was accepted from a board runtime snapshot.
func is_runtime_mission() -> bool:
	return has_active() and not _runtime_offer.is_empty()


## Active contract kind (delivery, bounty, smuggle, escort), or empty.
func active_kind() -> StringName:
	if not has_active():
		return &""
	var template: ContractType = _active_contract()
	if template == null:
		return &""
	return template.kind


## Bounty target system for the active mission, or empty.
func active_target_system_id() -> StringName:
	if not has_active():
		return &""
	var template: ContractType = _active_contract()
	if template == null:
		return &""
	return _normalize_id(template.target_system_id)


## Smuggle cargo commodity for the active mission, or empty.
func active_cargo_commodity_id() -> StringName:
	if not has_active():
		return &""
	var template: ContractType = _active_contract()
	if template == null:
		return &""
	return _normalize_id(template.cargo_commodity_id)


## Plain-English label for HUD / sheet (runtime label or content display name).
func active_display_label() -> String:
	if not has_active():
		return ""
	if not _runtime_offer.is_empty():
		var label: String = str(_runtime_offer.get(BalanceBoard.OFFER_KEY_LABEL, ""))
		if not label.is_empty():
			return label
	if ContentLibrary.has_item(_active_template_id):
		var item: ContentItem = ContentLibrary.item(_active_template_id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(_active_template_id)


## True when the kill/objective gate is satisfied (delivery always true).
## Smuggle: cargo qty for the template commodity must still be in the hold.
## Escort: freighter still alive.
func is_objective_ready() -> bool:
	if not has_active():
		return false
	var template: ContractType = _active_contract()
	if template == null:
		return false
	if template.kind == BalanceStanding.MISSION_KIND_BOUNTY:
		return _bounty_kills >= BalanceStanding.BOUNTY_KILLS_REQUIRED
	if template.kind == BalanceStanding.MISSION_KIND_SMUGGLE:
		return _hold_has_smuggle_cargo(template)
	if template.kind == BalanceStanding.MISSION_KIND_ESCORT:
		return _escort_alive
	return true


## Escort freighter still counted alive (tests / world ensure).
func is_escort_alive() -> bool:
	if not has_active():
		return false
	if active_kind() != BalanceStanding.MISSION_KIND_ESCORT:
		return false
	return _escort_alive


## World / escort hull: freighter was destroyed → fail with standing delta.
func notify_escort_destroyed() -> void:
	if not has_active():
		return
	if active_kind() != BalanceStanding.MISSION_KIND_ESCORT:
		return
	if not _escort_alive:
		return
	_escort_alive = false
	fail()


## Clear active mission without standing change (tests / reset).
func reset() -> void:
	_active_template_id = &""
	_state = STATE_NONE
	_bounty_kills = 0
	_runtime_offer = {}
	_escort_alive = true


## Optional save section (schema v1). Empty when no active mission.
func to_section() -> Dictionary:
	if not has_active():
		return {}
	var section: Dictionary = {BalanceSession.MISSION_KEY_TEMPLATE_ID: String(_active_template_id)}
	if is_objective_ready() and active_kind() == BalanceStanding.MISSION_KIND_BOUNTY:
		section[BalanceSession.MISSION_KEY_OBJECTIVE_MET] = true
	if not _runtime_offer.is_empty():
		section[BalanceSession.MISSION_KEY_RUNTIME] = true
		_write_runtime_keys(section)
	if active_kind() == BalanceStanding.MISSION_KIND_ESCORT:
		section[BalanceSession.MISSION_KEY_ESCORT_ALIVE] = _escort_alive
	return section


## Restore mission from save. Emits on_mission_accepted so HUD refreshes.
## Does not re-load smuggle cargo (cargo section already restored the hold).
func apply_section(raw: Variant) -> void:
	reset()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	if not data.has(BalanceSession.MISSION_KEY_TEMPLATE_ID):
		return
	var template_id: StringName = StringName(str(data[BalanceSession.MISSION_KEY_TEMPLATE_ID]))
	if String(template_id).is_empty():
		return
	var is_runtime: bool = data.get(BalanceSession.MISSION_KEY_RUNTIME, false) == true
	if is_runtime:
		var offer: Dictionary = _offer_from_save(data, template_id)
		if not _accept_runtime(offer, false):
			return
	elif not _accept_internal(template_id, false):
		return
	if data.get(BalanceSession.MISSION_KEY_OBJECTIVE_MET, false) == true:
		_bounty_kills = BalanceStanding.BOUNTY_KILLS_REQUIRED
	if active_kind() == BalanceStanding.MISSION_KIND_ESCORT:
		_escort_alive = data.get(BalanceSession.MISSION_KEY_ESCORT_ALIVE, true) == true


## Every loaded contract template id (sorted by ContentLibrary).
func list_template_ids() -> Array[StringName]:
	return ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY)


## Accept a template id or board offer id. Fails if one is already active,
## id unknown, or (smuggle) free volume cannot hold the cargo load.
func accept(template_id: StringName) -> bool:
	return _accept_internal(template_id, true)


func _accept_internal(template_id: StringName, load_smuggle_cargo: bool) -> bool:
	if has_active():
		return false
	# ContentLibrary path (legacy hand jobs + console by content id).
	var template: ContractType = _library_template(template_id)
	if template != null:
		return _accept_contract(template_id, template, {}, load_smuggle_cargo)
	# Board runtime offer path (hand board rows + radiant).
	var offer: Dictionary = BoardService.get_offer(template_id)
	if offer.is_empty():
		return false
	if not _accept_runtime(offer, load_smuggle_cargo):
		return false
	BoardService.claim_offer(template_id)
	return true


## Accept a runtime offer snapshot without BoardService.claim_offer.
## Used by board accept (after claim), incident promote, and tests.
func accept_runtime_offer(offer: Dictionary, load_smuggle_cargo: bool = true) -> bool:
	return _accept_runtime(offer, load_smuggle_cargo)


func _accept_runtime(offer: Dictionary, load_smuggle_cargo: bool) -> bool:
	if has_active() or offer.is_empty():
		return false
	var contract: ContractType = MissionOffer.contract_from_offer(offer)
	if contract == null:
		return false
	var offer_id: StringName = _normalize_id(offer.get(BalanceBoard.OFFER_KEY_ID, &""))
	if String(offer_id).is_empty():
		return false
	return _accept_contract(offer_id, contract, offer.duplicate(true), load_smuggle_cargo)


func _accept_contract(
	offer_id: StringName,
	template: ContractType,
	runtime_snapshot: Dictionary,
	load_smuggle_cargo: bool
) -> bool:
	if template == null:
		return false
	if (
		load_smuggle_cargo
		and template.kind == BalanceStanding.MISSION_KIND_SMUGGLE
		and not _try_load_smuggle_cargo(template)
	):
		return false
	_active_template_id = offer_id
	_state = STATE_ACTIVE
	_bounty_kills = 0
	_runtime_offer = runtime_snapshot
	_escort_alive = true
	EventBus.on_mission_accepted.emit(offer_id, template.offering_entity_id)
	return true


## True when the active mission can be turned in at this station.
func can_complete_at_station(station_id: StringName) -> bool:
	if not has_active():
		return false
	if not is_objective_ready():
		return false
	var template: ContractType = _active_contract()
	if template == null:
		return false
	var dest: StringName = _normalize_id(template.destination_station_id)
	var here: StringName = _normalize_id(station_id)
	if String(dest).is_empty():
		return not String(here).is_empty()
	return dest == here


## Destination station for the active mission, or empty.
func active_destination_station_id() -> StringName:
	if not has_active():
		return &""
	var template: ContractType = _active_contract()
	if template == null:
		return &""
	return _normalize_id(template.destination_station_id)


## Complete at a known station (station menu path — no silent fail on dock lookup).
func try_complete_at(station_id: StringName) -> Dictionary:
	var empty: Dictionary = {
		BalanceStanding.REPORT_KEY_ATTRIBUTED: false,
		BalanceStanding.REPORT_KEY_ENTITY_ID: &"",
		BalanceStanding.REPORT_KEY_DELTA: 0.0,
		BalanceStanding.REPORT_KEY_REASON: &"",
		&"pay_credits": 0,
	}
	if not has_active():
		return empty
	if not can_complete_at_station(station_id):
		return empty
	return complete()


## Complete the active mission → positive standing + credits with offering Entity.
func complete() -> Dictionary:
	if has_active() and not is_objective_ready():
		return {
			BalanceStanding.REPORT_KEY_ATTRIBUTED: false,
			BalanceStanding.REPORT_KEY_ENTITY_ID: &"",
			BalanceStanding.REPORT_KEY_DELTA: 0.0,
			BalanceStanding.REPORT_KEY_REASON: &"",
			&"pay_credits": 0,
		}
	return _finish(true, false)


static func _normalize_id(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return StringName(String(as_name).strip_edges())
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text.strip_edges())
	return StringName(str(value).strip_edges())


## Fail after a genuine attempt → milder negative.
func fail() -> Dictionary:
	return _finish(false, false)


## Abandon → stronger negative than fail.
func abandon() -> Dictionary:
	return _finish(false, true)


func _on_accept_requested(template_id: StringName) -> void:
	accept(template_id)


func _on_complete_requested() -> void:
	if not has_active():
		return
	var docked: StringName = _docked_station_id()
	if not can_complete_at_station(docked):
		return
	complete()


func _docked_station_id() -> StringName:
	var tree: SceneTree = get_tree()
	if tree != null:
		var dock_node: Node = tree.get_first_node_in_group(&"docking_service")
		if dock_node != null and dock_node.has_method(&"docked_station_id"):
			var station_raw: Variant = dock_node.call(&"docked_station_id")
			var from_service: StringName = _normalize_id(station_raw)
			if not String(from_service).is_empty():
				return from_service
	return _last_docked_station_id


func _on_abandon_requested() -> void:
	if not has_active():
		return
	abandon()


func _finish(succeeded: bool, abandoned: bool) -> Dictionary:
	var empty: Dictionary = {
		BalanceStanding.REPORT_KEY_ATTRIBUTED: false,
		BalanceStanding.REPORT_KEY_ENTITY_ID: &"",
		BalanceStanding.REPORT_KEY_DELTA: 0.0,
		BalanceStanding.REPORT_KEY_REASON: &"",
	}
	if not has_active():
		return empty

	var template_id: StringName = _active_template_id
	var template: ContractType = _active_contract()
	if template == null:
		reset()
		return empty

	var entity_id: StringName = template.offering_entity_id
	var raw_delta: float = template.standing_complete
	var reason: StringName = BalanceStanding.REASON_MISSION_COMPLETE
	var outcome: StringName = OUTCOME_COMPLETED

	if abandoned:
		raw_delta = template.standing_abandon
		reason = BalanceStanding.REASON_MISSION_ABANDON
		outcome = OUTCOME_ABANDONED
	elif not succeeded:
		raw_delta = template.standing_fail
		reason = BalanceStanding.REASON_MISSION_FAIL
		outcome = OUTCOME_FAILED

	if succeeded and not abandoned and template.kind == BalanceStanding.MISSION_KIND_SMUGGLE:
		if not _remove_smuggle_cargo(template):
			return empty

	var applied: float = StandingService.apply_entity_delta(entity_id, raw_delta, reason, true)
	var pay: int = 0
	if succeeded and not abandoned:
		var gross: int = maxi(0, template.pay_credits)
		pay = _pay_credits(gross)

	if abandoned:
		EventBus.on_mission_abandoned.emit(template_id, entity_id, applied)
	elif succeeded:
		EventBus.on_mission_completed.emit(template_id, entity_id, applied)
	else:
		EventBus.on_mission_failed.emit(template_id, entity_id, applied)

	reset()
	return {
		BalanceStanding.REPORT_KEY_ATTRIBUTED: true,
		BalanceStanding.REPORT_KEY_ENTITY_ID: entity_id,
		BalanceStanding.REPORT_KEY_DELTA: applied,
		BalanceStanding.REPORT_KEY_REASON: reason,
		&"template_id": template_id,
		&"outcome": outcome,
		&"pay_credits": pay,
	}


func _pay_credits(amount: int) -> int:
	var net: int = 0
	if amount <= 0:
		return net
	var tree: SceneTree = get_tree()
	if tree == null:
		return net
	var wallet: Node = tree.get_first_node_in_group(&"wallet_service")
	if wallet == null:
		return net
	if wallet.has_method(&"apply_job_pay_with_garnish"):
		var net_raw: Variant = wallet.call(&"apply_job_pay_with_garnish", amount)
		net = _variant_to_int(net_raw)
	elif wallet.has_method(&"add_credits"):
		wallet.call(&"add_credits", amount)
		net = amount
	return net


func _variant_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0


func _library_template(template_id: StringName) -> ContractType:
	if not ContentLibrary.has_item(template_id):
		return null
	var item: ContentItem = ContentLibrary.item(template_id)
	if item is ContractType:
		return item as ContractType
	return null


## Active contract from ContentLibrary or the runtime snapshot.
func _active_contract() -> ContractType:
	if not has_active():
		return null
	if not _runtime_offer.is_empty():
		return MissionOffer.contract_from_offer(_runtime_offer)
	return _library_template(_active_template_id)


func _write_runtime_keys(section: Dictionary) -> void:
	var offer: Dictionary = _runtime_offer
	section[BalanceSession.MISSION_KEY_KIND] = str(offer.get(BalanceBoard.OFFER_KEY_KIND, ""))
	section[BalanceSession.MISSION_KEY_OFFERING_ENTITY_ID] = str(
		offer.get(BalanceBoard.OFFER_KEY_OFFERING_ENTITY, "")
	)
	section[BalanceSession.MISSION_KEY_PAY_CREDITS] = _dict_int(
		offer, BalanceBoard.OFFER_KEY_PAY, 0
	)
	section[BalanceSession.MISSION_KEY_STANDING_COMPLETE] = _dict_float(
		offer, BalanceBoard.OFFER_KEY_STANDING_COMPLETE, BalanceStanding.MISSION_COMPLETE_DELTA
	)
	section[BalanceSession.MISSION_KEY_STANDING_FAIL] = _dict_float(
		offer, BalanceBoard.OFFER_KEY_STANDING_FAIL, BalanceStanding.MISSION_FAIL_DELTA
	)
	section[BalanceSession.MISSION_KEY_STANDING_ABANDON] = _dict_float(
		offer, BalanceBoard.OFFER_KEY_STANDING_ABANDON, BalanceStanding.MISSION_ABANDON_DELTA
	)
	section[BalanceSession.MISSION_KEY_DESTINATION_STATION_ID] = str(
		offer.get(BalanceBoard.OFFER_KEY_DESTINATION, "")
	)
	section[BalanceSession.MISSION_KEY_TARGET_SYSTEM_ID] = str(
		offer.get(BalanceBoard.OFFER_KEY_TARGET_SYSTEM, "")
	)
	section[BalanceSession.MISSION_KEY_CARGO_COMMODITY_ID] = str(
		offer.get(BalanceBoard.OFFER_KEY_CARGO_COMMODITY, "")
	)
	section[BalanceSession.MISSION_KEY_CARGO_QUANTITY] = _dict_int(
		offer, BalanceBoard.OFFER_KEY_CARGO_QUANTITY, 0
	)
	section[BalanceSession.MISSION_KEY_LABEL] = str(offer.get(BalanceBoard.OFFER_KEY_LABEL, ""))


func _offer_from_save(data: Dictionary, template_id: StringName) -> Dictionary:
	return {
		BalanceBoard.OFFER_KEY_ID: template_id,
		BalanceBoard.OFFER_KEY_KIND: StringName(str(data.get(BalanceSession.MISSION_KEY_KIND, ""))),
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY:
		StringName(str(data.get(BalanceSession.MISSION_KEY_OFFERING_ENTITY_ID, ""))),
		BalanceBoard.OFFER_KEY_PAY: _dict_int(data, BalanceSession.MISSION_KEY_PAY_CREDITS, 0),
		BalanceBoard.OFFER_KEY_STANDING_COMPLETE:
		_dict_float(
			data,
			BalanceSession.MISSION_KEY_STANDING_COMPLETE,
			BalanceStanding.MISSION_COMPLETE_DELTA
		),
		BalanceBoard.OFFER_KEY_STANDING_FAIL:
		_dict_float(
			data, BalanceSession.MISSION_KEY_STANDING_FAIL, BalanceStanding.MISSION_FAIL_DELTA
		),
		BalanceBoard.OFFER_KEY_STANDING_ABANDON:
		_dict_float(
			data, BalanceSession.MISSION_KEY_STANDING_ABANDON, BalanceStanding.MISSION_ABANDON_DELTA
		),
		BalanceBoard.OFFER_KEY_DESTINATION:
		StringName(str(data.get(BalanceSession.MISSION_KEY_DESTINATION_STATION_ID, ""))),
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM:
		StringName(str(data.get(BalanceSession.MISSION_KEY_TARGET_SYSTEM_ID, ""))),
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY:
		StringName(str(data.get(BalanceSession.MISSION_KEY_CARGO_COMMODITY_ID, ""))),
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY:
		_dict_int(data, BalanceSession.MISSION_KEY_CARGO_QUANTITY, 0),
		BalanceBoard.OFFER_KEY_LABEL: str(data.get(BalanceSession.MISSION_KEY_LABEL, "")),
		BalanceBoard.OFFER_KEY_SOURCE: BalanceBoard.OFFER_SOURCE_RADIANT,
	}


func _dict_int(data: Dictionary, key: StringName, default_value: int) -> int:
	if not data.has(key):
		return default_value
	var raw: Variant = data[key]
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return int(as_float)
	return default_value


func _dict_float(data: Dictionary, key: StringName, default_value: float) -> float:
	if not data.has(key):
		return default_value
	var raw: Variant = data[key]
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return as_float
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return float(as_int)
	return default_value


func _cargo_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"cargo_service")


func _hold_has_smuggle_cargo(template: ContractType) -> bool:
	if template == null:
		return false
	var commodity_id: StringName = _normalize_id(template.cargo_commodity_id)
	var qty: int = maxi(0, template.cargo_quantity)
	if String(commodity_id).is_empty() or qty <= 0:
		return false
	var cargo: Node = _cargo_service()
	if cargo == null or not cargo.has_method(&"quantity"):
		return false
	var have: int = _variant_to_int(cargo.call(&"quantity", commodity_id))
	return have >= qty


func _try_load_smuggle_cargo(template: ContractType) -> bool:
	if template == null:
		return false
	var commodity_id: StringName = _normalize_id(template.cargo_commodity_id)
	var qty: int = maxi(0, template.cargo_quantity)
	if String(commodity_id).is_empty() or qty <= 0:
		return false
	var cargo: Node = _cargo_service()
	if cargo == null:
		return false
	if not cargo.has_method(&"can_add") or not cargo.has_method(&"add"):
		return false
	if cargo.call(&"can_add", commodity_id, qty) != true:
		return false
	return cargo.call(&"add", commodity_id, qty) == true


func _remove_smuggle_cargo(template: ContractType) -> bool:
	if template == null:
		return false
	var commodity_id: StringName = _normalize_id(template.cargo_commodity_id)
	var qty: int = maxi(0, template.cargo_quantity)
	if String(commodity_id).is_empty() or qty <= 0:
		return false
	var cargo: Node = _cargo_service()
	if cargo == null or not cargo.has_method(&"remove"):
		return false
	return cargo.call(&"remove", commodity_id, qty) == true


# --- Console -----------------------------------------------------------------


static func usage() -> String:
	return (
		"%s <%s|%s|%s|%s|%s|%s> [id]"
		% [
			String(MISSION),
			ACTION_LIST,
			ACTION_ACCEPT,
			ACTION_COMPLETE,
			ACTION_FAIL,
			ACTION_ABANDON,
			ACTION_STATUS,
		]
	)


func _on_commands_requested() -> void:
	EventBus.on_console_command_registered.emit(
		MISSION, usage(), "List, accept, or resolve missions (standing outcomes)."
	)


func _on_command_invoked(name_of_command: StringName, args: PackedStringArray) -> void:
	if name_of_command != MISSION:
		return
	_run(args)


func _run(args: PackedStringArray) -> void:
	if args.is_empty():
		_say("Usage: %s" % usage())
		return

	var head: String = args[0].to_lower()
	match head:
		ACTION_LIST:
			_run_list()
		ACTION_STATUS:
			_run_status()
		ACTION_ACCEPT:
			_run_accept(args)
		ACTION_COMPLETE:
			_run_outcome(StringName(ACTION_COMPLETE))
		ACTION_FAIL:
			_run_outcome(StringName(ACTION_FAIL))
		ACTION_ABANDON:
			_run_outcome(StringName(ACTION_ABANDON))
		_:
			_say("'%s' is not a mission action. Usage: %s" % [args[0], usage()])


func _run_list() -> void:
	var docked: StringName = _docked_station_id()
	if not String(docked).is_empty():
		var board_ids: Array[StringName] = BoardService.offer_ids_for_station(docked)
		if not board_ids.is_empty():
			_say("Board at %s:" % docked)
			for oid: StringName in board_ids:
				var offer: Dictionary = BoardService.get_offer(oid)
				var label: String = str(offer.get(BalanceBoard.OFFER_KEY_LABEL, String(oid)))
				var kind: String = str(offer.get(BalanceBoard.OFFER_KEY_KIND, ""))
				_say("  %s  [%s]  %s" % [oid, kind, label])
			return
	var ids: Array[StringName] = list_template_ids()
	if ids.is_empty():
		_say("No mission templates loaded.")
		return
	_say("Missions:")
	for id: StringName in ids:
		var item: ContentItem = ContentLibrary.item(id)
		var label: String = String(id)
		var offerer: String = ""
		if item != null:
			label = item.display_name
			if item is ContractType:
				var ct: ContractType = item as ContractType
				offerer = String(ct.offering_entity_id)
		_say("  %s  %s  (offered by %s)" % [id, label, offerer])


func _run_status() -> void:
	if not has_active():
		_say("No active mission.")
		return
	var kind: StringName = active_kind()
	if kind == BalanceStanding.MISSION_KIND_BOUNTY:
		var phase: String = "ready" if is_objective_ready() else "hunt"
		_say(
			(
				"Active mission: %s (bounty %s, target %s)"
				% [active_template_id(), phase, active_target_system_id()]
			)
		)
		return
	if kind == BalanceStanding.MISSION_KIND_SMUGGLE:
		var cargo_state: String = "cargo ok" if is_objective_ready() else "cargo missing"
		_say(
			(
				"Active mission: %s (smuggle %s → %s)"
				% [active_template_id(), cargo_state, active_destination_station_id()]
			)
		)
		return
	if kind == BalanceStanding.MISSION_KIND_ESCORT:
		var escort_state: String = "alive" if _escort_alive else "lost"
		_say(
			(
				"Active mission: %s (escort freighter %s → %s)"
				% [active_template_id(), escort_state, active_destination_station_id()]
			)
		)
		return
	_say("Active mission: %s" % active_template_id())


func _run_accept(args: PackedStringArray) -> void:
	if args.size() != BalanceStanding.CONSOLE_MISSION_ACCEPT_ARGS:
		_say("Usage: mission accept <id>")
		return
	var template_id: StringName = StringName(args[BalanceStanding.CONSOLE_MISSION_ID_INDEX])
	if has_active():
		_say("Already on mission %s. Complete, fail, or abandon first." % active_template_id())
		return
	if not accept(template_id):
		_say("Cannot accept '%s' (unknown or invalid)." % template_id)
		return
	var label: String = active_display_label()
	_say(BalanceStanding.CONSOLE_MISSION_ACCEPTED_FORMAT % [template_id, label])


func _run_outcome(outcome: StringName) -> void:
	if not has_active():
		_say("No active mission.")
		return
	var template_id: StringName = active_template_id()
	var result: Dictionary = {}
	if outcome == StringName(ACTION_COMPLETE):
		result = complete()
	elif outcome == StringName(ACTION_FAIL):
		result = fail()
	else:
		result = abandon()

	var attributed: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	if not attributed:
		_say("Mission outcome failed.")
		return
	var entity_id: StringName = result[BalanceStanding.REPORT_KEY_ENTITY_ID]
	var delta: float = result[BalanceStanding.REPORT_KEY_DELTA]
	var standing: float = StandingService.get_entity_standing(entity_id)
	_say(
		(
			BalanceStanding.CONSOLE_MISSION_OUTCOME_FORMAT
			% [template_id, outcome, entity_id, standing, delta]
		)
	)


static func _say(line: String) -> void:
	EventBus.on_console_output.emit(line)
