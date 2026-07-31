class_name ContractType
extends ContentItem

## Mission / contract template — full-sized Alpha shape, tiny A3 content.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A3, docs/BETA_E3_ECONOMY.md E3.4
##
## Offered by an Entity. Standing outcomes default to BalanceStanding mission
## deltas; content may override magnitudes. One active mission max at runtime
## (MissionService). Kind is free-form for expansion; Alpha ships delivery.

## Who pays standing for this contract.
@export var offering_entity_id: StringName = &""

## Mission family (e.g. delivery, bounty, smuggle).
## See BalanceStanding.MISSION_KIND_*.
@export var kind: StringName = BalanceStanding.MISSION_KIND_DELIVERY

## Standing on complete / fail / abandon. Defaults match BalanceStanding.
@export var standing_complete: float = BalanceStanding.MISSION_COMPLETE_DELTA
@export var standing_fail: float = BalanceStanding.MISSION_FAIL_DELTA
@export var standing_abandon: float = BalanceStanding.MISSION_ABANDON_DELTA

## Credits paid on complete. Defaults match BalanceEconomy.
@export var pay_credits: int = BalanceEconomy.MISSION_PAY_DEFAULT

## Turn-in station. Empty = turn in at any docked station (A5 delivery).
@export var destination_station_id: StringName = &""

## Bounty: system where a hostile kill counts. Empty for non-bounty kinds.
@export var target_system_id: StringName = &""

## Smuggle: commodity content id loaded into the hold on accept.
@export var cargo_commodity_id: StringName = &""

## Smuggle: units loaded on accept; must still be held at turn-in.
@export var cargo_quantity: int = 0


## Everything wrong with this contract template. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if String(offering_entity_id).strip_edges().is_empty():
		problems.append(
			(
				"`offering_entity_id` is empty. Every contract names the Entity "
				+ "that offers it and pays standing."
			)
		)

	if String(kind).strip_edges().is_empty():
		problems.append("`kind` is empty. Name the contract family (e.g. delivery).")

	if pay_credits < 0:
		problems.append("`pay_credits` is negative. Mission pay cannot be below zero.")

	if kind == BalanceStanding.MISSION_KIND_BOUNTY:
		if String(target_system_id).strip_edges().is_empty():
			problems.append(
				(
					"`target_system_id` is empty. Bounty contracts name the system "
					+ "where the kill counts."
				)
			)
		if String(destination_station_id).strip_edges().is_empty():
			problems.append(
				(
					"`destination_station_id` is empty. Bounty contracts name the "
					+ "station where you turn the job in after the kill."
				)
			)

	if kind == BalanceStanding.MISSION_KIND_SMUGGLE:
		if String(destination_station_id).strip_edges().is_empty():
			problems.append(
				(
					"`destination_station_id` is empty. Smuggle contracts name the "
					+ "station that receives the cargo."
				)
			)
		if String(cargo_commodity_id).strip_edges().is_empty():
			problems.append(
				(
					"`cargo_commodity_id` is empty. Smuggle contracts name the "
					+ "commodity loaded on accept."
				)
			)
		if cargo_quantity <= 0:
			problems.append(
				"`cargo_quantity` must be greater than zero for smuggle " + "contracts."
			)

	problems.append_array(_delta_problems(standing_complete, "standing_complete"))
	problems.append_array(_delta_problems(standing_fail, "standing_fail"))
	problems.append_array(_delta_problems(standing_abandon, "standing_abandon"))
	return problems


func _delta_problems(value: float, field: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	var span: float = BalanceStanding.STANDING_MAX - BalanceStanding.STANDING_MIN
	if absf(value) > span:
		problems.append(
			(
				(
					"`%s` is %s; a single mission delta cannot exceed the full "
					+ "standing scale span (%s)."
				)
				% [field, value, span]
			)
		)
	return problems
