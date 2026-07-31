extends RefCounted

## Console commands for the standing ledger — Alpha A2.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A2
##
## `standing entity|person|show …`. Held by the StandingService autoload.

const STANDING: StringName = &"standing"
const KIND_ENTITY: String = "entity"
const KIND_PERSON: String = "person"
const ACTION_SHOW: String = "show"


func _init() -> void:
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)


static func usage() -> String:
	return (
		"%s <%s|%s|%s> [id] [value|tier]"
		% [String(STANDING), KIND_ENTITY, KIND_PERSON, ACTION_SHOW]
	)


static func _say(line: String) -> void:
	EventBus.on_console_output.emit(line)


func _on_commands_requested() -> void:
	EventBus.on_console_command_registered.emit(
		STANDING, usage(), "Set or show player standing with an Entity or Person."
	)


func _on_command_invoked(name_of_command: StringName, args: PackedStringArray) -> void:
	if name_of_command != STANDING:
		return
	_run(args)


func _run(args: PackedStringArray) -> void:
	if args.is_empty():
		_say("Usage: %s" % usage())
		return

	var head: String = args[0].to_lower()
	if head == ACTION_SHOW:
		_run_show(args.slice(1))
	elif head == KIND_ENTITY:
		_run_set(true, args.slice(1))
	elif head == KIND_PERSON:
		_run_set(false, args.slice(1))
	else:
		_say("'%s' is not entity, person, or show. Usage: %s" % [args[0], usage()])


func _run_show(args: PackedStringArray) -> void:
	if args.is_empty():
		_show_all()
		return
	if args.size() != BalanceStanding.CONSOLE_PAIR_ARG_COUNT:
		_say("Usage: standing show <entity|person> <id>")
		return

	var kind: String = args[0].to_lower()
	var id: StringName = StringName(args[1])
	if kind == KIND_ENTITY:
		_say_one("Entity", id, StandingService.get_entity_standing(id))
		return
	if kind == KIND_PERSON:
		_say_one("Person", id, StandingService.get_person_standing(id))
		return
	_say("'%s' is not entity or person." % args[0])


func _say_one(kind_label: String, id: StringName, value: float) -> void:
	var tier: StringName = StandingService.tier_for(value)
	_say(
		(
			"%s %s: %s (%s)  standing=%s"
			% [kind_label, id, StandingService.tier_display_name(tier), tier, value]
		)
	)


func _show_all() -> void:
	var entity_ids: Array[StringName] = ContentLibrary.ids_in(&"entities")
	if entity_ids.is_empty():
		_say("No entities loaded.")
	else:
		_say("Entities:")
		for id: StringName in entity_ids:
			var value: float = StandingService.get_entity_standing(id)
			var tier: StringName = StandingService.tier_for(value)
			_say("  %s  %s (%s)" % [id, value, StandingService.tier_display_name(tier)])

	var person_ids: Array[StringName] = ContentLibrary.ids_in(&"people")
	if person_ids.is_empty():
		_say("No people loaded.")
	else:
		_say("People:")
		for id: StringName in person_ids:
			var value: float = StandingService.get_person_standing(id)
			var tier: StringName = StandingService.tier_for(value)
			_say("  %s  %s (%s)" % [id, value, StandingService.tier_display_name(tier)])


func _run_set(is_entity: bool, args: PackedStringArray) -> void:
	var kind: String = KIND_ENTITY if is_entity else KIND_PERSON
	if args.size() != BalanceStanding.CONSOLE_PAIR_ARG_COUNT:
		_say("Usage: standing %s <id> <value|tier>" % kind)
		return

	var id: StringName = StringName(args[0])
	var token: String = args[1]
	var holder: Array = [0.0]
	if not _try_parse_standing_token(token, holder):
		_say("'%s' is not a number or a tier (%s)." % [token, ", ".join(_tier_words())])
		return
	var value: float = holder[0]

	if is_entity:
		if not _require_entity(id):
			return
		StandingService.set_entity_standing(id, value)
		_report_set("Entity", id, StandingService.get_entity_standing(id))
		return

	if not _require_person(id):
		return
	StandingService.set_person_standing(id, value)
	_report_set("Person", id, StandingService.get_person_standing(id))


func _require_entity(id: StringName) -> bool:
	if not ContentLibrary.has_item(id):
		_say("No content item '%s'." % id)
		return false
	var item: ContentItem = ContentLibrary.item(id)
	if not (item is Entity):
		_say("'%s' is not an Entity." % id)
		return false
	return true


func _require_person(id: StringName) -> bool:
	if not ContentLibrary.has_item(id):
		_say("No content item '%s'." % id)
		return false
	var item: ContentItem = ContentLibrary.item(id)
	if not (item is Person):
		_say("'%s' is not a Person." % id)
		return false
	return true


func _report_set(kind_label: String, id: StringName, after: float) -> void:
	var tier: StringName = StandingService.tier_for(after)
	_say(
		(
			"%s %s standing set to %s (%s)."
			% [kind_label, id, after, StandingService.tier_display_name(tier)]
		)
	)


## Fills out_value and returns true when token is a number or known tier.
static func _try_parse_standing_token(token: String, out_holder: Array) -> bool:
	if token.is_valid_float():
		out_holder[0] = token.to_float()
		return true
	var tier_token: StringName = StringName(token.to_lower())
	if BalanceStanding.KNOWN_TIERS.has(tier_token):
		out_holder[0] = StandingService.value_for_tier(tier_token)
		return true
	return false


static func _tier_words() -> PackedStringArray:
	var words: PackedStringArray = []
	for tier: StringName in BalanceStanding.KNOWN_TIERS:
		words.append(String(tier))
	return words
