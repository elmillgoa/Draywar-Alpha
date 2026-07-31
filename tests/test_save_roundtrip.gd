extends GutTest

## Save -> load restores a hostile test state byte-equivalently — Alpha A0.

const SaveFixture = preload("res://scripts/save_fixture.gd")
const SaveCodecScript = preload("res://src/systems/save/SaveCodec.gd")

const FIXTURE_PATH: String = "user://a0_roundtrip_test.sav"

var _service: SaveService = null


func before_each() -> void:
	_service = SaveService.new()


func after_each() -> void:
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)


func test_the_fixture_is_still_hostile_enough_to_prove_anything() -> void:
	var problems: PackedStringArray = SaveFixture.hostility_problems()
	assert_eq(
		problems.size(), 0, "the fixture has stopped being hostile:\n  %s" % "\n  ".join(problems)
	)


func test_a_text_serialiser_would_fail_this_fixture() -> void:
	var state: Dictionary = SaveFixture.sections()
	var through_text: Variant = str_to_var(var_to_str(state))
	assert_ne(
		var_to_bytes(through_text),
		var_to_bytes(state),
		"the fixture now survives Godot's text serialiser"
	)


func test_saving_then_loading_restores_the_state_byte_for_byte() -> void:
	var envelope: Dictionary = _hostile_envelope()
	var written: SaveResult = _service.save_to(FIXTURE_PATH, envelope)
	assert_true(written.ok(), "the save was refused: %s" % written.summary())

	var loaded: SaveResult = _service.load_from(FIXTURE_PATH)
	assert_true(loaded.ok(), "the load was refused: %s" % loaded.summary())
	if not loaded.ok():
		return

	var wanted: PackedByteArray = written.bytes
	var got: PackedByteArray = var_to_bytes(loaded.envelope)
	assert_eq(_digest(got), _digest(wanted), _difference(written.envelope, loaded.envelope))


func test_the_bytes_on_disk_are_the_bytes_the_save_reported() -> void:
	var written: SaveResult = _service.save_to(FIXTURE_PATH, _hostile_envelope())
	assert_true(written.ok(), written.summary())

	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var on_disk: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	assert_eq(_digest(on_disk), _digest(written.bytes))


func test_every_awkward_float_comes_back_bit_for_bit() -> void:
	var loaded: SaveResult = _saved_and_loaded()
	if loaded == null:
		return
	var came_back: Dictionary = _section_of(loaded, SaveFixture.SECTION_NUMBERS)
	var wanted: Dictionary = SaveFixture.awkward_floats()

	for key: Variant in wanted:
		var name_of_value: StringName = StringName(str(key))
		assert_true(came_back.has(name_of_value), "'%s' is missing" % name_of_value)
		if not came_back.has(name_of_value):
			continue
		var before: PackedByteArray = var_to_bytes(wanted[name_of_value])
		var after: PackedByteArray = var_to_bytes(came_back[name_of_value])
		assert_eq(
			after.hex_encode(),
			before.hex_encode(),
			"'%s' did not survive the round trip bit for bit" % name_of_value
		)


func test_reencoding_a_loaded_save_reproduces_the_file_exactly() -> void:
	var written: SaveResult = _service.save_to(FIXTURE_PATH, _hostile_envelope())
	var loaded: SaveResult = _service.load_from(FIXTURE_PATH)
	assert_true(loaded.ok(), loaded.summary())
	if not loaded.ok():
		return
	var again: SaveResult = _service.encode_bytes(loaded.envelope)
	assert_true(again.ok(), again.summary())
	assert_eq(_digest(again.bytes), _digest(written.bytes))


func test_the_same_state_encodes_to_the_same_bytes_whatever_order_it_was_built_in() -> void:
	var first: SaveResult = _service.encode_bytes(
		SaveService.envelope(SaveFixture.sections(), SaveFixture.PROFILE_NAME)
	)
	var second: SaveResult = _service.encode_bytes(
		SaveService.envelope(SaveFixture.sections_in_another_order(), SaveFixture.PROFILE_NAME)
	)
	assert_true(first.ok(), first.summary())
	assert_true(second.ok(), second.summary())
	assert_eq(_digest(second.bytes), _digest(first.bytes))


func test_encoding_the_same_state_twice_gives_the_same_bytes() -> void:
	var envelope: Dictionary = _hostile_envelope()
	var first: SaveResult = _service.encode_bytes(envelope)
	var second: SaveResult = _service.encode_bytes(envelope)
	assert_true(first.ok(), first.summary())
	assert_true(second.ok(), second.summary())
	assert_gt(
		first.bytes.size(), 0, "a dead encoder that returns empty bytes twice is not determinism"
	)
	assert_eq(_digest(second.bytes), _digest(first.bytes))


func test_keys_come_back_in_text_order_at_every_depth() -> void:
	var encoded: SaveResult = _service.encode_bytes(_hostile_envelope())
	assert_true(encoded.ok(), encoded.summary())
	_assert_sorted(encoded.envelope, "<save>")


func test_an_int_and_a_float_of_the_same_value_stay_different() -> void:
	var loaded: SaveResult = _saved_and_loaded()
	if loaded == null:
		return
	var edges: Dictionary = _section_of(loaded, SaveFixture.SECTION_EDGES)
	assert_eq(typeof(edges[&"seven_as_an_int"]), TYPE_INT)
	assert_eq(typeof(edges[&"seven_as_a_float"]), TYPE_FLOAT)


func test_a_string_and_a_string_name_stay_different() -> void:
	var loaded: SaveResult = _saved_and_loaded()
	if loaded == null:
		return
	var edges: Dictionary = _section_of(loaded, SaveFixture.SECTION_EDGES)
	assert_eq(typeof(edges[&"a_string"]), TYPE_STRING)
	assert_eq(typeof(edges[&"a_string_name"]), TYPE_STRING_NAME)


func test_the_reserved_shapes_survive_a_round_trip() -> void:
	var loaded: SaveResult = _saved_and_loaded()
	if loaded == null:
		return

	var ships: Variant = _section_value(loaded, SaveFixture.SECTION_SHIPS)
	assert_eq(typeof(ships), TYPE_ARRAY)
	var ledger: Variant = _section_value(loaded, SaveFixture.SECTION_LEDGER)
	assert_eq(typeof(ledger), TYPE_ARRAY)

	var standing: Dictionary = _section_of(loaded, SaveFixture.SECTION_STANDING)
	assert_gt(standing.size(), 6)

	var captain: Dictionary = _section_of(loaded, SaveFixture.SECTION_CAPTAIN)
	var captain_name: Variant = captain[&"name"]
	assert_eq(typeof(captain_name), TYPE_STRING)
	assert_eq(str(captain_name), SaveFixture.PROFILE_NAME)


func _digest(raw: PackedByteArray) -> String:
	var hasher: HashingContext = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(raw)
	return "%d bytes, sha256 %s" % [raw.size(), hasher.finish().hex_encode()]


func _hostile_envelope() -> Dictionary:
	return SaveService.envelope(
		SaveFixture.sections(), SaveFixture.PROFILE_NAME, SaveService.ORIGIN_AUTOSAVE_ENTRY
	)


func _saved_and_loaded() -> SaveResult:
	var written: SaveResult = _service.save_to(FIXTURE_PATH, _hostile_envelope())
	assert_true(written.ok(), "the save was refused: %s" % written.summary())
	var loaded: SaveResult = _service.load_from(FIXTURE_PATH)
	assert_true(loaded.ok(), "the load was refused: %s" % loaded.summary())
	if not loaded.ok():
		return null
	return loaded


func _section_value(loaded: SaveResult, name_of_section: StringName) -> Variant:
	var raw: Variant = loaded.envelope[&"sections"]
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var sections: Dictionary = raw
	if not sections.has(name_of_section):
		return null
	return sections[name_of_section]


func _section_of(loaded: SaveResult, name_of_section: StringName) -> Dictionary:
	var raw: Variant = _section_value(loaded, name_of_section)
	if typeof(raw) != TYPE_DICTIONARY:
		assert_true(false, "section '%s' is not a dictionary" % name_of_section)
		return {}
	var section: Dictionary = raw
	return section


func _difference(wanted: Variant, got: Variant) -> String:
	var where: String = _first_difference(wanted, got, "<save>")
	if not where.is_empty():
		return where
	return "every value matches; files differ only in arrangement"


func _first_difference(wanted: Variant, got: Variant, path: String) -> String:
	if typeof(wanted) != typeof(got):
		return (
			"%s: wrote a %s, read a %s"
			% [path, type_string(typeof(wanted)), type_string(typeof(got))]
		)
	if typeof(wanted) == TYPE_DICTIONARY:
		var wanted_table: Dictionary = wanted
		var got_table: Dictionary = got
		return _dictionary_difference(wanted_table, got_table, path)
	if typeof(wanted) == TYPE_ARRAY:
		var wanted_list: Array = wanted
		var got_list: Array = got
		return _array_difference(wanted_list, got_list, path)
	if var_to_bytes(wanted) != var_to_bytes(got):
		return (
			"%s: wrote %s, read %s (bit for bit)"
			% [path, var_to_bytes(wanted).hex_encode(), var_to_bytes(got).hex_encode()]
		)
	return ""


func _dictionary_difference(wanted: Dictionary, got: Dictionary, path: String) -> String:
	for key: Variant in wanted:
		var name_of_key: StringName = StringName(str(key))
		if not got.has(name_of_key):
			return "%s/%s: missing after the round trip" % [path, name_of_key]
		var deeper: String = _first_difference(
			wanted[name_of_key], got[name_of_key], "%s/%s" % [path, name_of_key]
		)
		if not deeper.is_empty():
			return deeper
	for key: Variant in got:
		var name_of_key: StringName = StringName(str(key))
		if not wanted.has(name_of_key):
			return "%s/%s: appeared from nowhere" % [path, name_of_key]
	return ""


func _array_difference(wanted: Array, got: Array, path: String) -> String:
	if wanted.size() != got.size():
		return "%s: %d entries became %d" % [path, wanted.size(), got.size()]
	for index: int in range(wanted.size()):
		var deeper: String = _first_difference(wanted[index], got[index], "%s[%d]" % [path, index])
		if not deeper.is_empty():
			return deeper
	return ""


func _assert_sorted(value: Variant, path: String) -> void:
	if typeof(value) == TYPE_ARRAY:
		var list: Array = value
		var index: int = 0
		for element: Variant in list:
			_assert_sorted(element, "%s[%d]" % [path, index])
			index += 1
		return
	if typeof(value) != TYPE_DICTIONARY:
		return
	var table: Dictionary = value
	var previous: String = ""
	for key: Variant in table:
		var text: String = str(key)
		assert_true(previous <= text, "%s: key '%s' comes after '%s'" % [path, previous, text])
		previous = text
		_assert_sorted(table[key], "%s/%s" % [path, text])
