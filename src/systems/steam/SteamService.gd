extends Node

## Steam packaging hook (no SDK dependency) — Steam S10.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10
##
## Autoload `SteamService`. Safe no-op until GodotSteam (or similar) is approved
## as a dependency. Call sites stay stable for launch prep.

var _presence: String = BalanceSettings.STEAM_PRESENCE_MENU
var _unlocked: Dictionary = {}


func is_steam_available() -> bool:
	return false


func app_id() -> int:
	return 0


## Rich presence string for overlay / friends (no-op without SDK).
func set_presence(line: String) -> void:
	_presence = line.strip_edges()
	if _presence.is_empty():
		_presence = BalanceSettings.STEAM_PRESENCE_MENU


func presence() -> String:
	return _presence


## Achievement unlock stub. Returns false when Steam is not wired.
func unlock_achievement(achievement_id: StringName) -> bool:
	if String(achievement_id).is_empty():
		return false
	_unlocked[achievement_id] = true
	return false


func is_achievement_marked(achievement_id: StringName) -> bool:
	var raw: Variant = _unlocked.get(achievement_id, false)
	if typeof(raw) != TYPE_BOOL:
		return false
	var marked: bool = raw
	return marked


func clear_debug_marks() -> void:
	_unlocked.clear()
