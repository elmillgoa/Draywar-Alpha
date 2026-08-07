class_name NewGameTip
extends CanvasLayer

## Dismissible control tip shown once on New Game — Path C B5.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B5
## REPAIR-1: panel stays within budget height; body scrolls; Escape dismisses.
##
## Constants live in BalanceSession. No new EventBus signals (local dismiss).

var _panel: PanelContainer = null
var _open: bool = false


func _ready() -> void:
	layer = BalanceSession.NEW_GAME_TIP_CANVAS_LAYER
	visible = false
	_build_ui()
	if not get_viewport().size_changed.is_connected(_fit_panel_to_viewport):
		get_viewport().size_changed.connect(_fit_panel_to_viewport)
	_fit_panel_to_viewport()


## Show the tip (call after a new career boots into play).
func show_tip() -> void:
	_fit_panel_to_viewport()
	_open = true
	visible = true


## Hide without feedback (tear-down / continue path).
func hide_tip() -> void:
	_open = false
	visible = false


## Whether the tip is currently on screen.
func is_open() -> bool:
	return _open and visible


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not visible:
		return
	var key_event: InputEventKey = event as InputEventKey
	if (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and (key_event.physical_keycode == KEY_ESCAPE or key_event.keycode == KEY_ESCAPE)
	):
		hide_tip()
		get_viewport().set_input_as_handled()
		return
	# Production binds Escape to pause_menu; only probe when the map exists.
	if (
		InputMap.has_action(BalanceSession.ACTION_PAUSE)
		and event.is_action_pressed(BalanceSession.ACTION_PAUSE)
	):
		hide_tip()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, BalanceSession.NEW_GAME_TIP_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.theme = DraywarUiTheme.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(
		BalanceSession.NEW_GAME_TIP_WIDTH, BalanceSession.NEW_GAME_TIP_HEIGHT
	)
	_panel.offset_left = -BalanceSession.NEW_GAME_TIP_HALF_WIDTH
	_panel.offset_top = -BalanceSession.NEW_GAME_TIP_HALF_HEIGHT
	_panel.offset_right = BalanceSession.NEW_GAME_TIP_HALF_WIDTH
	_panel.offset_bottom = BalanceSession.NEW_GAME_TIP_HALF_HEIGHT
	root.add_child(_panel)

	# Title + scroll body + pinned dismiss (footer always on screen).
	var outer: VBoxContainer = VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_BEGIN
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(outer)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	title.text = BalanceSession.NEW_GAME_TIP_TITLE
	outer.add_child(title)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceSession.NEW_GAME_TIP_SPACER)
	spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(spacer)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)

	var body: Label = Label.new()
	body.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.text = BalanceSession.NEW_GAME_TIP_BODY
	scroll.add_child(body)

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0.0, BalanceSession.NEW_GAME_TIP_SPACER)
	spacer2.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(spacer2)

	var dismiss: Button = Button.new()
	dismiss.text = BalanceSession.NEW_GAME_TIP_DISMISS
	dismiss.custom_minimum_size = Vector2(
		BalanceSession.NEW_GAME_TIP_BUTTON_WIDTH, BalanceSession.NEW_GAME_TIP_BUTTON_HEIGHT
	)
	dismiss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dismiss.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dismiss.pressed.connect(_on_dismiss_pressed)
	outer.add_child(dismiss)


## Cap the panel to the design height (and viewport) so Got it never sits off-screen.
func _fit_panel_to_viewport() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	# Design budget is the max; shrink further only if the window is smaller.
	var w: float = BalanceSession.NEW_GAME_TIP_WIDTH
	var h: float = BalanceSession.NEW_GAME_TIP_HEIGHT
	if vp.x > 1.0:
		w = minf(w, vp.x)
	if vp.y > 1.0:
		h = minf(h, vp.y)
	var half: float = BalanceSession.NEW_GAME_TIP_CENTER_HALF
	_panel.custom_minimum_size = Vector2(w, h)
	_panel.offset_left = -w * half
	_panel.offset_top = -h * half
	_panel.offset_right = w * half
	_panel.offset_bottom = h * half


func _on_dismiss_pressed() -> void:
	hide_tip()
