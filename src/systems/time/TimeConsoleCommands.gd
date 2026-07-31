extends RefCounted

## The console commands the time system answers to — Alpha A0.
##
## `time`, `combat` and `state`. Held by the TimeScale autoload.

const TIME: StringName = &"time"
const COMBAT: StringName = &"combat"
const STATE: StringName = &"state"

const ON: String = "on"
const OFF: String = "off"


func _init() -> void:
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)


static func time_usage() -> String:
	return "%s <%s>" % [String(TIME), "|".join(_speed_words())]


static func combat_usage() -> String:
	return "%s <%s|%s>" % [String(COMBAT), ON, OFF]


static func state_usage() -> String:
	return String(STATE)


static func rate_word(scale: float) -> String:
	return "%dx" % int(scale)


static func _speed_words() -> PackedStringArray:
	var words: PackedStringArray = []
	for scale: float in Balance.TIME_SCALES:
		words.append("%d" % int(scale))
	return words


static func _say(line: String) -> void:
	EventBus.on_console_output.emit(line)


func _on_commands_requested() -> void:
	EventBus.on_console_command_registered.emit(TIME, time_usage(), "Set how fast game time runs.")
	EventBus.on_console_command_registered.emit(
		COMBAT, combat_usage(), "Open or close the combat lock that holds time at normal speed."
	)
	EventBus.on_console_command_registered.emit(
		STATE, state_usage(), "Print how fast time is running and whether the combat lock is on."
	)


func _on_command_invoked(name_of_command: StringName, args: PackedStringArray) -> void:
	match name_of_command:
		TIME:
			_run_time(args)
		COMBAT:
			_run_combat(args)
		STATE:
			_run_state(args)


func _run_time(args: PackedStringArray) -> void:
	if args.size() != 1:
		_say("Usage: %s" % time_usage())
		return

	var wanted: String = args[0]
	if not wanted.is_valid_float():
		_refuse_speed(wanted)
		return

	var scale: float = wanted.to_float()
	if not TimeScale.request_scale(scale):
		_refuse_speed(wanted)
		return

	_report_speed("Speed set to %s." % rate_word(scale))


func _run_combat(args: PackedStringArray) -> void:
	if args.size() != 1:
		_say("Usage: %s" % combat_usage())
		return

	var word: String = args[0].to_lower()
	if word != ON and word != OFF:
		_say("'%s' is neither '%s' nor '%s'. Usage: %s" % [args[0], ON, OFF, combat_usage()])
		return

	TimeScale.set_combat_lock(word == ON)
	_say("Combat lock %s. Time is running at %s." % [word, rate_word(TimeScale.effective_scale())])


func _run_state(args: PackedStringArray) -> void:
	if not args.is_empty():
		_say("Usage: %s" % state_usage())
		return

	_say("Time is running at %s." % rate_word(TimeScale.effective_scale()))
	_say("Speed asked for: %s." % rate_word(TimeScale.requested_scale()))
	_say("Combat lock: %s." % (ON if TimeScale.is_combat_locked() else OFF))


func _refuse_speed(wanted: String) -> void:
	_say(
		"'%s' is not a speed this game runs at. Allowed: %s." % [wanted, ", ".join(_speed_words())]
	)


func _report_speed(prefix: String) -> void:
	var effective: String = rate_word(TimeScale.effective_scale())
	if TimeScale.is_combat_locked():
		_say(
			(
				(
					"%s The combat lock is holding time at %s, so it takes effect when the "
					% [prefix, effective]
				)
				+ "fight ends."
			)
		)
		return
	_say("%s Time is running at %s." % [prefix, effective])
