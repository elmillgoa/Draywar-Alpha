extends Node

## The console commands the save system answers to — Alpha A0.
##
## `save <name>` and `load <name>`. Lives in the save system so only this side
## of the boundary may touch `SaveService`. Child of `Main.tscn`.

const SAVE_COMMAND: StringName = &"save"
const LOAD_COMMAND: StringName = &"load"

var _service: SaveService = SaveService.new()


func _ready() -> void:
	EventBus.on_console_commands_requested.connect(_on_commands_requested)
	EventBus.on_console_command_invoked.connect(_on_command_invoked)


static func save_usage() -> String:
	return "%s <name>" % String(SAVE_COMMAND)


static func load_usage() -> String:
	return "%s <name>" % String(LOAD_COMMAND)


static func _say(line: String) -> void:
	EventBus.on_console_output.emit(line)


func _on_commands_requested() -> void:
	EventBus.on_console_command_registered.emit(
		SAVE_COMMAND, save_usage(), "Write a save file with this name."
	)
	EventBus.on_console_command_registered.emit(
		LOAD_COMMAND, load_usage(), "Read back the save file with this name."
	)


func _on_command_invoked(name_of_command: StringName, args: PackedStringArray) -> void:
	match name_of_command:
		SAVE_COMMAND:
			_run_save(args)
		LOAD_COMMAND:
			_run_load(args)


func _run_save(args: PackedStringArray) -> void:
	var file_name: String = _file_name(args, save_usage())
	if file_name.is_empty():
		return

	var path: String = SaveService.path_for(file_name)
	var written: SaveResult = _service.save_to(path, SaveService.envelope({}, file_name))
	if not written.ok():
		_say("Save failed: %s" % written.summary())
		return
	_say("Saved to '%s'." % path)


func _run_load(args: PackedStringArray) -> void:
	var file_name: String = _file_name(args, load_usage())
	if file_name.is_empty():
		return

	var path: String = SaveService.path_for(file_name)
	var loaded: SaveResult = _service.load_from(path)
	if not loaded.ok():
		_say("Load failed: %s" % loaded.summary())
		return
	_say("Loaded '%s'." % path)


func _file_name(args: PackedStringArray, usage: String) -> String:
	if args.size() != 1:
		_say("Usage: %s" % usage)
		return ""

	var wanted: String = args[0]
	if not wanted.is_valid_filename():
		_say(
			(
				(
					"'%s' is not a usable save name. Letters, digits, dashes and "
					+ "underscores only, and no directories."
				)
				% wanted
			)
		)
		return ""
	return wanted
