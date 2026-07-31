class_name MissionService
extends Node

## One active mission max; outcomes move Entity standing — Alpha A3.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A3
## Law: docs/reputation_and_standing.md §7
##
## Not a standing writer. Completes/fails/abandons call StandingService.
## Child of Main (not an autoload). Session-only for A3 (no save section).
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


func _ready() -> void:
	add_to_group(&"mission_service")
	EventBus.on_mission_accept_requested.connect(_on_accept_requested)
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)


func _exit_tree() -> void:
	if EventBus.on_mission_accept_requested.is_connected(_on_accept_requested):
		EventBus.on_mission_accept_requested.disconnect(_on_accept_requested)
	if EventBus.on_console_commands_requested.is_connected(_on_commands_requested):
		EventBus.on_console_commands_requested.disconnect(_on_commands_requested)
	if EventBus.on_console_command_invoked.is_connected(_on_command_invoked):
		EventBus.on_console_command_invoked.disconnect(_on_command_invoked)


## Whether a mission is currently active.
func has_active() -> bool:
	return _state == STATE_ACTIVE and not String(_active_template_id).is_empty()


## Active template id, or empty.
func active_template_id() -> StringName:
	return _active_template_id


## Clear active mission without standing change (tests / reset).
func reset() -> void:
	_active_template_id = &""
	_state = STATE_NONE


## Every loaded contract template id (sorted by ContentLibrary).
func list_template_ids() -> Array[StringName]:
	return ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY)


## Accept a template. Fails if one is already active or id is unknown.
func accept(template_id: StringName) -> bool:
	if has_active():
		return false
	var template: ContractType = _template(template_id)
	if template == null:
		return false
	_active_template_id = template_id
	_state = STATE_ACTIVE
	EventBus.on_mission_accepted.emit(template_id, template.offering_entity_id)
	return true


## Complete the active mission → positive standing with offering Entity.
func complete() -> Dictionary:
	return _finish(true, false)


## Fail after a genuine attempt → milder negative.
func fail() -> Dictionary:
	return _finish(false, false)


## Abandon → stronger negative than fail.
func abandon() -> Dictionary:
	return _finish(false, true)


func _on_accept_requested(template_id: StringName) -> void:
	accept(template_id)


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
	var template: ContractType = _template(template_id)
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

	var applied: float = StandingService.apply_entity_delta(entity_id, raw_delta, reason, true)

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
	}


func _template(template_id: StringName) -> ContractType:
	if not ContentLibrary.has_item(template_id):
		return null
	var item: ContentItem = ContentLibrary.item(template_id)
	if item is ContractType:
		return item as ContractType
	return null


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
	var item: ContentItem = ContentLibrary.item(template_id)
	var label: String = item.display_name if item != null else String(template_id)
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
