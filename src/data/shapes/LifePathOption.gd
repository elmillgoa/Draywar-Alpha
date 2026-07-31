class_name LifePathOption
extends ContentItem

## One life-path pick (origin, former trade, or the mark) — E4.1.
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.1 / D1–D3, D14
## Law: docs/reputation_and_standing.md
##
## Teeth = standing deltas + optional emergency loan. No gear, no ops.
## Full-sized shape; Alpha ships exactly nine rows (3 axes × 3 options).

## Player-facing short copy for create UI (E4.2). Flavor only.
@export var blurb: String = ""

## Which axis this option belongs to (origin / trade / mark).
@export var axis: StringName = &""

## Entity standing changes applied when this option is chosen.
@export var entity_deltas: Array[LifePathStandingDelta] = []

## Person standing changes applied when this option is chosen.
@export var person_deltas: Array[LifePathStandingDelta] = []

## When true, open the Free Haulers E3 emergency loan at career start.
@export var starts_with_debt: bool = false


## Everything wrong with this option. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if not BalanceStanding.LIFE_PATH_AXES.has(axis):
		problems.append(
			"`axis` is '%s'. Known axes: %s." % [axis, BalanceStanding.life_path_axes_named()]
		)

	problems.append_array(_delta_list_problems(entity_deltas, "entity_deltas"))
	problems.append_array(_delta_list_problems(person_deltas, "person_deltas"))
	return problems


func _delta_list_problems(
	entries: Array[LifePathStandingDelta], field: String
) -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}
	for index: int in entries.size():
		var entry: LifePathStandingDelta = entries[index]
		if entry == null:
			problems.append("`%s` entry %d is null." % [field, index])
			continue
		for fault: String in entry.validation_errors():
			problems.append("%s[%d]: %s" % [field, index, fault])
		if String(entry.target_id).strip_edges().is_empty():
			continue
		if seen.has(entry.target_id):
			problems.append(
				(
					"`%s` lists target '%s' more than once. One tooth per target."
					% [field, entry.target_id]
				)
			)
		seen[entry.target_id] = true
	return problems
