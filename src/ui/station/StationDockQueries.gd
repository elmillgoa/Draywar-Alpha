class_name StationDockQueries
extends RefCounted

## Pure station-board lookups shared by StationMenu (jobs, contacts, recovery).
##
## Keeps StationMenu under the file-length lint cap without changing behavior.


## Variant → StringName for values arriving from `Object.get` / `Object.call`,
## where the engine hands back an untyped Variant and strict typing needs a name.
static func as_name(value: Variant) -> StringName:
	var result: StringName = &""
	if typeof(value) == TYPE_STRING_NAME:
		var name_value: StringName = value
		result = name_value
	elif typeof(value) == TYPE_STRING:
		var text_value: String = value
		result = StringName(text_value)
	return result


## Variant → int for the same reason (a service may answer int or float).
static func as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var int_value: int = value
		return int_value
	if typeof(value) == TYPE_FLOAT:
		var float_value: float = value
		return int(float_value)
	return 0


static func station_resource(station_id: StringName) -> Station:
	if String(station_id).is_empty() or not ContentLibrary.has_item(station_id):
		return null
	var station_item: ContentItem = ContentLibrary.item(station_id)
	if station_item is Station:
		return station_item as Station
	return null


## Sticky-deep with the dock controller (hostile hole — recovery foothold path).
static func is_deep_negative_with_controller(station_id: StringName) -> bool:
	var controller_id: StringName = controller(station_id)
	if String(controller_id).is_empty():
		return false
	return (
		StandingService.get_entity_standing(controller_id) <= BalanceStanding.STICKY_NEGATIVE_FLOOR
	)


static func controller(station_id: StringName) -> StringName:
	var station: Station = station_resource(station_id)
	if station == null:
		return &""
	var controller_id: StringName = station.controller_entity_id
	if controller_id == Station.CONTROLLER_NOBODY or String(controller_id).is_empty():
		return &""
	return controller_id


static func system_id(station_id: StringName) -> StringName:
	var station: Station = station_resource(station_id)
	if station == null:
		return &""
	return station.system_id


## Controller standing display tier (Neutral when no controller).
static func controller_tier(station_id: StringName) -> StringName:
	var controller_id: StringName = controller(station_id)
	if String(controller_id).is_empty():
		return BalanceStanding.TIER_NEUTRAL
	var standing: float = StandingService.get_entity_standing(controller_id)
	return StandingService.tier_for(standing)


## Board offer instance ids for this dock (hand templates + radiant fills).
## Returns BoardService offer ids, not a raw ContentLibrary dump (S3a).
static func offered_templates(station_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if String(station_id).is_empty():
		return out
	return BoardService.offer_ids_for_station(station_id)


static func favor_person(station_id: StringName) -> StringName:
	## Recovery contact of this station's controller when not closed.
	var controller_id: StringName = controller(station_id)
	if String(controller_id).is_empty():
		return &""
	for chain_id: StringName in ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY):
		var item: ContentItem = ContentLibrary.item(chain_id)
		if item == null:
			continue
		var entity_raw: Variant = item.get("entity_id")
		var person_raw: Variant = item.get("person_id")
		if entity_raw == null or person_raw == null:
			continue
		var entity_id: StringName = StringName(str(entity_raw))
		var person_id: StringName = StringName(str(person_raw))
		if entity_id != controller_id:
			continue
		if StandingService.is_person_closed(person_id):
			continue
		return person_id
	return &""


static func offered_recovery_person(station_id: StringName, service: Node) -> StringName:
	var found: StringName = &""
	var controller_id: StringName = controller(station_id)
	if String(controller_id).is_empty() or service == null:
		return found
	if not service.has_method(&"has_offer_for_person"):
		return found
	for chain_id: StringName in ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY):
		var item: ContentItem = ContentLibrary.item(chain_id)
		if item == null:
			continue
		var entity_raw: Variant = item.get("entity_id")
		var person_raw: Variant = item.get("person_id")
		if entity_raw == null or person_raw == null:
			continue
		var entity_id: StringName = StringName(str(entity_raw))
		var person_id: StringName = StringName(str(person_raw))
		if entity_id != controller_id:
			continue
		var offerable: Variant = service.call(&"has_offer_for_person", person_id)
		if offerable == true:
			found = person_id
			break
	return found


## Person on the active recovery chain (empty when none).
static func active_recovery_person(service: Node) -> StringName:
	if service == null or not service.has_method(&"active_chain_id"):
		return &""
	var chain_id: StringName = as_name(service.call(&"active_chain_id"))
	if String(chain_id).is_empty() or not ContentLibrary.has_item(chain_id):
		return &""
	var item: ContentItem = ContentLibrary.item(chain_id)
	return as_name(item.get("person_id"))
