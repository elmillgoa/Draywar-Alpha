class_name StationCampaignUi
extends RefCounted

## Story section helpers for StationMenu — Steam S7.
##
## Lists available spine beats at the docked station. Buttons emit
## EventBus.on_spine_accept_requested only (never call CampaignService).


## Connect campaign bus signals to a zero-arg refresh callable.
static func connect_refresh(refresh: Callable) -> void:
	EventBus.on_campaign_flag_set.connect(refresh.unbind(BalanceCampaign.BUS_ARGS_FLAG_SET))
	EventBus.on_spine_completed.connect(refresh.unbind(BalanceCampaign.BUS_ARGS_SPINE_COMPLETED))
	EventBus.on_campaign_act_changed.connect(refresh.unbind(BalanceCampaign.BUS_ARGS_ACT_CHANGED))
	EventBus.on_mission_accepted.connect(refresh.unbind(BalanceCampaign.BUS_ARGS_MISSION_ACCEPTED))
	EventBus.on_mission_completed.connect(refresh.unbind(BalanceCampaign.BUS_ARGS_MISSION_CLOSED))
	EventBus.on_mission_failed.connect(refresh.unbind(BalanceCampaign.BUS_ARGS_MISSION_CLOSED))
	EventBus.on_mission_abandoned.connect(refresh.unbind(BalanceCampaign.BUS_ARGS_MISSION_CLOSED))


## Disconnect refresh callables from connect_refresh.
static func disconnect_refresh(refresh: Callable) -> void:
	_safe_disconnect(
		EventBus.on_campaign_flag_set, refresh.unbind(BalanceCampaign.BUS_ARGS_FLAG_SET)
	)
	_safe_disconnect(
		EventBus.on_spine_completed, refresh.unbind(BalanceCampaign.BUS_ARGS_SPINE_COMPLETED)
	)
	_safe_disconnect(
		EventBus.on_campaign_act_changed, refresh.unbind(BalanceCampaign.BUS_ARGS_ACT_CHANGED)
	)
	_safe_disconnect(
		EventBus.on_mission_accepted, refresh.unbind(BalanceCampaign.BUS_ARGS_MISSION_ACCEPTED)
	)
	_safe_disconnect(
		EventBus.on_mission_completed, refresh.unbind(BalanceCampaign.BUS_ARGS_MISSION_CLOSED)
	)
	_safe_disconnect(
		EventBus.on_mission_failed, refresh.unbind(BalanceCampaign.BUS_ARGS_MISSION_CLOSED)
	)
	_safe_disconnect(
		EventBus.on_mission_abandoned, refresh.unbind(BalanceCampaign.BUS_ARGS_MISSION_CLOSED)
	)


static func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


## Section header + empty box under `layout`. Returns the story VBox.
static func make_box(layout: VBoxContainer) -> VBoxContainer:
	var header: Label = Label.new()
	header.text = BalanceCampaign.STATION_SECTION_STORY
	header.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	layout.add_child(header)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(box)
	return box


## Resolve campaign from the scene tree and refresh (StationMenu helper).
static func refresh_for_tree(
	box: VBoxContainer, tree: SceneTree, station_id: StringName, menu_visible: bool
) -> void:
	var campaign: Node = null
	if tree != null:
		campaign = tree.get_first_node_in_group(BalanceCampaign.GROUP_CAMPAIGN_SERVICE)
	refresh_box(box, campaign, station_id, menu_visible)


## Clear and rebuild story rows for the docked station.
static func refresh_box(
	box: VBoxContainer, campaign: Node, station_id: StringName, menu_visible: bool
) -> void:
	if box == null:
		return
	_clear_children(box)
	if not menu_visible or campaign == null or String(station_id).is_empty():
		return

	var available: Array[StringName] = []
	if campaign.has_method(&"available_spine_ids_at"):
		var raw: Variant = campaign.call(&"available_spine_ids_at", station_id)
		if typeof(raw) == TYPE_ARRAY:
			var rows: Array = raw
			for entry: Variant in rows:
				available.append(_as_name(entry))

	if available.is_empty():
		var hint: String = ""
		if campaign.has_method(&"locked_hint_at"):
			hint = str(campaign.call(&"locked_hint_at", station_id))
		if hint.is_empty():
			hint = BalanceCampaign.STATION_STORY_NONE
		_add_label(box, hint, true)
		return

	for template_id: StringName in available:
		var label: String = BalanceCampaign.STATION_STORY_ACCEPT_FORMAT % _content_name(template_id)
		var can: bool = false
		if campaign.has_method(&"can_accept_spine"):
			can = campaign.call(&"can_accept_spine", template_id) == true
		var btn: Button = Button.new()
		btn.text = label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not can
		var captured: StringName = template_id
		btn.pressed.connect(func() -> void: EventBus.on_spine_accept_requested.emit(captured))
		box.add_child(btn)


static func _content_name(id: StringName) -> String:
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


static func _add_label(box: VBoxContainer, text: String, muted: bool) -> void:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if muted:
		label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	else:
		label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
	label.text = text
	box.add_child(label)


static func _clear_children(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


static func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return StringName(str(value))
