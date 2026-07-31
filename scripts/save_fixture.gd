extends RefCounted

## The hostile save fixture — Alpha A0. Developer tooling; does not ship.
##
## Deliberately loaded with values that break serialisers rather than tidy
## career numbers. A round trip over friendly data passes no matter what the
## serialiser does.
##
## Awkward floats are built by arithmetic: denormals and negative zero cannot
## be written as GDScript literals reliably (constant pooling of zeroes).

const SECTION_PROBE: StringName = &"probe"
const SECTION_NUMBERS: StringName = &"awkward_numbers"
const SECTION_EDGES: StringName = &"structural_edges"
const SECTION_LEDGER: StringName = &"ledger"
const SECTION_STANDING: StringName = &"standing"
const SECTION_SHIPS: StringName = &"ships"
const SECTION_CAPTAIN: StringName = &"captain"
const SECTION_LOCATION: StringName = &"location"

## Non-ASCII career name on purpose.
const PROFILE_NAME: String = "Vhen Draska — Ostrich, 3rd Levy"


## Positive zero's evil twin: equal to zero, different bit for bit.
static func negative_zero() -> float:
	var one: float = 1.0
	return (one - one) * -1.0


## Plain positive zero, also built rather than written.
static func positive_zero() -> float:
	var one: float = 1.0
	return one - one


## The smallest positive normal double.
static func smallest_normal() -> float:
	var base: float = 1e-308
	return base * 2.2250738585072014


## A genuine denormal, around 1e-310.
static func a_denormal() -> float:
	var small: float = 1e-300
	return small * 1e-10


## Every awkward float, keyed by what makes it awkward.
static func awkward_floats() -> Dictionary:
	return {
		&"negative_zero": negative_zero(),
		&"smallest_normal": smallest_normal(),
		&"denormal": a_denormal(),
		&"largest_finite": 1.7976931348623157e308,
		&"one_third": 1.0 / 3.0,
		&"pi": PI,
		&"two_to_the_53_plus_2": 9007199254740994.0,
		&"needs_full_precision": -123456.78901234567,
		&"just_past_1e16": 1.0000000000000002e16,
		&"small_exponent": 1e-7,
		&"whole_but_a_float": 7.0,
		&"plain_zero": positive_zero(),
	}


## The test state. Keys inserted in a deliberately unhelpful order.
static func sections() -> Dictionary:
	var floats: Dictionary = awkward_floats()
	return {
		SECTION_LEDGER: _ledger(),
		SECTION_CAPTAIN: _captain(),
		SECTION_NUMBERS: floats,
		SECTION_SHIPS: _ships(floats),
		SECTION_PROBE: _probe(floats),
		SECTION_EDGES: _edges(),
		SECTION_LOCATION: _location(floats),
		SECTION_STANDING: _standing(),
	}


## Same state, different insertion order and some String keys.
static func sections_in_another_order() -> Dictionary:
	var floats: Dictionary = awkward_floats()
	var reordered_floats: Dictionary = {}
	var names: Array = floats.keys()
	names.reverse()
	for key: Variant in names:
		reordered_floats[str(key)] = floats[key]
	return {
		"standing": _standing(),
		"location": _location(floats),
		SECTION_SHIPS: _ships(floats),
		SECTION_NUMBERS: reordered_floats,
		"captain": _captain(),
		"probe": _probe(floats),
		SECTION_EDGES: _edges(),
		SECTION_LEDGER: _ledger(),
	}


## Everything wrong with this fixture as a *test* — empty means still hostile.
static func hostility_problems() -> PackedStringArray:
	var found: PackedStringArray = []
	found.append_array(_negative_zero_problems())
	found.append_array(_denormal_problems())
	found.append_array(_text_loss_problems())
	found.append_array(_type_mix_problems())
	return found


static func _negative_zero_problems() -> PackedStringArray:
	var found: PackedStringArray = []
	var minus: float = negative_zero()
	var plus: float = positive_zero()
	if minus != plus:
		found.append("negative_zero() is not numerically zero; it is %s." % str(minus))
	if var_to_bytes(minus) == var_to_bytes(plus):
		found.append(
			(
				"negative_zero() and positive_zero() have the same bits. Both have to be "
				+ "built by arithmetic."
			)
		)
	if not _has_negative_sign(minus):
		found.append("negative_zero() is positive zero; the sign bit is not set.")
	if _has_negative_sign(plus):
		found.append("positive_zero() is NEGATIVE zero.")
	return found


static func _has_negative_sign(value: float) -> bool:
	return var_to_bytes(value) != var_to_bytes(absf(value))


static func _denormal_problems() -> PackedStringArray:
	var found: PackedStringArray = []
	var tiny: float = a_denormal()
	if tiny <= 0.0:
		found.append("a_denormal() is %s, not a positive denormal." % str(tiny))
	elif tiny >= smallest_normal():
		found.append(
			"a_denormal() is %s, which is not below the smallest normal double." % str(tiny)
		)
	return found


static func _text_loss_problems() -> PackedStringArray:
	var found: PackedStringArray = []
	var state: Dictionary = sections()
	var through_text: Variant = str_to_var(var_to_str(state))
	if var_to_bytes(through_text) == var_to_bytes(state):
		found.append(
			(
				"the fixture survives a text round trip intact, so it can no longer "
				+ "tell an exact serialiser from a lossy one."
			)
		)
	return found


static func _type_mix_problems() -> PackedStringArray:
	var found: PackedStringArray = []
	var edges: Dictionary = _edges()
	if typeof(edges[&"seven_as_an_int"]) != TYPE_INT:
		found.append("the fixture no longer contains an int beside an equal float.")
	if typeof(edges[&"seven_as_a_float"]) != TYPE_FLOAT:
		found.append("the fixture no longer contains a float beside an equal int.")
	if typeof(edges[&"a_string"]) != TYPE_STRING:
		found.append("the fixture no longer contains a String beside a StringName.")
	if typeof(edges[&"a_string_name"]) != TYPE_STRING_NAME:
		found.append("the fixture no longer contains a StringName beside a String.")
	return found


static func _probe(floats: Dictionary) -> Dictionary:
	return {
		&"label": &"a0_probe",
		&"shield": floats[&"smallest_normal"],
		&"structure": floats[&"negative_zero"],
		&"tick": 9007199254740993,
	}


static func _captain() -> Dictionary:
	return {
		&"name": PROFILE_NAME,
		&"callsign": &"ostrich_actual",
		&"credits": 41250,
		&"notes": "",
	}


static func _ships(floats: Dictionary) -> Array:
	return [
		{
			&"name": "Ostrich",
			&"hull_integrity": floats[&"one_third"],
			&"stored_at": null,
			&"hardpoints": [&"mount_alpha", &"mount_beta"],
			&"cargo": {&"alloy": 12, &"grain": 0},
		},
		{
			&"name": "",
			&"hull_integrity": floats[&"negative_zero"],
			&"stored_at": &"station_kell",
			&"hardpoints": [],
			&"cargo": {},
		},
	]


static func _standing() -> Dictionary:
	return {
		&"faction_one": 0,
		&"faction_two": -40,
		&"faction_three": 65,
		&"faction_four": -1,
		&"faction_five": 12,
		&"faction_six": 0,
		&"local_authority_kell": -75,
		&"local_authority_ardh": 3,
	}


static func _ledger() -> Array:
	return [
		{&"tick": 0, &"what": &"charter_signed", &"who": &"faction_one", &"note": ""},
		{&"tick": 9007199254740993, &"what": &"betrayal", &"who": &"faction_two", &"note": "—"},
		{&"tick": -1, &"what": &"debt_missed", &"who": &"faction_five", &"note": "grace 1/3"},
	]


static func _location(floats: Dictionary) -> Dictionary:
	return {
		&"system": &"kell_reach",
		&"x": floats[&"needs_full_precision"],
		&"y": floats[&"smallest_normal"],
		&"z": floats[&"denormal"],
		&"docked_at": null,
	}


static func _edges() -> Dictionary:
	return {
		&"an_empty_list": [],
		&"an_empty_table": {},
		&"a_null": null,
		&"a_true": true,
		&"a_false": false,
		&"seven_as_an_int": 7,
		&"seven_as_a_float": 7.0,
		&"a_string": "seven",
		&"a_string_name": &"seven",
		&"int64_max": 9223372036854775807,
		&"int64_min": -9223372036854775808,
		&"unicode": "— ż Þ 東 🜃",
		&"deeply_nested": [[[{&"z": [1, {&"a": []}]}]]],
	}
