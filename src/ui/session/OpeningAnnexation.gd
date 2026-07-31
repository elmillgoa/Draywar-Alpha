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


## Show annexation with a baggage line already formatted by Main / caller.
func show_annexation(baggage_line: String) -> void:
	_busy = false
	if _baggage != null:
		_baggage.text = baggage_line
	if _continue_btn != null:
		_continue_btn.disabled = false
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

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(layout)

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
	layout.add_child(spacer3)

	_continue_btn = Button.new()
	_continue_btn.text = BalanceSession.ANNEXATION_CONTINUE
	_continue_btn.custom_minimum_size = Vector2(
		BalanceSession.ANNEXATION_BUTTON_WIDTH, BalanceSession.ANNEXATION_BUTTON_HEIGHT
	)
	_continue_btn.pressed.connect(_on_continue_pressed)
	layout.add_child(_continue_btn)


func _on_continue_pressed() -> void:
	if not _open or _busy:
		return
	_busy = true
	if _continue_btn != null:
		_continue_btn.disabled = true
	EventBus.on_annexation_continue_requested.emit()
