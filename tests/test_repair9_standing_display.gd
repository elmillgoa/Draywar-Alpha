extends GutTest

## REPAIR-9: station/HUD standing display consistency.
##
## Three display defects from audit baseline ee17eab5:
## 1. Approach-refused prompt lacks glyph + color (S10 a11y — T12/W14).
## 2. Status line already has glyph + color on both branches — guard it (T12 HUD half).
## 3. Sell cap note always blames the dock; HOLD strings were dead.
##
## Out of scope: StandingService, save schema, EventBus signal set, load path.

const ENTITY_REACH: StringName = &"entity_reach_authority"
const STATION_PORT: StringName = &"station_alpha_port"
const SYSTEM_ALPHA: StringName = &"system_alpha"
## Below dock-refusal threshold (-50), Hostile band.
const HOSTILE_STANDING: float = -60.0
## Friendly band for status-line color/glyph checks.
const FRIENDLY_STANDING: float = 25.0


func after_each() -> void:
	StandingService.reset_to_defaults()


func _as_name(value: Variant) -> StringName:
	return StringName(str(value))


func _as_label(value: Variant) -> Label:
	if value is Label:
		var label: Label = value
		return label
	return null


func _as_string(value: Variant) -> String:
	return str(value)


func _status_tier_from(status: Dictionary) -> StringName:
	return _as_name(status.get(StandingService.STATUS_KEY_TIER, BalanceStanding.TIER_NEUTRAL))


# --- (a) refused approach prompt — red today, green after fix -----------------


func test_dock_refused_prompt_has_tier_color_and_glyph() -> void:
	# Close Mendi so Entity threshold is the only rule (recovery open still docks).
	StandingService.close_person(&"person_ra_mendi", BalanceStanding.RECOVERY_CLOSE_REASON_BETRAYAL)
	StandingService.set_entity_standing(ENTITY_REACH, HOSTILE_STANDING)
	assert_false(
		StandingService.can_dock_at_station(STATION_PORT),
		"fixture: Reach standing must refuse Alpha Port"
	)
	var status: Dictionary = StandingService.status_for_station(STATION_PORT)
	var tier: StringName = _status_tier_from(status)
	var glyph: String = BalanceStanding.tier_glyph(tier)
	var expected_color: Color = BalanceStanding.tier_color(tier)

	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame

	# In range, standing refuses → can_dock false (DockingService packs both).
	EventBus.on_dock_prompt_changed.emit(STATION_PORT, false)
	await get_tree().process_frame

	var prompt: Label = _as_label(hud.get("_prompt_label"))
	assert_not_null(prompt, "_prompt_label must exist after ready")
	assert_true(
		prompt.text.contains(glyph),
		"refused prompt must carry tier glyph '%s'; got: %s" % [glyph, prompt.text]
	)
	assert_eq(
		prompt.get_theme_color("font_color"),
		expected_color,
		"refused prompt font_color must be tier_color(%s)" % tier
	)


# --- (b) status line — green on arrival; guards S10 a11y on both branches -----


func test_status_line_has_tier_color_and_glyph() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, FRIENDLY_STANDING)
	var status: Dictionary = StandingService.status_for_system(SYSTEM_ALPHA)
	var tier: StringName = _status_tier_from(status)
	var glyph: String = BalanceStanding.tier_glyph(tier)
	var expected_color: Color = BalanceStanding.tier_color(tier)

	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	var status_label: Label = _as_label(hud.get("_status_label"))
	assert_not_null(status_label, "_status_label must exist after ready")

	# System branch of _refresh_status_line (free flight).
	EventBus.on_system_entered.emit(SYSTEM_ALPHA)
	await get_tree().process_frame
	assert_true(
		status_label.text.contains(glyph),
		"system status line must carry tier glyph '%s'; got: %s" % [glyph, status_label.text]
	)
	assert_eq(
		status_label.get_theme_color("font_color"),
		expected_color,
		"system status font_color must be tier_color(%s)" % tier
	)

	# Docked branch — same controller at Alpha Port.
	EventBus.on_docked.emit(STATION_PORT)
	await get_tree().process_frame
	var dock_status: Dictionary = StandingService.status_for_station(STATION_PORT)
	var dock_tier: StringName = _status_tier_from(dock_status)
	var dock_glyph: String = BalanceStanding.tier_glyph(dock_tier)
	var dock_color: Color = BalanceStanding.tier_color(dock_tier)
	assert_true(
		status_label.text.contains(dock_glyph),
		"docked status line must carry tier glyph '%s'; got: %s" % [dock_glyph, status_label.text]
	)
	assert_eq(
		status_label.get_theme_color("font_color"),
		dock_color,
		"docked status font_color must be tier_color(%s)" % dock_tier
	)


# --- Sell cap note: HOLD limit uses hold wording, not dock wording -------------


func test_sell_cap_note_uses_hold_strings_when_limit_is_hold() -> void:
	var row: StationTradeRow = StationTradeRow.new()
	add_child_autofree(row)
	await get_tree().process_frame

	row.set("_max_sell", 3)
	row.set("_sell_limit", BalanceEconomy.TRADE_LIMIT_HOLD)
	row.set("_max_buy", 99)
	row.set("_buy_limit", BalanceEconomy.TRADE_LIMIT_MARKET)
	var capped: String = _as_string(row.call("_cap_note", 10))
	assert_eq(
		capped,
		BalanceEconomy.STATION_TRADE_CAP_SELL_HOLD_FORMAT % 3,
		"hold-limited sell must say you are only carrying N"
	)
	assert_false(
		capped.contains("dock will only take"), "hold-limited sell must not blame the dock"
	)

	row.set("_max_sell", 0)
	row.set("_sell_limit", BalanceEconomy.TRADE_LIMIT_HOLD)
	var empty: String = _as_string(row.call("_cap_note", 1))
	assert_eq(
		empty, BalanceEconomy.STATION_TRADE_NONE_SELL_HOLD, "empty hold must use NONE_SELL_HOLD"
	)
