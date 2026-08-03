class_name MoneyLog
extends Node

## Money-event telemetry log — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2
##
## Single listener for EventBus.on_money_event; writes one CSV row per real
## credit movement to BalanceTelemetry.LOG_PATH (user://telemetry) so S9
## balance work has real per-activity numbers instead of guesses. Child of
## Main (not an autoload); holds no state anyone else queries. Buffers rows
## and flushes on BalanceTelemetry.FLUSH_ROW_THRESHOLD, on _exit_tree(), and
## on demand via flush(). Rotates the live file to a single ROTATED_PATH
## backup once it exceeds BalanceTelemetry.MAX_FILE_BYTES so a long playtest
## cannot grow it without bound. A failed file open disables logging quietly
## (one EventBus.on_console_output line) — telemetry must never crash or
## block a trade.

var _file: FileAccess = null
var _buffer: Array[String] = []
var _row_count: int = 0
var _enabled: bool = true


func _ready() -> void:
	add_to_group(&"money_log")
	EventBus.on_money_event.connect(_on_money_event)


func _exit_tree() -> void:
	if EventBus.on_money_event.is_connected(_on_money_event):
		EventBus.on_money_event.disconnect(_on_money_event)
	flush()
	_close_file()


## Write any buffered rows to disk now.
func flush() -> void:
	if _buffer.is_empty():
		return
	if not _ensure_file_ready():
		_buffer.clear()
		return
	for row: String in _buffer:
		_file.store_line(row)
	_file.flush()
	_buffer.clear()
	_maybe_rotate()


## Rows logged this session (buffered or already flushed).
func row_count() -> int:
	return _row_count


## Turn logging on or off. Rows already buffered are left pending, not lost.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_enabled() -> bool:
	return _enabled


## The live log's path (constant; rotation only touches the backup file).
func log_path() -> String:
	return BalanceTelemetry.LOG_PATH


## Delete the live log and its rotation backup, and reset session counters.
## Tests only — a real session never wants its history erased mid-play.
func clear_log() -> void:
	_close_file()
	if FileAccess.file_exists(BalanceTelemetry.LOG_PATH):
		DirAccess.remove_absolute(BalanceTelemetry.LOG_PATH)
	if FileAccess.file_exists(BalanceTelemetry.ROTATED_PATH):
		DirAccess.remove_absolute(BalanceTelemetry.ROTATED_PATH)
	_buffer.clear()
	_row_count = 0


func _on_money_event(
	reason: StringName, credits_delta: int, credits_after: int, detail: Dictionary
) -> void:
	if not _enabled:
		return
	_buffer.append(_build_row(reason, credits_delta, credits_after, detail))
	_row_count += 1
	if _buffer.size() >= BalanceTelemetry.FLUSH_ROW_THRESHOLD:
		flush()


func _build_row(
	reason: StringName, credits_delta: int, credits_after: int, detail: Dictionary
) -> String:
	var elapsed_text: String = (
		BalanceTelemetry.ELAPSED_SECONDS_FORMAT % WorldClock.elapsed_seconds()
	)
	var fields: PackedStringArray = PackedStringArray()
	fields.append(_escape_csv(elapsed_text))
	fields.append(_escape_csv(String(reason)))
	fields.append(_escape_csv(str(credits_delta)))
	fields.append(_escape_csv(str(credits_after)))
	fields.append(_escape_csv(_detail_string(detail, BalanceTelemetry.DETAIL_KEY_COMMODITY_ID)))
	fields.append(_escape_csv(_detail_string(detail, BalanceTelemetry.DETAIL_KEY_UNITS)))
	fields.append(_escape_csv(_detail_string(detail, BalanceTelemetry.DETAIL_KEY_UNIT_PRICE)))
	fields.append(_escape_csv(_detail_string(detail, BalanceTelemetry.DETAIL_KEY_STATION_ID)))
	fields.append(_escape_csv(_detail_string(detail, BalanceTelemetry.DETAIL_KEY_SYSTEM_ID)))
	return ",".join(fields)


func _detail_string(detail: Dictionary, key: StringName) -> String:
	if not detail.has(key):
		return ""
	return _variant_to_display(detail[key])


func _variant_to_display(value: Variant) -> String:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return String(as_name)
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return as_text
	return str(value)


func _escape_csv(field: String) -> String:
	var needs_quotes: bool = (
		field.contains(",") or field.contains('"') or field.contains("\n") or field.contains("\r")
	)
	if not needs_quotes:
		return field
	return '"' + field.replace('"', '""') + '"'


func _ensure_file_ready() -> bool:
	if _file != null:
		return true
	if not _prepare_directory():
		return false
	if FileAccess.file_exists(BalanceTelemetry.LOG_PATH):
		return _open_existing_for_append()
	return _create_with_header()


func _prepare_directory() -> bool:
	if DirAccess.dir_exists_absolute(BalanceTelemetry.LOG_DIRECTORY):
		return true
	var made: int = DirAccess.make_dir_recursive_absolute(BalanceTelemetry.LOG_DIRECTORY)
	if made == OK:
		return true
	_disable_with_error("MoneyLog: could not create telemetry directory (%s)." % error_string(made))
	return false


func _open_existing_for_append() -> bool:
	var handle: FileAccess = FileAccess.open(BalanceTelemetry.LOG_PATH, FileAccess.READ_WRITE)
	if handle == null:
		_disable_with_error(
			(
				"MoneyLog: could not open the telemetry log for append (%s)."
				% error_string(FileAccess.get_open_error())
			)
		)
		return false
	handle.seek_end()
	_file = handle
	return true


func _create_with_header() -> bool:
	var handle: FileAccess = FileAccess.open(BalanceTelemetry.LOG_PATH, FileAccess.WRITE)
	if handle == null:
		_disable_with_error(
			(
				"MoneyLog: could not create the telemetry log (%s)."
				% error_string(FileAccess.get_open_error())
			)
		)
		return false
	handle.store_line(BalanceTelemetry.CSV_HEADER)
	_file = handle
	return true


func _maybe_rotate() -> void:
	if _file == null:
		return
	if _file.get_length() < BalanceTelemetry.MAX_FILE_BYTES:
		return
	_rotate_file()


func _rotate_file() -> void:
	_file.close()
	_file = null
	var raw: PackedByteArray = PackedByteArray()
	var reader: FileAccess = FileAccess.open(BalanceTelemetry.LOG_PATH, FileAccess.READ)
	if reader != null:
		raw = reader.get_buffer(reader.get_length())
		reader.close()
	if FileAccess.file_exists(BalanceTelemetry.ROTATED_PATH):
		DirAccess.remove_absolute(BalanceTelemetry.ROTATED_PATH)
	var backup: FileAccess = FileAccess.open(BalanceTelemetry.ROTATED_PATH, FileAccess.WRITE)
	if backup != null:
		backup.store_buffer(raw)
		backup.close()
	var fresh: FileAccess = FileAccess.open(BalanceTelemetry.LOG_PATH, FileAccess.WRITE)
	if fresh == null:
		_disable_with_error("MoneyLog: could not start a fresh telemetry log after rotation.")
		return
	fresh.store_line(BalanceTelemetry.CSV_HEADER)
	_file = fresh


func _close_file() -> void:
	if _file != null:
		_file.close()
		_file = null


func _disable_with_error(message: String) -> void:
	if not _enabled:
		return
	_enabled = false
	EventBus.on_console_output.emit(message)
