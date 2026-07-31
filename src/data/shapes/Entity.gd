class_name Entity
extends ContentItem

## An institutional power — government, syndicate, league, order — Alpha A2.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A2
## Law: docs/reputation_and_standing.md
##
## Entities set the weather: they hold territory, have reach, and enforce
## standing where they can act. Full-sized shape; Alpha ships a handful.

## Typed links to other Entities (allied, rival, …). Empty is legal.
@export var relationship_links: Array[EntityLink] = []

## System content ids where this Entity can enforce standing.
@export var reach_system_ids: Array[StringName] = []

## Station content ids where this Entity can enforce standing.
@export var reach_station_ids: Array[StringName] = []

## Career start when the player has no stored entry for this Entity.
@export var default_player_standing: float = BalanceStanding.DEFAULT_STANDING

## Standing at or below this refuses docking at stations this Entity controls.
@export var dock_refusal_threshold: float = BalanceStanding.DEFAULT_DOCK_REFUSAL_THRESHOLD


## Everything wrong with this Entity. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

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

	if (
		dock_refusal_threshold < BalanceStanding.STANDING_MIN
		or dock_refusal_threshold > BalanceStanding.STANDING_MAX
	):
		(
			problems
			. append(
				(
					"`dock_refusal_threshold` is %s; must be between %s and %s."
					% [
						dock_refusal_threshold,
						BalanceStanding.STANDING_MIN,
						BalanceStanding.STANDING_MAX,
					]
				)
			)
		)

	problems.append_array(_list_problems(reach_system_ids, "reach_system_ids"))
	problems.append_array(_list_problems(reach_station_ids, "reach_station_ids"))
	problems.append_array(_link_problems())
	return problems


## Blank or duplicate entries in a StringName attachment list.
func _list_problems(entries: Array[StringName], field: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}
	for index: int in entries.size():
		var entry: StringName = entries[index]
		if String(entry).strip_edges().is_empty():
			problems.append(
				(
					"%s entry %d is empty. Declare only real places; blanks are unfinished."
					% [field, index]
				)
			)
			continue
		if seen.has(entry):
			problems.append(
				"%s lists '%s' more than once. One place is one entry." % [field, entry]
			)
		seen[entry] = true
	return problems


func _link_problems() -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen_targets: Dictionary[StringName, bool] = {}
	for index: int in relationship_links.size():
		var link: EntityLink = relationship_links[index]
		if link == null:
			problems.append(
				"relationship_links entry %d is null. Every slot needs an EntityLink." % index
			)
			continue
		var link_faults: PackedStringArray = link.validation_errors()
		for fault: String in link_faults:
			problems.append("relationship_links[%d]: %s" % [index, fault])
		if String(link.target_id).strip_edges().is_empty():
			continue
		if link.target_id == id:
			problems.append(
				(
					"relationship_links[%d] targets this Entity itself ('%s'). " % [index, id]
					+ "Links point at others."
				)
			)
		if seen_targets.has(link.target_id):
			problems.append(
				(
					"relationship_links lists target '%s' more than once. " % link.target_id
					+ "One link per target."
				)
			)
		seen_targets[link.target_id] = true
	return problems
