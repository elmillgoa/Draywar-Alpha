class_name RadiantJobGenerator
extends RefCounted

## Pure radiant offer builder for BoardService — Steam S3a.
##
## Deterministic: same (station, step, slot) + market/policing world state →
## same offer fields and instance_id. No RNG. Does not mutate market or board.


## Build one radiant offer for a board slot. Empty dict only when the station
## has no controller (caller should fall back to hand templates).
static func build_offer(
	station_id: StringName, step: int, slot: int, claimed: Dictionary
) -> Dictionary:
	var station: Station = _station(station_id)
	if station == null:
		return {}
	var offering: StringName = station.controller_entity_id
	if offering == Station.CONTROLLER_NOBODY or String(offering).is_empty():
		return {}

	var origin_system: StringName = station.system_id
	var kind: StringName = _pick_kind(station_id, origin_system, step, slot)
	var offer: Dictionary = {}
	match kind:
		BalanceStanding.MISSION_KIND_BOUNTY:
			offer = _build_bounty(station_id, offering, origin_system, step, slot)
		BalanceStanding.MISSION_KIND_ESCORT:
			offer = _build_escort(station_id, offering, origin_system, step, slot)
		BalanceStanding.MISSION_KIND_SMUGGLE:
			offer = _build_smuggle(station_id, offering, origin_system, step, slot)
		_:
			offer = _build_delivery(station_id, offering, origin_system, step, slot)

	if offer.is_empty():
		offer = _build_safe_delivery(station_id, offering, origin_system, step, slot)
	if offer.is_empty():
		return {}

	var instance_id: StringName = _instance_id(station_id, step, slot, kind)
	# Avoid colliding with a claimed id mid-cycle (re-roll salt via slot mix).
	if claimed.has(String(instance_id)):
		instance_id = StringName("%s_x" % String(instance_id))
	offer[BalanceBoard.OFFER_KEY_ID] = instance_id
	offer[BalanceBoard.OFFER_KEY_BOARD_STATION] = station_id
	offer[BalanceBoard.OFFER_KEY_SOURCE] = BalanceBoard.OFFER_SOURCE_RADIANT
	if not offer.has(BalanceBoard.OFFER_KEY_STANDING_COMPLETE):
		offer[BalanceBoard.OFFER_KEY_STANDING_COMPLETE] = BalanceStanding.MISSION_COMPLETE_DELTA
	if not offer.has(BalanceBoard.OFFER_KEY_STANDING_FAIL):
		offer[BalanceBoard.OFFER_KEY_STANDING_FAIL] = BalanceStanding.MISSION_FAIL_DELTA
	if not offer.has(BalanceBoard.OFFER_KEY_STANDING_ABANDON):
		offer[BalanceBoard.OFFER_KEY_STANDING_ABANDON] = BalanceStanding.MISSION_ABANDON_DELTA
	return offer


## Convert a hand ContractType into a board offer dict for this restock cycle.
static func offer_from_template(
	template: ContractType, station_id: StringName, step: int, slot: int
) -> Dictionary:
	if template == null:
		return {}
	var tid: StringName = template.id
	var instance_id: StringName = StringName(
		"board_%s_%d_h%d_%s" % [String(station_id), step, slot, String(tid)]
	)
	return {
		BalanceBoard.OFFER_KEY_ID: instance_id,
		BalanceBoard.OFFER_KEY_BOARD_STATION: station_id,
		BalanceBoard.OFFER_KEY_KIND: template.kind,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: template.offering_entity_id,
		BalanceBoard.OFFER_KEY_PAY: template.pay_credits,
		BalanceBoard.OFFER_KEY_STANDING_COMPLETE: template.standing_complete,
		BalanceBoard.OFFER_KEY_STANDING_FAIL: template.standing_fail,
		BalanceBoard.OFFER_KEY_STANDING_ABANDON: template.standing_abandon,
		BalanceBoard.OFFER_KEY_DESTINATION: template.destination_station_id,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: template.target_system_id,
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: template.cargo_commodity_id,
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: template.cargo_quantity,
		BalanceBoard.OFFER_KEY_LABEL: _hand_label(template),
		BalanceBoard.OFFER_KEY_SOURCE: BalanceBoard.OFFER_SOURCE_HAND,
		&"template_id": tid,
	}


static func _hand_label(template: ContractType) -> String:
	if template == null:
		return BalanceBoard.LABEL_FALLBACK
	if not template.display_name.is_empty():
		return template.display_name
	return String(template.id)


static func _instance_id(
	station_id: StringName, step: int, slot: int, kind: StringName
) -> StringName:
	return StringName("rad_%s_%d_s%d_%s" % [String(station_id), step, slot, String(kind)])


static func _pick_kind(
	station_id: StringName, origin_system: StringName, step: int, slot: int
) -> StringName:
	var policing: StringName = _policing(origin_system)
	var w_delivery: int = BalanceBoard.WEIGHT_DELIVERY_BASE
	var w_bounty: int = BalanceBoard.WEIGHT_BOUNTY_BASE
	var w_escort: int = BalanceBoard.WEIGHT_ESCORT_BASE
	var w_smuggle: int = BalanceBoard.WEIGHT_SMUGGLE_BASE

	if _has_any_shortage_route(station_id):
		w_delivery += BalanceBoard.WEIGHT_DELIVERY_SHORTAGE_BONUS

	if policing == StarSystem.POLICED_BY_CONTESTED:
		w_bounty += BalanceBoard.WEIGHT_BOUNTY_CONTESTED_BONUS
	elif policing == StarSystem.POLICED_BY_NOBODY:
		w_bounty += BalanceBoard.WEIGHT_BOUNTY_LAWLESS_BONUS
	elif policing == StarSystem.POLICED_BY_PATROLS:
		w_bounty = maxi(
			1,
			(
				(w_bounty * BalanceBoard.WEIGHT_BOUNTY_PATROLLED_NUM)
				/ BalanceBoard.WEIGHT_BOUNTY_PATROLLED_DEN
			)
		)

	if _has_risk_leg(station_id, origin_system):
		w_escort += BalanceBoard.WEIGHT_ESCORT_RISK_BONUS

	if _has_smuggle_candidate(station_id, origin_system):
		w_smuggle += BalanceBoard.WEIGHT_SMUGGLE_CONTRABAND_BONUS

	var total: int = w_delivery + w_bounty + w_escort + w_smuggle
	if total <= 0:
		return BalanceStanding.MISSION_KIND_DELIVERY
	var roll: int = (
		BalanceBoard.mix4(String(station_id).hash(), step, slot, String(origin_system).hash())
		% total
	)
	if roll < w_delivery:
		return BalanceStanding.MISSION_KIND_DELIVERY
	roll -= w_delivery
	if roll < w_bounty:
		return BalanceStanding.MISSION_KIND_BOUNTY
	roll -= w_bounty
	if roll < w_escort:
		return BalanceStanding.MISSION_KIND_ESCORT
	return BalanceStanding.MISSION_KIND_SMUGGLE


static func _build_delivery(
	station_id: StringName, offering: StringName, origin_system: StringName, step: int, slot: int
) -> Dictionary:
	var route: Dictionary = _pick_shortage_route(station_id, step, slot)
	if route.is_empty():
		return _build_safe_delivery(station_id, offering, origin_system, step, slot)
	var dest: StringName = StringName(str(route.get(&"dest", &"")))
	var hops: int = _dict_int(route, &"hops", 0)
	var severity: int = _dict_int(route, &"severity", 1)
	var pay: int = _pay_haul(hops, severity)
	var dest_name: String = _display_name(dest)
	return {
		BalanceBoard.OFFER_KEY_KIND: BalanceStanding.MISSION_KIND_DELIVERY,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: offering,
		BalanceBoard.OFFER_KEY_PAY: pay,
		BalanceBoard.OFFER_KEY_DESTINATION: dest,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: &"",
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: &"",
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: 0,
		BalanceBoard.OFFER_KEY_LABEL: BalanceBoard.LABEL_DELIVERY_FORMAT % dest_name,
	}


static func _build_safe_delivery(
	station_id: StringName, offering: StringName, _origin_system: StringName, step: int, slot: int
) -> Dictionary:
	var dest: StringName = _pick_other_station(station_id, step, slot)
	if String(dest).is_empty():
		return {}
	var hops: int = SectorGraph.hop_distance_stations(station_id, dest)
	if hops < 0:
		hops = 0
	var pay: int = _pay_haul(hops, 0)
	return {
		BalanceBoard.OFFER_KEY_KIND: BalanceStanding.MISSION_KIND_DELIVERY,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: offering,
		BalanceBoard.OFFER_KEY_PAY: pay,
		BalanceBoard.OFFER_KEY_DESTINATION: dest,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: &"",
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: &"",
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: 0,
		BalanceBoard.OFFER_KEY_LABEL: BalanceBoard.LABEL_DELIVERY_FORMAT % _display_name(dest),
	}


static func _build_bounty(
	station_id: StringName, offering: StringName, origin_system: StringName, step: int, slot: int
) -> Dictionary:
	var target_system: StringName = _pick_bounty_system(origin_system, step, slot)
	if String(target_system).is_empty():
		return {}
	var pay: int = maxi(
		BalanceBoard.PAY_FLOOR, BalanceBoard.PAY_BASE + BalanceBoard.PAY_BOUNTY_PREMIUM
	)
	return {
		BalanceBoard.OFFER_KEY_KIND: BalanceStanding.MISSION_KIND_BOUNTY,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: offering,
		BalanceBoard.OFFER_KEY_PAY: pay,
		BalanceBoard.OFFER_KEY_DESTINATION: station_id,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: target_system,
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: &"",
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: 0,
		BalanceBoard.OFFER_KEY_LABEL:
		BalanceBoard.LABEL_BOUNTY_FORMAT % _display_name(target_system),
	}


static func _build_escort(
	station_id: StringName, offering: StringName, origin_system: StringName, step: int, slot: int
) -> Dictionary:
	var dest: StringName = _pick_risk_destination(station_id, origin_system, step, slot)
	if String(dest).is_empty():
		dest = _pick_other_station(station_id, step, slot + BalanceBoard.SALT_ESCORT_FALLBACK)
	if String(dest).is_empty():
		return {}
	var dest_system: StringName = SectorGraph.system_of_station(dest)
	var hops: int = SectorGraph.hop_distance_stations(station_id, dest)
	if hops < 0:
		hops = 1
	var pay: int = maxi(
		BalanceBoard.PAY_FLOOR,
		BalanceBoard.PAY_BASE + hops * BalanceBoard.PAY_PER_HOP + BalanceBoard.PAY_ESCORT_PREMIUM
	)
	return {
		BalanceBoard.OFFER_KEY_KIND: BalanceStanding.MISSION_KIND_ESCORT,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: offering,
		BalanceBoard.OFFER_KEY_PAY: pay,
		BalanceBoard.OFFER_KEY_DESTINATION: dest,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: dest_system,
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: &"",
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: 0,
		BalanceBoard.OFFER_KEY_LABEL: BalanceBoard.LABEL_ESCORT_FORMAT % _display_name(dest),
	}


static func _build_smuggle(
	station_id: StringName, offering: StringName, origin_system: StringName, step: int, slot: int
) -> Dictionary:
	var route: Dictionary = _pick_smuggle_route(station_id, origin_system, step, slot)
	if route.is_empty():
		return {}
	var dest: StringName = StringName(str(route.get(&"dest", &"")))
	var commodity: StringName = StringName(str(route.get(&"commodity", &"")))
	var hops: int = _dict_int(route, &"hops", 1)
	var pay: int = maxi(
		BalanceBoard.PAY_FLOOR,
		BalanceBoard.PAY_BASE + hops * BalanceBoard.PAY_PER_HOP + BalanceBoard.PAY_SMUGGLE_PREMIUM
	)
	return {
		BalanceBoard.OFFER_KEY_KIND: BalanceStanding.MISSION_KIND_SMUGGLE,
		BalanceBoard.OFFER_KEY_OFFERING_ENTITY: offering,
		BalanceBoard.OFFER_KEY_PAY: pay,
		BalanceBoard.OFFER_KEY_DESTINATION: dest,
		BalanceBoard.OFFER_KEY_TARGET_SYSTEM: &"",
		BalanceBoard.OFFER_KEY_CARGO_COMMODITY: commodity,
		BalanceBoard.OFFER_KEY_CARGO_QUANTITY: BalanceBoard.SMUGGLE_CARGO_QUANTITY,
		BalanceBoard.OFFER_KEY_LABEL: BalanceBoard.LABEL_SMUGGLE_FORMAT % _display_name(dest),
	}


static func _pay_haul(hops: int, severity: int) -> int:
	var sev: int = clampi(severity, 0, BalanceBoard.PAY_SHORTAGE_SEVERITY_MAX)
	var pay: int = (
		BalanceBoard.PAY_BASE
		+ maxi(0, hops) * BalanceBoard.PAY_PER_HOP
		+ sev * BalanceBoard.PAY_SHORTAGE_BASE
	)
	return maxi(BalanceBoard.PAY_FLOOR, pay)


static func _has_any_shortage_route(origin_station: StringName) -> bool:
	return not _pick_shortage_route(origin_station, 0, 0).is_empty()


static func _pick_shortage_route(origin_station: StringName, step: int, slot: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for station_id: StringName in ContentLibrary.ids_in(&"stations"):
		if station_id == origin_station:
			continue
		for commodity_id: StringName in MarketService.traded_commodity_ids(station_id):
			var target: float = MarketService.target_stock(station_id, commodity_id)
			if target <= 0.0:
				continue
			var stock: float = MarketService.stock_exact(station_id, commodity_id)
			var ratio: float = stock / target
			if ratio > BalanceBoard.SHORTAGE_RATIO:
				continue
			if not _has_producer(commodity_id, origin_station):
				continue
			var hops: int = SectorGraph.hop_distance_stations(origin_station, station_id)
			if hops < 0:
				continue
			var severity: int = 1
			if ratio <= BalanceBoard.SHORTAGE_RATIO * BalanceBoard.SHORTAGE_SEVERITY_MID_FACTOR:
				severity = BalanceBoard.SHORTAGE_SEVERITY_MID
			if ratio <= BalanceBoard.SHORTAGE_RATIO * BalanceBoard.SHORTAGE_SEVERITY_DEEP_FACTOR:
				severity = BalanceBoard.SHORTAGE_SEVERITY_DEEP
			(
				candidates
				. append(
					{
						&"dest": station_id,
						&"commodity": commodity_id,
						&"hops": hops,
						&"severity": severity,
					}
				)
			)
	if candidates.is_empty():
		return {}
	var idx: int = BalanceBoard.pick_index(
		candidates.size(),
		String(origin_station).hash(),
		step,
		slot,
		BalanceBoard.SALT_SHORTAGE_ROUTE
	)
	return candidates[idx]


static func _has_producer(commodity_id: StringName, prefer_station: StringName) -> bool:
	if MarketService.trades(prefer_station, commodity_id):
		var st: Station = _station(prefer_station)
		if st != null and st.produces.has(commodity_id) and _rate(st.produces, commodity_id) > 0.0:
			return true
	for station_id: StringName in ContentLibrary.ids_in(&"stations"):
		var st: Station = _station(station_id)
		if st == null:
			continue
		if st.produces.has(commodity_id) and _rate(st.produces, commodity_id) > 0.0:
			return true
	return false


static func _has_risk_leg(origin_station: StringName, origin_system: StringName) -> bool:
	var origin_pol: StringName = _policing(origin_system)
	for station_id: StringName in ContentLibrary.ids_in(&"stations"):
		if station_id == origin_station:
			continue
		var dest_sys: StringName = SectorGraph.system_of_station(station_id)
		if String(dest_sys).is_empty():
			continue
		var dest_pol: StringName = _policing(dest_sys)
		if _is_risk_edge(origin_pol, dest_pol):
			return true
	return false


static func _is_risk_edge(a: StringName, b: StringName) -> bool:
	if a == b:
		return false
	# Patrolled ↔ contested/lawless, or contested ↔ lawless.
	var hard: bool = a == StarSystem.POLICED_BY_PATROLS or b == StarSystem.POLICED_BY_PATROLS
	var soft: bool = (
		a == StarSystem.POLICED_BY_NOBODY
		or b == StarSystem.POLICED_BY_NOBODY
		or a == StarSystem.POLICED_BY_CONTESTED
		or b == StarSystem.POLICED_BY_CONTESTED
	)
	return hard and soft or (a != b and soft)


static func _pick_risk_destination(
	origin_station: StringName, origin_system: StringName, step: int, slot: int
) -> StringName:
	var origin_pol: StringName = _policing(origin_system)
	var picks: Array[StringName] = []
	for station_id: StringName in ContentLibrary.ids_in(&"stations"):
		if station_id == origin_station:
			continue
		var dest_sys: StringName = SectorGraph.system_of_station(station_id)
		if String(dest_sys).is_empty():
			continue
		if _is_risk_edge(origin_pol, _policing(dest_sys)):
			picks.append(station_id)
	if picks.is_empty():
		return &""
	var idx: int = BalanceBoard.pick_index(
		picks.size(), String(origin_station).hash(), step, slot, BalanceBoard.SALT_RISK_DEST
	)
	return picks[idx]


static func _pick_bounty_system(origin_system: StringName, step: int, slot: int) -> StringName:
	var risky: Array[StringName] = []
	var all_systems: Array[StringName] = ContentLibrary.ids_in(&"star_systems")
	for system_id: StringName in all_systems:
		var pol: StringName = _policing(system_id)
		if pol == StarSystem.POLICED_BY_CONTESTED or pol == StarSystem.POLICED_BY_NOBODY:
			risky.append(system_id)
	if not risky.is_empty():
		var idx: int = BalanceBoard.pick_index(
			risky.size(), String(origin_system).hash(), step, slot, BalanceBoard.SALT_BOUNTY_SYSTEM
		)
		return risky[idx]
	if all_systems.is_empty():
		return &""
	# Fallback: any system including origin (thin content / all-patrolled).
	var any_idx: int = BalanceBoard.pick_index(
		all_systems.size(),
		String(origin_system).hash(),
		step,
		slot,
		BalanceBoard.SALT_BOUNTY_FALLBACK
	)
	return all_systems[any_idx]


static func _has_smuggle_candidate(origin_station: StringName, origin_system: StringName) -> bool:
	return not _pick_smuggle_route(origin_station, origin_system, 0, 0).is_empty()


static func _pick_smuggle_route(
	origin_station: StringName, _origin_system: StringName, step: int, slot: int
) -> Dictionary:
	var commodity: StringName = BalanceBoard.SMUGGLE_PREFERRED_COMMODITY
	if not ContentLibrary.has_item(commodity):
		return {}
	var item: ContentItem = ContentLibrary.item(commodity)
	if item == null or not (item is Commodity):
		return {}
	var commodity_res: Commodity = item as Commodity
	if commodity_res.contraband_for_entity_ids.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	for station_id: StringName in ContentLibrary.ids_in(&"stations"):
		if station_id == origin_station:
			continue
		var dest_station: Station = _station(station_id)
		if dest_station == null:
			continue
		# Dest that is not a Reach fee-dock, or that wants munitions — gray path.
		var controller: StringName = dest_station.controller_entity_id
		var is_reach_dock: bool = false
		for banned: StringName in commodity_res.contraband_for_entity_ids:
			if controller == banned:
				is_reach_dock = true
				break
		if is_reach_dock:
			continue
		if not MarketService.trades(station_id, commodity):
			# Still allow non-market gray drop if station exists on risk graph.
			if SectorGraph.hop_distance_stations(origin_station, station_id) < 0:
				continue
		var hops: int = SectorGraph.hop_distance_stations(origin_station, station_id)
		if hops < 0:
			continue
		candidates.append({&"dest": station_id, &"commodity": commodity, &"hops": hops})
	if candidates.is_empty():
		return {}
	var idx: int = BalanceBoard.pick_index(
		candidates.size(),
		String(origin_station).hash(),
		step,
		slot,
		BalanceBoard.SALT_SMUGGLE_ROUTE
	)
	return candidates[idx]


static func _pick_other_station(origin_station: StringName, step: int, slot: int) -> StringName:
	var picks: Array[StringName] = []
	for station_id: StringName in ContentLibrary.ids_in(&"stations"):
		if station_id == origin_station:
			continue
		if SectorGraph.hop_distance_stations(origin_station, station_id) < 0:
			continue
		picks.append(station_id)
	if picks.is_empty():
		return &""
	var idx: int = BalanceBoard.pick_index(
		picks.size(), String(origin_station).hash(), step, slot, BalanceBoard.SALT_OTHER_STATION
	)
	return picks[idx]


static func _station(station_id: StringName) -> Station:
	if String(station_id).is_empty() or not ContentLibrary.has_item(station_id):
		return null
	var item: ContentItem = ContentLibrary.item(station_id)
	if item is Station:
		return item as Station
	return null


static func _policing(system_id: StringName) -> StringName:
	if String(system_id).is_empty() or not ContentLibrary.has_item(system_id):
		return StarSystem.POLICED_BY_PATROLS
	var item: ContentItem = ContentLibrary.item(system_id)
	if item is StarSystem:
		return (item as StarSystem).policing
	return StarSystem.POLICED_BY_PATROLS


static func _display_name(id: StringName) -> String:
	if String(id).is_empty():
		return ""
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


static func _dict_int(data: Dictionary, key: StringName, default_value: int) -> int:
	if not data.has(key):
		return default_value
	var raw: Variant = data[key]
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return int(as_float)
	return default_value


static func _rate(map: Dictionary, commodity_id: StringName) -> float:
	if not map.has(commodity_id):
		return 0.0
	var raw: Variant = map[commodity_id]
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return as_float
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return float(as_int)
	return 0.0
