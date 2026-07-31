class_name CareerStart
extends RefCounted

## Applies life-path teeth at New Game — E4.1 / E4.6.
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.1 / D3–D4, D6, D10, D14
## Law: docs/reputation_and_standing.md — StandingService single writer.
##
## Lives under src/data so save + UI never cross a system boundary when they
## only need path memory (via CareerPathState). Main and tests call apply /
## apply_default after career reset and wallet boot. Standing deltas never
## ripple. Debt mark reuses the E3 Free Haulers loan via wallet.borrow().

## Compatibility accessors for tests / Main (delegate to path state).
static var origin_id: StringName:
	get:
		return CareerPathState.origin_id
	set(value):
		CareerPathState.origin_id = value

static var trade_id: StringName:
	get:
		return CareerPathState.trade_id
	set(value):
		CareerPathState.trade_id = value

static var mark_id: StringName:
	get:
		return CareerPathState.mark_id
	set(value):
		CareerPathState.mark_id = value

static var opening_complete: bool:
	get:
		return CareerPathState.opening_complete
	set(value):
		CareerPathState.opening_complete = value


## Clear path memory (new game cancel, quit to menu, before load apply).
static func reset() -> void:
	CareerPathState.reset()


## True when all three axis ids are set.
static func has_path() -> bool:
	return CareerPathState.has_path()


## Mark the create + annexation beat finished (Main on annexation continue).
static func mark_opening_complete() -> void:
	CareerPathState.mark_opening_complete()


## Optional career save section (schema v1 — no envelope bump).
static func to_section() -> Dictionary:
	return CareerPathState.to_section()


## Restore path ids from optional career section. Missing / empty → clear.
static func apply_section(section: Variant) -> void:
	CareerPathState.apply_section(section)


## Apply the locked default combo (periphery + merchant + clean).
static func apply_default(wallet: Node) -> void:
	apply(
		BalanceStanding.LIFE_PATH_DEFAULT_ORIGIN,
		BalanceStanding.LIFE_PATH_DEFAULT_TRADE,
		BalanceStanding.LIFE_PATH_DEFAULT_MARK,
		wallet
	)


## Apply one option id from each axis. Missing or wrong-type content is a loud
## error (no silent skip). Wallet may be null only when no mark opens debt.
static func apply(
	picked_origin: StringName, picked_trade: StringName, picked_mark: StringName, wallet: Node
) -> void:
	_apply_option(picked_origin, BalanceStanding.LIFE_PATH_AXIS_ORIGIN, wallet)
	_apply_option(picked_trade, BalanceStanding.LIFE_PATH_AXIS_TRADE, wallet)
	_apply_option(picked_mark, BalanceStanding.LIFE_PATH_AXIS_MARK, wallet)
	CareerPathState.record_picks(picked_origin, picked_trade, picked_mark)


## Display name for a stored path option id (empty if unset / unknown).
static func option_display_name(option_id: StringName) -> String:
	return CareerPathState.option_display_name(option_id)


## Load and apply a single life-path option by content id.
static func _apply_option(option_id: StringName, expected_axis: StringName, wallet: Node) -> void:
	if not ContentLibrary.has_item(option_id):
		push_error("CareerStart: no life-path option '%s'." % option_id)
		return
	var item: ContentItem = ContentLibrary.item(option_id)
	if not (item is LifePathOption):
		push_error(
			(
				"CareerStart: '%s' is not a LifePathOption (got %s)."
				% [option_id, item.get_class() if item != null else "null"]
			)
		)
		return
	var option: LifePathOption = item as LifePathOption
	if option.axis != expected_axis:
		push_error(
			(
				"CareerStart: '%s' axis is '%s'; expected '%s'."
				% [option_id, option.axis, expected_axis]
			)
		)
		return

	for entry: LifePathStandingDelta in option.entity_deltas:
		if entry == null or String(entry.target_id).is_empty():
			continue
		if is_equal_approx(entry.delta, 0.0):
			continue
		StandingService.apply_entity_delta(
			entry.target_id, entry.delta, BalanceStanding.REASON_LIFE_PATH, false
		)

	for entry: LifePathStandingDelta in option.person_deltas:
		if entry == null or String(entry.target_id).is_empty():
			continue
		if is_equal_approx(entry.delta, 0.0):
			continue
		StandingService.apply_person_delta(
			entry.target_id, entry.delta, BalanceStanding.REASON_LIFE_PATH
		)

	if option.starts_with_debt:
		_open_starter_debt(option_id, wallet)


static func _open_starter_debt(option_id: StringName, wallet: Node) -> void:
	if wallet == null or not wallet.has_method(&"borrow"):
		push_error("CareerStart: mark '%s' starts with debt but wallet is missing." % option_id)
		return
	var raw: Variant = wallet.call(&"borrow")
	var received: int = 0
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		received = as_int
	elif typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		received = int(as_float)
	if received <= 0:
		push_error(
			"CareerStart: mark '%s' could not open Free Haulers debt (borrow refused)." % option_id
		)
