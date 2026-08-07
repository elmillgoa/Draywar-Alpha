extends Node

## The console commands the save system answers to — Alpha A0 / B2.
##
## `save <name>` and `load <name>`. Thin wrapper over CareerSave so menu and
## console share one gather/apply path. Child of `Main.tscn`.

const SAVE_COMMAND: StringName = &"save"
const LOAD_COMMAND: StringName = &"load"


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

	var written: SaveResult = CareerSave.save_to_name(get_tree(), file_name)
	if not written.ok():
		_say("Save failed: %s" % written.summary())
		return
	_say("Saved to '%s'." % SaveService.path_for(file_name))


func _run_load(args: PackedStringArray) -> void:
	var file_name: String = _file_name(args, load_usage())
	if file_name.is_empty():
		return

	var path: String = SaveService.path_for(file_name)
	var loaded: SaveResult = CareerSave.load_envelope(path)
	if not loaded.ok():
		_say("Load failed: %s" % loaded.summary())
		return
	var sections: Dictionary = {}
	if loaded.envelope.has(SaveService.KEY_SECTIONS):
		var sections_raw: Variant = loaded.envelope[SaveService.KEY_SECTIONS]
		if typeof(sections_raw) == TYPE_DICTIONARY:
			sections = sections_raw
	CareerSave.apply_meta_sections(get_tree(), sections, path)
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
