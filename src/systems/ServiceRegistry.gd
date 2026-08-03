extends Node

## Career-reset registry — Steam S1.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S1
##
## Autoload named `ServiceRegistry`. Services register a reset callable so
## career reset does not depend only on a hand-maintained name list in Main.
## Holds no game state — only the list of reset callables.

var _resetters: Array[Callable] = []


## Register a zero-arg callable to run on career reset. Duplicates are ignored.
func register_resettable(callback: Callable) -> void:
	if not callback.is_valid():
		return
	for existing: Callable in _resetters:
		if existing == callback:
			return
	_resetters.append(callback)


## Drop a previously registered callable (e.g. node leaving the tree).
func unregister_resettable(callback: Callable) -> void:
	var next: Array[Callable] = []
	for existing: Callable in _resetters:
		if existing == callback:
			continue
		next.append(existing)
	_resetters = next


## Run every valid registered resetter. Invalid (freed) callables are skipped.
func reset_all() -> void:
	var still_valid: Array[Callable] = []
	for callback: Callable in _resetters:
		if not callback.is_valid():
			continue
		still_valid.append(callback)
		callback.call()
	_resetters = still_valid


## How many resetters are currently registered (tests / diagnostics).
func resetter_count() -> int:
	var count: int = 0
	for callback: Callable in _resetters:
		if callback.is_valid():
			count += 1
	return count
