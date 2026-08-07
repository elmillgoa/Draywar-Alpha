class_name StarSystem
extends ContentItem

## A star system as data — full-sized Alpha shape, tiny A0 content.
##
## Content ceilings live in Balance.CONTENT_BUDGET, not here.
## A0 ships empty gray boxes so "empty systems can load" is real. Gates and
## stations arrive as empty attachment points; A1 fills them without redesign.
##
## `held_by` is the controlling Entity id (or `HELD_BY_NOBODY`). `policing` is
## whether anybody flies patrols here — separate from who holds the system.

## What `policing` may say. Alpha needs controlled, contested, and lawless.
const POLICED_BY_PATROLS: StringName = &"patrolled"
const POLICED_BY_CONTESTED: StringName = &"contested"
const POLICED_BY_NOBODY: StringName = &"lawless"
const KNOWN_POLICING: Array[StringName] = [
	POLICED_BY_PATROLS,
	POLICED_BY_CONTESTED,
	POLICED_BY_NOBODY,
]

## What `held_by` says when nobody holds this system.
const HELD_BY_NOBODY: StringName = &"nobody"

## Who holds this system — controlling Entity id, or `HELD_BY_NOBODY`.
@export var held_by: StringName = &""

## Whether anybody flies patrols here. One of `KNOWN_POLICING`.
@export var policing: StringName = &""

## Station content ids sited in this system. Empty is legal (A0 gray boxes).
@export var station_ids: Array[StringName] = []

## System ids this system's gates lead to. Empty is legal until A1 adds gates.
@export var gate_destination_ids: Array[StringName] = []

## Optional one-line place flavor for HUD / station (empty is fine).
@export var flavor_line: String = ""


## Whether anybody flies patrols here.
func is_policed() -> bool:
	return policing == POLICED_BY_PATROLS


## Everything `policing` may say, for a complaint about a word that is not one.
static func policing_named() -> String:
	var names: PackedStringArray = []
	for known: StringName in KNOWN_POLICING:
		names.append(String(known))
	return ", ".join(names)


## Everything wrong with this system. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if String(held_by).strip_edges().is_empty():
		problems.append(
			(
				"`held_by` is empty. Every system says who holds it; write '%s' " % HELD_BY_NOBODY
				+ "when nobody does, so an answered slot cannot be mistaken for "
				+ "one somebody forgot."
			)
		)

	if not KNOWN_POLICING.has(policing):
		problems.append(
			(
				"`policing` is '%s'. Every system says whether anybody flies " % policing
				+ "patrols here; the answers that exist are: %s." % policing_named()
			)
		)

	problems.append_array(_list_problems(station_ids, "station_ids"))
	problems.append_array(_list_problems(gate_destination_ids, "gate_destination_ids"))
	return problems


## Blank or duplicate entries in an attachment list.
func _list_problems(entries: Array[StringName], field: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}
	for index: int in entries.size():
		var entry: StringName = entries[index]
		if String(entry).strip_edges().is_empty():
			problems.append(
				(
					(
						"%s entry %d is empty. A system declares the attachments it has; "
						% [field, index]
					)
					+ "a blank entry is one somebody meant to fill in."
				)
			)
			continue
		if seen.has(entry):
			problems.append(
				"%s lists '%s' more than once. One attachment is one place." % [field, entry]
			)
		seen[entry] = true
	return problems
