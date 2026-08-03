class_name StationBoardUi
extends RefCounted

## Jobs / contacts board helpers for StationMenu (file-length lint).


static func accept_job_label(template_id: StringName) -> String:
	if String(template_id).is_empty():
		return BalanceStanding.STATION_ACCEPT_JOB_LABEL
	# ContentLibrary hand template (console / legacy id).
	if ContentLibrary.has_item(template_id):
		return _label_from_content(template_id)
	# Board runtime offer (hand board row or radiant).
	var offer: Dictionary = BoardService.get_offer(template_id)
	if not offer.is_empty():
		return _label_from_offer(offer)
	return BalanceStanding.STATION_ACCEPT_JOB_LABEL


static func clear_box(box: VBoxContainer) -> void:
	if box == null:
		return
	var doomed: Array[Node] = []
	for child: Node in box.get_children():
		doomed.append(child)
	for child: Node in doomed:
		box.remove_child(child)
		child.queue_free()


static func refresh_contacts(
	contacts_list: VBoxContainer, controller: StringName, menu_visible: bool
) -> void:
	clear_box(contacts_list)
	if contacts_list == null or not menu_visible:
		return
	if String(controller).is_empty():
		return
	for person_id: StringName in ContentLibrary.ids_in(&"people"):
		var item: ContentItem = ContentLibrary.item(person_id)
		if item == null or not (item is Person):
			continue
		var person: Person = item as Person
		if person.primary_entity_id != controller:
			continue
		var line: Label = Label.new()
		line.text = (
			BalanceEconomy.STATION_CONTACT_LINE_FORMAT % [person.display_name, String(person.rank)]
		)
		line.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contacts_list.add_child(line)


static func _label_from_content(template_id: StringName) -> String:
	var item: ContentItem = ContentLibrary.item(template_id)
	if item == null:
		return BalanceStanding.STATION_ACCEPT_JOB_LABEL
	var kind: StringName = _as_name(item.get("kind"))
	return _label_for_kind(
		kind, _as_name(item.get("destination_station_id")), _as_name(item.get("target_system_id"))
	)


static func _label_from_offer(offer: Dictionary) -> String:
	var kind: StringName = StringName(str(offer.get(BalanceBoard.OFFER_KEY_KIND, &"")))
	var dest: StringName = StringName(str(offer.get(BalanceBoard.OFFER_KEY_DESTINATION, &"")))
	var target: StringName = StringName(str(offer.get(BalanceBoard.OFFER_KEY_TARGET_SYSTEM, &"")))
	return _label_for_kind(kind, dest, target)


static func _label_for_kind(kind: StringName, dest_id: StringName, target_id: StringName) -> String:
	if kind == BalanceStanding.MISSION_KIND_BOUNTY:
		if String(target_id).is_empty():
			return BalanceStanding.STATION_ACCEPT_BOUNTY_LABEL
		return BalanceStanding.STATION_ACCEPT_BOUNTY_FORMAT % _content_name(target_id)
	if kind == BalanceStanding.MISSION_KIND_SMUGGLE:
		if String(dest_id).is_empty():
			return BalanceStanding.STATION_ACCEPT_SMUGGLE_LABEL
		return BalanceStanding.STATION_ACCEPT_SMUGGLE_FORMAT % _content_name(dest_id)
	if kind == BalanceStanding.MISSION_KIND_ESCORT:
		if String(dest_id).is_empty():
			return BalanceStanding.STATION_ACCEPT_ESCORT_LABEL
		return BalanceStanding.STATION_ACCEPT_ESCORT_FORMAT % _content_name(dest_id)
	if String(dest_id).is_empty():
		return BalanceStanding.STATION_ACCEPT_JOB_LABEL
	return BalanceStanding.STATION_ACCEPT_JOB_TO_FORMAT % _content_name(dest_id)


static func _content_name(id: StringName) -> String:
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


static func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""
