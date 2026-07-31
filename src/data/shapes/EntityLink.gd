class_name EntityLink
extends Resource

## One typed relationship from an Entity to another — Alpha A2.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A2
##
## Alpha hierarchy is flat: links are simple typed edges, not parent/child.

const RELATION_ALLIED: StringName = &"allied"
const RELATION_SUBSIDIARY: StringName = &"subsidiary"
const RELATION_RIVAL: StringName = &"rival"
const RELATION_ENEMY: StringName = &"enemy"
const RELATION_MEMBER_OF: StringName = &"member_of"

const KNOWN_RELATIONS: Array[StringName] = [
	RELATION_ALLIED,
	RELATION_SUBSIDIARY,
	RELATION_RIVAL,
	RELATION_ENEMY,
	RELATION_MEMBER_OF,
]

## Other Entity content id this link points at.
@export var target_id: StringName = &""

## One of `KNOWN_RELATIONS`.
@export var relation_type: StringName = &""


## Plain list of relation type names for validation messages.
static func relations_named() -> String:
	var names: PackedStringArray = []
	for known: StringName in KNOWN_RELATIONS:
		names.append(String(known))
	return ", ".join(names)


## Everything wrong with this link. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = []

	if String(target_id).strip_edges().is_empty():
		problems.append("`target_id` is empty. A relationship link needs a target Entity id.")

	if not KNOWN_RELATIONS.has(relation_type):
		problems.append(
			"`relation_type` is '%s'. Known types: %s." % [relation_type, relations_named()]
		)

	return problems
