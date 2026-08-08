class_name FlightHUD
extends CanvasLayer

## Readable flight HUD — Alpha A5.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1–A2, A5
##
## Display only. Listens to EventBus; resolves display names via ContentLibrary.
## Status line shows the protected standing moment (local controller only).
## Credits, fuel, hull, and gate jump prompts are session readouts.

const CombatReticleScript = preload("res://src/ui/hud/CombatReticle.gd")

var _system_label: Label = null
var _speed_label: Label = null
var _throttle_label: Label = null
var _prompt_label: Label = null
var _status_label: Label = null
var _credits_label: Label = null
var _fuel_label: Label = null
var _condition_label: Label = null
var _mission_label: Label = null
var _target_label: Label = null
var _kill_toast_label: Label = null
var _nav_title_label: Label = null
var _nav_here_label: Label = null
var _nav_gates_label: Label = null
var _root: Control = null
var _combat_reticle: Control = null
var _dock_fade: ColorRect = null

var _current_system_id: StringName = &""
var _docked_station_id: StringName = &""
var _gate_dest_id: StringName = &""
var _gate_can_jump: bool = false
var _dock_prompt_id: StringName = &""
var _dock_can_dock: bool = false
var _tow_available: bool = false
var _tow_fee: int = 0
var _crippled: bool = false
var _hostile_present: bool = false
var _target_locked: bool = false
var _target_label_text: String = ""
var _target_distance: float = 0.0
var _target_hull_percent: int = BalanceCombat.HULL_PERCENT_FULL
var _condition_hit_flash_left: float = 0.0
var _condition_base_color: Color = Color.WHITE
var _dock_fade_left: float = 0.0
var _dock_fade_peak: float = 0.0
var _dock_fade_base: Color = Color.TRANSPARENT
var _kill_toast_left: float = 0.0
## S4: active free-flight incident for [1]/[2] response keys.
var _active_incident_id: StringName = &""
var _active_incident_kind: StringName = &""


func _ready() -> void:
	layer = BalanceFlight.HUD_CANVAS_LAYER
	_build_labels()
	EventBus.on_system_entered.connect(_on_system_entered)
	EventBus.on_player_speed_changed.connect(_on_speed_changed)
	EventBus.on_player_throttle_changed.connect(_on_throttle_changed)
	EventBus.on_dock_prompt_changed.connect(_on_dock_prompt_changed)
	EventBus.on_gate_prompt_changed.connect(_on_gate_prompt_changed)
	EventBus.on_tow_prompt_changed.connect(_on_tow_prompt_changed)
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_undocked.connect(_on_undocked)
	EventBus.on_status_moment.connect(_on_status_moment)
	EventBus.on_entity_standing_changed.connect(_on_entity_standing_changed)
	EventBus.on_dock_refused.connect(_on_dock_refused)
	EventBus.on_credits_changed.connect(_on_credits_changed)
	EventBus.on_fuel_changed.connect(_on_fuel_changed)
	EventBus.on_condition_changed.connect(_on_condition_changed)
	EventBus.on_mission_accepted.connect(_on_mission_changed)
	EventBus.on_mission_completed.connect(_on_mission_closed)
	EventBus.on_mission_failed.connect(_on_mission_closed)
	EventBus.on_mission_abandoned.connect(_on_mission_closed)
	EventBus.on_player_crippled.connect(_on_player_crippled)
	EventBus.on_player_repaired_from_cripple.connect(_on_player_repaired_from_cripple)
	EventBus.on_hostile_killed.connect(_on_hostile_killed)
	EventBus.on_kill_attributed.connect(_on_kill_attributed)
	EventBus.on_kill_unattributed.connect(_on_kill_unattributed)
	EventBus.on_market_news.connect(_on_market_news_toast)
	EventBus.on_campaign_ending_blocked.connect(_on_campaign_ending_blocked)
	EventBus.on_incident_prompt.connect(_on_incident_prompt)
	EventBus.on_incident_resolved.connect(_on_incident_resolved)
	EventBus.on_target_lock_changed.connect(_on_target_lock_changed)
	EventBus.on_hostile_damaged.connect(_on_hostile_damaged)
	EventBus.on_player_damaged.connect(_on_player_damaged_flash)
	# REPAIR-3: charter breach was emitted with no listener. Surface it so an
	# unpaid fleet is not silently fired while free-flying.
	EventBus.on_ops_charter_breached.connect(_on_ops_charter_breached)
	_refresh_mission_line()


func _exit_tree() -> void:
	_disconnect(EventBus.on_system_entered, _on_system_entered)
	_disconnect(EventBus.on_player_speed_changed, _on_speed_changed)
	_disconnect(EventBus.on_player_throttle_changed, _on_throttle_changed)
	_disconnect(EventBus.on_dock_prompt_changed, _on_dock_prompt_changed)
	_disconnect(EventBus.on_gate_prompt_changed, _on_gate_prompt_changed)
	_disconnect(EventBus.on_tow_prompt_changed, _on_tow_prompt_changed)
	_disconnect(EventBus.on_docked, _on_docked)
	_disconnect(EventBus.on_undocked, _on_undocked)
	_disconnect(EventBus.on_status_moment, _on_status_moment)
	_disconnect(EventBus.on_entity_standing_changed, _on_entity_standing_changed)
	_disconnect(EventBus.on_dock_refused, _on_dock_refused)
	_disconnect(EventBus.on_credits_changed, _on_credits_changed)
	_disconnect(EventBus.on_fuel_changed, _on_fuel_changed)
	_disconnect(EventBus.on_condition_changed, _on_condition_changed)
	_disconnect(EventBus.on_mission_accepted, _on_mission_changed)
	_disconnect(EventBus.on_mission_completed, _on_mission_closed)
	_disconnect(EventBus.on_mission_failed, _on_mission_closed)
	_disconnect(EventBus.on_mission_abandoned, _on_mission_closed)
	_disconnect(EventBus.on_player_crippled, _on_player_crippled)
	_disconnect(EventBus.on_player_repaired_from_cripple, _on_player_repaired_from_cripple)
	_disconnect(EventBus.on_hostile_killed, _on_hostile_killed)
	_disconnect(EventBus.on_kill_attributed, _on_kill_attributed)
	_disconnect(EventBus.on_kill_unattributed, _on_kill_unattributed)
	_disconnect(EventBus.on_market_news, _on_market_news_toast)
	_disconnect(EventBus.on_campaign_ending_blocked, _on_campaign_ending_blocked)
	_disconnect(EventBus.on_incident_prompt, _on_incident_prompt)
	_disconnect(EventBus.on_incident_resolved, _on_incident_resolved)
	_disconnect(EventBus.on_target_lock_changed, _on_target_lock_changed)
	_disconnect(EventBus.on_hostile_damaged, _on_hostile_damaged)
	_disconnect(EventBus.on_player_damaged, _on_player_damaged_flash)
	_disconnect(EventBus.on_ops_charter_breached, _on_ops_charter_breached)


func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _build_labels() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = DraywarUiTheme.build()
	add_child(_root)

	_system_label = _make_label(_root, BalanceFlight.HUD_TITLE_FONT_SIZE)
	_system_label.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_system_label.position = Vector2(BalanceFlight.HUD_MARGIN, BalanceFlight.HUD_MARGIN)
	_system_label.text = "SYSTEM"

	_speed_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_speed_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE) * BalanceFlight.HUD_LINE_SPEED
		)
	)
	_speed_label.text = "SPEED  0"

	_throttle_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_throttle_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceFlight.HUD_LINE_SPEED
		)
	)
	_throttle_label.text = "THROTTLE  0%"

	_status_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_status_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceFlight.HUD_LINE_THROTTLE
		)
	)
	_status_label.text = ""

	_credits_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_credits_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceFlight.HUD_LINE_STATUS
		)
	)
	_credits_label.text = BalanceEconomy.HUD_CREDITS_FORMAT % 0

	_fuel_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_fuel_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceEconomy.HUD_LINE_CREDITS
		)
	)
	_fuel_label.text = (BalanceEconomy.HUD_FUEL_FORMAT % int(BalanceEconomy.PERCENT_SCALE))

	_condition_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_condition_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceEconomy.HUD_LINE_FUEL
		)
	)
	_condition_label.text = (
		BalanceEconomy.HUD_CONDITION_FORMAT % int(BalanceEconomy.PERCENT_SCALE)
	)
	_condition_base_color = BalanceUi.FONT_COLOR

	_mission_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_mission_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceEconomy.HUD_LINE_MISSION
		)
	)
	_mission_label.text = ""

	_target_label = _make_label(_root, BalanceFlight.HUD_FONT_SIZE)
	_target_label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_target_label.position = Vector2(
		BalanceFlight.HUD_MARGIN,
		(
			BalanceFlight.HUD_MARGIN
			+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
			+ float(BalanceFlight.HUD_FONT_SIZE) * (BalanceEconomy.HUD_LINE_MISSION + 1.0)
		)
	)
	_target_label.text = BalanceCombat.HUD_TARGET_LOCK_NONE

	_combat_reticle = CombatReticleScript.new()
	_combat_reticle.name = "CombatReticle"
	_root.add_child(_combat_reticle)

	_build_nav_panel(_root)

	_prompt_label = _make_label(_root, BalanceFlight.HUD_PROMPT_FONT_SIZE)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_label.offset_bottom = -BalanceFlight.HUD_MARGIN * BalanceFlight.HUD_LINE_THROTTLE
	_prompt_label.offset_top = (
		-BalanceFlight.HUD_MARGIN * BalanceFlight.HUD_LINE_THROTTLE
		- float(BalanceFlight.HUD_PROMPT_FONT_SIZE)
	)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_prompt_label.text = ""

	# Temporary kill attribution toast (E2.3) — sits just above the prompt.
	_kill_toast_label = _make_label(_root, BalanceFlight.HUD_PROMPT_FONT_SIZE)
	_kill_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_kill_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_kill_toast_label.offset_bottom = (
		-BalanceFlight.HUD_MARGIN * BalanceFlight.HUD_LINE_THROTTLE
		- float(BalanceFlight.HUD_PROMPT_FONT_SIZE) * BalanceFlight.HUD_LINE_SPEED
	)
	_kill_toast_label.offset_top = (
		_kill_toast_label.offset_bottom - float(BalanceFlight.HUD_PROMPT_FONT_SIZE)
	)
	_kill_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kill_toast_label.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	_kill_toast_label.text = ""

	# Full-screen dock/undock flash (visual only — does not block input).
	_dock_fade = ColorRect.new()
	_dock_fade.name = "DockFade"
	_dock_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dock_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_dock_fade.visible = false
	_root.add_child(_dock_fade)


func _build_nav_panel(parent: Control) -> void:
	# Right-side nav: current system + gate destinations from ContentLibrary.
	_nav_title_label = _make_label(parent, BalanceFlight.HUD_TITLE_FONT_SIZE)
	_nav_title_label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_nav_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_nav_title_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_nav_title_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_nav_title_label.offset_right = -BalanceEconomy.NAV_PANEL_RIGHT_MARGIN
	_nav_title_label.offset_top = BalanceFlight.HUD_MARGIN
	_nav_title_label.text = BalanceEconomy.NAV_TITLE_TEXT

	_nav_here_label = _make_label(parent, BalanceFlight.HUD_FONT_SIZE)
	_nav_here_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_nav_here_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_nav_here_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_nav_here_label.offset_right = -BalanceEconomy.NAV_PANEL_RIGHT_MARGIN
	_nav_here_label.offset_top = (
		BalanceFlight.HUD_MARGIN
		+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
		+ float(BalanceFlight.HUD_FONT_SIZE) * BalanceEconomy.HUD_LINE_NAV_HERE
	)
	_nav_here_label.text = BalanceEconomy.NAV_HERE_FORMAT % "—"

	_nav_gates_label = _make_label(parent, BalanceFlight.HUD_FONT_SIZE)
	_nav_gates_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_nav_gates_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_nav_gates_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_nav_gates_label.offset_right = -BalanceEconomy.NAV_PANEL_RIGHT_MARGIN
	_nav_gates_label.offset_top = (
		BalanceFlight.HUD_MARGIN
		+ float(BalanceFlight.HUD_TITLE_FONT_SIZE)
		+ float(BalanceFlight.HUD_FONT_SIZE) * (BalanceEconomy.HUD_LINE_NAV_GATES + 1.0)
	)
	_nav_gates_label.text = BalanceEconomy.NAV_GATES_HEADER


func _make_label(parent: Control, font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _content_name(id: StringName) -> String:
	if id == &"":
		return ""
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


## Commodity display name for an active smuggle job, or "cargo".
func _smuggle_cargo_name(service: Node, template_id: StringName) -> String:
	var cargo_id: StringName = &""
	if service != null and service.has_method(&"active_cargo_commodity_id"):
		cargo_id = _variant_to_name(service.call(&"active_cargo_commodity_id"))
	if String(cargo_id).is_empty() and ContentLibrary.has_item(template_id):
		var item: ContentItem = ContentLibrary.item(template_id)
		if item is ContractType:
			cargo_id = (item as ContractType).cargo_commodity_id
	if String(cargo_id).is_empty():
		return "cargo"
	return _content_name(cargo_id)


func _variant_to_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""


func _refresh_status_line() -> void:
	if _docked_station_id != &"":
		var station_status: Dictionary = StandingService.status_for_station(_docked_station_id)
		var dock_tier: StringName = _status_tier(station_status)
		var dock_display: String = str(station_status[StandingService.STATUS_KEY_TIER_DISPLAY])
		_status_label.text = (
			BalanceStanding.DOCKED_STATUS_FORMAT
			% [
				_content_name(_docked_station_id),
				"%s %s" % [BalanceStanding.tier_glyph(dock_tier), dock_display],
				station_status[StandingService.STATUS_KEY_ENTITY_DISPLAY],
			]
		)
		_status_label.add_theme_color_override("font_color", BalanceStanding.tier_color(dock_tier))
		return
	if _current_system_id != &"":
		var system_status: Dictionary = StandingService.status_for_system(_current_system_id)
		var sys_tier: StringName = _status_tier(system_status)
		var base_line: String = str(system_status[StandingService.STATUS_KEY_LINE])
		_status_label.text = "%s %s" % [BalanceStanding.tier_glyph(sys_tier), base_line]
		_status_label.add_theme_color_override("font_color", BalanceStanding.tier_color(sys_tier))
		return
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)


func _status_tier(status: Dictionary) -> StringName:
	if status.has(StandingService.STATUS_KEY_TIER):
		return _variant_to_name(status[StandingService.STATUS_KEY_TIER])
	return BalanceStanding.TIER_NEUTRAL


func _refresh_prompt() -> void:
	_prompt_label.text = _prompt_text()
	# Approach-refused uses the same glyph+color as the press-F refused path
	# (S10 a11y: color + glyph + tier name). Other prompts stay accent.
	if _is_dock_refused_prompt():
		var status: Dictionary = StandingService.status_for_station(_dock_prompt_id)
		var refuse_tier: StringName = _status_tier(status)
		_prompt_label.add_theme_color_override(
			"font_color", BalanceStanding.tier_color(refuse_tier)
		)
	else:
		_prompt_label.add_theme_color_override("font_color", BalanceUi.ACCENT)


## True when the approach prompt is the standing-refusal line (not PRESS F / APPROACHING).
func _is_dock_refused_prompt() -> bool:
	if _dock_prompt_id == &"":
		return false
	if _dock_can_dock:
		return false
	return not StandingService.can_dock_at_station(_dock_prompt_id)


## The one prompt line, in priority order. Split out of `_refresh_prompt` when
## the tow line pushed it past the linter's return-count ceiling; the order and
## the conditions are unchanged apart from the tow.
func _prompt_text() -> String:
	# Cripple fail-state beats everything free-flying; dock still wins when near.
	if _dock_prompt_id != &"":
		return _dock_prompt_text()
	# A dry tank away from a berth is the one thing the player cannot fly out of.
	# Say so, and say the way out, or the rescue may as well not exist (PT-11).
	if _tow_available and _docked_station_id == &"":
		return BalanceEconomy.TOW_PROMPT_FORMAT % _tow_fee
	if _crippled and _docked_station_id == &"":
		return BalanceCombat.HUD_CRIPPLED_MESSAGE
	if _gate_dest_id != &"":
		return _gate_prompt_text()
	if _hostile_present and _docked_station_id == &"":
		return BalanceCombat.HUD_COMBAT_PROMPT
	return ""


func _dock_prompt_text() -> String:
	var station_label: String = _content_name(_dock_prompt_id)
	if _dock_can_dock:
		return "PRESS F TO DOCK — %s" % station_label
	if not StandingService.can_dock_at_station(_dock_prompt_id):
		var status: Dictionary = StandingService.status_for_station(_dock_prompt_id)
		var refuse_tier: StringName = _status_tier(status)
		return (
			BalanceStanding.DOCK_REFUSED_PROMPT_FORMAT
			% [
				(
					"%s %s"
					% [
						BalanceStanding.tier_glyph(refuse_tier),
						status[StandingService.STATUS_KEY_TIER_DISPLAY],
					]
				),
				status[StandingService.STATUS_KEY_ENTITY_DISPLAY],
			]
		)
	return "APPROACHING %s" % station_label.to_upper()


func _gate_prompt_text() -> String:
	var dest_label: String = _content_name(_gate_dest_id)
	if _gate_can_jump:
		return BalanceEconomy.JUMP_PROMPT_FORMAT % dest_label
	return (
		BalanceEconomy.JUMP_PROMPT_NO_FUEL_FORMAT
		% [str(int(BalanceEconomy.JUMP_FUEL_COST)), dest_label]
	)


func _on_speed_changed(speed: float) -> void:
	var scaled: float = speed * BalanceFlight.HUD_SPEED_DISPLAY_SCALE
	var shown: int = int(roundf(scaled))
	_speed_label.text = "SPEED  %d" % shown


func _on_throttle_changed(throttle: float) -> void:
	var scaled: float = throttle * BalanceFlight.THROTTLE_PERCENT_SCALE
	var percent: int = int(roundf(scaled))
	_throttle_label.text = "THROTTLE  %d%%" % percent


func _on_credits_changed(credits: int) -> void:
	if credits <= BalanceEconomy.UPKEEP_LOW_FUNDS_THRESHOLD:
		_credits_label.text = BalanceEconomy.HUD_CREDITS_LOW_FORMAT % credits
		_credits_label.add_theme_color_override(&"font_color", BalanceUi.FONT_COLOR_WARNING)
	else:
		_credits_label.text = BalanceEconomy.HUD_CREDITS_FORMAT % credits
		_credits_label.add_theme_color_override(&"font_color", BalanceUi.FONT_COLOR)


func _on_fuel_changed(fuel: float, fuel_max: float) -> void:
	var pct: int = 0
	if fuel_max > 0.0:
		pct = int(roundf((fuel / fuel_max) * BalanceEconomy.PERCENT_SCALE))
	_fuel_label.text = BalanceEconomy.HUD_FUEL_FORMAT % pct


func _on_condition_changed(condition: float, condition_max: float) -> void:
	var pct: int = 0
	if condition_max > 0.0:
		pct = int(roundf((condition / condition_max) * BalanceEconomy.PERCENT_SCALE))
	_condition_label.text = BalanceEconomy.HUD_CONDITION_FORMAT % pct


func _on_mission_changed(_template_id: StringName, _entity_id: StringName) -> void:
	_refresh_mission_line()


func _on_mission_closed(_template_id: StringName, _entity_id: StringName, _delta: float) -> void:
	_refresh_mission_line()


func _refresh_mission_line() -> void:
	if _mission_label == null:
		return
	var tree: SceneTree = get_tree()
	var service: Node = null
	if tree != null:
		service = tree.get_first_node_in_group(&"mission_service")
	if (
		service == null
		or not service.has_method(&"has_active")
		or service.call(&"has_active") != true
	):
		_mission_label.text = ""
		return
	var template_raw: Variant = service.call(&"active_template_id")
	var template_id: StringName = _variant_to_name(template_raw)
	var kind: StringName = &""
	if service.has_method(&"active_kind"):
		kind = _variant_to_name(service.call(&"active_kind"))
	_mission_label.text = _mission_line_text(service, kind, template_id)


func _mission_line_text(service: Node, kind: StringName, template_id: StringName) -> String:
	if kind == BalanceStanding.MISSION_KIND_BOUNTY:
		return _mission_line_bounty(service)
	if kind == BalanceStanding.MISSION_KIND_SMUGGLE:
		return _mission_line_smuggle(service, template_id)
	if kind == BalanceStanding.MISSION_KIND_ESCORT:
		return _mission_line_escort(service)
	var job_name: String = _content_name(template_id)
	if service.has_method(&"active_display_label"):
		var runtime_label: String = str(service.call(&"active_display_label"))
		if not runtime_label.is_empty():
			job_name = runtime_label
	var dest_id: StringName = &""
	if service.has_method(&"active_destination_station_id"):
		dest_id = _variant_to_name(service.call(&"active_destination_station_id"))
	if String(dest_id).is_empty():
		return BalanceStanding.HUD_MISSION_NO_DEST_FORMAT % job_name
	return BalanceStanding.HUD_MISSION_FORMAT % [job_name, _content_name(dest_id)]


func _mission_line_bounty(service: Node) -> String:
	var objective_ready: bool = false
	if service.has_method(&"is_objective_ready"):
		objective_ready = service.call(&"is_objective_ready") == true
	if objective_ready:
		var dest_id: StringName = &""
		if service.has_method(&"active_destination_station_id"):
			dest_id = _variant_to_name(service.call(&"active_destination_station_id"))
		return BalanceStanding.HUD_MISSION_BOUNTY_READY_FORMAT % _content_name(dest_id)
	var target_id: StringName = &""
	if service.has_method(&"active_target_system_id"):
		target_id = _variant_to_name(service.call(&"active_target_system_id"))
	return BalanceStanding.HUD_MISSION_BOUNTY_FORMAT % _content_name(target_id)


func _mission_line_smuggle(service: Node, template_id: StringName) -> String:
	var cargo_name: String = _smuggle_cargo_name(service, template_id)
	var smuggle_dest: StringName = &""
	if service.has_method(&"active_destination_station_id"):
		smuggle_dest = _variant_to_name(service.call(&"active_destination_station_id"))
	if String(smuggle_dest).is_empty():
		return BalanceStanding.HUD_MISSION_SMUGGLE_NO_DEST_FORMAT % cargo_name
	return BalanceStanding.HUD_MISSION_SMUGGLE_FORMAT % [cargo_name, _content_name(smuggle_dest)]


func _mission_line_escort(service: Node) -> String:
	var escort_dest: StringName = &""
	if service.has_method(&"active_destination_station_id"):
		escort_dest = _variant_to_name(service.call(&"active_destination_station_id"))
	if service.has_method(&"is_escort_alive") and service.call(&"is_escort_alive") != true:
		return BalanceStanding.HUD_MISSION_ESCORT_LOST
	if String(escort_dest).is_empty():
		return BalanceStanding.HUD_MISSION_ESCORT_NO_DEST
	return BalanceStanding.HUD_MISSION_ESCORT_FORMAT % _content_name(escort_dest)


func _on_system_entered(system_id: StringName) -> void:
	_current_system_id = system_id
	_system_label.text = "SYSTEM  %s" % _content_name(system_id).to_upper()
	_refresh_status_line()
	_refresh_nav_panel()
	_refresh_hostile_flag()
	_refresh_prompt()


## Nav readout text for tests and external readers (HERE + GATES lines).
func nav_here_text() -> String:
	if _nav_here_label == null:
		return ""
	return _nav_here_label.text


## Gate list block from the nav panel (header + lines).
func nav_gates_text() -> String:
	if _nav_gates_label == null:
		return ""
	return _nav_gates_label.text


func _refresh_nav_panel() -> void:
	if _nav_here_label == null or _nav_gates_label == null:
		return
	var here_name: String = _content_name(_current_system_id)
	if here_name.is_empty():
		here_name = "—"
	_nav_here_label.text = BalanceEconomy.NAV_HERE_FORMAT % here_name.to_upper()

	var lines: PackedStringArray = PackedStringArray()
	lines.append(BalanceEconomy.NAV_GATES_HEADER)
	var destinations: Array[StringName] = _gate_destinations_for(_current_system_id)
	if destinations.is_empty():
		lines.append(BalanceEconomy.NAV_NO_GATES)
	else:
		var shown: int = 0
		for dest_id: StringName in destinations:
			if shown >= BalanceEconomy.NAV_MAX_GATE_LINES:
				break
			lines.append(BalanceEconomy.NAV_GATE_LINE_FORMAT % _content_name(dest_id))
			shown += 1
	_nav_gates_label.text = "\n".join(lines)


func _gate_destinations_for(system_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if String(system_id).is_empty() or not ContentLibrary.has_item(system_id):
		return result
	var item: ContentItem = ContentLibrary.item(system_id)
	var system: StarSystem = item as StarSystem
	if system == null:
		return result
	for dest_id: StringName in system.gate_destination_ids:
		result.append(dest_id)
	return result


func _on_status_moment(
	_kind: StringName,
	_place_id: StringName,
	_entity_id: StringName,
	_standing: float,
	_tier: StringName
) -> void:
	_refresh_status_line()


func _on_entity_standing_changed(
	_entity_id: StringName, _old_value: float, _new_value: float, _tier: StringName
) -> void:
	_refresh_status_line()


func _on_dock_prompt_changed(station_id: StringName, can_dock: bool) -> void:
	_dock_prompt_id = station_id
	_dock_can_dock = can_dock
	_refresh_prompt()


func _on_gate_prompt_changed(destination_system_id: StringName, can_jump: bool) -> void:
	_gate_dest_id = destination_system_id
	_gate_can_jump = can_jump
	_refresh_prompt()


func _on_tow_prompt_changed(available: bool, fee_credits: int) -> void:
	_tow_available = available
	_tow_fee = fee_credits
	_refresh_prompt()


func _on_dock_refused(
	_station_id: StringName, _entity_id: StringName, _standing: float, _tier: StringName
) -> void:
	var status: Dictionary = StandingService.status_for_station(_station_id)
	var refuse_tier: StringName = _status_tier(status)
	_prompt_label.text = (
		BalanceStanding.DOCK_REFUSED_PROMPT_FORMAT
		% [
			(
				"%s %s"
				% [
					BalanceStanding.tier_glyph(refuse_tier),
					status[StandingService.STATUS_KEY_TIER_DISPLAY],
				]
			),
			status[StandingService.STATUS_KEY_ENTITY_DISPLAY],
		]
	)
	_prompt_label.add_theme_color_override("font_color", BalanceStanding.tier_color(refuse_tier))


func _on_docked(station_id: StringName) -> void:
	_docked_station_id = station_id
	_dock_prompt_id = &""
	_gate_dest_id = &""
	_prompt_label.text = ""
	_clear_active_incident()
	_refresh_status_line()
	_start_dock_fade(BalanceUi.DOCK_FADE_COLOR)


func _on_undocked(_station_id: StringName) -> void:
	_docked_station_id = &""
	_refresh_status_line()
	_refresh_hostile_flag()
	_refresh_prompt()
	_start_dock_fade(BalanceUi.UNDOCK_FADE_COLOR)


func _start_dock_fade(base: Color) -> void:
	if _dock_fade == null:
		return
	_dock_fade_base = base
	_dock_fade_peak = BalanceUi.DOCK_FADE_PEAK_ALPHA
	_dock_fade_left = BalanceUi.DOCK_FADE_DURATION
	_dock_fade.visible = true
	_dock_fade.color = Color(base.r, base.g, base.b, _dock_fade_peak)


func _on_player_crippled() -> void:
	_crippled = true
	_refresh_prompt()


func _on_player_repaired_from_cripple() -> void:
	_crippled = false
	_refresh_prompt()


func _on_hostile_killed(_system_id: StringName, _victim_entity_id: StringName) -> void:
	_refresh_hostile_flag()
	_refresh_prompt()
	_refresh_mission_line()


func _on_kill_attributed(
	_system_id: StringName, entity_id: StringName, _delta: float, _reason: StringName
) -> void:
	var display: String = _content_name(entity_id)
	if display.is_empty():
		display = String(entity_id)
	_show_kill_toast(BalanceStanding.format_kill_attributed(display))


func _on_kill_unattributed(_system_id: StringName, _victim_entity_id: StringName) -> void:
	_show_kill_toast(BalanceStanding.format_kill_unattributed())


func _show_kill_toast(line: String) -> void:
	if _kill_toast_label == null:
		return
	_kill_toast_label.text = line
	_kill_toast_left = BalanceStanding.HUD_KILL_TOAST_SECONDS


## Job 6: the last route to an ending just shut. Unlike news, this is NOT
## suppressed while docked — it is the one message the player must not miss.
func _on_campaign_ending_blocked(_grade: StringName, line: String) -> void:
	if line.is_empty():
		return
	_show_kill_toast(line)


## REPAIR-3: upkeep miss threshold breached a charter — standing already hit and
## the ship is about to be fired. Always toast (docked or not); missing this is
## how a silent fleet loss looks like a bug.
func _on_ops_charter_breached(_ops_ship_id: StringName, entity_id: StringName) -> void:
	var display: String = _content_name(entity_id)
	if display.is_empty():
		display = String(entity_id)
	if display.is_empty():
		display = "unknown"
	_show_kill_toast(BalanceOps.CHARTER_BREACH_TOAST_FORMAT % display)


## S3b: sector news toast while free-flying (same slot as kill toast).
func _on_market_news_toast(line: String) -> void:
	if String(_docked_station_id).is_empty() == false:
		return
	if line.is_empty():
		return
	_show_kill_toast(line)


## S3b / S4: incident prompt while free-flying; track id/kind for [1]/[2].
func _on_incident_prompt(incident_id: StringName, kind: StringName, prompt: String) -> void:
	if String(_docked_station_id).is_empty() == false:
		return
	if prompt.is_empty():
		return
	_active_incident_id = incident_id
	_active_incident_kind = kind
	_show_kill_toast(prompt)


func _on_incident_resolved(
	incident_id: StringName,
	_kind: StringName,
	_system_id: StringName,
	_outcome: StringName,
	_promoted: bool
) -> void:
	if incident_id == _active_incident_id:
		_clear_active_incident()


func _clear_active_incident() -> void:
	_active_incident_id = &""
	_active_incident_kind = &""


## S4: map incident kind + primary/secondary to a choice (tests / input).
static func choice_for_incident_action(kind: StringName, primary: bool) -> StringName:
	if primary:
		return BalanceEnforcement.primary_choice_for_kind(kind)
	return BalanceEnforcement.secondary_choice_for_kind(kind)


## Active free-flight incident id (tests / external readers).
func active_incident_id() -> StringName:
	return _active_incident_id


## Current kill-feedback toast text (tests / external readers).
func kill_toast_text() -> String:
	if _kill_toast_label == null:
		return ""
	return _kill_toast_label.text


func _unhandled_input(event: InputEvent) -> void:
	if not _can_respond_to_incident():
		return
	if event.is_action_pressed(BalanceEnforcement.ACTION_INCIDENT_A):
		_respond_active_incident(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(BalanceEnforcement.ACTION_INCIDENT_B):
		_respond_active_incident(false)
		get_viewport().set_input_as_handled()


func _can_respond_to_incident() -> bool:
	if String(_docked_station_id).is_empty() == false:
		return false
	if String(_active_incident_id).is_empty():
		return false
	return true


func _respond_active_incident(primary: bool) -> void:
	if not _can_respond_to_incident():
		return
	var choice: StringName = choice_for_incident_action(_active_incident_kind, primary)
	if String(choice).is_empty():
		return
	var incident_id: StringName = _active_incident_id
	IncidentService.respond(incident_id, choice)


func _process(delta: float) -> void:
	if _condition_hit_flash_left <= 0.0 and _dock_fade_left <= 0.0 and _kill_toast_left <= 0.0:
		return
	var dt: float = TimeScale.scaled_delta(delta)
	if _condition_hit_flash_left > 0.0:
		_condition_hit_flash_left = maxf(0.0, _condition_hit_flash_left - dt)
		if _condition_hit_flash_left <= 0.0 and _condition_label != null:
			_condition_label.add_theme_color_override("font_color", _condition_base_color)
	if _dock_fade_left > 0.0 and _dock_fade != null:
		_dock_fade_left = maxf(0.0, _dock_fade_left - dt)
		var duration: float = BalanceUi.DOCK_FADE_DURATION
		var t: float = 0.0 if duration <= 0.0 else _dock_fade_left / duration
		var alpha: float = _dock_fade_peak * t
		_dock_fade.color = Color(_dock_fade_base.r, _dock_fade_base.g, _dock_fade_base.b, alpha)
		if _dock_fade_left <= 0.0:
			_dock_fade.visible = false
			_dock_fade.color = Color(_dock_fade_base.r, _dock_fade_base.g, _dock_fade_base.b, 0.0)
	if _kill_toast_left > 0.0:
		_kill_toast_left = maxf(0.0, _kill_toast_left - dt)
		if _kill_toast_left <= 0.0 and _kill_toast_label != null:
			_kill_toast_label.text = ""


func _on_target_lock_changed(locked: bool, label: String, distance: float) -> void:
	_target_locked = locked
	_target_label_text = label
	_target_distance = distance
	if locked:
		_target_hull_percent = _read_locked_hull_percent()
	else:
		_target_hull_percent = BalanceCombat.HULL_PERCENT_FULL
	_refresh_target_line()


func _on_hostile_damaged(_remaining_hp: float) -> void:
	if not _target_locked:
		return
	# Re-read locked target so profile max_hp is the percent denominator.
	_target_hull_percent = _read_locked_hull_percent()
	_refresh_target_line()


func _on_player_damaged_flash(_condition: float) -> void:
	if _condition_label == null:
		return
	_condition_hit_flash_left = BalanceCombat.HIT_FLASH_SECONDS
	_condition_label.add_theme_color_override("font_color", BalanceCombat.COLOR_CONDITION_HIT_FLASH)


func _read_locked_hull_percent() -> int:
	var full: int = BalanceCombat.HULL_PERCENT_FULL
	var tree: SceneTree = get_tree()
	if tree == null:
		return full
	var ship: Node = tree.get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP)
	if ship == null or not ship.has_method(&"locked_target"):
		return full
	var raw: Variant = ship.call(&"locked_target")
	if raw == null or not (raw is Node):
		return full
	var target: Node = raw
	if not is_instance_valid(target) or not target.has_method(&"remaining_hp"):
		return full
	var hp_raw: Variant = target.call(&"remaining_hp")
	var hp: float = 0.0
	if typeof(hp_raw) == TYPE_FLOAT:
		hp = hp_raw
	elif typeof(hp_raw) == TYPE_INT:
		var hp_i: int = hp_raw
		hp = float(hp_i)
	else:
		return full
	var max_hp: float = BalanceCombat.HOSTILE_HP
	if target.has_method(&"hull_max"):
		var max_raw: Variant = target.call(&"hull_max")
		if typeof(max_raw) == TYPE_FLOAT:
			max_hp = max_raw
		elif typeof(max_raw) == TYPE_INT:
			var max_i: int = max_raw
			max_hp = float(max_i)
	return BalanceCombat.hostile_hull_percent(hp, max_hp)


func _refresh_target_line() -> void:
	if _target_label == null:
		return
	if not _target_locked or _target_label_text.is_empty():
		_target_label.text = BalanceCombat.HUD_TARGET_LOCK_NONE
		return
	_target_label.text = BalanceCombat.format_target_lock_line(
		_target_label_text, _target_distance, _target_hull_percent
	)


func _refresh_hostile_flag() -> void:
	_hostile_present = false
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if is_instance_valid(node):
			_hostile_present = true
			return
