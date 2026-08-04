class_name CampaignJournal
extends CanvasLayer

## Thin campaign journal — Steam S7.
##
## Shows current act and spine blurbs (open / done / locked).
## Open via EventBus; PauseMenu Journal button emits open.

var _panel: PanelContainer = null
var _act_label: Label = null
var _lines_box: VBoxContainer = null


func _ready() -> void:
	layer = BalanceCampaign.JOURNAL_CANVAS_LAYER
	visible = false
	_build_ui()
	EventBus.on_campaign_journal_open_requested.connect(_on_open_requested)
	EventBus.on_campaign_journal_close_requested.connect(_on_close_requested)
	EventBus.on_campaign_flag_set.connect(_on_campaign_changed)
	EventBus.on_spine_completed.connect(_on_spine_completed)
	EventBus.on_campaign_act_changed.connect(_on_act_changed)


func _exit_tree() -> void:
	_disconnect(EventBus.on_campaign_journal_open_requested, _on_open_requested)
	_disconnect(EventBus.on_campaign_journal_close_requested, _on_close_requested)
	_disconnect(EventBus.on_campaign_flag_set, _on_campaign_changed)
	_disconnect(EventBus.on_spine_completed, _on_spine_completed)
	_disconnect(EventBus.on_campaign_act_changed, _on_act_changed)


func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_open_requested() -> void:
	_refresh()
	visible = true


func _on_close_requested() -> void:
	visible = false


func _on_campaign_changed(_flag_name: StringName) -> void:
	if visible:
		_refresh()


func _on_spine_completed(_template_id: StringName) -> void:
	if visible:
		_refresh()


func _on_act_changed(_act: int) -> void:
	if visible:
		_refresh()


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
	_panel.custom_minimum_size = Vector2(
		BalanceCampaign.JOURNAL_WIDTH, BalanceCampaign.JOURNAL_HEIGHT
	)
	_panel.offset_left = -BalanceCampaign.JOURNAL_HALF_WIDTH
	_panel.offset_top = -BalanceCampaign.JOURNAL_HALF_HEIGHT
	_panel.offset_right = BalanceCampaign.JOURNAL_HALF_WIDTH
	_panel.offset_bottom = BalanceCampaign.JOURNAL_HALF_HEIGHT
	root.add_child(_panel)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(outer)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = BalanceCampaign.JOURNAL_TITLE
	outer.add_child(title)

	_act_label = Label.new()
	_act_label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_act_label.text = ""
	outer.add_child(_act_label)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceCampaign.JOURNAL_SPACER)
	outer.add_child(spacer)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_lines_box = VBoxContainer.new()
	_lines_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lines_box)

	var close_btn: Button = Button.new()
	close_btn.text = BalanceCampaign.JOURNAL_CLOSE
	close_btn.custom_minimum_size = Vector2(
		BalanceCampaign.JOURNAL_BUTTON_WIDTH, BalanceCampaign.JOURNAL_BUTTON_HEIGHT
	)
	close_btn.pressed.connect(_on_close_pressed)
	outer.add_child(close_btn)


func _on_close_pressed() -> void:
	EventBus.on_campaign_journal_close_requested.emit()


func _refresh() -> void:
	_clear_lines()
	var campaign: Node = _campaign_service()
	if campaign == null:
		_act_label.text = BalanceCampaign.JOURNAL_ACT_FORMAT % BalanceCampaign.JOURNAL_ACT_NONE
		_add_muted(BalanceCampaign.JOURNAL_EMPTY)
		return
	var act: int = 0
	if campaign.has_method(&"current_act"):
		var act_raw: Variant = campaign.call(&"current_act")
		if typeof(act_raw) == TYPE_INT:
			act = act_raw
		elif typeof(act_raw) == TYPE_FLOAT:
			var act_float: float = act_raw
			act = int(act_float)
	_act_label.text = (BalanceCampaign.JOURNAL_ACT_FORMAT % BalanceCampaign.act_display_name(act))
	var lines_raw: Variant = []
	if campaign.has_method(&"journal_lines"):
		lines_raw = campaign.call(&"journal_lines")
	if typeof(lines_raw) != TYPE_ARRAY:
		_add_muted(BalanceCampaign.JOURNAL_EMPTY)
		return
	var lines: Array = lines_raw
	if lines.is_empty():
		_add_muted(BalanceCampaign.JOURNAL_EMPTY)
		return
	for entry: Variant in lines:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		var title_text: String = str(row.get(BalanceCampaign.JOURNAL_KEY_TITLE, ""))
		var blurb: String = str(row.get(BalanceCampaign.JOURNAL_KEY_BLURB, ""))
		var status: StringName = StringName(str(row.get(BalanceCampaign.JOURNAL_KEY_STATUS, "")))
		var status_label: String = BalanceCampaign.JOURNAL_SECTION_LOCKED
		var color: Color = BalanceUi.FONT_COLOR_MUTED
		if status == BalanceCampaign.JOURNAL_STATUS_DONE:
			status_label = BalanceCampaign.JOURNAL_SECTION_DONE
			color = BalanceUi.ACCENT
		elif status == BalanceCampaign.JOURNAL_STATUS_OPEN:
			status_label = BalanceCampaign.JOURNAL_SECTION_OPEN
			color = BalanceUi.TITLE_COLOR
		var head: Label = Label.new()
		head.add_theme_color_override("font_color", color)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.text = BalanceCampaign.JOURNAL_LINE_FORMAT % [status_label, title_text]
		_lines_box.add_child(head)
		if not blurb.is_empty():
			var body: Label = Label.new()
			body.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.text = blurb
			_lines_box.add_child(body)


func _add_muted(text: String) -> void:
	var label: Label = Label.new()
	label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_lines_box.add_child(label)


func _clear_lines() -> void:
	if _lines_box == null:
		return
	for child: Node in _lines_box.get_children():
		_lines_box.remove_child(child)
		child.queue_free()


func _campaign_service() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(BalanceCampaign.GROUP_CAMPAIGN_SERVICE)
