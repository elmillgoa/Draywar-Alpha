extends GutTest

## The console's parser, roster and dispatcher — Alpha A0.

const FAKE: StringName = &"fake"
const FAKE_TWO: StringName = &"fake_two"

var _console: ConsoleService = null
var _fake: FakeSystem = null
var _output: PackedStringArray = []
var _invoked_names: Array[StringName] = []
var _invoked_args: Array[PackedStringArray] = []


func before_each() -> void:
	_output = []
	_invoked_names = []
	_invoked_args = []
	_console = ConsoleService.new()
	EventBus.on_console_output.connect(_record_output)
	EventBus.on_console_command_invoked.connect(_record_invocation)


func after_each() -> void:
	EventBus.on_console_output.disconnect(_record_output)
	EventBus.on_console_command_invoked.disconnect(_record_invocation)
	_console = null
	_fake = null


func test_a_line_splits_into_a_command_word_and_its_arguments() -> void:
	assert_eq(ConsoleService.tokenise("time 4"), PackedStringArray(["time", "4"]))


func test_whitespace_of_any_kind_separates_arguments_and_runs_of_it_collapse() -> void:
	assert_eq(
		ConsoleService.tokenise("  save   my\tcareer \n"),
		PackedStringArray(["save", "my", "career"])
	)


func test_a_line_with_nothing_in_it_produces_no_tokens() -> void:
	assert_eq(ConsoleService.tokenise(""), PackedStringArray([]))
	assert_eq(ConsoleService.tokenise("   \t  "), PackedStringArray([]))


func test_empty_input_does_nothing_and_is_not_an_error() -> void:
	_console.start()
	_output = []

	_console.submit("")
	_console.submit("   ")
	_console.submit("\t")

	assert_eq(_output.size(), 0, "pressing return on an empty prompt is not a mistake")
	assert_eq(_invoked_names.size(), 0, "and nothing is dispatched")


func test_an_unknown_command_is_refused_by_name_and_never_reaches_the_bus() -> void:
	_console.start()
	_output = []

	_console.submit("teleport sirius")

	assert_gt(_output.size(), 0, "an unknown command must not be swallowed in silence")
	var said: String = "\n".join(_output)
	assert_string_contains(said, "teleport")
	assert_string_contains(said, "help")
	assert_eq(_invoked_names.size(), 0, "an unregistered name must never be dispatched")


func test_a_near_miss_is_refused_rather_than_guessed_at() -> void:
	# Register a real neighbour so fuzzy-match-to-it is possible. Without a
	# close real command on the roster this only proves "unknown is unknown".
	# Do not use `time` — the TimeScale autoload already owns that name.
	var register_neighbour: Callable = _register_teleport_command
	EventBus.on_console_commands_requested.connect(register_neighbour)
	_console.start()
	EventBus.on_console_commands_requested.disconnect(register_neighbour)
	_output = []
	_invoked_names.clear()

	_console.submit("telepor here")

	assert_string_contains("\n".join(_output), "telepor")
	assert_eq(_invoked_names.size(), 0, "'telepor' is not 'teleport' — do not guess")
	assert_false(_console.knows(&"telepor"), "a near miss must not invent a roster entry")


func test_a_registered_name_dispatches_exactly_once_with_its_arguments_intact() -> void:
	_start_with_fake()

	_console.submit("fake alpha beta")

	assert_eq(_invoked_names.size(), 1, "one line typed is one dispatch")
	assert_eq(_invoked_names[0], FAKE)
	assert_eq(_invoked_args[0], PackedStringArray(["alpha", "beta"]))


func test_a_command_with_no_arguments_dispatches_with_an_empty_argument_list() -> void:
	_start_with_fake()

	_console.submit("fake")

	assert_eq(_invoked_names.size(), 1)
	assert_eq(_invoked_args[0], PackedStringArray([]))


func test_the_system_that_registered_the_name_is_the_one_that_hears_it() -> void:
	_start_with_fake()

	_console.submit("fake_two only")

	assert_eq(_fake.invocations.size(), 1)
	assert_eq(_fake.invocations[0], PackedStringArray(["only"]))


func test_help_is_on_the_roster_before_any_system_has_said_anything() -> void:
	_console.start()
	assert_true(_console.knows(ConsoleService.HELP))


func test_help_lists_every_command_on_the_roster_including_itself() -> void:
	_start_with_fake()
	_output = []

	_console.submit("help")

	var said: String = "\n".join(_output)
	var roster: PackedStringArray = _console.commands()
	assert_gt(roster.size(), 0)
	for name_of_command: String in roster:
		assert_string_contains(said, name_of_command)
		assert_string_contains(said, _console.usage_of(StringName(name_of_command)))
		assert_string_contains(said, _console.summary_of(StringName(name_of_command)))
	assert_string_contains(said, String(ConsoleService.HELP))


func test_the_roster_comes_back_in_alphabetical_order() -> void:
	_start_with_fake()
	var roster: PackedStringArray = _console.commands()
	var sorted: PackedStringArray = roster.duplicate()
	sorted.sort()
	assert_eq(roster, sorted)


func test_asking_again_rebuilds_the_roster_rather_than_adding_to_it() -> void:
	_start_with_fake()
	var first: PackedStringArray = _console.commands()

	_console.start()

	assert_eq(_console.commands(), first)


func test_a_system_that_was_not_listening_has_no_command() -> void:
	_console.start()
	assert_false(_console.knows(FAKE))


func test_a_second_registration_of_one_name_is_caught_and_the_first_stands() -> void:
	var greedy: GreedySystem = GreedySystem.new(FAKE)

	_console.start()

	assert_push_error("registered twice")
	assert_true(_console.knows(FAKE))
	assert_eq(_console.summary_of(FAKE), greedy.first_summary)
	assert_string_contains("\n".join(_output), "twice")
	greedy = null


func _start_with_fake() -> void:
	var names: Array[StringName] = [FAKE, FAKE_TWO]
	_fake = FakeSystem.new(names)
	_console.start()
	_output = []


func _record_output(line: String) -> void:
	_output.append(line)


func _record_invocation(name_of_command: StringName, args: PackedStringArray) -> void:
	_invoked_names.append(name_of_command)
	_invoked_args.append(args)


func _register_teleport_command() -> void:
	EventBus.on_console_command_registered.emit(
		&"teleport", "teleport <place>", "A command a typo might almost hit."
	)


class FakeSystem:
	extends RefCounted

	var invocations: Array[PackedStringArray] = []
	var _names: Array[StringName] = []

	func _init(names: Array[StringName]) -> void:
		_names = names
		EventBus.on_console_commands_requested.connect(_on_commands_requested)
		EventBus.on_console_command_invoked.connect(_on_command_invoked)

	func _on_commands_requested() -> void:
		for name_of_command: StringName in _names:
			EventBus.on_console_command_registered.emit(
				name_of_command,
				"%s <thing>" % String(name_of_command),
				"A fake command belonging to a fake system."
			)

	func _on_command_invoked(name_of_command: StringName, args: PackedStringArray) -> void:
		if _names.has(name_of_command):
			invocations.append(args)


class GreedySystem:
	extends RefCounted

	var first_summary: String = "The registration that should stand."
	var _name: StringName = &""

	func _init(name_of_command: StringName) -> void:
		_name = name_of_command
		EventBus.on_console_commands_requested.connect(_on_commands_requested)

	func _on_commands_requested() -> void:
		EventBus.on_console_command_registered.emit(_name, "fake", first_summary)
		EventBus.on_console_command_registered.emit(_name, "fake", "The one that must be refused.")
