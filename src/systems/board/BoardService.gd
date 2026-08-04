extends Node

## Station job boards + radiant fill — Steam S3a.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3a
##
## Autoload named `BoardService`, deliberately with **no `class_name`**: same
## pattern as MarketService. Station UI and MissionService reach it by bare
## autoload name; helpers (RadiantJobGenerator) carry class_name inside this
## system folder.
##
## **Steps are derived from the clock, never integrated from deltas.**
## `wanted = floor(elapsed / BOARD_STEP_SECONDS)` — jump away-time and live
## time share this with MarketService. Offers at step N for a station are a
## pure function of content + market catch-up state + step + station_id.
##
## There is **no randomness**. Claimed offers for the current restock cycle are
## the only mid-step board memory that must survive a save.

## Board steps applied since career start (coupled to WorldClock).
var _steps_done: int = 0
## station_id → Array of offer Dictionary for the current step.
var _offers_by_station: Dictionary = {}
## station_id string → Dictionary of claimed offer_id string → true.
var _claimed_by_station: Dictionary = {}
## offer_id string → offer Dictionary (index across stations for accept).
var _offer_index: Dictionary = {}
var _catching_up: bool = false


func _ready() -> void:
	ServiceRegistry.register_resettable(reset)
	WorldClock.register_category_subscriber(BalanceWorldClock.CATEGORY_BOARD, _on_world_tick)


## Clear board state for a new career.
func reset() -> void:
	_steps_done = 0
	_offers_by_station.clear()
	_claimed_by_station.clear()
	_offer_index.clear()


## Run restock steps WorldClock says are owed. Idempotent.
func catch_up() -> void:
	if _catching_up:
		return
	# Market first so radiant shortage reads match the current shelf.
	MarketService.catch_up()
	var elapsed: float = WorldClock.elapsed_seconds()
	if not is_finite(elapsed) or elapsed < 0.0:
		return
	var step_secs: float = BalanceBoard.BOARD_STEP_SECONDS
	var wanted: int = floori(elapsed / step_secs)
	if wanted <= _steps_done:
		return
	_catching_up = true
	_steps_done = wanted
	# New restock cycle: drop per-station caches and claims.
	_offers_by_station.clear()
	_claimed_by_station.clear()
	_offer_index.clear()
	_catching_up = false


## Board steps applied since career start.
func steps_done() -> int:
	catch_up()
	return _steps_done


## Offer instance ids currently listed at this dock (unclaimed).
func offer_ids_for_station(station_id: StringName) -> Array[StringName]:
	catch_up()
	var out: Array[StringName] = []
	if String(station_id).is_empty():
		return out
	_ensure_station_board(station_id)
	var claimed: Dictionary = _claimed_map(station_id)
	var offers: Array = _offers_by_station.get(station_id, [])
	for raw: Variant in offers:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = raw
		var id_raw: Variant = offer.get(BalanceBoard.OFFER_KEY_ID, &"")
		var oid: StringName = StringName(str(id_raw))
		if String(oid).is_empty():
			continue
		if claimed.has(String(oid)):
			continue
		out.append(oid)
	return out


## Full offer snapshot for an id, or empty if unknown / claimed.
func get_offer(offer_id: StringName) -> Dictionary:
	catch_up()
	if String(offer_id).is_empty():
		return {}
	var key: String = String(offer_id)
	if not _offer_index.has(key):
		# Lazy: materialize every station board once so hand/radiant ids resolve.
		_materialize_all_stations()
	if not _offer_index.has(key):
		return {}
	var offer: Dictionary = _offer_index[key]
	if _is_claimed_anywhere(key):
		return {}
	return offer.duplicate(true)


## True when this offer is still on some station board this cycle.
func is_offer_available(offer_id: StringName) -> bool:
	return not get_offer(offer_id).is_empty()


## Mark offer claimed for this restock cycle (accept path). Returns false if
## the offer was already gone.
func claim_offer(offer_id: StringName) -> bool:
	catch_up()
	var key: String = String(offer_id)
	if key.is_empty():
		return false
	if not _offer_index.has(key):
		_materialize_all_stations()
	if not _offer_index.has(key):
		return false
	if _is_claimed_anywhere(key):
		return false
	var offer: Dictionary = _offer_index[key]
	var station_guess: StringName = _station_for_offer(offer)
	var station_key: String = String(station_guess)
	if not _claimed_by_station.has(station_key):
		_claimed_by_station[station_key] = {}
	var claimed: Dictionary = _claimed_by_station[station_key]
	claimed[key] = true
	return true


## Optional `boards` save section.
func to_section() -> Dictionary:
	catch_up()
	var claimed_out: Dictionary = {}
	for station_key: Variant in _claimed_by_station.keys():
		var cmap: Dictionary = _claimed_by_station[station_key]
		var ids: Array = []
		for oid: Variant in cmap.keys():
			ids.append(str(oid))
		ids.sort()
		claimed_out[str(station_key)] = ids
	return {
		BalanceBoard.SAVE_KEY_STEPS: _steps_done,
		BalanceBoard.SAVE_KEY_CLAIMED: claimed_out,
	}


## Restore board step counter and mid-cycle claims. Offers re-derive on query.
func apply_section(raw: Variant) -> void:
	reset()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	_steps_done = _restored_steps(data)
	if data.has(BalanceBoard.SAVE_KEY_CLAIMED):
		var claimed_raw: Variant = data[BalanceBoard.SAVE_KEY_CLAIMED]
		if typeof(claimed_raw) == TYPE_DICTIONARY:
			var claimed_dict: Dictionary = claimed_raw
			_apply_claimed(claimed_dict)


func _restored_steps(data: Dictionary) -> int:
	if not data.has(BalanceBoard.SAVE_KEY_STEPS):
		return 0
	var raw_steps: Variant = data[BalanceBoard.SAVE_KEY_STEPS]
	var saved: int = 0
	if typeof(raw_steps) == TYPE_INT:
		saved = raw_steps
	elif typeof(raw_steps) == TYPE_FLOAT:
		var as_float: float = raw_steps
		if is_finite(as_float):
			saved = int(as_float)
	var elapsed: float = WorldClock.elapsed_seconds()
	var ceiling: int = 0
	if is_finite(elapsed) and elapsed > 0.0:
		ceiling = floori(elapsed / BalanceBoard.BOARD_STEP_SECONDS)
	return clampi(saved, 0, ceiling)


func _apply_claimed(claimed_raw: Dictionary) -> void:
	for station_key: Variant in claimed_raw.keys():
		var list_raw: Variant = claimed_raw[station_key]
		if typeof(list_raw) != TYPE_ARRAY:
			continue
		var cmap: Dictionary = {}
		for item: Variant in list_raw:
			cmap[str(item)] = true
		_claimed_by_station[str(station_key)] = cmap


func _on_world_tick(_delta_seconds: float) -> void:
	catch_up()


func _materialize_all_stations() -> void:
	for station_id: StringName in ContentLibrary.ids_in(&"stations"):
		_ensure_station_board(station_id)


func _ensure_station_board(station_id: StringName) -> void:
	if _offers_by_station.has(station_id):
		return
	var offers: Array = _generate_station_offers(station_id)
	_offers_by_station[station_id] = offers
	for raw: Variant in offers:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = raw
		var id_raw: Variant = offer.get(BalanceBoard.OFFER_KEY_ID, &"")
		var key: String = str(id_raw)
		if key.is_empty():
			continue
		_offer_index[key] = offer


func _generate_station_offers(station_id: StringName) -> Array:
	var out: Array = []
	var station: Station = null
	if ContentLibrary.has_item(station_id):
		var item: ContentItem = ContentLibrary.item(station_id)
		if item is Station:
			station = item as Station
	if station == null:
		return out
	var controller: StringName = station.controller_entity_id
	if controller == Station.CONTROLLER_NOBODY or String(controller).is_empty():
		return out

	var claimed: Dictionary = _claimed_map(station_id)
	var hand: Array[ContractType] = _hand_templates_for(controller)
	var slots: int = BalanceBoard.BOARD_SLOTS_PER_STATION
	var hand_max: int = BalanceBoard.BOARD_HAND_SLOTS_MAX
	var hand_cap: int = mini(hand_max, hand.size())
	# Deterministic hand order: sort by id, then rotate by step mix.
	if hand_cap > 0 and not hand.is_empty():
		var rot: int = BalanceBoard.pick_index(
			hand.size(), String(station_id).hash(), _steps_done, 0, BalanceBoard.SALT_HAND_ROTATE
		)
		for i: int in hand_cap:
			var idx: int = (rot + i) % hand.size()
			var offer: Dictionary = RadiantJobGenerator.offer_from_template(
				hand[idx], station_id, _steps_done, i
			)
			if not offer.is_empty():
				out.append(offer)

	var slot: int = out.size()
	while out.size() < slots:
		var radiant: Dictionary = RadiantJobGenerator.build_offer(
			station_id, _steps_done, slot, claimed
		)
		if radiant.is_empty():
			break
		# Skip duplicate instance ids within the same board.
		var rid: String = str(radiant.get(BalanceBoard.OFFER_KEY_ID, ""))
		if _array_has_offer_id(out, rid):
			slot += 1
			if slot > slots + BalanceBoard.BOARD_SLOTS_PER_STATION:
				break
			continue
		out.append(radiant)
		slot += 1
	return out


func _hand_templates_for(controller: StringName) -> Array[ContractType]:
	var out: Array[ContractType] = []
	for id: StringName in ContentLibrary.ids_in(BalanceStanding.MISSION_CONTENT_CATEGORY):
		var item: ContentItem = ContentLibrary.item(id)
		if item == null or not (item is ContractType):
			continue
		var ct: ContractType = item as ContractType
		if ct.is_spine:
			continue
		if ct.offering_entity_id != controller:
			continue
		out.append(ct)
	out.sort_custom(
		func(a: ContractType, b: ContractType) -> bool: return String(a.id) < String(b.id)
	)
	return out


func _array_has_offer_id(offers: Array, offer_id: String) -> bool:
	if offer_id.is_empty():
		return false
	for raw: Variant in offers:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = raw
		if str(offer.get(BalanceBoard.OFFER_KEY_ID, "")) == offer_id:
			return true
	return false


func _claimed_map(station_id: StringName) -> Dictionary:
	var key: String = String(station_id)
	if not _claimed_by_station.has(key):
		return {}
	return _claimed_by_station[key]


func _is_claimed_anywhere(offer_key: String) -> bool:
	for station_key: Variant in _claimed_by_station.keys():
		var cmap: Dictionary = _claimed_by_station[station_key]
		if cmap.has(offer_key):
			return true
	return false


func _station_for_offer(offer: Dictionary) -> StringName:
	var board: StringName = StringName(str(offer.get(BalanceBoard.OFFER_KEY_BOARD_STATION, &"")))
	if not String(board).is_empty():
		return board
	return StringName(str(offer.get(BalanceBoard.OFFER_KEY_DESTINATION, &"")))
