class_name StationHullUi
extends RefCounted

## Pure hull Services helpers for StationMenu (E2.5).
##
## Keeps StationMenu under the file-length lint cap.


## Hull id to switch to from the current active hull (other of the two).
static func switch_target_hull_id(ships: Node) -> StringName:
	if ships == null or not ships.has_method(&"active_hull_id"):
		return &""
	var active: StringName = _as_name(ships.call(&"active_hull_id"))
	if active == BalanceFlight.FIGHTER_HULL_ID:
		return BalanceFlight.PLAYER_HULL_ID
	if active == BalanceFlight.PLAYER_HULL_ID:
		return BalanceFlight.FIGHTER_HULL_ID
	if ships.has_method(&"owns") and ships.call(&"owns", BalanceFlight.FIGHTER_HULL_ID) == true:
		return BalanceFlight.FIGHTER_HULL_ID
	return BalanceFlight.PLAYER_HULL_ID


## True when the session owns the Fighter hull.
static func owns_fighter(ships: Node) -> bool:
	if ships == null or not ships.has_method(&"owns"):
		return false
	return ships.call(&"owns", BalanceFlight.FIGHTER_HULL_ID) == true


## True when ShipService says buy is allowed (docked + can afford + not owned).
static func can_buy_fighter(ships: Node) -> bool:
	if ships == null or not ships.has_method(&"can_buy_fighter"):
		return false
	return ships.call(&"can_buy_fighter") == true


## True when switch to target is allowed (owned + cargo fits).
static func can_switch_to(ships: Node, hull_id: StringName) -> bool:
	if ships == null or not ships.has_method(&"can_switch_to"):
		return false
	return ships.call(&"can_switch_to", hull_id) == true


## Update Buy Fighter / Switch hull button visibility, labels, disabled state.
static func refresh_buttons(
	buy_btn: Button, switch_btn: Button, ships: Node, menu_visible: bool
) -> void:
	if buy_btn == null or switch_btn == null:
		return
	if not menu_visible or ships == null:
		buy_btn.visible = false
		switch_btn.visible = false
		return

	var fighter_owned: bool = owns_fighter(ships)
	if fighter_owned:
		buy_btn.visible = false
	else:
		buy_btn.visible = true
		buy_btn.text = (
			BalanceEconomy.STATION_BUY_FIGHTER_FORMAT % BalanceEconomy.FIGHTER_PURCHASE_COST
		)
		buy_btn.disabled = not can_buy_fighter(ships)

	var target: StringName = switch_target_hull_id(ships)
	switch_btn.visible = fighter_owned and not String(target).is_empty()
	if switch_btn.visible:
		switch_btn.text = BalanceEconomy.STATION_SWITCH_HULL_FORMAT % _content_name(target)
		switch_btn.disabled = not can_switch_to(ships, target)


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
