extends GutTest

## E5.1 Content budget lift — ceilings only; no new play content.
##
## Implements: docs/BETA_E5_CONTENT_SCALE.md E5.1

const ContentLibraryScript = preload("res://src/systems/ContentLibrary.gd")

## Live pack after S9 floor fill (E5 was 6/10/19).
const LIVE_SYSTEMS: int = 8
const LIVE_STATIONS: int = 16
const LIVE_PEOPLE: int = 35

## S9 Steam §10 ceilings (were E5 8/10/24).
const S9_STAR_SYSTEMS_CEILING: int = 10
const S9_STATIONS_CEILING: int = 22
const S9_PEOPLE_CEILING: int = 50


func test_e5_content_budget_ceilings() -> void:
	assert_eq(Balance.CONTENT_BUDGET[&"star_systems"], S9_STAR_SYSTEMS_CEILING)
	assert_eq(Balance.CONTENT_BUDGET[&"stations"], S9_STATIONS_CEILING)
	assert_eq(Balance.CONTENT_BUDGET[&"people"], S9_PEOPLE_CEILING)


func test_live_content_loads_under_e5_ceilings() -> void:
	var systems: Array[StringName] = ContentLibrary.ids_in(&"star_systems")
	var stations: Array[StringName] = ContentLibrary.ids_in(&"stations")
	var people: Array[StringName] = ContentLibrary.ids_in(&"people")
	assert_eq(systems.size(), LIVE_SYSTEMS, "S9 live systems under ceiling")
	assert_eq(stations.size(), LIVE_STATIONS, "S9 live stations under ceiling")
	assert_eq(people.size(), LIVE_PEOPLE, "S9 live people under ceiling")
	assert_lte(systems.size(), Balance.CONTENT_BUDGET[&"star_systems"])
	assert_lte(stations.size(), Balance.CONTENT_BUDGET[&"stations"])
	assert_lte(people.size(), Balance.CONTENT_BUDGET[&"people"])
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))


func test_star_systems_over_e5_budget_fails_loudly() -> void:
	var root: String = _fixture_root("e5_systems_overbudget")
	var ceiling: int = Balance.CONTENT_BUDGET[&"star_systems"]
	for index: int in range(ceiling + 1):
		_write_system(
			root.path_join("star_systems/s%d.tres" % index),
			StringName("fixture_sys_%d" % index),
			"Sys %d" % index
		)

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)

	assert_gt(problems.size(), 0, "exceeding star_systems budget must fail loudly")
	assert_string_contains("\n".join(problems), "ceiling")
	library.free()


func _fixture_root(label: String) -> String:
	var path: String = "user://gut_e5_budget_%s" % label
	if DirAccess.dir_exists_absolute(path):
		_wipe_dir(path)
	DirAccess.make_dir_recursive_absolute(path)
	return path


func _wipe_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var child: String = path.path_join(entry)
		if dir.current_is_dir():
			_wipe_dir(child)
			DirAccess.remove_absolute(child)
		else:
			DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()


func _write_system(path: String, id: StringName, display_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var system := StarSystem.new()
	system.id = id
	system.display_name = display_name
	system.held_by = StarSystem.HELD_BY_NOBODY
	system.policing = StarSystem.POLICED_BY_NOBODY
	assert_eq(ResourceSaver.save(system, path), OK, "save fixture %s" % path)
