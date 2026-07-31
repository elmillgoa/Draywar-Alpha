class_name SaveResult
extends RefCounted

## What every save and load hands back — Alpha A0 save schema.
##
## The save system never calls `push_error`. A function that shouts cannot be
## tested, because GUT records an unexpected engine error as a test failure.
## Every problem is therefore **returned**, and the caller decides.
##
## Check `ok()` on every result.

## Everything wrong. Empty means the operation succeeded.
var problems: PackedStringArray = []

## The canonical envelope. Populated on a successful save and a successful load.
var envelope: Dictionary = {}

## The exact bytes of the save file — what was written, or what was read.
var bytes: PackedByteArray = []

## Which schema version the envelope is in. See `SaveSchema.CURRENT_VERSION`.
var schema_version: int = 0


## Builds a failed result carrying one problem. The common case.
static func failed(problem: String) -> SaveResult:
	var result: SaveResult = SaveResult.new()
	result.problems.append(problem)
	return result


## Whether the operation succeeded.
func ok() -> bool:
	return problems.is_empty()


## Every problem on one line, for a log or an assertion message.
func summary() -> String:
	if problems.is_empty():
		return "ok"
	return "; ".join(problems)
