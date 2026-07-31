extends SceneTree

## Project-wide strict-typing gate.
##
## Godot's `--import` does NOT surface script parse errors — verified: it exits 0
## with a knowingly untyped script sitting in the tree. A passing import
## therefore proves nothing about typing, so this walks every .gd file and
## re-parses it. Under the error-level warning settings in project.godot an
## untyped declaration IS a parse error, so a parse failure is a typing failure.
##
## One engine launch for the whole tree, rather than one per file.
##
##     godot --headless --path . --script res://scripts/check_types.gd
##
## Exit code 0 means every script compiled clean. Run it via scripts/lint.ps1.
##
## Two engine behaviours this works around — both verified in 4.6.1, both
## silently producing a false PASS if you get them wrong:
##
##   1. The `ResourceLoader` global resolves to null inside a `--script` main
##      loop, so the global `load()` function is used instead.
##   2. `load()` returns a non-null GDScript object even when the script failed
##      to parse. Null-checking the result passes everything. The honest signal
##      is `GDScript.reload()`, which returns ERR_PARSE_ERROR (43) on failure.

const SCAN_ROOTS: Array[String] = ["res://src", "res://tests", "res://scripts"]


func _initialize() -> void:
	var found: Array[String] = []
	# Named scan_root rather than root: SceneTree already has a `root` property,
	# and shadowing it is an error under this project's warning levels.
	for scan_root: String in SCAN_ROOTS:
		_collect_scripts(scan_root, found)
	found.sort()

	var failed: Array[String] = []
	for path: String in found:
		if not _script_parses(path):
			failed.append(path)

	print("")
	if failed.is_empty():
		print("Type check: %d script(s), all clean." % found.size())
		quit(0)
		return

	print("Type check: %d script(s), %d FAILED:" % [found.size(), failed.size()])
	for path: String in failed:
		print("  ", path)
	print("(Scroll up for the SCRIPT ERROR lines naming the offending symbol.)")
	quit(1)


## Returns true only if the script parses cleanly.
##
## Order matters. `can_instantiate()` is checked first because it is a pure
## query: a script that failed to parse cannot be instantiated. `reload()` is
## only the fallback, because it has two side effects that produce wrong answers
## if used as the primary signal:
##   - it fails on any script that currently has live instances (this very file
##     is one), reporting a healthy script as broken;
##   - it is a real re-parse, so it prints engine noise.
## The fallback still matters: an abstract script is legitimately
## non-instantiable, and only a re-parse can tell that apart from a broken one.
func _script_parses(path: String) -> bool:
	var res: Resource = load(path)
	var script: GDScript = res as GDScript
	if script == null:
		return false
	if script.can_instantiate():
		return true
	return script.reload() == OK


func _collect_scripts(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return  # Root not present yet — tests/ and scripts/ may be empty early on.

	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full_path: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect_scripts(full_path, out)
			elif entry.ends_with(".gd"):
				out.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
