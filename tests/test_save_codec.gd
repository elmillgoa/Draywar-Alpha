extends GutTest

## What may be in a save, and what a damaged file does — Alpha A0.

const SaveCodecScript = preload("res://src/systems/save/SaveCodec.gd")
const SaveSchemaScript = preload("res://src/systems/save/SaveSchema.gd")

const EIGHT_BYTES: int = 8


func test_a_float_that_is_not_a_number_is_refused() -> void:
	for bad: float in [NAN, INF, -INF]:
		var result: SaveResult = SaveCodecScript.encode(_wrapped(bad))
		assert_false(result.ok(), "%s should not be storable" % str(bad))
		assert_string_contains(result.summary(), "finite")


func test_a_vector_is_refused_and_says_what_to_store_instead() -> void:
	var result: SaveResult = SaveCodecScript.encode(_wrapped(Vector3.ONE))
	assert_false(result.ok(), "a Vector3 should not be storable")
	assert_string_contains(result.summary(), "separate floats")
	assert_string_contains(result.summary(), "32-bit")


func test_an_object_is_refused() -> void:
	var stray: RefCounted = RefCounted.new()
	var result: SaveResult = SaveCodecScript.encode(_wrapped(stray))
	assert_false(result.ok(), "an object should not be storable")
	assert_string_contains(result.summary(), "may contain only")


func test_a_key_that_is_not_a_name_is_refused() -> void:
	var result: SaveResult = SaveCodecScript.encode({&"format": &"x", 7: "keyed by a number"})
	assert_false(result.ok(), "an integer key should be refused")
	assert_string_contains(result.summary(), "Every key in a save is a name")


func test_a_problem_names_where_in_the_save_it_is() -> void:
	var envelope: Dictionary = {&"sections": {&"ship": {&"hull_integrity": NAN}}}
	var result: SaveResult = SaveCodecScript.encode(envelope)
	assert_false(result.ok())
	assert_string_contains(result.summary(), "<save>/sections/ship/hull_integrity")


func test_every_problem_is_reported_not_only_the_first() -> void:
	var envelope: Dictionary = {
		&"a": NAN,
		&"b": Vector2.ZERO,
		&"c": {&"d": INF},
	}
	var result: SaveResult = SaveCodecScript.encode(envelope)
	assert_eq(result.problems.size(), 3, "all three faults should be reported in one pass")


func test_ordinary_shapes_are_accepted() -> void:
	var envelope: Dictionary = {
		&"empty_list": [],
		&"empty_table": {},
		&"nothing": null,
		&"yes": true,
		&"big": 9223372036854775807,
		&"negative": -1,
		&"text": "an em dash — and a þ",
		&"name": &"an_id",
		&"nested": [[{&"deep": [{}]}]],
		&"zero": 0.0,
	}
	var result: SaveResult = SaveCodecScript.encode(envelope)
	assert_true(result.ok(), "ordinary data was refused: %s" % result.summary())
	assert_gt(result.bytes.size(), 0)


func test_a_typed_container_is_normalised_rather_than_refused() -> void:
	var typed: Array[StringName] = [&"b", &"a"]
	var plain: Array = [&"b", &"a"]
	var from_typed: SaveResult = SaveCodecScript.encode({&"ids": typed})
	var from_plain: SaveResult = SaveCodecScript.encode({&"ids": plain})
	assert_true(from_typed.ok(), from_typed.summary())
	assert_eq(from_typed.bytes, from_plain.bytes)


func test_a_string_key_and_a_name_key_encode_identically() -> void:
	var as_text: SaveResult = SaveCodecScript.encode({"alpha": 1, "beta": 2})
	var as_names: SaveResult = SaveCodecScript.encode({&"alpha": 1, &"beta": 2})
	assert_true(as_text.ok(), as_text.summary())
	assert_eq(as_text.bytes, as_names.bytes)


func test_array_order_is_preserved() -> void:
	var result: SaveResult = SaveCodecScript.encode({&"log": [&"third", &"first", &"second"]})
	assert_true(result.ok(), result.summary())
	var back: SaveResult = SaveCodecScript.decode(result.bytes)
	var entries: Variant = back.envelope[&"log"]
	assert_eq(typeof(entries), TYPE_ARRAY)
	var list: Array = entries
	assert_eq(list, [&"third", &"first", &"second"] as Array)


func test_an_empty_file_is_refused_without_troubling_the_decoder() -> void:
	var result: SaveResult = SaveCodecScript.decode(PackedByteArray())
	assert_false(result.ok())
	assert_string_contains(result.summary(), "truncated")
	assert_engine_error_count(0)


func test_a_file_that_is_not_an_encoded_envelope_is_refused_quietly() -> void:
	var not_a_save: PackedByteArray = var_to_bytes("just a string, not a save")
	var result: SaveResult = SaveCodecScript.decode(not_a_save)
	assert_false(result.ok())
	assert_string_contains(result.summary(), "not a Draywar save")
	assert_engine_error_count(0)


func test_a_file_with_extra_bytes_on_the_end_is_refused() -> void:
	var good: SaveResult = SaveCodecScript.encode({&"a": 1})
	var padded: PackedByteArray = good.bytes.duplicate()
	padded.append(0)
	var result: SaveResult = SaveCodecScript.decode(padded)
	assert_false(result.ok())
	assert_string_contains(result.summary(), "canonical")


func test_a_file_whose_keys_are_out_of_order_is_refused() -> void:
	var out_of_order: Dictionary = {}
	out_of_order[&"zebra"] = 1
	out_of_order[&"alpha"] = 2
	var result: SaveResult = SaveCodecScript.decode(var_to_bytes(out_of_order))
	assert_false(result.ok())
	assert_string_contains(result.summary(), "canonical")


func test_a_truncated_file_is_refused() -> void:
	var good: PackedByteArray = var_to_bytes({&"only_key": "a value long enough to cut"})
	var cut: PackedByteArray = good.slice(0, good.size() - EIGHT_BYTES)
	var result: SaveResult = SaveCodecScript.decode(cut)
	assert_false(result.ok())
	assert_engine_error_count(2)


func _wrapped(value: Variant) -> Dictionary:
	return {&"sections": {&"probe": value}}
