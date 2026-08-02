class_name SectorMapPanel
extends CanvasLayer

## Sector chart — E5.5. Functional map: all systems, gate links, current highlight.
##
## Open from pause (button) or flight (M). No click-to-jump.

var _root: Control = null
var _panel: PanelContainer = null
var _chart: Control = null
var _current_label: Label = null
var _current_system_id: StringName = &""
var _node_labels: Dictionary = {}


func _ready() -> void:
	layer = BalanceSession.SECTOR_MAP_CANVAS_LAYER
	visible = false
	_build_ui()
	EventBus.on_sector_map_open_requested.connect(_on_open_requested)
	EventBus.on_sector_map_close_requested.connect(_on_close_requested)
	EventBus.on_system_entered.connect(_on_system_entered)
	EventBus.on_pause_changed.connect(_on_pause_changed)


func _exit_tree() -> void:
	if EventBus.on_sector_map_open_requested.is_connected(_on_open_requested):
		EventBus.on_sector_map_open_requested.disconnect(_on_open_requested)
	if EventBus.on_sector_map_close_requested.is_connected(_on_close_requested):
		EventBus.on_sector_map_close_requested.disconnect(_on_close_requested)
	if EventBus.on_system_entered.is_connected(_on_system_entered):
		EventBus.on_system_entered.disconnect(_on_system_entered)
	if EventBus.on_pause_changed.is_connected(_on_pause_changed):
		EventBus.on_pause_changed.disconnect(_on_pause_changed)


## Test helper: system ids currently drawn as node labels.
func listed_system_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _node_labels.keys():
		if typeof(key) == TYPE_STRING_NAME:
			var as_name: StringName = key
			out.append(as_name)
		elif typeof(key) == TYPE_STRING:
			var as_text: String = key
			out.append(StringName(as_text))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## Test helper: undirected edge pairs from chart data (sorted "a|b" keys).
func chart_edge_keys() -> PackedStringArray:
	var keys: Dictionary = {}
	for id: StringName in ContentLibrary.ids_in(&"star_systems"):
		for dest: StringName in SectorGraph.neighbors(id):
			var a: String = String(id)
			var b: String = String(dest)
			var key: String = a + "|" + b if a < b else b + "|" + a
			keys[key] = true
	var out: PackedStringArray = PackedStringArray()
	var sorted_keys: Array = keys.keys()
	sorted_keys.sort()
	for raw_key: Variant in sorted_keys:
		out.append(str(raw_key))
	return out


## Test helper: current highlight system id.
func current_system_id() -> StringName:
	return _current_system_id


func _on_open_requested() -> void:
	_refresh_chart()
	visible = true


func _on_close_requested() -> void:
	visible = false


func _on_system_entered(system_id: StringName) -> void:
	_current_system_id = system_id
	if visible:
		_refresh_chart()
	else:
		_update_current_line()


func _on_pause_changed(open: bool) -> void:
	if not open and visible:
		# Closing pause does not force-close map if opened from flight; leave open.
		pass


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
		BalanceSession.SECTOR_MAP_WIDTH, BalanceSession.SECTOR_MAP_HEIGHT
	)
	_panel.offset_left = -BalanceSession.SECTOR_MAP_HALF_WIDTH
	_panel.offset_top = -BalanceSession.SECTOR_MAP_HALF_HEIGHT
	_panel.offset_right = BalanceSession.SECTOR_MAP_HALF_WIDTH
	_panel.offset_bottom = BalanceSession.SECTOR_MAP_HALF_HEIGHT
	_root.add_child(_panel)

	var layout: VBoxContainer = VBoxContainer.new()
	_panel.add_child(layout)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", BalanceFlight.HUD_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = BalanceSession.SECTOR_MAP_TITLE
	layout.add_child(title)

	_current_label = Label.new()
	_current_label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_label.text = ""
	layout.add_child(_current_label)

	_chart = Control.new()
	_chart.custom_minimum_size = Vector2(
		BalanceSession.SECTOR_MAP_CHART_WIDTH, BalanceSession.SECTOR_MAP_CHART_HEIGHT
	)
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_chart)

	var close_btn: Button = Button.new()
	close_btn.text = BalanceSession.SECTOR_MAP_CLOSE
	close_btn.custom_minimum_size = Vector2(
		BalanceSession.MENU_BUTTON_WIDTH, BalanceSession.MENU_BUTTON_HEIGHT
	)
	close_btn.pressed.connect(_on_close_pressed)
	layout.add_child(close_btn)


func _on_close_pressed() -> void:
	EventBus.on_sector_map_close_requested.emit()


func _refresh_chart() -> void:
	for child: Node in _chart.get_children():
		child.queue_free()
	_node_labels.clear()

	var positions: Dictionary = BalanceSession.SECTOR_MAP_NODE_POSITIONS
	# Draw undirected edges once.
	var drawn_edges: Dictionary = {}
	for id: StringName in ContentLibrary.ids_in(&"star_systems"):
		if not positions.has(id):
			continue
		var from_pos: Vector2 = _chart_pos(positions, id)
		for dest: StringName in SectorGraph.neighbors(id):
			if not positions.has(dest):
				continue
			var a: String = String(id)
			var b: String = String(dest)
			var key: String = a + "|" + b if a < b else b + "|" + a
			if drawn_edges.has(key):
				continue
			drawn_edges[key] = true
			var to_pos: Vector2 = _chart_pos(positions, dest)
			var line: Line2D = Line2D.new()
			line.width = BalanceSession.SECTOR_MAP_EDGE_WIDTH
			line.default_color = BalanceSession.SECTOR_MAP_EDGE_COLOR
			line.add_point(from_pos)
			line.add_point(to_pos)
			_chart.add_child(line)

	for id: StringName in ContentLibrary.ids_in(&"star_systems"):
		var system: StarSystem = ContentLibrary.item(id) as StarSystem
		if system == null:
			continue
		var pos: Vector2 = _chart_pos(positions, id)
		var is_here: bool = id == _current_system_id
		var marker: ColorRect = ColorRect.new()
		var size: float = (
			BalanceSession.SECTOR_MAP_NODE_SIZE_CURRENT
			if is_here
			else BalanceSession.SECTOR_MAP_NODE_SIZE
		)
		marker.size = Vector2(size, size)
		var half: float = size * BalanceSession.SECTOR_MAP_NODE_HALF
		marker.position = pos - Vector2(half, half)
		marker.color = (
			BalanceSession.SECTOR_MAP_NODE_COLOR_CURRENT
			if is_here
			else BalanceSession.SECTOR_MAP_NODE_COLOR
		)
		_chart.add_child(marker)

		var label: Label = Label.new()
		label.text = system.display_name
		label.position = (
			pos
			+ Vector2(
				BalanceSession.SECTOR_MAP_LABEL_OFFSET_X, BalanceSession.SECTOR_MAP_LABEL_OFFSET_Y
			)
		)
		if is_here:
			label.add_theme_color_override("font_color", BalanceUi.ACCENT)
		else:
			label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
		_chart.add_child(label)
		_node_labels[id] = label

	_update_current_line()


func _chart_pos(positions: Dictionary, system_id: StringName) -> Vector2:
	if not positions.has(system_id):
		return BalanceSession.SECTOR_MAP_FALLBACK_POS
	var raw: Variant = positions[system_id]
	if typeof(raw) == TYPE_VECTOR2:
		var pos: Vector2 = raw
		return pos
	return BalanceSession.SECTOR_MAP_FALLBACK_POS


func _update_current_line() -> void:
	if _current_label == null:
		return
	if _current_system_id == &"" or not ContentLibrary.has_item(_current_system_id):
		_current_label.text = BalanceSession.SECTOR_MAP_CURRENT_UNKNOWN
		return
	var system: StarSystem = ContentLibrary.item(_current_system_id) as StarSystem
	var place: String = system.display_name if system != null else String(_current_system_id)
	_current_label.text = BalanceSession.SECTOR_MAP_CURRENT_FORMAT % place
