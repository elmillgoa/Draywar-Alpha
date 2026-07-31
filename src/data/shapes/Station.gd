class_name Station
extends ContentItem

## A dockable station as data — full-sized Alpha shape, tiny A1 content.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## `system_id` is the star system this station sits in. `controller_entity_id`
## is who holds the dock (Entity id, or `CONTROLLER_NOBODY` until A2). World
## placement for A1 uses BalanceFlight positions; `position_offset` is reserved
## for multi-station layouts without redesign.

## What `controller_entity_id` says when nobody holds this station.
const CONTROLLER_NOBODY: StringName = &"nobody"

## Star system content id this station is sited in.
@export var system_id: StringName = &""

## Controlling Entity id, or `CONTROLLER_NOBODY`.
@export var controller_entity_id: StringName = CONTROLLER_NOBODY

## Optional local offset from the system's station anchor. Zero for A1.
@export var position_offset: Vector3 = Vector3.ZERO


## Everything wrong with this station. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if String(system_id).strip_edges().is_empty():
		problems.append(
			(
				"`system_id` is empty. Every station declares the system it sits in "
				+ "so the world builder and standing service can resolve place."
			)
		)

	if String(controller_entity_id).strip_edges().is_empty():
		problems.append(
			(
				"`controller_entity_id` is empty. Every station says who holds the dock; "
				+ "write '%s' when nobody does." % CONTROLLER_NOBODY
			)
		)

	return problems
