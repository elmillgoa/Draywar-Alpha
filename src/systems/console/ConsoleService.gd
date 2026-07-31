class_name ConsoleService
extends RefCounted

## The debug console's parser, roster and dispatcher — Alpha A0.
##
## Not a node and not an autoload. Whoever shows the console owns one and
## drives it. Four bus signals: request, register, invoke, output.

## The one command the console owns.
const HELP: StringName = &"help"
const HELP_USAGE: String = "help"
const HELP_SUMMARY: String = "List every command the console knows about."

var _usage: Dictionary[StringName, String] = {}
var _summary: Dictionary[StringName, String] = {}

## True only while `start()` is rebuilding the roster. Orphan ConsoleService
## instances stay connected to the bus; they must ignore later rebuilds so a
## second console in tests (or a second start elsewhere) does not treat
## legitimate re-registrations as double-claims.
var _accepting_registrations: bool = false


func _init() -> void:
	EventBus.on_console_command_registered.connect(_on_command_registered)


## Asks every system to declare what it answers to, and rebuilds the roster.
func start() -> void:
	_usage.clear()
	_summary.clear()
	_usage[HELP] = HELP_USAGE
	_summary[HELP] = HELP_SUMMARY
	_accepting_registrations = true
	EventBus.on_console_commands_requested.emit()
	_accepting_registrations = false


## Every command name the console knows, in reading order.
func commands() -> PackedStringArray:
	var names: PackedStringArray = []
	for name_of_command: StringName in _usage:
		names.append(String(name_of_command))
	names.sort()
	return names


## Whether a name is on the roster.
func knows(name_of_command: StringName) -> bool:
	return _usage.has(name_of_command)


## The one-line argument form registered for a command, or "" if unknown.
func usage_of(name_of_command: StringName) -> String:
	if not _usage.has(name_of_command):
		return ""
	return _usage[name_of_command]


## The one-line description registered for a command, or "" if unknown.
func summary_of(name_of_command: StringName) -> String:
	if not _summary.has(name_of_command):
		return ""
	return _summary[name_of_command]


## Runs one typed line.
func submit(line: String) -> void:
	var tokens: PackedStringArray = tokenise(line)
	if tokens.is_empty():
		return

	var word: String = tokens[0]
	var name_of_command: StringName = StringName(word)
	var args: PackedStringArray = tokens.slice(1)

	if name_of_command == HELP:
		_print_help()
		return

	if not _usage.has(name_of_command):
		EventBus.on_console_output.emit(
			"Unknown command '%s'. Type '%s' for the list of commands." % [word, String(HELP)]
		)
		return

	EventBus.on_console_command_invoked.emit(name_of_command, args)


## A typed line split into a command word and its arguments.
static func tokenise(line: String) -> PackedStringArray:
	var tokens: PackedStringArray = []
	var current: String = ""
	for index: int in line.length():
		var character: String = line[index]
		if character.strip_edges().is_empty():
			if not current.is_empty():
				tokens.append(current)
				current = ""
			continue
		current += character
	if not current.is_empty():
		tokens.append(current)
	return tokens


func _print_help() -> void:
	var names: PackedStringArray = commands()
	var longest: int = 0
	for name_of_command: String in names:
		longest = maxi(longest, usage_of(StringName(name_of_command)).length())

	EventBus.on_console_output.emit("Commands:")
	for name_of_command: String in names:
		var key: StringName = StringName(name_of_command)
		EventBus.on_console_output.emit("  %s  %s" % [usage_of(key).rpad(longest), summary_of(key)])


func _on_command_registered(name_of_command: StringName, usage: String, summary: String) -> void:
	if not _accepting_registrations:
		return
	if _usage.has(name_of_command):
		var complaint: String = (
			(
				"Console command '%s' is registered twice. The first registration stands "
				% String(name_of_command)
			)
			+ (
				"and this one is refused: two systems answering to one name is a bug, "
				+ "not a precedence question."
			)
		)
		push_error(complaint)
		EventBus.on_console_output.emit(complaint)
		return

	_usage[name_of_command] = usage
	_summary[name_of_command] = summary
