class_name RecoveryService
extends Node

## Personal recovery chain runtime — Alpha A4.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A4
## Law: docs/reputation_and_standing.md §5–§6
##
## One active recovery step max. Completes/fails/abandons/betrays call
## StandingService (single writer). Child of Main (not an autoload).
## Progress (completed step ids per chain) persists via standing section key
## `recovery_progress` when save round-trips through this service.
##
## Console: `recovery status|accept|complete|fail|abandon|betray`, `favor <person>`.
##
## Alpha §5 bootstrap: first deniable step unlocks at Friendly personal only;
## follow-ons require prior chain success (and Friendly + not closed).

const RECOVERY: StringName = &"recovery"
const FAVOR: StringName = &"favor"
const ACTION_LIST: String = "list"
const ACTION_ACCEPT: String = "accept"
const ACTION_COMPLETE: String = "complete"
const ACTION_FAIL: String = "fail"
const ACTION_ABANDON: String = "abandon"
const ACTION_BETRAY: String = "betray"
const ACTION_STATUS: String = "status"

const STATE_NONE: StringName = &"none"
const STATE_ACTIVE: StringName = &"active"

const OUTCOME_COMPLETED: StringName = &"completed"
const OUTCOME_FAILED: StringName = &"failed"
const OUTCOME_ABANDONED: StringName = &"abandoned"
const OUTCOME_BETRAYED: StringName = &"betrayed"

## Report dictionary keys for outcomes.
const REPORT_KEY_OK: StringName = &"ok"
const REPORT_KEY_CHAIN_ID: StringName = &"chain_id"
const REPORT_KEY_STEP_ID: StringName = &"step_id"
const REPORT_KEY_PERSON_ID: StringName = &"person_id"
const REPORT_KEY_ENTITY_ID: StringName = &"entity_id"
const REPORT_KEY_PERSON_DELTA: StringName = &"person_delta"
const REPORT_KEY_ENTITY_DELTA: StringName = &"entity_delta"
const REPORT_KEY_OUTCOME: StringName = &"outcome"

var _active_chain_id: StringName = &""
var _active_step_id: StringName = &""
var _state: StringName = STATE_NONE
## chain_id → Array of completed step ids (StringName), in order.
var _completed_steps: Dictionary[StringName, Array] = {}


func _ready() -> void:
	add_to_group(&"recovery_service")
	ServiceRegistry.register_resettable(reset)
	EventBus.on_recovery_accept_requested.connect(_on_accept_requested)
	EventBus.on_recovery_complete_requested.connect(_on_complete_requested)
	EventBus.on_recovery_abandon_requested.connect(_on_abandon_requested)
	EventBus.on_recovery_favor_requested.connect(_on_favor_requested)
	EventBus.on_recovery_betray_requested.connect(_on_betray_requested)
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)


func _exit_tree() -> void:
	ServiceRegistry.unregister_resettable(reset)
	if EventBus.on_recovery_accept_requested.is_connected(_on_accept_requested):
		EventBus.on_recovery_accept_requested.disconnect(_on_accept_requested)
	if EventBus.on_recovery_complete_requested.is_connected(_on_complete_requested):
		EventBus.on_recovery_complete_requested.disconnect(_on_complete_requested)
	if EventBus.on_recovery_abandon_requested.is_connected(_on_abandon_requested):
		EventBus.on_recovery_abandon_requested.disconnect(_on_abandon_requested)
	if EventBus.on_recovery_favor_requested.is_connected(_on_favor_requested):
		EventBus.on_recovery_favor_requested.disconnect(_on_favor_requested)
	if EventBus.on_recovery_betray_requested.is_connected(_on_betray_requested):
		EventBus.on_recovery_betray_requested.disconnect(_on_betray_requested)
	if EventBus.on_docked.is_connected(_on_docked):
		EventBus.on_docked.disconnect(_on_docked)
	if EventBus.on_console_commands_requested.is_connected(_on_commands_requested):
		EventBus.on_console_commands_requested.disconnect(_on_commands_requested)
	if EventBus.on_console_command_invoked.is_connected(_on_command_invoked):
		EventBus.on_console_command_invoked.disconnect(_on_command_invoked)


## Whether a recovery step is currently active.
func has_active() -> bool:
	return _state == STATE_ACTIVE and not String(_active_chain_id).is_empty()


func active_chain_id() -> StringName:
	return _active_chain_id


func active_step_id() -> StringName:
	return _active_step_id


## Clear active step and chain progress (tests / reset). Does not clear standing.
func reset() -> void:
	_active_chain_id = &""
	_active_step_id = &""
	_state = STATE_NONE
	_completed_steps.clear()


## Clear only the active step without wiping chain progress.
func clear_active() -> void:
	_active_chain_id = &""
	_active_step_id = &""
	_state = STATE_NONE


## Every loaded recovery chain id (sorted).
func list_chain_ids() -> Array[StringName]:
	return ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY)


## Completed step ids for a chain (copy).
func completed_step_ids(chain_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if not _completed_steps.has(chain_id):
		return out
	var raw: Array = _completed_steps[chain_id]
	for entry: Variant in raw:
		out.append(StringName(str(entry)))
	return out


## Next offerable step for this Person, or empty dictionary when none.
## Keys: chain_id, step_id, step (RecoveryStep), chain (RecoveryChain).
func next_step_for_person(person_id: StringName) -> Dictionary:
	if not StandingService.can_offer_recovery(person_id):
		return {}
	var chain: RecoveryChain = _chain_for_person(person_id)
	if chain == null:
		return {}
	var next_step: RecoveryStep = _next_step(chain)
	if next_step == null:
		return {}
	return {
		&"chain_id": chain.id,
		&"step_id": next_step.id,
		&"step": next_step,
		&"chain": chain,
	}


## Whether this Person currently has an offerable recovery step.
func has_offer_for_person(person_id: StringName) -> bool:
	return not next_step_for_person(person_id).is_empty()


## Accept the next recovery step for this Person. Fails if busy / gated.
func accept(person_id: StringName) -> bool:
	if has_active():
		return false
	var offer: Dictionary = next_step_for_person(person_id)
	if offer.is_empty():
		return false
	var chain_id: StringName = offer[&"chain_id"]
	var step_id: StringName = offer[&"step_id"]
	_active_chain_id = chain_id
	_active_step_id = step_id
	_state = STATE_ACTIVE
	EventBus.on_recovery_accepted.emit(chain_id, step_id, person_id)
	return true


## Complete the active recovery step → personal + entity deltas, record success.
func complete() -> Dictionary:
	return _finish_success()


## Fail after an attempt → mild personal hit; no chain advance.
func fail() -> Dictionary:
	return _finish_soft(false)


## Abandon → stronger personal hit; no chain advance.
func abandon() -> Dictionary:
	return _finish_soft(true)


## Betray the active Person (or named Person) → close route + standing dump.
func betray(person_id: StringName = &"") -> Dictionary:
	var target: StringName = person_id
	if String(target).is_empty() and has_active():
		var chain: RecoveryChain = _chain(_active_chain_id)
		if chain != null:
			target = chain.person_id
	if String(target).is_empty():
		return _empty_report()
	if StandingService.is_person_closed(target):
		return _empty_report()

	var entity_id: StringName = &""
	var chain_for_person: RecoveryChain = _chain_for_person(target)
	if chain_for_person != null:
		entity_id = chain_for_person.entity_id
	elif ContentLibrary.has_item(target):
		var item: ContentItem = ContentLibrary.item(target)
		if item is Person:
			var person: Person = item as Person
			entity_id = person.primary_entity_id

	var person_delta: float = StandingService.apply_person_delta(
		target,
		BalanceStanding.RECOVERY_BETRAYAL_PERSONAL_DELTA,
		BalanceStanding.REASON_RECOVERY_BETRAYAL
	)
	var entity_delta: float = 0.0
	if not String(entity_id).is_empty():
		entity_delta = StandingService.apply_entity_delta(
			entity_id,
			BalanceStanding.RECOVERY_BETRAYAL_ENTITY_DELTA,
			BalanceStanding.REASON_RECOVERY_BETRAYAL,
			false
		)

	StandingService.close_person(target, BalanceStanding.RECOVERY_CLOSE_REASON_BETRAYAL)

	# S4: one-hop network betrayal — small personal hit only; do not close them.
	_apply_network_betrayal_hits(target)

	if has_active():
		var active_chain: RecoveryChain = _chain(_active_chain_id)
		if active_chain != null and active_chain.person_id == target:
			clear_active()

	EventBus.on_recovery_betrayed.emit(target, person_delta, entity_delta)

	return {
		REPORT_KEY_OK: true,
		REPORT_KEY_CHAIN_ID: chain_for_person.id if chain_for_person != null else &"",
		REPORT_KEY_STEP_ID: &"",
		REPORT_KEY_PERSON_ID: target,
		REPORT_KEY_ENTITY_ID: entity_id,
		REPORT_KEY_PERSON_DELTA: person_delta,
		REPORT_KEY_ENTITY_DELTA: entity_delta,
		REPORT_KEY_OUTCOME: OUTCOME_BETRAYED,
	}


## Small personal standing gift if the Person is not closed (console bootstrap).
func favor(person_id: StringName) -> Dictionary:
	if String(person_id).is_empty():
		return _empty_report()
	if StandingService.is_person_closed(person_id):
		return {
			REPORT_KEY_OK: false,
			REPORT_KEY_PERSON_ID: person_id,
			REPORT_KEY_PERSON_DELTA: 0.0,
			REPORT_KEY_OUTCOME: &"closed",
		}
	var applied: float = StandingService.apply_person_delta(
		person_id,
		BalanceStanding.RECOVERY_FAVOR_PERSONAL_DELTA,
		BalanceStanding.REASON_RECOVERY_FAVOR
	)
	return {
		REPORT_KEY_OK: true,
		REPORT_KEY_PERSON_ID: person_id,
		REPORT_KEY_PERSON_DELTA: applied,
		REPORT_KEY_OUTCOME: &"favor",
	}


## Progress map for save (chain_id → Array of step id strings).
func progress_to_section() -> Dictionary:
	var out: Dictionary = {}
	for chain_id: StringName in _completed_steps:
		var steps: Array = []
		var raw_list: Array = _completed_steps[chain_id]
		for entry: Variant in raw_list:
			steps.append(str(entry))
		out[chain_id] = steps
	return out


## Restore chain progress from save. Does not touch active step.
func apply_progress_section(raw: Variant) -> void:
	_completed_steps.clear()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var map: Dictionary = raw
	for key: Variant in map:
		var chain_id: StringName = StringName(str(key))
		var raw_steps: Variant = map[key]
		if typeof(raw_steps) != TYPE_ARRAY:
			continue
		var steps: Array = []
		for entry: Variant in raw_steps:
			steps.append(StringName(str(entry)))
		_completed_steps[chain_id] = steps


func _on_accept_requested(person_id: StringName) -> void:
	accept(person_id)


func _on_complete_requested() -> void:
	if has_active():
		complete()


func _on_abandon_requested() -> void:
	if has_active():
		abandon()


func _on_favor_requested(person_id: StringName) -> void:
	favor(person_id)


func _on_betray_requested(person_id: StringName) -> void:
	betray(person_id)


## On dock: announce offerable recovery steps for the station controller's people.
func _on_docked(station_id: StringName) -> void:
	if has_active():
		return
	if not ContentLibrary.has_item(station_id):
		return
	var station_item: ContentItem = ContentLibrary.item(station_id)
	if not (station_item is Station):
		return
	var station: Station = station_item as Station
	var controller: StringName = station.controller_entity_id
	if controller == Station.CONTROLLER_NOBODY or String(controller).is_empty():
		return
	for chain_id: StringName in list_chain_ids():
		var chain: RecoveryChain = _chain(chain_id)
		if chain == null or chain.entity_id != controller:
			continue
		var offer: Dictionary = next_step_for_person(chain.person_id)
		if offer.is_empty():
			continue
		EventBus.on_recovery_offered.emit(offer[&"chain_id"], offer[&"step_id"], chain.person_id)


func _finish_success() -> Dictionary:
	if not has_active():
		return _empty_report()
	var chain: RecoveryChain = _chain(_active_chain_id)
	var step: RecoveryStep = _step(chain, _active_step_id)
	if chain == null or step == null:
		clear_active()
		return _empty_report()

	# Closed mid-job: refuse credit (betrayal path uses betray(), not complete).
	if StandingService.is_person_closed(chain.person_id):
		return _empty_report()

	var person_delta: float = StandingService.apply_person_delta(
		chain.person_id, step.personal_standing_delta, BalanceStanding.REASON_RECOVERY_COMPLETE
	)
	var entity_delta: float = StandingService.apply_entity_delta(
		chain.entity_id, step.entity_standing_delta, BalanceStanding.REASON_RECOVERY_COMPLETE, false
	)
	StandingService.record_personal_success(chain.person_id)
	_mark_step_complete(chain.id, step.id)
	_pay_recovery_stipend()

	var chain_id: StringName = chain.id
	var step_id: StringName = step.id
	var person_id: StringName = chain.person_id
	var entity_id: StringName = chain.entity_id
	clear_active()

	EventBus.on_recovery_completed.emit(
		chain_id, step_id, person_id, entity_id, person_delta, entity_delta
	)

	return {
		REPORT_KEY_OK: true,
		REPORT_KEY_CHAIN_ID: chain_id,
		REPORT_KEY_STEP_ID: step_id,
		REPORT_KEY_PERSON_ID: person_id,
		REPORT_KEY_ENTITY_ID: entity_id,
		REPORT_KEY_PERSON_DELTA: person_delta,
		REPORT_KEY_ENTITY_DELTA: entity_delta,
		REPORT_KEY_OUTCOME: OUTCOME_COMPLETED,
	}


func _pay_recovery_stipend() -> void:
	var amount: int = BalanceEconomy.RECOVERY_STEP_PAY
	if amount <= 0:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var wallet: Node = tree.get_first_node_in_group(&"wallet_service")
	if wallet != null and wallet.has_method(&"add_credits"):
		wallet.call(&"add_credits", amount)


func _finish_soft(abandoned: bool) -> Dictionary:
	if not has_active():
		return _empty_report()
	var chain: RecoveryChain = _chain(_active_chain_id)
	var step: RecoveryStep = _step(chain, _active_step_id)
	if chain == null or step == null:
		clear_active()
		return _empty_report()

	var raw_delta: float = BalanceStanding.RECOVERY_FAIL_PERSONAL_DELTA
	var reason: StringName = BalanceStanding.REASON_RECOVERY_FAIL
	var outcome: StringName = OUTCOME_FAILED
	if abandoned:
		raw_delta = BalanceStanding.RECOVERY_ABANDON_PERSONAL_DELTA
		reason = BalanceStanding.REASON_RECOVERY_ABANDON
		outcome = OUTCOME_ABANDONED

	var person_delta: float = StandingService.apply_person_delta(chain.person_id, raw_delta, reason)
	var chain_id: StringName = chain.id
	var step_id: StringName = step.id
	var person_id: StringName = chain.person_id
	clear_active()

	if abandoned:
		EventBus.on_recovery_abandoned.emit(chain_id, step_id, person_id, person_delta)
	else:
		EventBus.on_recovery_failed.emit(chain_id, step_id, person_id, person_delta)

	return {
		REPORT_KEY_OK: true,
		REPORT_KEY_CHAIN_ID: chain_id,
		REPORT_KEY_STEP_ID: step_id,
		REPORT_KEY_PERSON_ID: person_id,
		REPORT_KEY_ENTITY_ID: chain.entity_id if chain != null else &"",
		REPORT_KEY_PERSON_DELTA: person_delta,
		REPORT_KEY_ENTITY_DELTA: 0.0,
		REPORT_KEY_OUTCOME: outcome,
	}


func _mark_step_complete(chain_id: StringName, step_id: StringName) -> void:
	var list: Array = []
	if _completed_steps.has(chain_id):
		list = _completed_steps[chain_id]
	if not list.has(step_id):
		list.append(step_id)
	_completed_steps[chain_id] = list


func _next_step(chain: RecoveryChain) -> RecoveryStep:
	if chain == null or chain.steps.is_empty():
		return null
	var done: Array[StringName] = completed_step_ids(chain.id)
	for index: int in chain.steps.size():
		var step: RecoveryStep = chain.steps[index]
		if step == null:
			continue
		if done.has(step.id):
			continue
		if step.requires_prior_success:
			# Follow-on: need at least one prior completed step on this chain.
			if done.is_empty():
				return null
			# Also require StandingService history (deniable job records success).
			if (
				StandingService.personal_success_count(chain.person_id)
				< BalanceStanding.RECOVERY_MIN_SUCCESS_FOR_FOLLOW_ON
			):
				return null
		return step
	return null


func _chain_for_person(person_id: StringName) -> RecoveryChain:
	for id: StringName in list_chain_ids():
		var chain: RecoveryChain = _chain(id)
		if chain != null and chain.person_id == person_id:
			return chain
	return null


func _chain(chain_id: StringName) -> RecoveryChain:
	if String(chain_id).is_empty() or not ContentLibrary.has_item(chain_id):
		return null
	var item: ContentItem = ContentLibrary.item(chain_id)
	if item is RecoveryChain:
		return item as RecoveryChain
	return null


func _step(chain: RecoveryChain, step_id: StringName) -> RecoveryStep:
	if chain == null:
		return null
	for step: RecoveryStep in chain.steps:
		if step != null and step.id == step_id:
			return step
	return null


## S4: after closing a betrayed Person, apply a small personal hit to each
## network contact. Does not close them. One hop only (Person.network_person_ids).
func _apply_network_betrayal_hits(betrayed_person_id: StringName) -> void:
	if String(betrayed_person_id).is_empty():
		return
	if not ContentLibrary.has_item(betrayed_person_id):
		return
	var item: ContentItem = ContentLibrary.item(betrayed_person_id)
	if not (item is Person):
		return
	var person: Person = item as Person
	for contact_id: StringName in person.network_person_ids:
		if String(contact_id).is_empty() or contact_id == betrayed_person_id:
			continue
		if StandingService.is_person_closed(contact_id):
			continue
		StandingService.apply_person_delta(
			contact_id,
			BalanceStanding.RECOVERY_NETWORK_BETRAYAL_PERSONAL_DELTA,
			BalanceStanding.REASON_RECOVERY_NETWORK_BETRAYAL
		)


func _empty_report() -> Dictionary:
	return {
		REPORT_KEY_OK: false,
		REPORT_KEY_CHAIN_ID: &"",
		REPORT_KEY_STEP_ID: &"",
		REPORT_KEY_PERSON_ID: &"",
		REPORT_KEY_ENTITY_ID: &"",
		REPORT_KEY_PERSON_DELTA: 0.0,
		REPORT_KEY_ENTITY_DELTA: 0.0,
		REPORT_KEY_OUTCOME: &"",
	}


# --- Console -----------------------------------------------------------------


static func recovery_usage() -> String:
	return (
		"%s <%s|%s|%s|%s|%s|%s|%s> [person_id]"
		% [
			String(RECOVERY),
			ACTION_LIST,
			ACTION_ACCEPT,
			ACTION_COMPLETE,
			ACTION_FAIL,
			ACTION_ABANDON,
			ACTION_BETRAY,
			ACTION_STATUS,
		]
	)


static func favor_usage() -> String:
	return "%s <person_id>" % String(FAVOR)


func _on_commands_requested() -> void:
	EventBus.on_console_command_registered.emit(
		RECOVERY, recovery_usage(), "List, accept, or resolve personal recovery steps."
	)
	EventBus.on_console_command_registered.emit(
		FAVOR, favor_usage(), "Small personal standing gift (bootstrap trust)."
	)


func _on_command_invoked(name_of_command: StringName, args: PackedStringArray) -> void:
	if name_of_command == RECOVERY:
		_run_recovery(args)
	elif name_of_command == FAVOR:
		_run_favor(args)


func _run_recovery(args: PackedStringArray) -> void:
	if args.is_empty():
		_say("Usage: %s" % recovery_usage())
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
		ACTION_BETRAY:
			_run_betray(args)
		_:
			_say("'%s' is not a recovery action. Usage: %s" % [args[0], recovery_usage()])


func _run_list() -> void:
	var ids: Array[StringName] = list_chain_ids()
	if ids.is_empty():
		_say("No recovery chains loaded.")
		return
	_say(BalanceStanding.CONSOLE_RECOVERY_LIST_HEADER)
	for id: StringName in ids:
		var chain: RecoveryChain = _chain(id)
		if chain == null:
			_say("  %s" % id)
			continue
		var person_label: String = _person_display(chain.person_id)
		if StandingService.is_person_closed(chain.person_id):
			_say(BalanceStanding.CONSOLE_RECOVERY_LIST_CLOSED % [person_label, chain.person_id])
			continue
		var done: Array[StringName] = completed_step_ids(id)
		if done.size() >= chain.steps.size() and chain.steps.size() > 0:
			_say(BalanceStanding.CONSOLE_RECOVERY_LIST_DONE % [person_label, chain.person_id])
			continue
		if has_offer_for_person(chain.person_id):
			var job_name: String = _offer_job_name(next_step_for_person(chain.person_id))
			_say(
				(
					BalanceStanding.CONSOLE_RECOVERY_LIST_OFFER
					% [person_label, job_name, chain.person_id]
				)
			)
		else:
			_say(BalanceStanding.CONSOLE_RECOVERY_LIST_GATED % [person_label, chain.person_id])


func _run_status() -> void:
	if has_active():
		var chain: RecoveryChain = _chain(active_chain_id())
		var step: RecoveryStep = _step(chain, active_step_id())
		var job_name: String = String(active_step_id())
		var person_label: String = String(active_chain_id())
		if step != null and not step.display_name.is_empty():
			job_name = step.display_name
		if chain != null:
			person_label = _person_display(chain.person_id)
		_say(BalanceStanding.CONSOLE_RECOVERY_ACTIVE_LINE % [job_name, person_label])
		_say(BalanceStanding.CONSOLE_RECOVERY_COMPLETE_HINT)
		return

	_say(BalanceStanding.CONSOLE_RECOVERY_NO_ACTIVE)
	var ids: Array[StringName] = list_chain_ids()
	for id: StringName in ids:
		var chain: RecoveryChain = _chain(id)
		if chain == null:
			continue
		var person_label: String = _person_display(chain.person_id)
		var done: Array[StringName] = completed_step_ids(id)
		var personal: float = StandingService.get_person_standing(chain.person_id)

		if StandingService.is_person_closed(chain.person_id):
			_say(BalanceStanding.CONSOLE_RECOVERY_CLOSED_LINE % person_label)
			continue

		_say(
			(
				BalanceStanding.CONSOLE_RECOVERY_PROGRESS_LINE
				% [chain.display_name, done.size(), chain.steps.size()]
			)
		)

		if done.size() >= chain.steps.size() and chain.steps.size() > 0:
			_say(
				(
					BalanceStanding.CONSOLE_RECOVERY_CHAIN_DONE
					% [person_label, done.size(), chain.steps.size()]
				)
			)
			continue

		if has_offer_for_person(chain.person_id):
			var job_name: String = _offer_job_name(next_step_for_person(chain.person_id))
			_say(BalanceStanding.CONSOLE_RECOVERY_JOB_AVAILABLE % [job_name, person_label])
			_say(BalanceStanding.CONSOLE_RECOVERY_ACCEPT_HINT % chain.person_id)
		else:
			_say(
				(
					BalanceStanding.CONSOLE_RECOVERY_NOT_YET
					% [
						person_label,
						str(BalanceStanding.TIER_FRIENDLY_MIN),
						str(personal),
					]
				)
			)


func _offer_job_name(offer: Dictionary) -> String:
	if offer.is_empty():
		return ""
	var chain_id: StringName = &""
	var step_id: StringName = &""
	if offer.has(&"chain_id"):
		chain_id = StringName(str(offer[&"chain_id"]))
	if offer.has(&"step_id"):
		step_id = StringName(str(offer[&"step_id"]))
	var chain: RecoveryChain = _chain(chain_id)
	var step: RecoveryStep = _step(chain, step_id)
	if step != null and not step.display_name.is_empty():
		return step.display_name
	if step_id != &"":
		return String(step_id)
	return ""


func _person_display(person_id: StringName) -> String:
	if ContentLibrary.has_item(person_id):
		var item: ContentItem = ContentLibrary.item(person_id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(person_id)


func _run_accept(args: PackedStringArray) -> void:
	if args.size() != BalanceStanding.CONSOLE_RECOVERY_ACCEPT_ARGS:
		_say("Usage: recovery accept <person_id>")
		return
	var person_id: StringName = StringName(args[BalanceStanding.CONSOLE_RECOVERY_PERSON_INDEX])
	if has_active():
		_say(
			(
				"Already on recovery %s / %s. Complete, fail, abandon, or betray first."
				% [active_chain_id(), active_step_id()]
			)
		)
		return
	if not accept(person_id):
		_say("Cannot accept recovery from '%s' (no offer or gated)." % person_id)
		return
	_say(
		(
			BalanceStanding.CONSOLE_RECOVERY_ACCEPTED_FORMAT
			% [active_chain_id(), active_step_id(), person_id]
		)
	)


func _run_outcome(outcome: StringName) -> void:
	if not has_active():
		_say("No active recovery step.")
		return
	var chain_id: StringName = active_chain_id()
	var step_id: StringName = active_step_id()
	var result: Dictionary = {}
	if outcome == StringName(ACTION_COMPLETE):
		result = complete()
	elif outcome == StringName(ACTION_FAIL):
		result = fail()
	else:
		result = abandon()

	if not result[REPORT_KEY_OK]:
		_say("Recovery outcome failed.")
		return
	var person_id: StringName = result[REPORT_KEY_PERSON_ID]
	var entity_id: StringName = result[REPORT_KEY_ENTITY_ID]
	var person_delta: float = result[REPORT_KEY_PERSON_DELTA]
	var entity_delta: float = result[REPORT_KEY_ENTITY_DELTA]
	_say(
		(
			BalanceStanding.CONSOLE_RECOVERY_OUTCOME_FORMAT
			% [
				step_id,
				outcome,
				person_id,
				person_delta,
				entity_id,
				entity_delta,
			]
		)
	)
	if not String(entity_id).is_empty():
		_say(
			(
				"  Entity standing now %s; personal %s."
				% [
					StandingService.get_entity_standing(entity_id),
					StandingService.get_person_standing(person_id),
				]
			)
		)
	# Silence unused when only fail path — chain_id used for clarity in tests.
	if String(chain_id).is_empty():
		pass


func _run_betray(args: PackedStringArray) -> void:
	var person_id: StringName = &""
	if args.size() >= BalanceStanding.CONSOLE_RECOVERY_ACCEPT_ARGS:
		person_id = StringName(args[BalanceStanding.CONSOLE_RECOVERY_PERSON_INDEX])
	var result: Dictionary = betray(person_id)
	if not result[REPORT_KEY_OK]:
		_say("Betray failed (no person / already closed).")
		return
	var target: StringName = result[REPORT_KEY_PERSON_ID]
	var entity_id: StringName = result[REPORT_KEY_ENTITY_ID]
	_say(
		(
			BalanceStanding.CONSOLE_RECOVERY_BETRAY_FORMAT
			% [
				target,
				StandingService.get_person_standing(target),
				result[REPORT_KEY_PERSON_DELTA],
				entity_id,
				result[REPORT_KEY_ENTITY_DELTA],
			]
		)
	)


func _run_favor(args: PackedStringArray) -> void:
	if args.size() != BalanceStanding.CONSOLE_FAVOR_ARGS:
		_say("Usage: %s" % favor_usage())
		return
	var person_id: StringName = StringName(args[BalanceStanding.CONSOLE_FAVOR_PERSON_INDEX])
	if StandingService.is_person_closed(person_id):
		_say(
			(
				BalanceStanding.CONSOLE_FAVOR_CLOSED_FORMAT
				% [person_id, StandingService.person_close_reason(person_id)]
			)
		)
		return
	var result: Dictionary = favor(person_id)
	if not result[REPORT_KEY_OK]:
		_say("Favor failed.")
		return
	_say(
		(
			BalanceStanding.CONSOLE_FAVOR_FORMAT
			% [
				person_id,
				StandingService.get_person_standing(person_id),
				result[REPORT_KEY_PERSON_DELTA],
			]
		)
	)


static func _say(line: String) -> void:
	EventBus.on_console_output.emit(line)
