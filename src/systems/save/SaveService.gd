class_name SaveService
extends RefCounted

## Saving and loading a career — Alpha A0.
##
## Not an autoload. Holds no state between calls; anything that needs it makes
## one. Reads and writes files; it does not announce anything on the bus —
## `CareerSave.apply_meta_sections()` emits `EventBus.on_save_loaded` once the
## restored state is actually in place.

const SaveCodec = preload("res://src/systems/save/SaveCodec.gd")
const SaveMigrations = preload("res://src/systems/save/SaveMigrations.gd")
const SaveSchema = preload("res://src/systems/save/SaveSchema.gd")

## Where career saves live. Created on first write.
const SAVE_DIRECTORY: String = "user://saves"

## The extension a save file carries.
const FILE_EXTENSION: String = "sav"

const CURRENT_SCHEMA_VERSION: int = SaveSchema.CURRENT_VERSION
const KEY_SECTIONS: StringName = SaveSchema.KEY_SECTIONS
## Envelope field naming who asked for the write (Job 10 — autosave reads it).
const KEY_ORIGIN: StringName = SaveSchema.KEY_ORIGIN
const ORIGIN_MANUAL: StringName = SaveSchema.ORIGIN_MANUAL
const ORIGIN_AUTOSAVE_ENTRY: StringName = SaveSchema.ORIGIN_AUTOSAVE_ENTRY
const ORIGIN_AUTOSAVE_DOCK: StringName = SaveSchema.ORIGIN_AUTOSAVE_DOCK
const CAREER_STANDARD: StringName = SaveSchema.CAREER_STANDARD

## The migration steps this service will run. Replaceable for seam tests.
var migration_steps: Dictionary[int, Callable] = SaveMigrations.registered_steps()


## A fresh envelope at the current schema version, wrapped around `sections`.
static func envelope(
	sections: Dictionary,
	profile_name: String = "",
	origin: StringName = SaveSchema.ORIGIN_MANUAL,
	career_mode: StringName = SaveSchema.CAREER_STANDARD
) -> Dictionary:
	return SaveSchema.envelope(sections, profile_name, origin, career_mode)


## The full path of a save file with the given base name.
static func path_for(file_name: String) -> String:
	return "%s/%s.%s" % [SAVE_DIRECTORY, file_name, FILE_EXTENSION]


## The save file written most recently, or `""` when there are none.
static func most_recent_path() -> String:
	if not DirAccess.dir_exists_absolute(SAVE_DIRECTORY):
		return ""

	var newest: String = ""
	var newest_written_at: int = 0
	for file_name: String in DirAccess.get_files_at(SAVE_DIRECTORY):
		if file_name.get_extension() != FILE_EXTENSION:
			continue
		var path: String = "%s/%s" % [SAVE_DIRECTORY, file_name]
		var written_at: int = int(FileAccess.get_modified_time(path))
		if newest.is_empty() or written_at > newest_written_at:
			newest = path
			newest_written_at = written_at
		elif written_at == newest_written_at and path > newest:
			newest = path
	return newest


## Writes an envelope to `path`. The result carries the exact bytes written.
func save_to(path: String, envelope_data: Dictionary) -> SaveResult:
	var shape: PackedStringArray = SaveSchema.problems_in(envelope_data)
	if not shape.is_empty():
		return _refused(shape)

	var encoded: SaveResult = SaveCodec.encode(envelope_data)
	if not encoded.ok():
		return encoded

	var trouble: String = _write(path, encoded.bytes)
	if not trouble.is_empty():
		return SaveResult.failed(trouble)

	encoded.schema_version = SaveSchema.version_of(encoded.envelope)
	return encoded


## Reads the save at `path`, migrating it forward if it is an older schema.
func load_from(path: String) -> SaveResult:
	if not FileAccess.file_exists(path):
		return SaveResult.failed("there is no save file at '%s'." % path)

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return SaveResult.failed(
			(
				"could not open '%s' for reading (%s)."
				% [path, error_string(FileAccess.get_open_error())]
			)
		)

	var raw: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	# No `on_save_loaded` here. Reading a file is not loading a career: at this
	# point nothing has been applied, so a listener told "the load happened"
	# would read exactly the state the load is about to replace. The
	# announcement lives at the end of `CareerSave.apply_meta_sections()`.
	return decode_bytes(raw)


## The bytes a save file would contain for this envelope, without writing one.
func encode_bytes(envelope_data: Dictionary) -> SaveResult:
	var shape: PackedStringArray = SaveSchema.problems_in(envelope_data)
	if not shape.is_empty():
		return _refused(shape)
	return SaveCodec.encode(envelope_data)


## The envelope inside a save file's bytes, without reading one from disk.
func decode_bytes(raw: PackedByteArray) -> SaveResult:
	var decoded: SaveResult = SaveCodec.decode(raw)
	if not decoded.ok():
		return decoded

	var marker: String = SaveSchema.format_problem(decoded.envelope)
	if not marker.is_empty():
		return SaveResult.failed(marker)

	var migrated: SaveResult = SaveMigrations.apply(decoded.envelope, migration_steps)
	if not migrated.ok():
		return migrated

	var shape: PackedStringArray = SaveSchema.problems_in(migrated.envelope)
	if not shape.is_empty():
		return _refused(shape)

	migrated.bytes = raw
	migrated.schema_version = SaveSchema.version_of(migrated.envelope)
	return migrated


static func _refused(problems: PackedStringArray) -> SaveResult:
	var result: SaveResult = SaveResult.new()
	result.problems = problems
	return result


## Puts bytes on disk. Returns "" on success, or what went wrong.
static func _write(path: String, raw: PackedByteArray) -> String:
	var directory: String = path.get_base_dir()
	if not directory.is_empty() and not DirAccess.dir_exists_absolute(directory):
		var made: int = DirAccess.make_dir_recursive_absolute(directory)
		if made != OK:
			return "could not create '%s' (%s)." % [directory, error_string(made)]

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return (
			"could not open '%s' for writing (%s)."
			% [path, error_string(FileAccess.get_open_error())]
		)

	file.store_buffer(raw)
	file.close()
	return ""
