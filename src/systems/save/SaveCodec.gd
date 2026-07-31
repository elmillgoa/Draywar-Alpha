extends RefCounted

## Save bytes, deterministically — Alpha A0.
##
## Acceptance: a save round-trips **byte-equivalently**.
##
##   1. Keys are sorted at every depth (Godot dictionaries iterate insertion order).
##   2. Values survive bit for bit — binary `var_to_bytes` / `bytes_to_var`.
##
## Allowed: null, bool, int, float, String, StringName, Array, Dictionary.
## Vector3 and other maths types are refused (32-bit float loss).


## An accumulating problem list, passed down the recursion.
class Problems:
	extends RefCounted

	var lines: PackedStringArray = []

	func add(line: String) -> void:
		lines.append(line)


## Where messages start numbering the tree from.
const ROOT_PATH: String = "<save>"

## Every type a save may contain. Anything else is refused.
const ALLOWED_TYPES: Array[int] = [
	TYPE_NIL,
	TYPE_BOOL,
	TYPE_INT,
	TYPE_FLOAT,
	TYPE_STRING,
	TYPE_STRING_NAME,
	TYPE_ARRAY,
	TYPE_DICTIONARY,
]


## The canonical form of an envelope, plus everything wrong with it.
static func canonicalise(envelope_data: Dictionary) -> SaveResult:
	var problems: Problems = Problems.new()
	var canonical: Dictionary = _canonical_dictionary(envelope_data, ROOT_PATH, problems)
	var result: SaveResult = SaveResult.new()
	result.problems = problems.lines
	if result.ok():
		result.envelope = canonical
	return result


## The bytes of a save file: the canonical envelope, encoded.
static func encode(envelope_data: Dictionary) -> SaveResult:
	var result: SaveResult = canonicalise(envelope_data)
	if result.ok():
		result.bytes = var_to_bytes(result.envelope)
	return result


## The envelope inside a save file's bytes.
static func decode(raw: PackedByteArray) -> SaveResult:
	var shape: String = _encoded_dictionary_problem(raw)
	if not shape.is_empty():
		return SaveResult.failed(shape)

	var value: Variant = bytes_to_var(raw)
	if typeof(value) != TYPE_DICTIONARY:
		return SaveResult.failed(
			(
				(
					"the file decoded to a %s, not a save envelope. It is either not a "
					% type_string(typeof(value))
				)
				+ "Draywar save or it is damaged."
			)
		)

	var decoded: Dictionary = value
	var result: SaveResult = canonicalise(decoded)
	if not result.ok():
		return result

	if var_to_bytes(result.envelope) != raw:
		return SaveResult.failed(
			(
				"the file is not in canonical form: re-encoding what it contains does "
				+ "not reproduce it byte for byte. It has been edited, truncated, "
				+ "padded, or written by something other than this save service."
			)
		)

	result.bytes = raw
	return result


## Whether `raw` even begins as an encoded Dictionary. Returns "" if it does.
static func _encoded_dictionary_problem(raw: PackedByteArray) -> String:
	var smallest: int = var_to_bytes({}).size()
	if raw.size() < smallest:
		return (
			(
				"the file is %d byte(s) long; the smallest possible save is %d. It is "
				% [raw.size(), smallest]
			)
			+ "empty or truncated."
		)
	if raw.decode_u16(0) != TYPE_DICTIONARY:
		return (
			"the file does not begin with an encoded save envelope. It is not a " + "Draywar save."
		)
	return ""


static func _canonical_value(value: Variant, path: String, problems: Problems) -> Variant:
	var kind: int = typeof(value)
	if kind == TYPE_ARRAY:
		var as_array: Array = value
		return _canonical_array(as_array, path, problems)
	if kind == TYPE_DICTIONARY:
		var as_dictionary: Dictionary = value
		return _canonical_dictionary(as_dictionary, path, problems)
	if kind == TYPE_FLOAT:
		var as_float: float = value
		_check_float(as_float, path, problems)
		return value
	if ALLOWED_TYPES.has(kind):
		return value
	problems.add(_refusal(path, kind))
	return null


static func _check_float(value: float, path: String, problems: Problems) -> void:
	if is_finite(value):
		return
	problems.add(
		(
			(
				"%s holds %s, which is not a finite number. A NaN or an infinity in a "
				% [path, str(value)]
			)
			+ "save is a bug that happened earlier; storing it hides the moment it "
			+ "was still fixable."
		)
	)


static func _refusal(path: String, kind: int) -> String:
	var advice: String = ""
	if kind == TYPE_VECTOR2 or kind == TYPE_VECTOR3 or kind == TYPE_VECTOR4:
		advice = (
			" Store the components as separate floats: in a standard Godot build a "
			+ "vector holds 32-bit floats, so putting a position in one has already "
			+ "lost half the precision before the save service sees it."
		)
	return (
		(
			"%s holds a %s. A save may contain only: null, bool, int, float, String, "
			% [path, type_string(kind)]
		)
		+ "StringName, Array, Dictionary. See the header of "
		+ "src/systems/save/SaveCodec.gd for why the list is that short."
		+ advice
	)


static func _canonical_array(source: Array, path: String, problems: Problems) -> Array:
	var out: Array = []
	var index: int = 0
	for element: Variant in source:
		out.append(_canonical_value(element, "%s[%d]" % [path, index], problems))
		index += 1
	return out


static func _canonical_dictionary(
	source: Dictionary, path: String, problems: Problems
) -> Dictionary:
	var names: Array[StringName] = []
	var seen: Dictionary[StringName, bool] = {}

	for key: Variant in source:
		var kind: int = typeof(key)
		if kind != TYPE_STRING and kind != TYPE_STRING_NAME:
			problems.add(
				(
					(
						"%s is keyed by a %s. Every key in a save is a name: a String or "
						% [path, type_string(kind)]
					)
					+ "a StringName. An indexed thing is an Array."
				)
			)
			continue
		var key_name: StringName = StringName(str(key))
		if seen.has(key_name):
			problems.add(
				(
					(
						"%s has two keys that normalise to '%s'. Normalising would drop "
						% [path, key_name]
					)
					+ "one of them silently, so it is refused instead."
				)
			)
			continue
		seen[key_name] = true
		names.append(key_name)

	names.sort_custom(_alphabetically)

	var out: Dictionary = {}
	for key_name: StringName in names:
		var child: String = "%s/%s" % [path, key_name]
		out[key_name] = _canonical_value(source[key_name], child, problems)
	return out


static func _alphabetically(first: StringName, second: StringName) -> bool:
	return String(first) < String(second)
