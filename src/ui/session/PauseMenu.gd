class_name PauseMenu
extends CanvasLayer

## Pause menu — Path C B2.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B2
##
## Resume, captain sheet, save, load, quit to menu. Visibility follows
## on_pause_changed.

var _panel: PanelContainer = null
var _feedback: Label = null
var _root: Control = null


func _ready() -> void:
	layer = BalanceSession.PAUSE_MENU_CANVAS_LAYER
	visible = false
	_build_ui()
	EventBus.on_pause_changed.connect(_on_pause_changed)


func _exit_tree() -> void:
	if EventBus.on_pause_changed.is_connected(_on_pause_changed):
		EventBus.on_pause_changed.disconnect(_on_pause_changed)


func show_feedback(text: String) -> void:
	if _feedback != null:
		_feedback.text = text


func _on_pause_changed(open: bool) -> void:
	visible = open
	if open:
		show_feedback("")


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, BalanceSession.MENU_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.theme = DraywarUiTheme.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(
		BalanceSession.MENU_WIDTH, BalanceSession.MENU_HEIGHT_WITH_MAP
	)
	_panel.offset_left = -BalanceSession.MENU_HALF_WIDTH
	_panel.offset_top = -BalanceSession.MENU_HALF_HEIGHT_WITH_MAP
	_panel.offset_right = BalanceSession.MENU_HALF_WIDTH
	_panel.offset_bottom = BalanceSession.MENU_HALF_HEIGHT_WITH_MAP
	_root.add_child(_panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(layout)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = BalanceSession.PAUSE_TITLE
	layout.add_child(title)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceSession.MENU_SPACER_HEIGHT)
	layout.add_child(spacer)

	var button_size: Vector2 = Vector2(
		BalanceSession.MENU_BUTTON_WIDTH, BalanceSession.MENU_BUTTON_HEIGHT
	)

	var resume_btn: Button = _make_button(layout, button_size, BalanceSession.PAUSE_RESUME)
	resume_btn.pressed.connect(_on_resume_pressed)

	var sheet_btn: Button = _make_button(layout, button_size, BalanceSession.PAUSE_CAPTAIN_SHEET)
	sheet_btn.pressed.connect(_on_sheet_pressed)

	var map_btn: Button = _make_button(layout, button_size, BalanceSession.PAUSE_SECTOR_MAP)
	map_btn.pressed.connect(_on_map_pressed)

	var save_btn: Button = _make_button(layout, button_size, BalanceSession.PAUSE_SAVE)
	save_btn.pressed.connect(_on_save_pressed)

	var load_btn: Button = _make_button(layout, button_size, BalanceSession.PAUSE_LOAD)
	load_btn.pressed.connect(_on_load_pressed)

	var quit_btn: Button = _make_button(layout, button_size, BalanceSession.PAUSE_QUIT_TO_MENU)
	quit_btn.pressed.connect(_on_quit_to_menu_pressed)

	_feedback = Label.new()
	_feedback.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.text = ""
	layout.add_child(_feedback)


func _make_button(parent: Control, size: Vector2, text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = size
	parent.add_child(btn)
	return btn


func _on_resume_pressed() -> void:
	EventBus.on_pause_changed.emit(false)


func _on_sheet_pressed() -> void:
	EventBus.on_captain_sheet_open_requested.emit()


func _on_map_pressed() -> void:
	EventBus.on_sector_map_open_requested.emit()


func _on_save_pressed() -> void:
	EventBus.on_manual_save_requested.emit()


func _on_load_pressed() -> void:
	EventBus.on_manual_load_requested.emit()


func _on_quit_to_menu_pressed() -> void:
	EventBus.on_quit_to_menu_requested.emit()
