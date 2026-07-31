class_name AttributionService
extends Node

## Combat kill attribution — decides whether a kill hits standing (Alpha A3).
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A3
## Law: docs/reputation_and_standing.md §7
##
## Not a standing writer. Resolves system security + witnesses + evidence, then
## calls StandingService when attributed. Child of Main (not an autoload).
## Console: `kill …`, `trade legal …`.

const KILL: StringName = &"kill"
const TRADE: StringName = &"trade"
const TRADE_LEGAL: String = "legal"


func _ready() -> void:
	add_to_group(&"attribution_service")
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)


func _exit_tree() -> void:
	if EventBus.on_console_commands_requested.is_connected(_on_commands_requested):
		EventBus.on_console_commands_requested.disconnect(_on_commands_requested)
	if EventBus.on_console_command_invoked.is_connected(_on_command_invoked):
		EventBus.on_console_command_invoked.disconnect(_on_command_invoked)


## Report a kill. Returns attribution result dictionary (keys in BalanceStanding).
## Attributed hit goes to the local system controller when present; lawless
## evidence may fall back to victim_entity_id when nobody holds the system.
func report_kill(
	system_id: StringName,
	victim_entity_id: StringName,
	witness_count: int,
	evidence: bool,
) -> Dictionary:
	EventBus.on_kill_reported.emit(system_id, victim_entity_id, witness_count, evidence)

	var empty_entity: StringName = &""
	var unattributed: Dictionary = {
		BalanceStanding.REPORT_KEY_ATTRIBUTED: false,
		BalanceStanding.REPORT_KEY_ENTITY_ID: empty_entity,
		BalanceStanding.REPORT_KEY_DELTA: 0.0,
		BalanceStanding.REPORT_KEY_REASON: BalanceStanding.REASON_COMBAT_KILL,
		BalanceStanding.REPORT_KEY_SYSTEM_ID: system_id,
		BalanceStanding.REPORT_KEY_VICTIM_ENTITY_ID: victim_entity_id,
	}

	if not ContentLibrary.has_item(system_id):
		EventBus.on_kill_unattributed.emit(system_id, victim_entity_id)
		return unattributed

	var item: ContentItem = ContentLibrary.item(system_id)
	if not (item is StarSystem):
		EventBus.on_kill_unattributed.emit(system_id, victim_entity_id)
		return unattributed

	var system: StarSystem = item as StarSystem
	var should_attribute: bool = _should_attribute(system.policing, witness_count, evidence)
	if not should_attribute:
		EventBus.on_kill_unattributed.emit(system_id, victim_entity_id)
		return unattributed

	var target_entity: StringName = _attribution_target(system, victim_entity_id)
	if String(target_entity).strip_edges().is_empty() or target_entity == StarSystem.HELD_BY_NOBODY:
		EventBus.on_kill_unattributed.emit(system_id, victim_entity_id)
		return unattributed

	var applied: float = (
		StandingService
		. apply_entity_delta(
			target_entity,
			BalanceStanding.COMBAT_KILL_DELTA,
			BalanceStanding.REASON_COMBAT_KILL,
			true,
		)
	)
	EventBus.on_kill_attributed.emit(
		system_id, target_entity, applied, BalanceStanding.REASON_COMBAT_KILL
	)
	return {
		BalanceStanding.REPORT_KEY_ATTRIBUTED: true,
		BalanceStanding.REPORT_KEY_ENTITY_ID: target_entity,
		BalanceStanding.REPORT_KEY_DELTA: applied,
		BalanceStanding.REPORT_KEY_REASON: BalanceStanding.REASON_COMBAT_KILL,
		BalanceStanding.REPORT_KEY_SYSTEM_ID: system_id,
		BalanceStanding.REPORT_KEY_VICTIM_ENTITY_ID: victim_entity_id,
	}


func _should_attribute(policing: StringName, witness_count: int, evidence: bool) -> bool:
	if policing == StarSystem.POLICED_BY_PATROLS:
		return true
	if policing == StarSystem.POLICED_BY_CONTESTED:
		return witness_count >= BalanceStanding.ATTRIBUTION_WITNESS_THRESHOLD or evidence
	if policing == StarSystem.POLICED_BY_NOBODY:
		return evidence
	return false


func _attribution_target(system: StarSystem, victim_entity_id: StringName) -> StringName:
	var holder: StringName = system.held_by
	var has_controller: bool = (
		holder != StarSystem.HELD_BY_NOBODY and not String(holder).strip_edges().is_empty()
	)
	if has_controller:
		return holder
	if system.policing == StarSystem.POLICED_BY_NOBODY:
		return victim_entity_id
	return StarSystem.HELD_BY_NOBODY


# --- Console -----------------------------------------------------------------


static func kill_usage() -> String:
	return "%s <system_id> [witnesses] [evidence] [victim_entity]" % String(KILL)


static func trade_usage() -> String:
	return "%s %s <entity_id>" % [String(TRADE), TRADE_LEGAL]


func _on_commands_requested() -> void:
	EventBus.on_console_command_registered.emit(
		KILL, kill_usage(), "Report a kill for standing attribution (prove-it)."
	)
	EventBus.on_console_command_registered.emit(
		TRADE, trade_usage(), "Record a legal trade standing gain (soft-capped)."
	)


func _on_command_invoked(name_of_command: StringName, args: PackedStringArray) -> void:
	if name_of_command == KILL:
		_run_kill(args)
	elif name_of_command == TRADE:
		_run_trade(args)


func _run_kill(args: PackedStringArray) -> void:
	if (
		args.size() < BalanceStanding.CONSOLE_KILL_MIN_ARGS
		or args.size() > BalanceStanding.CONSOLE_KILL_MAX_ARGS
	):
		_say("Usage: %s" % kill_usage())
		return

	var system_id: StringName = StringName(args[BalanceStanding.CONSOLE_KILL_INDEX_SYSTEM])
	var witnesses: int = BalanceStanding.ATTRIBUTION_DEFAULT_WITNESSES
	var evidence: bool = false
	var victim: StringName = &""

	if args.size() >= BalanceStanding.CONSOLE_KILL_SIZE_WITH_WITNESSES:
		var witness_token: String = args[BalanceStanding.CONSOLE_KILL_INDEX_WITNESSES]
		if not witness_token.is_valid_int():
			_say("'%s' is not a witness count." % witness_token)
			return
		witnesses = witness_token.to_int()
	if args.size() >= BalanceStanding.CONSOLE_KILL_SIZE_WITH_EVIDENCE:
		evidence = _parse_evidence(args[BalanceStanding.CONSOLE_KILL_INDEX_EVIDENCE])
	if args.size() >= BalanceStanding.CONSOLE_KILL_SIZE_WITH_VICTIM:
		victim = StringName(args[BalanceStanding.CONSOLE_KILL_INDEX_VICTIM])
		if not _require_entity(victim):
			return

	if not ContentLibrary.has_item(system_id):
		_say("No system '%s'." % system_id)
		return
	var system_item: ContentItem = ContentLibrary.item(system_id)
	if not (system_item is StarSystem):
		_say("'%s' is not a star system." % system_id)
		return

	var result: Dictionary = report_kill(system_id, victim, witnesses, evidence)
	var attributed: bool = result[BalanceStanding.REPORT_KEY_ATTRIBUTED]
	if attributed:
		var entity_id: StringName = result[BalanceStanding.REPORT_KEY_ENTITY_ID]
		var delta: float = result[BalanceStanding.REPORT_KEY_DELTA]
		var standing: float = StandingService.get_entity_standing(entity_id)
		_say(
			BalanceStanding.CONSOLE_KILL_ATTRIBUTED_FORMAT % [system_id, entity_id, standing, delta]
		)
	else:
		_say(BalanceStanding.CONSOLE_KILL_UNATTRIBUTED_FORMAT % system_id)


func _run_trade(args: PackedStringArray) -> void:
	if args.size() != BalanceStanding.CONSOLE_TRADE_LEGAL_ARGS:
		_say("Usage: %s" % trade_usage())
		return
	if args[0].to_lower() != TRADE_LEGAL:
		_say("Usage: %s" % trade_usage())
		return

	var entity_id: StringName = StringName(args[BalanceStanding.CONSOLE_TRADE_ENTITY_INDEX])
	if not _require_entity(entity_id):
		return

	var applied: float = StandingService.record_legal_trade(entity_id)
	var standing: float = StandingService.get_entity_standing(entity_id)
	if is_equal_approx(applied, 0.0):
		_say(
			(
				BalanceStanding.CONSOLE_TRADE_CAPPED_FORMAT
				% [entity_id, BalanceStanding.TRADE_STANDING_SOFT_CAP]
			)
		)
	else:
		_say(BalanceStanding.CONSOLE_TRADE_FORMAT % [entity_id, standing, applied])


func _require_entity(id: StringName) -> bool:
	if not ContentLibrary.has_item(id):
		_say("No content item '%s'." % id)
		return false
	var item: ContentItem = ContentLibrary.item(id)
	if not (item is Entity):
		_say("'%s' is not an Entity." % id)
		return false
	return true


static func _parse_evidence(token: String) -> bool:
	var lower: String = token.to_lower()
	return (
		lower == BalanceStanding.CONSOLE_EVIDENCE_TRUE
		or lower == BalanceStanding.CONSOLE_EVIDENCE_ON
		or lower == BalanceStanding.CONSOLE_EVIDENCE_YES
		or lower == BalanceStanding.CONSOLE_EVIDENCE_TRUE_WORD
	)


static func _say(line: String) -> void:
	EventBus.on_console_output.emit(line)
