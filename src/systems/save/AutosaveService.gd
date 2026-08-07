class_name AutosaveService
extends Node

## Writes the career automatically on docking and on system entry — Job 10.
##
## `SaveSchema` has declared `ORIGIN_AUTOSAVE_DOCK` and `ORIGIN_AUTOSAVE_ENTRY`
## since A0 and nothing has ever called them: before this, the only code that
## wrote a save was the pause menu's Save button. That is why a fresh career
## could lose an entire run to one bad fight with nothing to reload.
##
## Armed / disarmed by Main. It has to be, and the reason is not caution:
## `on_system_entered` fires while `_boot_play_session()` is still building the
## session (there is no ship yet, so the save would have no `world` section),
## and again while a load is being applied (where re-saving would overwrite the
## file being read). Disarmed is the safe default a new instance starts in.
##
## The write is deferred by one message-queue flush rather than run inside the
## signal handler, because placement settles *after* the announcement: a gate
## jump builds the destination — which emits `on_system_entered` — and only then
## moves the ship to the arrival point. Saving inline would file the new system
## with the old coordinates. `call_deferred` is dropped silently if this node is
## freed in between, which teardown does.

## Save slot to write. Its own file, not the manual one — see
## `BalanceSession.AUTOSAVE_SAVE_NAME`. Replaceable so tests do not tread on a
## real player's autosave, the same seam `SaveService.migration_steps` offers.
var save_name: String = BalanceSession.AUTOSAVE_SAVE_NAME

var _armed: bool = false
var _last_result: SaveResult = null


func _ready() -> void:
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_system_entered.connect(_on_system_entered)


func _exit_tree() -> void:
	if EventBus.on_docked.is_connected(_on_docked):
		EventBus.on_docked.disconnect(_on_docked)
	if EventBus.on_system_entered.is_connected(_on_system_entered):
		EventBus.on_system_entered.disconnect(_on_system_entered)


## Turn autosaving on or off. Main arms this only once a session is genuinely
## playable and disarms it around boot, load and teardown.
func set_armed(value: bool) -> void:
	_armed = value


func is_armed() -> bool:
	return _armed


## The result of the last autosave attempt (null until one has run).
func last_result() -> SaveResult:
	return _last_result


## Write the career now, whatever the armed state. Used by the arming caller and
## by tests; the signal paths go through `_write_when_armed`.
func write_now(origin: StringName) -> SaveResult:
	_last_result = CareerSave.save_to_name(get_tree(), save_name, "", origin)
	if not _last_result.ok():
		push_warning("Autosave failed: %s" % _last_result.summary())
	return _last_result


func _on_docked(_station_id: StringName) -> void:
	_queue_write(SaveService.ORIGIN_AUTOSAVE_DOCK)


func _on_system_entered(_system_id: StringName) -> void:
	_queue_write(SaveService.ORIGIN_AUTOSAVE_ENTRY)


func _queue_write(origin: StringName) -> void:
	if not _armed:
		return
	call_deferred(&"_write_when_armed", origin)


func _write_when_armed(origin: StringName) -> void:
	if not _armed or not is_inside_tree():
		return
	write_now(origin)
