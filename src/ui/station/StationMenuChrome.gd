class_name StationMenuChrome
extends RefCounted

## Shared station menu chrome helpers — keeps StationMenu under line caps.


static func add_section_header(parent: Control, text: String) -> Label:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BalanceEconomy.STATION_SECTION_SPACER)
	parent.add_child(spacer)
	var header: Label = Label.new()
	header.add_theme_color_override("font_color", BalanceUi.ACCENT)
	header.text = text
	parent.add_child(header)
	return header


static func make_button(parent: Control, size: Vector2, text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = size
	parent.add_child(btn)
	return btn


static func content_name(id: StringName) -> String:
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)
