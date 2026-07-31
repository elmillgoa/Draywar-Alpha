extends GutTest

## The envelope, the version field and the migration seam — Alpha A0 schema v1.

const SaveCodecScript = preload("res://src/systems/save/SaveCodec.gd")
const SaveSchemaScript = preload("res://src/systems/save/SaveSchema.gd")
const SaveMigrationsScript = preload("res://src/systems/save/SaveMigrations.gd")

const FIXTURE_PATH: String = "user://a0_service_test.sav"
const FIRST_SCHEMA_VERSION: int = 1

var _service: SaveService = null
var _steps_run: PackedInt32Array = []


func before_each() -> void:
	_service = SaveService.new()
	_steps_run = []


func after_each() -> void:
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)


func test_a_fresh_envelope_carries_the_current_schema_version() -> void:
	var envelope: Dictionary = SaveService.envelope({})
	assert_true(envelope.has(SaveSchemaScript.KEY_SCHEMA_VERSION))
	assert_eq(SaveSchemaScript.version_of(envelope), SaveService.CURRENT_SCHEMA_VERSION)
	assert_eq(SaveService.CURRENT_SCHEMA_VERSION, 1, "A0 is schema version 1")


func test_the_version_can_be_read_out_of_a_file_before_anything_else_is_trusted() -> void:
	var written: SaveResult = _service.save_to(FIXTURE_PATH, SaveService.envelope({}))
	assert_true(written.ok(), written.summary())

	var raw: SaveResult = SaveCodecScript.decode(written.bytes)
	assert_true(raw.ok(), raw.summary())
	assert_eq(SaveSchemaScript.version_of(raw.envelope), SaveService.CURRENT_SCHEMA_VERSION)
	assert_eq(written.schema_version, SaveService.CURRENT_SCHEMA_VERSION)


func test_a_save_from_a_newer_build_is_refused_and_names_both_versions() -> void:
	var future: Dictionary = SaveService.envelope({})
	future[SaveSchemaScript.KEY_SCHEMA_VERSION] = SaveService.CURRENT_SCHEMA_VERSION + 1
	var result: SaveResult = _service.decode_bytes(SaveCodecScript.encode(future).bytes)

	assert_false(result.ok())
	assert_string_contains(result.summary(), "newer build")
	assert_string_contains(result.summary(), str(SaveService.CURRENT_SCHEMA_VERSION))


func test_an_older_save_with_no_migration_is_refused_and_says_why() -> void:
	var result: SaveResult = _service.decode_bytes(_older_save_bytes(0))
	assert_false(result.ok())
	assert_string_contains(result.summary(), "no migration from 0")
	assert_string_contains(result.summary(), "start a new career")


func test_every_older_schema_this_build_knows_has_a_step_registered_for_it() -> void:
	# At A0, CURRENT is 1 and the registry is empty — one step per version behind
	# this one means zero steps.
	var registered: Dictionary[int, Callable] = SaveMigrationsScript.registered_steps()

	for version: int in range(FIRST_SCHEMA_VERSION, SaveService.CURRENT_SCHEMA_VERSION):
		assert_true(registered.has(version), "no migration from schema version %d" % version)

	assert_eq(
		registered.size(),
		SaveService.CURRENT_SCHEMA_VERSION - FIRST_SCHEMA_VERSION,
		"there is one step per version behind this one, and nothing else"
	)


func test_the_migration_seam_runs_a_registered_step() -> void:
	_service.migration_steps = {0: _step_to_current}
	var result: SaveResult = _service.decode_bytes(_older_save_bytes(0))

	assert_true(result.ok(), "the seam should have carried the save forward: %s" % result.summary())
	assert_eq(_steps_run, PackedInt32Array([SaveService.CURRENT_SCHEMA_VERSION]))
	assert_eq(result.schema_version, SaveService.CURRENT_SCHEMA_VERSION)


func test_the_migration_seam_chains_steps_in_order() -> void:
	_service.migration_steps = {-1: _step_to_zero, 0: _step_to_current}
	var result: SaveResult = _service.decode_bytes(_older_save_bytes(-1))

	assert_true(result.ok(), "chained migration failed: %s" % result.summary())
	assert_eq(_steps_run, PackedInt32Array([0, SaveService.CURRENT_SCHEMA_VERSION]))


func test_a_migration_that_does_not_raise_the_version_is_refused() -> void:
	_service.migration_steps = {0: _step_that_changes_nothing}
	var result: SaveResult = _service.decode_bytes(_older_save_bytes(0))

	assert_false(result.ok())
	assert_string_contains(result.summary(), "must raise the version")


func test_a_migration_that_returns_something_else_is_refused() -> void:
	_service.migration_steps = {0: _step_that_returns_nonsense}
	var result: SaveResult = _service.decode_bytes(_older_save_bytes(0))

	assert_false(result.ok())
	assert_string_contains(result.summary(), "instead of an")


func test_a_file_that_is_not_a_draywar_save_is_refused() -> void:
	var impostor: Dictionary = {&"format": &"some_other_game", &"schema_version": 1}
	var result: SaveResult = _service.decode_bytes(SaveCodecScript.encode(impostor).bytes)
	assert_false(result.ok())
	assert_string_contains(result.summary(), "not a Draywar save")


func test_a_missing_or_unexpected_field_is_refused() -> void:
	var short: Dictionary = SaveService.envelope({})
	short.erase(SaveSchemaScript.KEY_PROFILE_NAME)
	var missing: SaveResult = _service.decode_bytes(SaveCodecScript.encode(short).bytes)
	assert_false(missing.ok())
	assert_string_contains(missing.summary(), "profile_name")

	var extra: Dictionary = SaveService.envelope({})
	extra[&"something_new"] = 1
	var surprised: SaveResult = _service.decode_bytes(SaveCodecScript.encode(extra).bytes)
	assert_false(surprised.ok())
	assert_string_contains(surprised.summary(), "unexpected field")


func test_all_three_save_origins_are_accepted_and_nothing_else_is() -> void:
	for origin: StringName in [
		SaveService.ORIGIN_MANUAL,
		SaveService.ORIGIN_AUTOSAVE_ENTRY,
		SaveService.ORIGIN_AUTOSAVE_DOCK
	]:
		var good: Dictionary = SaveService.envelope({}, "", origin)
		var accepted: SaveResult = _service.encode_bytes(good)
		assert_true(
			accepted.ok(), "'%s' should be a valid origin: %s" % [origin, accepted.summary()]
		)

	var bad: Dictionary = SaveService.envelope({}, "", &"autosave_whenever")
	var refused: SaveResult = _service.encode_bytes(bad)
	assert_false(refused.ok())
	assert_string_contains(refused.summary(), "origin")


func test_only_the_standard_career_mode_is_accepted() -> void:
	var standard: Dictionary = SaveService.envelope({}, "", SaveService.ORIGIN_MANUAL)
	assert_true(_service.encode_bytes(standard).ok())

	var ironman: Dictionary = SaveService.envelope({}, "", SaveService.ORIGIN_MANUAL, &"ironman")
	var refused: SaveResult = _service.encode_bytes(ironman)
	assert_false(refused.ok())
	assert_string_contains(refused.summary(), "career_mode")


func test_loading_a_file_that_is_not_there_is_refused_clearly() -> void:
	var result: SaveResult = _service.load_from("user://a0_no_such_save.sav")
	assert_false(result.ok())
	assert_string_contains(result.summary(), "no save file")


func test_saving_creates_the_directory_it_needs() -> void:
	var nested: String = "user://a0_made_up_dir/deeper/career.sav"
	var written: SaveResult = _service.save_to(nested, SaveService.envelope({}))
	assert_true(written.ok(), written.summary())
	assert_true(FileAccess.file_exists(nested))
	if FileAccess.file_exists(nested):
		DirAccess.remove_absolute(nested)
	DirAccess.remove_absolute("user://a0_made_up_dir/deeper")
	DirAccess.remove_absolute("user://a0_made_up_dir")


func _older_save_bytes(version: int) -> PackedByteArray:
	var envelope: Dictionary = SaveService.envelope({&"probe": {&"integrity": 0.5}}, "Older")
	envelope[SaveSchemaScript.KEY_SCHEMA_VERSION] = version
	return SaveCodecScript.encode(envelope).bytes


func _bumped(envelope: Dictionary, to_version: int) -> Dictionary:
	var out: Dictionary = envelope.duplicate(true)
	out[SaveSchemaScript.KEY_SCHEMA_VERSION] = to_version
	_steps_run.append(to_version)
	return out


func _step_to_zero(envelope: Dictionary) -> Dictionary:
	return _bumped(envelope, 0)


func _step_to_current(envelope: Dictionary) -> Dictionary:
	return _bumped(envelope, SaveService.CURRENT_SCHEMA_VERSION)


func _step_that_changes_nothing(envelope: Dictionary) -> Dictionary:
	return envelope


func _step_that_returns_nonsense(_envelope: Dictionary) -> Variant:
	return "not an envelope"
