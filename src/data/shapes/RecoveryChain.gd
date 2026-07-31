class_name RecoveryChain
extends ContentItem

## One personal recovery chain — Alpha A4 / E4.4.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A4; docs/BETA_E4_OPENING_CAST.md E4.4
## Law: docs/reputation_and_standing.md §5
## Scope: E4.4 budget ceiling 2 (Mendi/Reach + Jax/Drift).
##
## A Person under an Entity offers deniable work so the player can climb sticky
## deep-negative Entity standing. Full-sized shape; one chain per foothold Entity.

## Person who offers this chain (must match a loaded Person id).
@export var person_id: StringName = &""

## Entity whose standing this chain moves (must match person's primary Entity).
@export var entity_id: StringName = &""

## Ordered steps (3–5 for Alpha). First is the deniable trust test.
@export var steps: Array[RecoveryStep] = []


## Everything wrong with this chain. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if String(person_id).strip_edges().is_empty():
		problems.append(
			"`person_id` is empty. Every recovery chain names the Person " + "who offers it."
		)

	if String(entity_id).strip_edges().is_empty():
		problems.append(
			(
				"`entity_id` is empty. Every recovery chain names the Entity "
				+ "whose standing the chain moves."
			)
		)

	var step_count: int = steps.size()
	if step_count < BalanceStanding.RECOVERY_CHAIN_MIN_STEPS:
		problems.append(
			(
				"`steps` has %d entry(ies); Alpha recovery chains need at least %d."
				% [step_count, BalanceStanding.RECOVERY_CHAIN_MIN_STEPS]
			)
		)
	if step_count > BalanceStanding.RECOVERY_CHAIN_MAX_STEPS:
		problems.append(
			(
				"`steps` has %d entry(ies); Alpha recovery chains allow at most %d."
				% [step_count, BalanceStanding.RECOVERY_CHAIN_MAX_STEPS]
			)
		)

	var seen: Dictionary[StringName, bool] = {}
	for index: int in steps.size():
		var step: RecoveryStep = steps[index]
		if step == null:
			problems.append("`steps` entry %d is null." % index)
			continue
		problems.append_array(step.validation_errors())
		if String(step.id).is_empty():
			continue
		if seen.has(step.id):
			problems.append(
				"`steps` lists id '%s' more than once. Step ids must be unique." % step.id
			)
		seen[step.id] = true
		if index == 0 and step.requires_prior_success:
			problems.append(
				(
					(
						"First step '%s' has requires_prior_success=true. "
						+ "Alpha §5 bootstrap: the deniable first job unlocks at "
						+ "Friendly personal standing alone."
					)
					% step.id
				)
			)
		if index > 0 and not step.requires_prior_success:
			problems.append(
				(
					(
						"Follow-on step '%s' has requires_prior_success=false. "
						+ "Only the deniable first job may skip prior success."
					)
					% step.id
				)
			)

	return problems
