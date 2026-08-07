class_name LossScreen
extends CanvasLayer

## The run is over — hull reached zero away from a berth. Job 10.
##
## Implements: Elliot's 2026-08-07 loss decision — "Losing a fight: death and
## respawn. The run ends and restarts from a defined point."
##
## Before this, zero hull left the ship frozen with "DOCK FOR REPAIR" on screen
## pointing at a station it could not reach, and nothing to reload. This says
## what happened and offers the way back.
##
## Pure view (conventions section 3.1): it listens to `on_player_crippled` to
## know when to appear and emits a request when a button is pressed. It decides
## nothing — Main owns the restart, and `HullConditionService` remains the only
## thing that decides the ship is finished.
##
## Armed / disarmed by Main so a career loaded from a save that was written at
## zero hull does not open the loss screen on top of its own load.

var _panel: PanelContainer = null
var _armed: bool = false
var _open: bool = false


func _ready() -> void:
	layer = BalanceSession.LOSS_SCREEN_CANVAS_LAYER
	visible = false
	_build_ui()
	EventBus.on_player_crippled.connect(_on_player_crippled)
	if not get_viewport().size_changed.is_connected(_fit_panel_to_viewport):
		get_viewport().size_changed.connect(_fit_panel_to_viewport)
	_fit_panel_to_viewport()


func _exit_tree() -> void:
	if EventBus.on_player_crippled.is_connected(_on_player_crippled):
		EventBus.on_player_crippled.disconnect(_on_player_crippled)


## Only a live, playable session may end in a loss screen. Boot, load and
## teardown all arrive here as `false`.
func set_armed(value: bool) -> void:
	_armed = value
	if not value:
		hide_loss()


func is_armed() -> bool:
	return _armed


## Put the run's ending on screen.
func show_loss() -> void:
	_fit_panel_to_viewport()
	_open = true
	visible = true


func hide_loss() -> void:
	_open = false
	visible = false


## Whether the loss screen is currently on screen.
func is_showing() -> bool:
	return _open and visible


func _on_player_crippled() -> void:
	if not _armed:
		return
	show_loss()


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, BalanceSession.LOSS_DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.theme = DraywarUiTheme.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(BalanceSession.LOSS_WIDTH, BalanceSession.LOSS_HEIGHT)
	_panel.offset_left = -BalanceSession.LOSS_HALF_WIDTH
	_panel.offset_top = -BalanceSession.LOSS_HALF_HEIGHT
	_panel.offset_right = BalanceSession.LOSS_HALF_WIDTH
	_panel.offset_bottom = BalanceSession.LOSS_HALF_HEIGHT
	root.add_child(_panel)

	# Title + scrolling body + pinned buttons, so the way out is never pushed
	# off a short window the way the captain sheet's list was (PT-9).
	var outer: VBoxContainer = VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_BEGIN
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(outer)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_WARNING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	title.text = BalanceSession.LOSS_TITLE
	outer.add_child(title)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceSession.LOSS_SPACER)
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
	body.text = BalanceSession.LOSS_BODY
	scroll.add_child(body)

	var spacer_two: Control = Control.new()
	spacer_two.custom_minimum_size = Vector2(0.0, BalanceSession.LOSS_SPACER)
	spacer_two.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(spacer_two)

	var restart_btn: Button = _make_button(outer, BalanceSession.LOSS_RESTART)
	restart_btn.pressed.connect(_on_restart_pressed)

	var quit_btn: Button = _make_button(outer, BalanceSession.LOSS_QUIT)
	quit_btn.pressed.connect(_on_quit_pressed)


func _make_button(parent: Control, text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(
		BalanceSession.LOSS_BUTTON_WIDTH, BalanceSession.LOSS_BUTTON_HEIGHT
	)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(btn)
	return btn


## Cap the panel to the design size (and the viewport) so both buttons stay on
## screen at the shipping window size.
func _fit_panel_to_viewport() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	var w: float = minf(BalanceSession.LOSS_WIDTH, vp.x)
	var h: float = minf(BalanceSession.LOSS_HEIGHT, vp.y)
	var half: float = BalanceSession.LOSS_CENTER_HALF
	_panel.custom_minimum_size = Vector2(w, h)
	_panel.offset_left = -w * half
	_panel.offset_top = -h * half
	_panel.offset_right = w * half
	_panel.offset_bottom = h * half


func _on_restart_pressed() -> void:
	AudioService.play_ui_click()
	EventBus.on_run_restart_requested.emit()


func _on_quit_pressed() -> void:
	AudioService.play_ui_click()
	EventBus.on_quit_to_menu_requested.emit()
