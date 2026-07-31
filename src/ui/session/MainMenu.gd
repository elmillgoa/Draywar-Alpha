class_name MainMenu
extends CanvasLayer

## Main menu — Path C B2.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B2
##
## New Game / Continue / Quit. Actions go through EventBus. Continue is disabled
## when no career save exists.

var _panel: PanelContainer = null
var _continue_btn: Button = null
var _feedback: Label = null


func _ready() -> void:
	layer = BalanceSession.MAIN_MENU_CANVAS_LAYER
	visible = true
	_build_ui()
	refresh_continue()


## Enable Continue when a most-recent save path exists.
## `has_continue` is supplied by Main (avoids ui→systems direct reach).
func refresh_continue(has_continue: bool = false) -> void:
	if _continue_btn == null:
		return
	_continue_btn.disabled = not has_continue


func show_feedback(text: String) -> void:
	if _feedback != null:
		_feedback.text = text


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, BalanceSession.MENU_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.theme = DraywarUiTheme.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(BalanceSession.MENU_WIDTH, BalanceSession.MENU_HEIGHT)
	_panel.offset_left = -BalanceSession.MENU_HALF_WIDTH
	_panel.offset_top = -BalanceSession.MENU_HALF_HEIGHT
	_panel.offset_right = BalanceSession.MENU_HALF_WIDTH
	_panel.offset_bottom = BalanceSession.MENU_HALF_HEIGHT
	root.add_child(_panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(layout)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = BalanceSession.MAIN_TITLE
	layout.add_child(title)

	if not BalanceSession.MAIN_TAGLINE.strip_edges().is_empty():
		var tagline: Label = Label.new()
		tagline.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tagline.text = BalanceSession.MAIN_TAGLINE
		layout.add_child(tagline)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceSession.MENU_SPACER_HEIGHT)
	layout.add_child(spacer)

	var button_size: Vector2 = Vector2(
		BalanceSession.MENU_BUTTON_WIDTH, BalanceSession.MENU_BUTTON_HEIGHT
	)

	var new_game_btn: Button = _make_button(layout, button_size, BalanceSession.MAIN_NEW_GAME)
	new_game_btn.pressed.connect(_on_new_game_pressed)

	_continue_btn = _make_button(layout, button_size, BalanceSession.MAIN_CONTINUE)
	_continue_btn.pressed.connect(_on_continue_pressed)

	var quit_btn: Button = _make_button(layout, button_size, BalanceSession.MAIN_QUIT)
	quit_btn.pressed.connect(_on_quit_pressed)

	_feedback = Label.new()
	_feedback.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.text = ""
	layout.add_child(_feedback)


func _make_button(parent: Control, size: Vector2, text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = size
	parent.add_child(btn)
	return btn


func _on_new_game_pressed() -> void:
	EventBus.on_new_game_requested.emit()


func _on_continue_pressed() -> void:
	EventBus.on_continue_requested.emit()


func _on_quit_pressed() -> void:
	EventBus.on_quit_to_desktop_requested.emit()
