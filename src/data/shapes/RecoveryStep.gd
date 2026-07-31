class_name RecoveryStep
extends Resource

## One step in a personal recovery chain — Alpha A4.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A4
## Law: docs/reputation_and_standing.md §5
##
## First step is the deniable trust test (tiny Entity delta). Later steps stay
## one-on-one with the same Person for Alpha's single chain.

## Stable key within the parent RecoveryChain.
@export var id: StringName = &""

## What the player is shown for this step.
@export var display_name: String = ""

## Personal standing change on success (solid trust build).
@export var personal_standing_delta: float = BalanceStanding.RECOVERY_DEFAULT_PERSONAL_DELTA

## Entity standing change on success (tiny early; slightly larger later).
@export var entity_standing_delta: float = BalanceStanding.RECOVERY_DEFAULT_ENTITY_DELTA

## When true, a prior step of this chain must already have succeeded.
## Alpha §5 bootstrap: the first deniable job sets this false (Friendly personal
## only). Follow-ons set true so history builds from the deniable job.
@export var requires_prior_success: bool = true


## Everything wrong with this step. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = []

	if String(id).strip_edges().is_empty():
		problems.append("`id` is empty. Every recovery step needs a stable key.")

	if display_name.strip_edges().is_empty():
		problems.append("`display_name` is empty. Nothing would render for this step.")

	problems.append_array(_delta_problems(personal_standing_delta, "personal_standing_delta"))
	problems.append_array(_delta_problems(entity_standing_delta, "entity_standing_delta"))
	return problems


func _delta_problems(value: float, field: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	var span: float = BalanceStanding.STANDING_MAX - BalanceStanding.STANDING_MIN
	if absf(value) > span:
		problems.append(
			(
				(
					"`%s` is %s; a single recovery delta cannot exceed the full "
					+ "standing scale span (%s)."
				)
				% [field, value, span]
			)
		)
	return problems
