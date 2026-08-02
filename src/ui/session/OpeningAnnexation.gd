class_name OpeningAnnexation
extends CanvasLayer

## Opening annexation beat — presentation only (E4.3 / D5).
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.3 / D5–D6, D11
##
## Shown once after life-path apply, before fly tip + starter dock. Does not
## mutate world control. Baggage line reflects post-path local standing.
## Continue is one-shot while open (no free mid-press).

var _panel: PanelContainer = null
var _baggage: Label = null
var _continue_btn: Button = null
var _open: bool = false
var _busy: bool = false


func _ready() -> void:
	layer = BalanceSession.ANNEXATION_CANVAS_LAYER
	visible = false
	_build_ui()
	if not get_viewport().size_changed.is_connected(_fit_panel_to_viewport):
		get_viewport().size_changed.connect(_fit_panel_to_viewport)
	_fit_panel_to_viewport()


## Show annexation with a baggage line already formatted by Main / caller.
func show_annexation(baggage_line: String) -> void:
	_busy = false
	if _baggage != null:
		_baggage.text = baggage_line
	if _continue_btn != null:
		_continue_btn.disabled = false
	_fit_panel_to_viewport()
	_open = true
	visible = true


## Hide without emitting (Main after continue / tear-down).
func hide_annexation() -> void:
	_open = false
	_busy = false
	visible = false


## Whether the annexation beat is currently on screen.
func is_open() -> bool:
	return _open and visible


## Build baggage from a StandingService status dictionary (system or station).
static func baggage_from_status(status: Dictionary) -> String:
	if status.is_empty():
		return BalanceSession.ANNEXATION_BAGGAGE_UNCONTROLLED
	var uncontrolled: bool = true
	if status.has(StandingService.STATUS_KEY_UNCONTROLLED):
		var flag: Variant = status[StandingService.STATUS_KEY_UNCONTROLLED]
		if typeof(flag) == TYPE_BOOL:
			var flag_bool: bool = flag
			uncontrolled = flag_bool
	if uncontrolled:
		return BalanceSession.ANNEXATION_BAGGAGE_UNCONTROLLED
	var tier_display: String = ""
	var entity_display: String = ""
	if status.has(StandingService.STATUS_KEY_TIER_DISPLAY):
		tier_display = str(status[StandingService.STATUS_KEY_TIER_DISPLAY])
	if status.has(StandingService.STATUS_KEY_ENTITY_DISPLAY):
		entity_display = str(status[StandingService.STATUS_KEY_ENTITY_DISPLAY])
	if tier_display.strip_edges().is_empty() or entity_display.strip_edges().is_empty():
		return BalanceSession.ANNEXATION_BAGGAGE_UNCONTROLLED
	return BalanceSession.ANNEXATION_BAGGAGE_FORMAT % [tier_display, entity_display]


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, BalanceSession.ANNEXATION_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.theme = DraywarUiTheme.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(
		BalanceSession.ANNEXATION_WIDTH, BalanceSession.ANNEXATION_HEIGHT
	)
	_panel.offset_left = -BalanceSession.ANNEXATION_HALF_WIDTH
	_panel.offset_top = -BalanceSession.ANNEXATION_HALF_HEIGHT
	_panel.offset_right = BalanceSession.ANNEXATION_HALF_WIDTH
	_panel.offset_bottom = BalanceSession.ANNEXATION_HALF_HEIGHT
	root.add_child(_panel)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_BEGIN
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(outer)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(layout)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = BalanceSession.ANNEXATION_TITLE
	layout.add_child(title)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceSession.ANNEXATION_SPACER)
	layout.add_child(spacer)

	var body: Label = Label.new()
	body.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = BalanceSession.ANNEXATION_BODY
	layout.add_child(body)

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0.0, BalanceSession.ANNEXATION_SPACER)
	layout.add_child(spacer2)

	_baggage = Label.new()
	_baggage.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_baggage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_baggage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_baggage.text = ""
	layout.add_child(_baggage)

	var spacer3: Control = Control.new()
	spacer3.custom_minimum_size = Vector2(0.0, BalanceSession.ANNEXATION_SPACER)
	outer.add_child(spacer3)

	_continue_btn = Button.new()
	_continue_btn.text = BalanceSession.ANNEXATION_CONTINUE
	_continue_btn.custom_minimum_size = Vector2(
		BalanceSession.ANNEXATION_BUTTON_WIDTH, BalanceSession.ANNEXATION_BUTTON_HEIGHT
	)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_continue_btn.pressed.connect(_on_continue_pressed)
	outer.add_child(_continue_btn)


## Cap the modal to the visible window so Continue never sits off-screen.
func _fit_panel_to_viewport() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	var margin: float = BalanceSession.ANNEXATION_VIEWPORT_MARGIN
	var avail_w: float = vp.x - margin - margin
	var avail_h: float = vp.y - margin - margin
	var w: float = BalanceSession.ANNEXATION_WIDTH
	var h: float = BalanceSession.ANNEXATION_HEIGHT
	if avail_w > 1.0:
		w = minf(w, avail_w)
	if avail_h > 1.0:
		h = minf(h, avail_h)
	var half: float = BalanceSession.ANNEXATION_CENTER_HALF
	_panel.custom_minimum_size = Vector2(w, h)
	_panel.offset_left = -w * half
	_panel.offset_top = -h * half
	_panel.offset_right = w * half
	_panel.offset_bottom = h * half


func _on_continue_pressed() -> void:
	if not _open or _busy:
		return
	_busy = true
	if _continue_btn != null:
		_continue_btn.disabled = true
	EventBus.on_annexation_continue_requested.emit()
