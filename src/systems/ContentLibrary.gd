extends Node

## The content pipeline — Alpha A0.
##
## Autoload named `ContentLibrary`. It answers questions about content; it does
## not decide anything with it.
##
## **It is never told what exists.** On boot it scans `src/data/content/` and
## takes whatever is there. A directory is a category, every `.tres` inside it
## is an item, and the id written in the file is the key.
##
## Silently skipping bad content is this project's signature failure mode
## (`docs/traps.md`). Every fault is a reported problem, not a skip.
## `reload()` uses `push_error`; `load_from()` returns problems for tests.

## Where content lives. Categories are the directories immediately inside it.
const CONTENT_ROOT: String = "res://src/data/content"

## What a content file looks like. `.res` is the binary form of the same thing.
const RESOURCE_EXTENSIONS: PackedStringArray = ["tres", "res"]

## Exporting leaves one of these beside every converted text resource.
const EXPORT_REMAP_SUFFIX: String = ".remap"

var _items: Dictionary[StringName, ContentItem] = {}
var _category_of: Dictionary[StringName, StringName] = {}
var _categories: Array[StringName] = []
var _problems: PackedStringArray = []


func _ready() -> void:
	reload()


## Re-scans the content root and complains loudly about anything wrong.
func reload() -> void:
	_problems = load_from(CONTENT_ROOT)
	for problem: String in _problems:
		push_error("Content: " + problem)


## Replaces everything with what is under `root`, and returns what is wrong.
func load_from(root: String) -> PackedStringArray:
	_items = {}
	_category_of = {}
	_categories = []
	var found: PackedStringArray = []

	var root_dir: DirAccess = DirAccess.open(root)
	if root_dir == null:
		found.append(
			(
				"the content root '%s' could not be opened (%s). No content was loaded at all."
				% [root, error_string(DirAccess.get_open_error())]
			)
		)
		return found

	for loose: String in resource_entries(root_dir.get_files()):
		found.append(
			(
				(
					"'%s' sits directly in the content root. Content lives in a category "
					% root.path_join(loose)
				)
				+ "directory, because the directory name is the category."
			)
		)

	var directories: PackedStringArray = root_dir.get_directories()
	directories.sort()
	if directories.is_empty():
		found.append(
			(
				"the content root '%s' has no category directories. Either content has " % root
				+ "been deleted or the loader is pointed somewhere wrong; both are worse "
				+ "than an empty game, so this is an error rather than an empty result."
			)
		)
		return found

	for directory: String in directories:
		var category: StringName = StringName(directory)
		_categories.append(category)
		found.append_array(_load_category(root.path_join(directory), category))

	return found


## Every problem found by the last `reload()`. Empty means the content is sound.
func problems() -> PackedStringArray:
	return _problems.duplicate()


## How many valid items are loaded, across every category.
func count() -> int:
	return _items.size()


## Whether an id resolves. Use this before `item()` when absence is expected.
func has_item(id: StringName) -> bool:
	return _items.has(id)


## The item with this id, or null.
func item(id: StringName) -> ContentItem:
	if not _items.has(id):
		push_error(
			"Content: no item with id '%s'. Loaded ids are: %s" % [id, ", ".join(_id_strings())]
		)
		return null
	return _items[id]


## Every loaded id, in alphabetical order.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _items:
		out.append(id)
	out.sort_custom(_alphabetically)
	return out


## Every category directory found, sorted — including any that turned out empty.
func categories() -> Array[StringName]:
	return _categories.duplicate()


## The ids in one category, sorted. Empty for a category that does not exist.
func ids_in(category: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _category_of:
		if _category_of[id] == category:
			out.append(id)
	out.sort_custom(_alphabetically)
	return out


## The items in one category, sorted by id.
func items_in(category: StringName) -> Array[ContentItem]:
	var out: Array[ContentItem] = []
	for id: StringName in ids_in(category):
		out.append(_items[id])
	return out


## The resource paths worth loading, out of one directory listing.
##
## Exporting converts text resources to binary and drops a `.remap` beside them.
## De-duplicate by stem; prefer `.tres`.
static func resource_entries(entries: PackedStringArray) -> PackedStringArray:
	var chosen: Dictionary[String, String] = {}
	for raw: String in entries:
		var entry: String = raw
		if entry.ends_with(EXPORT_REMAP_SUFFIX):
			entry = entry.trim_suffix(EXPORT_REMAP_SUFFIX)
		if not RESOURCE_EXTENSIONS.has(entry.get_extension()):
			continue
		var stem: String = entry.get_basename()
		if chosen.has(stem) and chosen[stem].ends_with(".tres"):
			continue
		chosen[stem] = entry

	var out: PackedStringArray = []
	for stem: String in chosen:
		out.append(chosen[stem])
	out.sort()
	return out


func _load_category(directory: String, category: StringName) -> PackedStringArray:
	var found: PackedStringArray = []
	var paths: PackedStringArray = _collect_resources(directory)
	paths.sort()

	if paths.is_empty():
		found.append(
			(
				(
					"category '%s' (%s) contains no content. An empty category is either "
					% [category, directory]
				)
				+ "content that went missing or a directory that should not exist."
			)
		)

	var loaded: int = 0
	for path: String in paths:
		var problem: String = _load_item(path, category)
		if problem.is_empty():
			loaded += 1
		else:
			found.append(problem)

	if not Balance.CONTENT_BUDGET.has(category):
		found.append(
			(
				"category '%s' has no ceiling in src/data/Balance.gd. Every category " % category
				+ "declares its Alpha budget there so that exceeding it is caught rather "
				+ "than discovered."
			)
		)
	else:
		var ceiling: int = Balance.CONTENT_BUDGET[category]
		if loaded > ceiling:
			found.append(
				(
					(
						"category '%s' holds %d item(s); the Alpha budget ceiling is %d. "
						% [category, loaded, ceiling]
					)
					+ "Budgets are ceilings, not targets, and exceeding one is a stop "
					+ "condition - ask before raising it."
				)
			)

	return found


## Loads one file into the library. Returns "" on success, or what went wrong.
func _load_item(path: String, category: StringName) -> String:
	var resource: Resource = load(path)
	if resource == null:
		return "'%s' could not be loaded at all." % path

	var content: ContentItem = resource as ContentItem
	if content == null:
		return (
			"'%s' loaded as %s, not a ContentItem. " % [path, resource.get_class()]
			+ "A .tres whose script is missing or broken does exactly this: load() "
			+ "hands back a plausible object rather than failing, so the type is "
			+ "what has to be checked."
		)

	var faults: PackedStringArray = content.validation_errors()
	if not faults.is_empty():
		return "'%s': %s" % [path, " ".join(faults)]

	if _items.has(content.id):
		return (
			(
				"'%s' uses id '%s', which is already taken by '%s'. Ids are the keys "
				% [path, content.id, _items[content.id].resource_path]
			)
			+ "content and save files refer to each other by; they must be unique."
		)

	_items[content.id] = content
	_category_of[content.id] = category
	return ""


## Every resource path under a directory, recursing into subdirectories.
func _collect_resources(directory: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return out

	for sub: String in dir.get_directories():
		out.append_array(_collect_resources(directory.path_join(sub)))
	for entry: String in resource_entries(dir.get_files()):
		out.append(directory.path_join(entry))
	return out


## Orders two ids the way a human reads them.
##
## `Array[StringName].sort()` compares by internal pointer, not text.
func _alphabetically(first: StringName, second: StringName) -> bool:
	return String(first) < String(second)


func _id_strings() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: StringName in ids():
		out.append(String(id))
	return out
