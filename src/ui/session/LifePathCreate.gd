class_name LifePathCreate
extends CanvasLayer

## Life-path create screen — three axes, confirm applies teeth (E4.2).
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.2 / D1–D3, D11–D12
##
## Cold New Game only. Confirm disabled until every axis has a pick. Cancel
## returns to main menu (Main tears down). Theme shared with session shell.
## Actions go through EventBus — no free mid-press (one-shot while open).

var _panel: PanelContainer = null
var _confirm_btn: Button = null
var _cancel_btn: Button = null
var _hint: Label = null
var _open: bool = false
var _busy: bool = false

var _selected_origin: StringName = &""
var _selected_trade: StringName = &""
var _selected_mark: StringName = &""

## option_id → Button for selected-state styling.
var _option_buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	layer = BalanceSession.LIFE_PATH_CREATE_CANVAS_LAYER
	visible = false
	_build_ui()


## Open the create screen and reset picks to none.
func show_create() -> void:
	_busy = false
	_selected_origin = &""
	_selected_trade = &""
	_selected_mark = &""
	if _cancel_btn != null:
		_cancel_btn.disabled = false
	_clear_button_highlights()
	_refresh_confirm_state()
	_open = true
	visible = true


## Hide without emitting (Main after confirm / cancel / tear-down).
func hide_create() -> void:
	_open = false
	_busy = false
	visible = false


## Whether the create screen is currently shown.
func is_open() -> bool:
	return _open and visible


## Current origin pick (empty if none).
func selected_origin() -> StringName:
	return _selected_origin


## Current trade pick (empty if none).
func selected_trade() -> StringName:
	return _selected_trade


## Current mark pick (empty if none).
func selected_mark() -> StringName:
	return _selected_mark


## True when all three axes have a selection.
func has_full_selection() -> bool:
	return (
		not String(_selected_origin).is_empty()
		and not String(_selected_trade).is_empty()
		and not String(_selected_mark).is_empty()
	)


## Player-facing teeth line for one option (standing + optional debt).
static func format_teeth_summary(option: LifePathOption) -> String:
	if option == null:
		return BalanceSession.LIFE_PATH_CREATE_TEETH_NONE
	var parts: PackedStringArray = []
	for entry: LifePathStandingDelta in option.entity_deltas:
		var line: String = _format_delta_line(entry)
		if not line.is_empty():
			parts.append(line)
	for entry: LifePathStandingDelta in option.person_deltas:
		var line: String = _format_delta_line(entry)
		if not line.is_empty():
			parts.append(line)
	if option.starts_with_debt:
		parts.append(
			(
				BalanceSession.LIFE_PATH_CREATE_TEETH_DEBT
				% [BalanceEconomy.LOAN_PRINCIPAL, BalanceEconomy.LOAN_REPAY_TOTAL]
			)
		)
	if parts.is_empty():
		return BalanceSession.LIFE_PATH_CREATE_TEETH_NONE
	return BalanceSession.LIFE_PATH_CREATE_TEETH_JOIN.join(parts)


static func _format_delta_line(entry: LifePathStandingDelta) -> String:
	if entry == null or String(entry.target_id).is_empty():
		return ""
	if is_equal_approx(entry.delta, 0.0):
		return ""
	var display: String = String(entry.target_id)
	if ContentLibrary.has_item(entry.target_id):
		var item: ContentItem = ContentLibrary.item(entry.target_id)
		if item != null and not item.display_name.strip_edges().is_empty():
			display = item.display_name
	var delta_i: int = int(entry.delta)
	return BalanceSession.LIFE_PATH_CREATE_TEETH_DELTA_FORMAT % [display, delta_i]


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, BalanceSession.LIFE_PATH_CREATE_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.theme = DraywarUiTheme.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(
		BalanceSession.LIFE_PATH_CREATE_WIDTH, BalanceSession.LIFE_PATH_CREATE_HEIGHT
	)
	_panel.offset_left = -BalanceSession.LIFE_PATH_CREATE_HALF_WIDTH
	_panel.offset_top = -BalanceSession.LIFE_PATH_CREATE_HALF_HEIGHT
	_panel.offset_right = BalanceSession.LIFE_PATH_CREATE_HALF_WIDTH
	_panel.offset_bottom = BalanceSession.LIFE_PATH_CREATE_HALF_HEIGHT
	root.add_child(_panel)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_BEGIN
	_panel.add_child(outer)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = BalanceSession.LIFE_PATH_CREATE_TITLE
	outer.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.text = BalanceSession.LIFE_PATH_CREATE_SUBTITLE
	outer.add_child(subtitle)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceSession.LIFE_PATH_CREATE_SPACER)
	outer.add_child(spacer)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", int(BalanceSession.LIFE_PATH_CREATE_AXIS_GAP))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)

	_build_axis_column(
		columns, BalanceSession.LIFE_PATH_CREATE_AXIS_ORIGIN, BalanceStanding.LIFE_PATH_AXIS_ORIGIN
	)
	_build_axis_column(
		columns, BalanceSession.LIFE_PATH_CREATE_AXIS_TRADE, BalanceStanding.LIFE_PATH_AXIS_TRADE
	)
	_build_axis_column(
		columns, BalanceSession.LIFE_PATH_CREATE_AXIS_MARK, BalanceStanding.LIFE_PATH_AXIS_MARK
	)

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0.0, BalanceSession.LIFE_PATH_CREATE_SPACER)
	outer.add_child(spacer2)

	_hint = Label.new()
	_hint.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.text = BalanceSession.LIFE_PATH_CREATE_NEED_ALL
	outer.add_child(_hint)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", BalanceSession.LIFE_PATH_CREATE_ACTION_GAP)
	outer.add_child(actions)

	var button_size: Vector2 = Vector2(
		BalanceSession.LIFE_PATH_CREATE_BUTTON_WIDTH, BalanceSession.LIFE_PATH_CREATE_BUTTON_HEIGHT
	)

	_cancel_btn = Button.new()
	_cancel_btn.text = BalanceSession.LIFE_PATH_CREATE_CANCEL
	_cancel_btn.custom_minimum_size = button_size
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	actions.add_child(_cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = BalanceSession.LIFE_PATH_CREATE_CONFIRM
	_confirm_btn.custom_minimum_size = button_size
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	actions.add_child(_confirm_btn)

	_refresh_confirm_state()


func _build_axis_column(parent: Control, axis_title: String, axis: StringName) -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(BalanceSession.LIFE_PATH_CREATE_COLUMN_MIN_WIDTH, 0.0)
	parent.add_child(col)

	var header: Label = Label.new()
	header.add_theme_color_override("font_color", BalanceUi.ACCENT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.text = axis_title
	col.add_child(header)

	var options: Array[LifePathOption] = _options_for_axis(axis)
	for option: LifePathOption in options:
		var btn: Button = Button.new()
		btn.text = _option_button_text(option)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0.0, BalanceSession.LIFE_PATH_CREATE_OPTION_MIN_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var option_id: StringName = option.id
		btn.pressed.connect(_on_option_pressed.bind(axis, option_id))
		col.add_child(btn)
		_option_buttons[option_id] = btn


func _options_for_axis(axis: StringName) -> Array[LifePathOption]:
	var out: Array[LifePathOption] = []
	for item: ContentItem in ContentLibrary.items_in(BalanceStanding.LIFE_PATH_CONTENT_CATEGORY):
		if not (item is LifePathOption):
			continue
		var option: LifePathOption = item as LifePathOption
		if option.axis != axis:
			continue
		out.append(option)
	return out


func _option_button_text(option: LifePathOption) -> String:
	var blurb: String = option.blurb.strip_edges()
	if blurb.is_empty():
		blurb = BalanceSession.LIFE_PATH_CREATE_BLURB_FALLBACK
	var teeth: String = format_teeth_summary(option)
	return BalanceSession.LIFE_PATH_CREATE_OPTION_FORMAT % [option.display_name, blurb, teeth]


func _on_option_pressed(axis: StringName, option_id: StringName) -> void:
	if not _open or _busy:
		return
	if axis == BalanceStanding.LIFE_PATH_AXIS_ORIGIN:
		_selected_origin = option_id
	elif axis == BalanceStanding.LIFE_PATH_AXIS_TRADE:
		_selected_trade = option_id
	elif axis == BalanceStanding.LIFE_PATH_AXIS_MARK:
		_selected_mark = option_id
	else:
		return
	_refresh_option_highlights()
	_refresh_confirm_state()


func _clear_button_highlights() -> void:
	for option_id: StringName in _option_buttons:
		var btn: Button = _option_buttons[option_id]
		if btn != null:
			btn.modulate = Color.WHITE


func _refresh_option_highlights() -> void:
	_clear_button_highlights()
	_highlight_if_selected(_selected_origin)
	_highlight_if_selected(_selected_trade)
	_highlight_if_selected(_selected_mark)


func _highlight_if_selected(option_id: StringName) -> void:
	if String(option_id).is_empty():
		return
	if not _option_buttons.has(option_id):
		return
	var btn: Button = _option_buttons[option_id]
	if btn != null:
		btn.modulate = BalanceUi.ACCENT


func _refresh_confirm_state() -> void:
	var can_confirm: bool = has_full_selection()
	if _confirm_btn != null:
		_confirm_btn.disabled = not can_confirm or _busy
	if _hint != null:
		if can_confirm:
			_hint.text = ""
		else:
			_hint.text = BalanceSession.LIFE_PATH_CREATE_NEED_ALL


func _on_confirm_pressed() -> void:
	if not _open or _busy:
		return
	if not has_full_selection():
		return
	_busy = true
	if _confirm_btn != null:
		_confirm_btn.disabled = true
	if _cancel_btn != null:
		_cancel_btn.disabled = true
	EventBus.on_life_path_confirmed.emit(_selected_origin, _selected_trade, _selected_mark)


func _on_cancel_pressed() -> void:
	if not _open or _busy:
		return
	_busy = true
	if _confirm_btn != null:
		_confirm_btn.disabled = true
	if _cancel_btn != null:
		_cancel_btn.disabled = true
	EventBus.on_life_path_cancel_requested.emit()
