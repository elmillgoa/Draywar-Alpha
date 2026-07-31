class_name Person
extends ContentItem

## A named individual with personal standing — Alpha A2.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A2
## Law: docs/reputation_and_standing.md
##
## Personal standing is separate from Entity standing. Only the primary Entity
## matters for Alpha influence; secondary associations are deferred.

const RANK_LOW: StringName = &"low"
const RANK_MID: StringName = &"mid"
const RANK_HIGH: StringName = &"high"
const KNOWN_RANKS: Array[StringName] = [RANK_LOW, RANK_MID, RANK_HIGH]

## Entity this person belongs to (primary association only for Alpha).
@export var primary_entity_id: StringName = &""

## Rank within the primary Entity. One of `KNOWN_RANKS`.
@export var rank: StringName = &""

## Other Person ids this contact would actually talk to (short, same-side).
@export var network_person_ids: Array[StringName] = []

## Career start when the player has no stored entry for this Person.
@export var default_player_standing: float = BalanceStanding.DEFAULT_STANDING


## Plain list of rank names for validation messages.
static func ranks_named() -> String:
	var names: PackedStringArray = []
	for known: StringName in KNOWN_RANKS:
		names.append(String(known))
	return ", ".join(names)


## Everything wrong with this Person. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if String(primary_entity_id).strip_edges().is_empty():
		problems.append(
			(
				"`primary_entity_id` is empty. Every Person belongs to one Entity "
				+ "(Alpha ignores secondary associations)."
			)
		)

	if not KNOWN_RANKS.has(rank):
		problems.append("`rank` is '%s'. Known ranks: %s." % [rank, ranks_named()])

	if (
		default_player_standing < BalanceStanding.STANDING_MIN
		or default_player_standing > BalanceStanding.STANDING_MAX
	):
		(
			problems
			. append(
				(
					"`default_player_standing` is %s; must be between %s and %s."
					% [
						default_player_standing,
						BalanceStanding.STANDING_MIN,
						BalanceStanding.STANDING_MAX,
					]
				)
			)
		)

	problems.append_array(_network_problems())
	return problems


func _network_problems() -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}
	for index: int in network_person_ids.size():
		var entry: StringName = network_person_ids[index]
		if String(entry).strip_edges().is_empty():
			problems.append(
				"network_person_ids entry %d is empty. A network lists real people." % index
			)
			continue
		if entry == id:
			problems.append(
				"network_person_ids lists this Person ('%s'). Networks point at others." % id
			)
		if seen.has(entry):
			problems.append(
				"network_person_ids lists '%s' more than once. One contact is one entry." % entry
			)
		seen[entry] = true
	return problems
