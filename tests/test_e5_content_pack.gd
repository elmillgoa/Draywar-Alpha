extends GutTest

## E5.2 Systems + stations pack.
##
## Implements: docs/BETA_E5_CONTENT_SCALE.md E5.2

const REQUIRED_SYSTEMS: Array[StringName] = [
	&"system_alpha",
	&"system_beta",
	&"system_gamma",
	&"system_delta",
	&"system_epsilon",
	&"system_zeta",
]


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_exactly_six_systems_including_greek_ids() -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(&"star_systems")
	assert_eq(ids.size(), 6)
	for system_id: StringName in REQUIRED_SYSTEMS:
		assert_true(ContentLibrary.has_item(system_id), "%s loads" % system_id)
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))


func test_stations_nine_to_ten_and_bidirectional_wiring() -> void:
	var station_ids: Array[StringName] = ContentLibrary.ids_in(&"stations")
	assert_gte(station_ids.size(), 9)
	assert_lte(station_ids.size(), 10)
	assert_lte(station_ids.size(), Balance.CONTENT_BUDGET[&"stations"])
	for station_id: StringName in station_ids:
		var station: Station = ContentLibrary.item(station_id) as Station
		assert_ne(station, null)
		assert_true(ContentLibrary.has_item(station.system_id), "%s system exists" % station_id)
		var system: StarSystem = ContentLibrary.item(station.system_id) as StarSystem
		assert_ne(system, null)
		assert_true(
			system.station_ids.has(station_id),
			"%s listed on %s.station_ids" % [station_id, station.system_id]
		)


func test_new_systems_have_dock_and_flavor() -> void:
	for system_id: StringName in [&"system_delta", &"system_epsilon", &"system_zeta"]:
		var system: StarSystem = ContentLibrary.item(system_id) as StarSystem
		assert_ne(system, null)
		assert_gte(system.station_ids.size(), 1, "%s needs a dock" % system_id)
		assert_false(system.flavor_line.is_empty(), "%s flavor" % system_id)


func test_new_dock_controllers_have_contacts() -> void:
	var new_stations: Array[StringName] = [
		&"station_delta_port",
		&"station_delta_yard",
		&"station_epsilon_belt",
		&"station_zeta_spur",
	]
	for station_id: StringName in new_stations:
		var station: Station = ContentLibrary.item(station_id) as Station
		assert_ne(station, null)
		var found: int = 0
		for person_id: StringName in ContentLibrary.ids_in(&"people"):
			var person: Person = ContentLibrary.item(person_id) as Person
			if person != null and person.primary_entity_id == station.controller_entity_id:
				found += 1
		assert_gte(found, 1, "%s controller has ≥1 contact person" % station_id)


func test_status_moment_resolves_for_every_system() -> void:
	for system_id: StringName in REQUIRED_SYSTEMS:
		var system: StarSystem = ContentLibrary.item(system_id) as StarSystem
		assert_ne(system, null)
		assert_true(ContentLibrary.has_item(system.held_by), "%s controller entity" % system_id)
		var payload: Dictionary = StandingService.status_for_system(system_id)
		var uncontrolled_raw: Variant = payload.get(StandingService.STATUS_KEY_UNCONTROLLED, true)
		var uncontrolled: bool = true
		if typeof(uncontrolled_raw) == TYPE_BOOL:
			uncontrolled = uncontrolled_raw
		assert_false(uncontrolled, "%s has controller status" % system_id)
		var entity_raw: Variant = payload.get(StandingService.STATUS_KEY_ENTITY_ID, &"")
		var entity_id: StringName = &""
		if typeof(entity_raw) == TYPE_STRING_NAME:
			entity_id = entity_raw
		elif typeof(entity_raw) == TYPE_STRING:
			var entity_text: String = entity_raw
			entity_id = StringName(entity_text)
		assert_eq(entity_id, system.held_by)
