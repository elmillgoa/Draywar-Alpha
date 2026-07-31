class_name LifePathStandingDelta
extends Resource

## One standing tooth on a life-path option — Entity or Person target.
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.1
## Law: docs/reputation_and_standing.md — magnitudes only; writes go through
## StandingService via CareerStart.

## Content id of the Entity or Person this delta hits.
@export var target_id: StringName = &""

## Raw standing change applied at career start (no ripple).
@export var delta: float = 0.0


## Everything wrong with this delta. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = []

	if String(target_id).strip_edges().is_empty():
		problems.append("`target_id` is empty. Every life-path tooth names a target.")

	var span: float = BalanceStanding.STANDING_MAX - BalanceStanding.STANDING_MIN
	if absf(delta) > span:
		problems.append(
			(
				(
					"`delta` is %s; a single life-path delta cannot exceed the full "
					+ "standing scale span (%s)."
				)
				% [delta, span]
			)
		)

	return problems
