class_name StationOutfitUi
extends RefCounted

## Pure outfitting helpers for StationMenu — Steam S5.
##
## Builds install/remove rows into a VBox. Keeps StationMenu under line caps.
## Buttons emit EventBus outfit requests (never call ShipService directly).


## Section header + empty box parented under `layout`. Returns the outfit VBox.
static func make_box(layout: VBoxContainer) -> VBoxContainer:
	var header: Label = Label.new()
	header.text = BalanceOutfit.STATION_SECTION_OUTFITTING
	header.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	layout.add_child(header)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(box)
	return box


## Clear and rebuild outfitting rows for the active hull.
static func refresh_box(box: VBoxContainer, ships: Node, _wallet: Node, menu_visible: bool) -> void:
	if box == null:
		return
	_clear_children(box)
	if not menu_visible or ships == null:
		return

	var hull_id: StringName = _active_hull_id(ships)
	if String(hull_id).is_empty():
		return

	_add_label(box, BalanceOutfit.STATION_OUTFIT_INSTALLED_HEADER, true)
	_add_installed_weapons(box, ships, hull_id)
	_add_installed_equipment(box, ships, hull_id)

	_add_label(box, BalanceOutfit.STATION_OUTFIT_WEAPONS_HEADER, true)
	_add_catalog_weapons(box, ships, hull_id)

	_add_label(box, BalanceOutfit.STATION_OUTFIT_EQUIPMENT_HEADER, true)
	_add_catalog_equipment(box, ships, hull_id)


static func _add_installed_weapons(box: VBoxContainer, ships: Node, hull_id: StringName) -> void:
	if not ships.has_method(&"installed_weapons"):
		return
	var weapons: Array[StringName] = _as_name_array(ships.call(&"installed_weapons", hull_id))
	var i: int = 0
	while i < weapons.size():
		var item_id: StringName = weapons[i]
		if item_id == BalanceOutfit.EMPTY_SLOT or String(item_id).is_empty():
			_add_label(box, "W%d: %s" % [i + 1, BalanceOutfit.STATION_OUTFIT_EMPTY_SLOT], false)
		else:
			var refund: int = _weapon_refund(item_id)
			var btn: Button = Button.new()
			btn.text = (
				BalanceOutfit.STATION_OUTFIT_REMOVE_FORMAT % [_content_name(item_id), refund]
			)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var captured_id: StringName = item_id
			var captured_slot: int = i
			btn.pressed.connect(
				func() -> void:
					EventBus.on_outfit_uninstall_requested.emit(captured_id, captured_slot)
			)
			box.add_child(btn)
		i += 1


static func _add_installed_equipment(box: VBoxContainer, ships: Node, hull_id: StringName) -> void:
	if not ships.has_method(&"installed_equipment"):
		return
	var equipment: Array[StringName] = _as_name_array(ships.call(&"installed_equipment", hull_id))
	var i: int = 0
	while i < equipment.size():
		var item_id: StringName = equipment[i]
		if item_id == BalanceOutfit.EMPTY_SLOT or String(item_id).is_empty():
			_add_label(box, "E%d: %s" % [i + 1, BalanceOutfit.STATION_OUTFIT_EMPTY_SLOT], false)
		else:
			var refund: int = _equipment_refund(item_id)
			var btn: Button = Button.new()
			btn.text = (
				BalanceOutfit.STATION_OUTFIT_REMOVE_FORMAT % [_content_name(item_id), refund]
			)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var captured_id: StringName = item_id
			var captured_slot: int = i
			btn.pressed.connect(
				func() -> void:
					EventBus.on_outfit_uninstall_requested.emit(captured_id, captured_slot)
			)
			box.add_child(btn)
		i += 1


static func _add_catalog_weapons(box: VBoxContainer, ships: Node, hull_id: StringName) -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(&"weapons")
	for item_id: StringName in ids:
		if not ContentLibrary.has_item(item_id):
			continue
		var item: ContentItem = ContentLibrary.item(item_id)
		if not (item is Weapon):
			continue
		var weapon: Weapon = item as Weapon
		if not _role_ok_for_hull(hull_id, weapon.hauler_ok, weapon.fighter_ok):
			continue
		var btn: Button = Button.new()
		btn.text = (
			BalanceOutfit.STATION_OUTFIT_INSTALL_FORMAT % [weapon.display_name, weapon.buy_price]
		)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not _can_install(ships, item_id)
		var captured: StringName = item_id
		btn.pressed.connect(func() -> void: EventBus.on_outfit_install_requested.emit(captured))
		box.add_child(btn)


static func _add_catalog_equipment(box: VBoxContainer, ships: Node, hull_id: StringName) -> void:
	var ids: Array[StringName] = ContentLibrary.ids_in(&"equipment")
	for item_id: StringName in ids:
		if not ContentLibrary.has_item(item_id):
			continue
		var item: ContentItem = ContentLibrary.item(item_id)
		if not (item is Equipment):
			continue
		var equip: Equipment = item as Equipment
		if not _role_ok_for_hull(hull_id, equip.hauler_ok, equip.fighter_ok):
			continue
		var btn: Button = Button.new()
		btn.text = (
			BalanceOutfit.STATION_OUTFIT_INSTALL_FORMAT % [equip.display_name, equip.buy_price]
		)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not _can_install(ships, item_id)
		var captured: StringName = item_id
		btn.pressed.connect(func() -> void: EventBus.on_outfit_install_requested.emit(captured))
		box.add_child(btn)


static func _can_install(ships: Node, item_id: StringName) -> bool:
	if ships == null or not ships.has_method(&"can_install"):
		return false
	return ships.call(&"can_install", item_id) == true


static func _role_ok_for_hull(hull_id: StringName, hauler_ok: bool, fighter_ok: bool) -> bool:
	if not ContentLibrary.has_item(hull_id):
		return false
	var item: ContentItem = ContentLibrary.item(hull_id)
	if not (item is Hull):
		return false
	var role: StringName = (item as Hull).role
	if role == Hull.ROLE_FIGHTER:
		return fighter_ok
	if role == Hull.ROLE_HAULER:
		return hauler_ok
	return false


static func _weapon_refund(item_id: StringName) -> int:
	if not ContentLibrary.has_item(item_id):
		return 0
	var item: ContentItem = ContentLibrary.item(item_id)
	if item is Weapon:
		return BalanceOutfit.sell_refund((item as Weapon).buy_price)
	return 0


static func _equipment_refund(item_id: StringName) -> int:
	if not ContentLibrary.has_item(item_id):
		return 0
	var item: ContentItem = ContentLibrary.item(item_id)
	if item is Equipment:
		return BalanceOutfit.sell_refund((item as Equipment).buy_price)
	return 0


static func _active_hull_id(ships: Node) -> StringName:
	if ships == null or not ships.has_method(&"active_hull_id"):
		return &""
	return _as_name(ships.call(&"active_hull_id"))


static func _content_name(id: StringName) -> String:
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


static func _add_label(box: VBoxContainer, text: String, emphasize: bool) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if emphasize:
		label.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	else:
		label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	box.add_child(label)


static func _clear_children(box: VBoxContainer) -> void:
	var children: Array[Node] = box.get_children()
	for child: Node in children:
		box.remove_child(child)
		child.queue_free()


static func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return &""


static func _as_name_array(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	var arr: Array = value
	for entry: Variant in arr:
		out.append(_as_name(entry))
	return out
