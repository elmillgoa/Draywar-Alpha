extends RefCounted

## The shape of a Draywar save — Alpha A0 schema version 1.
##
## Documented in `docs/save_schema.md`. This file is the single definition of
## what a save envelope *is*: its version, its field names, and which values
## each field may hold.
##
## Version 1 stores the envelope only. There is no captain, ship or wallet yet,
## so `sections` may be empty or hold probe data for tests. Later contracts add
## sections and bump the version with a migration step.

## The marker every Draywar save begins with.
const FORMAT_MARKER: StringName = &"draywar_save"

## The schema version this build writes and reads.
const CURRENT_VERSION: int = 1

const KEY_FORMAT: StringName = &"format"
const KEY_SCHEMA_VERSION: StringName = &"schema_version"
const KEY_PROFILE_NAME: StringName = &"profile_name"
const KEY_ORIGIN: StringName = &"origin"
const KEY_CAREER_MODE: StringName = &"career_mode"
const KEY_SECTIONS: StringName = &"sections"

## Every field a version 1 envelope has.
const FIELDS: Array[StringName] = [
	KEY_FORMAT,
	KEY_SCHEMA_VERSION,
	KEY_PROFILE_NAME,
	KEY_ORIGIN,
	KEY_CAREER_MODE,
	KEY_SECTIONS,
]

## How a file came to exist.
const ORIGIN_MANUAL: StringName = &"manual"
const ORIGIN_AUTOSAVE_ENTRY: StringName = &"autosave_entry"
const ORIGIN_AUTOSAVE_DOCK: StringName = &"autosave_dock"
const ORIGINS: Array[StringName] = [ORIGIN_MANUAL, ORIGIN_AUTOSAVE_ENTRY, ORIGIN_AUTOSAVE_DOCK]

## Reserved space. Ironman is deferred; version 1 knows one mode.
const CAREER_STANDARD: StringName = &"standard"
const CAREER_MODES: Array[StringName] = [CAREER_STANDARD]


## A fresh version 1 envelope wrapped around a set of sections.
static func envelope(
	sections: Dictionary,
	profile_name: String = "",
	origin: StringName = ORIGIN_MANUAL,
	career_mode: StringName = CAREER_STANDARD
) -> Dictionary:
	return {
		KEY_FORMAT: FORMAT_MARKER,
		KEY_SCHEMA_VERSION: CURRENT_VERSION,
		KEY_PROFILE_NAME: profile_name,
		KEY_ORIGIN: origin,
		KEY_CAREER_MODE: career_mode,
		KEY_SECTIONS: sections,
	}


## Whether an envelope states a schema version this build can read as a number.
static func has_version(envelope_data: Dictionary) -> bool:
	if not envelope_data.has(KEY_SCHEMA_VERSION):
		return false
	return typeof(envelope_data[KEY_SCHEMA_VERSION]) == TYPE_INT


## The schema version an envelope claims. Meaningless unless `has_version()`.
static func version_of(envelope_data: Dictionary) -> int:
	if not has_version(envelope_data):
		return 0
	var claimed: Variant = envelope_data[KEY_SCHEMA_VERSION]
	var version: int = claimed
	return version


## Everything wrong with an envelope's shape. Empty means valid.
static func problems_in(envelope_data: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = []
	found.append_array(_field_problems(envelope_data))
	if envelope_data.has(KEY_FORMAT):
		var marker: String = format_problem(envelope_data)
		if not marker.is_empty():
			found.append(marker)
	found.append_array(_version_problems(envelope_data))
	found.append_array(_value_problems(envelope_data))
	return found


## Missing and unexpected top-level fields.
static func _field_problems(envelope_data: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = []
	for field: StringName in FIELDS:
		if not envelope_data.has(field):
			found.append(
				(
					"the envelope has no '%s' field. Every version %d save has all of: %s."
					% [field, CURRENT_VERSION, _field_list()]
				)
			)
	for key: Variant in envelope_data:
		var name_of_key: StringName = StringName(str(key))
		if not FIELDS.has(name_of_key):
			found.append(
				(
					(
						"the envelope has an unexpected field '%s'. A version %d save has "
						% [name_of_key, CURRENT_VERSION]
					)
					+ (
						"exactly these fields: %s. An unknown one means the file came "
						% _field_list()
					)
					+ "from a build that knew something this one does not, so it is "
					+ "refused rather than dropped."
				)
			)
	return found


## Whether the envelope carries the Draywar marker. Returns "" when it does.
static func format_problem(envelope_data: Dictionary) -> String:
	if not envelope_data.has(KEY_FORMAT):
		return "the envelope has no '%s' marker. This is not a Draywar save file." % KEY_FORMAT
	var marker: Variant = envelope_data[KEY_FORMAT]
	if typeof(marker) != TYPE_STRING_NAME or StringName(str(marker)) != FORMAT_MARKER:
		return (
			"'%s' is '%s', not &'%s'. This is not a Draywar save file."
			% [KEY_FORMAT, str(marker), FORMAT_MARKER]
		)
	return ""


static func _version_problems(envelope_data: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = []
	if not envelope_data.has(KEY_SCHEMA_VERSION):
		return found
	if not has_version(envelope_data):
		found.append(
			(
				(
					"'%s' is not a whole number. The version has to be readable before "
					% KEY_SCHEMA_VERSION
				)
				+ "anything else in the file can be trusted."
			)
		)
	elif version_of(envelope_data) != CURRENT_VERSION:
		found.append(
			(
				(
					"'%s' is %d; this build's schema is version %d. Migration is "
					% [KEY_SCHEMA_VERSION, version_of(envelope_data), CURRENT_VERSION]
				)
				+ "SaveMigrations.gd's job and runs before this check."
			)
		)
	return found


static func _value_problems(envelope_data: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = []
	found.append_array(_typed_field_problem(envelope_data, KEY_PROFILE_NAME, TYPE_STRING))
	found.append_array(_typed_field_problem(envelope_data, KEY_SECTIONS, TYPE_DICTIONARY))
	found.append_array(_choice_problem(envelope_data, KEY_ORIGIN, ORIGINS))
	found.append_array(_choice_problem(envelope_data, KEY_CAREER_MODE, CAREER_MODES))
	return found


static func _typed_field_problem(
	envelope_data: Dictionary, field: StringName, wanted: int
) -> PackedStringArray:
	var found: PackedStringArray = []
	if not envelope_data.has(field):
		return found
	var actual: int = typeof(envelope_data[field])
	if actual != wanted:
		found.append(
			(
				"'%s' is a %s; a version %d save stores a %s there."
				% [field, type_string(actual), CURRENT_VERSION, type_string(wanted)]
			)
		)
	return found


static func _choice_problem(
	envelope_data: Dictionary, field: StringName, allowed: Array[StringName]
) -> PackedStringArray:
	var found: PackedStringArray = []
	if not envelope_data.has(field):
		return found
	var raw: Variant = envelope_data[field]
	if typeof(raw) != TYPE_STRING_NAME or not allowed.has(StringName(str(raw))):
		found.append(
			(
				"'%s' is '%s'. Version %d allows only: %s."
				% [field, str(raw), CURRENT_VERSION, _name_list(allowed)]
			)
		)
	return found


static func _field_list() -> String:
	return _name_list(FIELDS)


static func _name_list(names: Array[StringName]) -> String:
	var out: PackedStringArray = []
	for name_of_field: StringName in names:
		out.append(String(name_of_field))
	return ", ".join(out)
