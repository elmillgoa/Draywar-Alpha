class_name NewGameTip
extends CanvasLayer

## Dismissible control tip shown once on New Game — Path C B5.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B5
##
## Constants live in BalanceSession. No new EventBus signals (local dismiss).

var _panel: PanelContainer = null
var _open: bool = false


func _ready() -> void:
	layer = BalanceSession.NEW_GAME_TIP_CANVAS_LAYER
	visible = false
	_build_ui()


## Show the tip (call after a new career boots into play).
func show_tip() -> void:
	_open = true
	visible = true


## Hide without feedback (tear-down / continue path).
func hide_tip() -> void:
	_open = false
	visible = false


## Whether the tip is currently on screen.
func is_open() -> bool:
	return _open and visible


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

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(layout)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = BalanceSession.NEW_GAME_TIP_TITLE
	layout.add_child(title)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceSession.NEW_GAME_TIP_SPACER)
	layout.add_child(spacer)

	var body: Label = Label.new()
	body.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = BalanceSession.NEW_GAME_TIP_BODY
	layout.add_child(body)

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0.0, BalanceSession.NEW_GAME_TIP_SPACER)
	layout.add_child(spacer2)

	var dismiss: Button = Button.new()
	dismiss.text = BalanceSession.NEW_GAME_TIP_DISMISS
	dismiss.custom_minimum_size = Vector2(
		BalanceSession.NEW_GAME_TIP_BUTTON_WIDTH, BalanceSession.NEW_GAME_TIP_BUTTON_HEIGHT
	)
	dismiss.pressed.connect(_on_dismiss_pressed)
	layout.add_child(dismiss)


func _on_dismiss_pressed() -> void:
	hide_tip()
