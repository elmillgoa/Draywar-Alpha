extends GutTest

## Tests for the content pipeline — Alpha A0.
##
## Discovery is independent of the loader. Bad content is reported, not skipped.

const ContentLibraryScript = preload("res://src/systems/ContentLibrary.gd")

const AUTOLOAD_SETTING: String = "autoload/ContentLibrary"
const SINGLETON_MARKER: String = "*"
const FIXTURE_PREFIX: String = "user://a0_content_fixture_"


func after_each() -> void:
	var user_dir: DirAccess = DirAccess.open("user://")
	if user_dir == null:
		return
	for entry: String in user_dir.get_directories():
		if ("user://" + entry).begins_with(FIXTURE_PREFIX):
			_wipe("user://" + entry)


func test_library_is_registered_as_a_singleton_autoload() -> void:
	var value: String = str(ProjectSettings.get_setting(AUTOLOAD_SETTING, ""))
	assert_gt(value.length(), 0, "project.godot must declare %s" % AUTOLOAD_SETTING)
	assert_true(
		value.begins_with(SINGLETON_MARKER),
		"the content library must be a singleton ('*' prefix), got '%s'" % value
	)
	assert_file_exists(value.trim_prefix(SINGLETON_MARKER))


func test_the_content_shipped_in_the_project_is_valid() -> void:
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(
		problems.size(),
		0,
		"content loaded at boot reported problems:\n  %s" % "\n  ".join(problems)
	)


func test_playable_system_alpha_has_station_and_gate() -> void:
	# A1: system_alpha is the playable gray box with a dock and a gate marker.
	assert_true(ContentLibrary.has_item(&"system_alpha"))
	var item: ContentItem = ContentLibrary.item(&"system_alpha")
	assert_true(item is StarSystem)
	var system: StarSystem = item as StarSystem
	assert_gte(system.station_ids.size(), 1, "system_alpha must list at least one station for A1")
	assert_gte(
		system.gate_destination_ids.size(),
		1,
		"system_alpha must list at least one gate destination for A1"
	)
	assert_true(
		system.station_ids.has(&"station_alpha_port"),
		"system_alpha should include station_alpha_port"
	)
	assert_true(
		system.gate_destination_ids.has(&"system_beta"),
		"system_alpha gate should point at system_beta"
	)


func test_a5_systems_have_stations_gates_and_distinct_policing() -> void:
	# A5: three systems, each dockable, linked by gates, distinct security.
	var expected: Dictionary = {
		&"system_alpha":
		{
			&"station": &"station_alpha_port",
			&"policing": StarSystem.POLICED_BY_PATROLS,
		},
		&"system_beta":
		{
			&"station": &"station_beta_hub",
			&"policing": StarSystem.POLICED_BY_CONTESTED,
		},
		&"system_gamma":
		{
			&"station": &"station_gamma_outpost",
			&"policing": StarSystem.POLICED_BY_NOBODY,
		},
	}
	for system_id: StringName in expected:
		assert_true(ContentLibrary.has_item(system_id), "missing system '%s'" % system_id)
		var item: ContentItem = ContentLibrary.item(system_id)
		assert_true(item is StarSystem, "'%s' must load as a StarSystem" % system_id)
		var system: StarSystem = item as StarSystem
		var expect: Dictionary = expected[system_id]
		var expect_station: StringName = expect[&"station"]
		var expect_policing: StringName = expect[&"policing"]
		assert_true(
			system.station_ids.has(expect_station),
			"'%s' must include station %s" % [system_id, expect_station]
		)
		assert_gt(system.gate_destination_ids.size(), 0, "'%s' needs a gate" % system_id)
		assert_eq(system.policing, expect_policing, "'%s' policing" % system_id)


func test_shipped_station_and_hull_exist_and_are_valid() -> void:
	assert_true(ContentLibrary.has_item(&"station_alpha_port"), "station_alpha_port missing")
	assert_true(ContentLibrary.has_item(&"hull_courier"), "hull_courier missing")
	var station_item: ContentItem = ContentLibrary.item(&"station_alpha_port")
	assert_true(station_item is Station)
	var station: Station = station_item as Station
	assert_eq(station.system_id, &"system_alpha")
	assert_eq(station.validation_errors().size(), 0)
	var hull_item: ContentItem = ContentLibrary.item(&"hull_courier")
	assert_true(hull_item is Hull)
	var hull: Hull = hull_item as Hull
	assert_eq(hull.validation_errors().size(), 0)
	assert_gt(hull.max_speed, 0.0)


func test_every_content_file_on_disk_is_discovered_and_nothing_extra_is() -> void:
	var paths: PackedStringArray = _tres_paths(ContentLibrary.CONTENT_ROOT)
	paths.sort()
	assert_gt(paths.size(), 0, "no .tres content found under %s" % ContentLibrary.CONTENT_ROOT)

	for path: String in paths:
		var content: ContentItem = load(path) as ContentItem
		assert_not_null(content, "%s should load as a ContentItem" % path)
		if content == null:
			continue
		assert_true(
			ContentLibrary.has_item(content.id),
			"'%s' is on disk but the library did not discover id '%s'" % [path, content.id]
		)

	assert_eq(
		ContentLibrary.count(),
		paths.size(),
		"the library holds a different number of items than there are files on disk"
	)


func test_a_system_added_as_a_file_alone_is_picked_up() -> void:
	var root: String = _fixture_root("added")
	_write_system(root.path_join("star_systems/one.tres"), &"fixture_one", "One")

	var library := ContentLibraryScript.new()
	var before: PackedStringArray = library.load_from(root)
	assert_eq(before.size(), 0, "clean fixture reported: %s" % "\n".join(before))
	assert_eq(library.count(), 1, "one file should mean one item")

	_write_system(root.path_join("star_systems/two.tres"), &"fixture_two", "Two")
	var after: PackedStringArray = library.load_from(root)

	assert_eq(after.size(), 0, "adding a file reported: %s" % "\n".join(after))
	assert_eq(library.count(), 2, "the second file should have been found by scanning")
	assert_true(library.has_item(&"fixture_two"), "the new id should resolve")
	assert_eq(library.ids_in(&"star_systems").size(), 2)
	library.free()


func test_the_directory_name_is_the_category() -> void:
	var root: String = _fixture_root("category")
	_write_system(root.path_join("star_systems/a.tres"), &"fixture_sys", "Sys")

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)

	assert_eq(problems.size(), 0, "clean fixture reported: %s" % "\n".join(problems))
	assert_eq(
		library.categories(), [&"star_systems"] as Array[StringName], "category comes from the path"
	)
	library.free()


func test_an_item_that_fails_its_own_validation_is_reported() -> void:
	var root: String = _fixture_root("invalid")
	_write_system(root.path_join("star_systems/ok.tres"), &"fixture_ok", "Fine")
	_write_system(root.path_join("star_systems/bad.tres"), &"", "")

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)
	var joined: String = "\n".join(problems)

	assert_gt(problems.size(), 0, "a malformed item must be reported, not skipped quietly")
	assert_string_contains(joined, "bad.tres")
	assert_string_contains(joined, "id")
	assert_eq(library.count(), 1, "only the valid item should be in the library")
	library.free()


func test_a_file_that_is_not_content_is_reported() -> void:
	var root: String = _fixture_root("wrongtype")
	DirAccess.make_dir_recursive_absolute(root.path_join("star_systems"))
	var stranger: Resource = Resource.new()
	assert_eq(ResourceSaver.save(stranger, root.path_join("star_systems/stranger.tres")), OK)

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)

	assert_gt(problems.size(), 0, "a non-ContentItem resource must be reported")
	assert_string_contains("\n".join(problems), "stranger.tres")
	assert_eq(library.count(), 0, "it must not be counted as content")
	library.free()


func test_two_items_sharing_an_id_are_reported() -> void:
	var root: String = _fixture_root("duplicate")
	_write_system(root.path_join("star_systems/first.tres"), &"fixture_clash", "First")
	_write_system(root.path_join("star_systems/second.tres"), &"fixture_clash", "Second")

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)

	assert_gt(problems.size(), 0, "a duplicate id must be reported")
	assert_string_contains("\n".join(problems), "fixture_clash")
	assert_eq(library.count(), 1, "the clash must not silently overwrite the first item")
	library.free()


func test_a_missing_content_root_is_an_error_not_an_empty_library() -> void:
	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(FIXTURE_PREFIX + "nonexistent")

	assert_gt(problems.size(), 0, "an unreadable content root must be an error")
	assert_eq(library.count(), 0)
	library.free()


func test_a_content_root_with_no_categories_is_an_error() -> void:
	var root: String = _fixture_root("empty")
	DirAccess.make_dir_recursive_absolute(root)

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)

	assert_gt(problems.size(), 0, "an empty content root must be an error, not an empty result")
	library.free()


func test_content_loose_in_the_root_is_reported() -> void:
	var root: String = _fixture_root("loose")
	_write_system(root.path_join("star_systems/ok.tres"), &"fixture_ok", "Fine")
	_write_system(root.path_join("stray.tres"), &"fixture_stray", "Stray")

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)

	assert_gt(problems.size(), 0, "a file with no category must be reported")
	assert_string_contains("\n".join(problems), "stray.tres")
	library.free()


func test_a_category_over_its_budget_is_reported() -> void:
	var root: String = _fixture_root("overbudget")
	var ceiling: int = Balance.CONTENT_BUDGET[&"hulls"]
	for index: int in range(ceiling + 1):
		_write_system(
			root.path_join("hulls/h%d.tres" % index),
			StringName("fixture_hull_%d" % index),
			"Hull %d" % index
		)

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)

	assert_gt(problems.size(), 0, "exceeding a content budget must fail loudly")
	assert_string_contains("\n".join(problems), "ceiling")
	library.free()


func test_a_category_with_no_declared_budget_is_reported() -> void:
	var root: String = _fixture_root("nobudget")
	_write_system(root.path_join("gadgets/a.tres"), &"fixture_gadget", "Gadget")

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)

	assert_gt(problems.size(), 0, "a category with no ceiling in Balance.gd must be reported")
	assert_string_contains("\n".join(problems), "gadgets")
	library.free()


func test_every_live_category_declares_a_ceiling_and_stays_under_it() -> void:
	for category: StringName in ContentLibrary.categories():
		assert_true(
			Balance.CONTENT_BUDGET.has(category),
			"category '%s' has no ceiling in src/data/Balance.gd" % category
		)
		if not Balance.CONTENT_BUDGET.has(category):
			continue
		var ceiling: int = Balance.CONTENT_BUDGET[category]
		var held: int = ContentLibrary.ids_in(category).size()
		assert_lte(
			held, ceiling, "category '%s' holds %d of a ceiling of %d" % [category, held, ceiling]
		)


func test_exported_remap_entries_resolve_to_one_loadable_path_each() -> void:
	assert_eq(
		ContentLibraryScript.resource_entries(PackedStringArray(["alloy.tres"])),
		PackedStringArray(["alloy.tres"])
	)
	assert_eq(
		ContentLibraryScript.resource_entries(PackedStringArray(["alloy.tres.remap"])),
		PackedStringArray(["alloy.tres"])
	)
	assert_eq(
		ContentLibraryScript.resource_entries(PackedStringArray(["alloy.res", "alloy.tres.remap"])),
		PackedStringArray(["alloy.tres"])
	)
	assert_eq(
		ContentLibraryScript.resource_entries(PackedStringArray(["README.md", "Commodity.gd"])),
		PackedStringArray([])
	)


func test_ids_come_back_in_alphabetical_order() -> void:
	var root: String = _fixture_root("ordering")
	_write_system(root.path_join("star_systems/z.tres"), &"zulu", "Zulu")
	_write_system(root.path_join("star_systems/a.tres"), &"alpha", "Alpha")
	_write_system(root.path_join("star_systems/m.tres"), &"mike", "Mike")

	var library := ContentLibraryScript.new()
	var problems: PackedStringArray = library.load_from(root)
	assert_eq(problems.size(), 0, "clean fixture reported: %s" % "\n".join(problems))

	var expected: Array[StringName] = [&"alpha", &"mike", &"zulu"]
	assert_eq(library.ids(), expected, "ids() must be ordered by text")
	library.free()


func _fixture_root(suffix: String) -> String:
	return FIXTURE_PREFIX + suffix


func _write_system(path: String, id: StringName, label: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var item: StarSystem = StarSystem.new()
	item.id = id
	item.display_name = label
	item.held_by = StarSystem.HELD_BY_NOBODY
	item.policing = StarSystem.POLICED_BY_NOBODY
	assert_eq(ResourceSaver.save(item, path), OK, "could not write fixture %s" % path)


func _tres_paths(directory: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(_tres_paths(directory.path_join(sub)))
	for entry: String in dir.get_files():
		if entry.get_extension() == "tres":
			out.append(directory.path_join(entry))
	return out


func _wipe(directory: String) -> void:
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_wipe(directory.path_join(sub))
	for entry: String in dir.get_files():
		DirAccess.remove_absolute(directory.path_join(entry))
	DirAccess.remove_absolute(directory)
