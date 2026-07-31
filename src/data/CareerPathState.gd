class_name CareerPathState
extends RefCounted

## Session memory for chosen life-path ids — readable from UI and save (data layer).
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.1 / E4.5 / E4.6 (path memory)
##
## Lives under src/data so CaptainSheet and CareerSave may read it without
## crossing system boundaries. Standing teeth still apply only via CareerStart
## → StandingService.

## Selected origin option id (empty when unset / old save).
static var origin_id: StringName = &""
## Selected former-trade option id.
static var trade_id: StringName = &""
## Selected mark option id.
static var mark_id: StringName = &""
## True after annexation continue (or when loaded from a save that finished opening).
static var opening_complete: bool = false


## Clear path memory (new game cancel, quit to menu, before load apply).
static func reset() -> void:
	origin_id = &""
	trade_id = &""
	mark_id = &""
	opening_complete = false


## True when all three axis ids are set.
static func has_path() -> bool:
	return (
		not String(origin_id).is_empty()
		and not String(trade_id).is_empty()
		and not String(mark_id).is_empty()
	)


## Mark the create + annexation beat finished (Main on annexation continue).
static func mark_opening_complete() -> void:
	opening_complete = true


## Record picks after teeth apply. Opening not complete until annexation continues.
static func record_picks(
	picked_origin: StringName, picked_trade: StringName, picked_mark: StringName
) -> void:
	origin_id = picked_origin
	trade_id = picked_trade
	mark_id = picked_mark
	opening_complete = false


## Optional career save section (schema v1 — no envelope bump).
static func to_section() -> Dictionary:
	if not has_path() and not opening_complete:
		return {}
	return {
		BalanceSession.CAREER_KEY_ORIGIN_ID: String(origin_id),
		BalanceSession.CAREER_KEY_TRADE_ID: String(trade_id),
		BalanceSession.CAREER_KEY_MARK_ID: String(mark_id),
		BalanceSession.CAREER_KEY_OPENING_COMPLETE: opening_complete,
	}


## Restore path ids from optional career section. Missing / empty → clear.
static func apply_section(section: Variant) -> void:
	reset()
	if typeof(section) != TYPE_DICTIONARY:
		return
	var data: Dictionary = section
	if data.has(BalanceSession.CAREER_KEY_ORIGIN_ID):
		origin_id = _variant_to_name(data[BalanceSession.CAREER_KEY_ORIGIN_ID])
	if data.has(BalanceSession.CAREER_KEY_TRADE_ID):
		trade_id = _variant_to_name(data[BalanceSession.CAREER_KEY_TRADE_ID])
	if data.has(BalanceSession.CAREER_KEY_MARK_ID):
		mark_id = _variant_to_name(data[BalanceSession.CAREER_KEY_MARK_ID])
	if data.has(BalanceSession.CAREER_KEY_OPENING_COMPLETE):
		var flag: Variant = data[BalanceSession.CAREER_KEY_OPENING_COMPLETE]
		if typeof(flag) == TYPE_BOOL:
			var as_bool: bool = flag
			opening_complete = as_bool
		elif typeof(flag) == TYPE_INT:
			var as_int: int = flag
			opening_complete = as_int != 0
	elif has_path():
		# Old partial / bare path keys without the flag — treat as past opening.
		opening_complete = true


## Display name for a stored path option id (empty if unset / unknown).
static func option_display_name(option_id: StringName) -> String:
	if String(option_id).is_empty():
		return ""
	if not ContentLibrary.has_item(option_id):
		return String(option_id)
	var item: ContentItem = ContentLibrary.item(option_id)
	if item != null and not item.display_name.strip_edges().is_empty():
		return item.display_name
	return String(option_id)


static func _variant_to_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""
