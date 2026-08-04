class_name OptionsMenu
extends CanvasLayer

## Options / a11y panel — Steam S10.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10
##
## FOV, sensitivity, volumes, fullscreen, key rebinds. Opens from main or pause.

var _root: Control = null
var _panel: PanelContainer = null
var _feedback: Label = null
var _fullscreen_btn: Button = null
var _bind_buttons: Dictionary = {}
var _listening_action: StringName = &""
var _fov_slider: HSlider = null
var _sens_slider: HSlider = null
var _master_slider: HSlider = null
var _ui_slider: HSlider = null
var _sfx_slider: HSlider = null
var _fov_value: Label = null
var _sens_value: Label = null
var _master_value: Label = null
var _ui_value: Label = null
var _sfx_value: Label = null
var _last_value_label: Label = null


func _ready() -> void:
	layer = BalanceSettings.OPTIONS_CANVAS_LAYER
	visible = false
	_build_ui()
	EventBus.on_options_open_requested.connect(_on_open)
	EventBus.on_options_close_requested.connect(_on_close)
	EventBus.on_settings_changed.connect(_refresh_from_service)


func _exit_tree() -> void:
	if EventBus.on_options_open_requested.is_connected(_on_open):
		EventBus.on_options_open_requested.disconnect(_on_open)
	if EventBus.on_options_close_requested.is_connected(_on_close):
		EventBus.on_options_close_requested.disconnect(_on_close)
	if EventBus.on_settings_changed.is_connected(_refresh_from_service):
		EventBus.on_settings_changed.disconnect(_refresh_from_service)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening_action == &"":
		if event.is_action_pressed(BalanceSession.ACTION_PAUSE):
			_close_and_save()
			get_viewport().set_input_as_handled()
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_ESCAPE:
		_listening_action = &""
		_refresh_bind_labels()
		get_viewport().set_input_as_handled()
		return
	SettingsService.set_bind(_listening_action, key_event.physical_keycode)
	SettingsService.save_to_disk()
	_listening_action = &""
	_refresh_bind_labels()
	_feedback.text = BalanceSettings.OPTIONS_APPLY_FEEDBACK
	AudioService.play_ui_confirm()
	get_viewport().set_input_as_handled()


func _on_open() -> void:
	visible = true
	_listening_action = &""
	_refresh_from_service()
	_feedback.text = ""


func _on_close() -> void:
	visible = false
	_listening_action = &""


func _close_and_save() -> void:
	SettingsService.save_to_disk()
	EventBus.on_options_close_requested.emit()


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
		BalanceSettings.OPTIONS_WIDTH, BalanceSettings.OPTIONS_HEIGHT
	)
	_panel.offset_left = -BalanceSettings.OPTIONS_HALF_WIDTH
	_panel.offset_top = -BalanceSettings.OPTIONS_HALF_HEIGHT
	_panel.offset_right = BalanceSettings.OPTIONS_HALF_WIDTH
	_panel.offset_bottom = BalanceSettings.OPTIONS_HALF_HEIGHT
	_root.add_child(_panel)

	var outer: VBoxContainer = VBoxContainer.new()
	_panel.add_child(outer)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = BalanceSettings.OPTIONS_TITLE
	outer.add_child(title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, BalanceSettings.OPTIONS_SCROLL_HEIGHT)
	outer.add_child(scroll)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)

	_fov_slider = _add_slider_row(
		layout,
		BalanceSettings.OPTIONS_FOV,
		BalanceSettings.FOV_MIN,
		BalanceSettings.FOV_MAX,
		BalanceSettings.FOV_STEP,
		SettingsService.fov()
	)
	_fov_value = _last_value_label
	_fov_slider.value_changed.connect(_on_fov_changed)

	_sens_slider = _add_slider_row(
		layout,
		BalanceSettings.OPTIONS_SENSITIVITY,
		BalanceSettings.SENSITIVITY_MIN,
		BalanceSettings.SENSITIVITY_MAX,
		BalanceSettings.SENSITIVITY_STEP,
		SettingsService.sensitivity()
	)
	_sens_value = _last_value_label
	_sens_slider.value_changed.connect(_on_sens_changed)

	_master_slider = _add_slider_row(
		layout,
		BalanceSettings.OPTIONS_MASTER_VOLUME,
		BalanceSettings.VOLUME_MIN,
		BalanceSettings.VOLUME_MAX,
		BalanceSettings.VOLUME_STEP,
		SettingsService.master_volume()
	)
	_master_value = _last_value_label
	_master_slider.value_changed.connect(_on_master_changed)

	_ui_slider = _add_slider_row(
		layout,
		BalanceSettings.OPTIONS_UI_VOLUME,
		BalanceSettings.VOLUME_MIN,
		BalanceSettings.VOLUME_MAX,
		BalanceSettings.VOLUME_STEP,
		SettingsService.ui_volume()
	)
	_ui_value = _last_value_label
	_ui_slider.value_changed.connect(_on_ui_changed)

	_sfx_slider = _add_slider_row(
		layout,
		BalanceSettings.OPTIONS_SFX_VOLUME,
		BalanceSettings.VOLUME_MIN,
		BalanceSettings.VOLUME_MAX,
		BalanceSettings.VOLUME_STEP,
		SettingsService.sfx_volume()
	)
	_sfx_value = _last_value_label
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	_fullscreen_btn = Button.new()
	_fullscreen_btn.custom_minimum_size = Vector2(
		BalanceSession.MENU_BUTTON_WIDTH, BalanceSession.MENU_BUTTON_HEIGHT
	)
	_fullscreen_btn.pressed.connect(_on_fullscreen_pressed)
	layout.add_child(_fullscreen_btn)

	var note: Label = Label.new()
	note.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = BalanceSettings.OPTIONS_CONTROLLER_NOTE
	layout.add_child(note)

	var rebind_header: Label = Label.new()
	rebind_header.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	rebind_header.text = BalanceSettings.OPTIONS_REBINDS_HEADER
	layout.add_child(rebind_header)

	var rebind_hint: Label = Label.new()
	rebind_hint.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	rebind_hint.text = BalanceSettings.OPTIONS_REBIND_HINT
	layout.add_child(rebind_hint)

	for row: Dictionary in BalanceSettings.REBIND_ROWS:
		var action: StringName = row["action"]
		var label_text: String = str(row["label"])
		var row_box: HBoxContainer = HBoxContainer.new()
		layout.add_child(row_box)
		var name_label: Label = Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = label_text
		row_box.add_child(name_label)
		var bind_btn: Button = Button.new()
		bind_btn.custom_minimum_size = Vector2(
			BalanceSettings.OPTIONS_BIND_BUTTON_WIDTH, BalanceSettings.OPTIONS_BIND_BUTTON_HEIGHT
		)
		bind_btn.pressed.connect(_on_bind_pressed.bind(action))
		row_box.add_child(bind_btn)
		_bind_buttons[action] = bind_btn

	var reset_btn: Button = Button.new()
	reset_btn.text = BalanceSettings.OPTIONS_RESET
	reset_btn.custom_minimum_size = Vector2(
		BalanceSession.MENU_BUTTON_WIDTH, BalanceSession.MENU_BUTTON_HEIGHT
	)
	reset_btn.pressed.connect(_on_reset_pressed)
	outer.add_child(reset_btn)

	var close_btn: Button = Button.new()
	close_btn.text = BalanceSettings.OPTIONS_CLOSE
	close_btn.custom_minimum_size = Vector2(
		BalanceSession.MENU_BUTTON_WIDTH, BalanceSession.MENU_BUTTON_HEIGHT
	)
	close_btn.pressed.connect(_on_close_pressed)
	outer.add_child(close_btn)

	_feedback = Label.new()
	_feedback.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.text = ""
	outer.add_child(_feedback)

	_refresh_from_service()


func _add_slider_row(
	parent: Control, title: String, min_v: float, max_v: float, step: float, start: float
) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = title
	row.add_child(name_label)
	var value_label: Label = Label.new()
	value_label.custom_minimum_size = Vector2(BalanceSettings.OPTIONS_VALUE_LABEL_WIDTH, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_last_value_label = value_label
	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = start
	slider.custom_minimum_size = Vector2(
		BalanceSettings.OPTIONS_SLIDER_WIDTH, BalanceSettings.OPTIONS_SLIDER_HEIGHT
	)
	row.add_child(slider)
	return slider


func _refresh_from_service() -> void:
	if _fov_slider != null:
		_fov_slider.set_value_no_signal(SettingsService.fov())
		_fov_value.text = str(_round_to_int(SettingsService.fov()))
	if _sens_slider != null:
		_sens_slider.set_value_no_signal(SettingsService.sensitivity())
		_sens_value.text = "%.2f" % SettingsService.sensitivity()
	if _master_slider != null:
		_master_slider.set_value_no_signal(SettingsService.master_volume())
		_master_value.text = (
			"%d%%"
			% _round_to_int(SettingsService.master_volume() * BalanceSettings.OPTIONS_PERCENT_SCALE)
		)
	if _ui_slider != null:
		_ui_slider.set_value_no_signal(SettingsService.ui_volume())
		_ui_value.text = (
			"%d%%"
			% _round_to_int(SettingsService.ui_volume() * BalanceSettings.OPTIONS_PERCENT_SCALE)
		)
	if _sfx_slider != null:
		_sfx_slider.set_value_no_signal(SettingsService.sfx_volume())
		_sfx_value.text = (
			"%d%%"
			% _round_to_int(SettingsService.sfx_volume() * BalanceSettings.OPTIONS_PERCENT_SCALE)
		)
	_update_fullscreen_label()
	_refresh_bind_labels()


func _update_fullscreen_label() -> void:
	if _fullscreen_btn == null:
		return
	if SettingsService.fullscreen():
		_fullscreen_btn.text = BalanceSettings.OPTIONS_FULLSCREEN_ON
	else:
		_fullscreen_btn.text = BalanceSettings.OPTIONS_FULLSCREEN_OFF


func _refresh_bind_labels() -> void:
	for action: Variant in _bind_buttons.keys():
		var btn: Button = _bind_buttons[action]
		var act: StringName = action
		if act == _listening_action:
			btn.text = BalanceSettings.OPTIONS_LISTENING
		else:
			btn.text = SettingsService.bind_label(act)


func _on_fov_changed(value: float) -> void:
	SettingsService.set_fov(value)
	SettingsService.save_to_disk()
	_fov_value.text = str(_round_to_int(value))


func _on_sens_changed(value: float) -> void:
	SettingsService.set_sensitivity(value)
	SettingsService.save_to_disk()
	_sens_value.text = "%.2f" % value


func _on_master_changed(value: float) -> void:
	SettingsService.set_master_volume(value)
	SettingsService.save_to_disk()
	_master_value.text = ("%d%%" % _round_to_int(value * BalanceSettings.OPTIONS_PERCENT_SCALE))


func _on_ui_changed(value: float) -> void:
	SettingsService.set_ui_volume(value)
	SettingsService.save_to_disk()
	_ui_value.text = "%d%%" % _round_to_int(value * BalanceSettings.OPTIONS_PERCENT_SCALE)
	AudioService.play_ui_click()


func _on_sfx_changed(value: float) -> void:
	SettingsService.set_sfx_volume(value)
	SettingsService.save_to_disk()
	_sfx_value.text = "%d%%" % _round_to_int(value * BalanceSettings.OPTIONS_PERCENT_SCALE)
	AudioService.play_weapon()


func _on_fullscreen_pressed() -> void:
	SettingsService.set_fullscreen(not SettingsService.fullscreen())
	SettingsService.save_to_disk()
	_update_fullscreen_label()
	AudioService.play_ui_click()


func _on_bind_pressed(action: StringName) -> void:
	_listening_action = action
	_refresh_bind_labels()


func _on_reset_pressed() -> void:
	SettingsService.reset_to_defaults()
	_feedback.text = BalanceSettings.OPTIONS_APPLY_FEEDBACK
	AudioService.play_ui_confirm()


func _on_close_pressed() -> void:
	AudioService.play_ui_click()
	_close_and_save()


func _round_to_int(value: float) -> int:
	var rounded: float = roundf(value)
	return int(rounded)
