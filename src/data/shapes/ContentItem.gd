class_name ContentItem
extends Resource

## The shape every piece of content shares — Alpha A0 data pipeline.
##
## Hulls, weapons, commodities, entities, people, star systems, stations and
## contract templates are all `ContentItem` subclasses saved as `.tres` files
## under `src/data/content/<category>/`. `src/systems/ContentLibrary.gd` finds
## them by scanning that directory: it is never told what exists, so **adding
## content requires zero code changes**.
##
## Two things this base class is for:
##
##   1. **A stable key.** `id` is how one piece of content refers to another and
##      how a save file names something without embedding it. It is not the
##      display name and it never changes once content ships.
##   2. **Loud failure.** `validation_errors()` is how content says it is wrong.
##      The loader collects the answers and reports every one; nothing is
##      skipped quietly.

## Characters an id may contain. Ids are lowercase snake_case so they can be
## used unquoted as dictionary keys, file names and save-file fields.
const ID_ALPHABET: String = "abcdefghijklmnopqrstuvwxyz0123456789_"

## The stable machine-readable key, unique across all content of all categories.
@export var id: StringName = &""

## What the player is shown. Free text; may be changed at any time.
@export var display_name: String = ""


## Everything wrong with this item, in plain sentences. Empty means valid.
##
## Called by the loader for every item it finds. Return problems rather than
## calling `push_error` directly: the loader decides how loudly to complain and
## the tests need to inspect the answer without tripping the engine's error
## tracking.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = []

	var text_id: String = String(id)
	if text_id.strip_edges().is_empty():
		problems.append("`id` is empty. Every item needs a stable key.")
	else:
		for character: String in text_id:
			if not ID_ALPHABET.contains(character):
				problems.append(
					(
						"`id` is '%s'; ids are lowercase snake_case (allowed: %s)."
						% [text_id, ID_ALPHABET]
					)
				)
				break

	if display_name.strip_edges().is_empty():
		problems.append("`display_name` is empty. Nothing would render for this item.")

	return problems
