class_name MissionOffer
extends RefCounted

## Runtime / radiant offer → ContractType — systems/mission helper (S3a).
##
## Lives under mission/ so MissionService does not class_name-reference board/.
## BoardService builds offer dicts; this is the only place mission rehydrates them.


## ContractType resource from a board/runtime offer snapshot (not ContentLibrary).
static func contract_from_offer(offer: Dictionary) -> ContractType:
	if offer.is_empty():
		return null
	var contract: ContractType = ContractType.new()
	var id_raw: Variant = offer.get(BalanceBoard.OFFER_KEY_ID, &"")
	contract.id = StringName(str(id_raw))
	contract.display_name = str(
		offer.get(BalanceBoard.OFFER_KEY_LABEL, BalanceBoard.LABEL_FALLBACK)
	)
	contract.kind = StringName(str(offer.get(BalanceBoard.OFFER_KEY_KIND, &"")))
	contract.offering_entity_id = StringName(
		str(offer.get(BalanceBoard.OFFER_KEY_OFFERING_ENTITY, &""))
	)
	contract.pay_credits = _as_int(offer.get(BalanceBoard.OFFER_KEY_PAY, BalanceBoard.PAY_FLOOR))
	contract.standing_complete = _as_float(
		offer.get(BalanceBoard.OFFER_KEY_STANDING_COMPLETE, BalanceStanding.MISSION_COMPLETE_DELTA)
	)
	contract.standing_fail = _as_float(
		offer.get(BalanceBoard.OFFER_KEY_STANDING_FAIL, BalanceStanding.MISSION_FAIL_DELTA)
	)
	contract.standing_abandon = _as_float(
		offer.get(BalanceBoard.OFFER_KEY_STANDING_ABANDON, BalanceStanding.MISSION_ABANDON_DELTA)
	)
	contract.destination_station_id = StringName(
		str(offer.get(BalanceBoard.OFFER_KEY_DESTINATION, &""))
	)
	contract.target_system_id = StringName(
		str(offer.get(BalanceBoard.OFFER_KEY_TARGET_SYSTEM, &""))
	)
	contract.cargo_commodity_id = StringName(
		str(offer.get(BalanceBoard.OFFER_KEY_CARGO_COMMODITY, &""))
	)
	contract.cargo_quantity = _as_int(offer.get(BalanceBoard.OFFER_KEY_CARGO_QUANTITY, 0))
	return contract


static func _as_int(raw: Variant) -> int:
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return int(as_float)
	return 0


static func _as_float(raw: Variant) -> float:
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return as_float
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return float(as_int)
	return 0.0
