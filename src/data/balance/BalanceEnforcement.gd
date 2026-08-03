class_name BalanceEnforcement
extends RefCounted

## Per-Entity heat + patrol pressure — Steam S4.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S4
## Law: docs/reputation_and_standing.md (no standing writes from heat)
##
## Heat is per-Entity (the enforcer), not a global wanted bar. Tunables only.

# --- Save ------------------------------------------------------------------

const SAVE_SECTION_KEY: StringName = &"enforcement"
const SAVE_KEY_HEAT: StringName = &"heat"
const SAVE_KEY_STEPS: StringName = &"steps_done"

# --- Heat scale ------------------------------------------------------------

const HEAT_MAX: float = 100.0
const HEAT_MIN: float = 0.0

## Decay applied once per security / incident step (same cadence as IncidentService).
const HEAT_DECAY_PER_SECURITY_STEP: float = 3.0

## Attributed kill in a patrolled system → heat on the enforcing Entity.
const HEAT_KILL_PATROLLED: float = 25.0

## Attributed kill in contested space.
const HEAT_KILL_CONTESTED: float = 10.0

## Attributed kill in lawless space: law has no teeth — no heat.
const HEAT_KILL_LAWLESS: float = 0.0

## Flee / ignore a customs scan (customs only exist in patrolled).
const HEAT_CUSTOMS_FLEE: float = 20.0

## Contraband seized for a controller (full in patrolled; half contested; 0 lawless).
const HEAT_CONTRABAND: float = 15.0

const HEAT_CONTRABAND_CONTESTED_FACTOR: float = 0.5

# --- Pressure / hunt thresholds (patrolled systems only) -------------------

## More intercept pressure when heat is at or above this.
const HEAT_THRESHOLD_PRESSURE: float = 25.0

## Force a patrol-response intercept attempt when heat is at or above this.
const HEAT_THRESHOLD_HUNT: float = 50.0

## Min security steps between forced patrol responses in one system.
const HUNT_COOLDOWN_STEPS: int = 2

## Under pressure, intercept fire modulus (lower = more often). Clamped ≥ 1.
const FIRE_MOD_INTERCEPT_PRESSURE: int = 2

# --- Mutation reasons (EventBus on_heat_changed) ---------------------------

const REASON_HEAT_KILL: StringName = &"heat_kill"
const REASON_HEAT_CUSTOMS_FLEE: StringName = &"heat_customs_flee"
const REASON_HEAT_CONTRABAND: StringName = &"heat_contraband"
const REASON_HEAT_DECAY: StringName = &"heat_decay"
const REASON_HEAT_SET: StringName = &"heat_set"

# --- Patrol response prompt (reuses KIND_INTERCEPT) ------------------------

const LABEL_PATROL_RESPONSE: String = "Patrol response — you are wanted here"
const PROMPT_PATROL_RESPONSE: String = "Authority patrol closing. Submit or resist?"

## Offer dictionary flag: this intercept is a heat-driven patrol response.
const KEY_PATROL_RESPONSE: StringName = &"patrol_response"

# --- Input actions (bound in FlightInput; HUD reads these names only) ------

const ACTION_INCIDENT_A: StringName = &"incident_a"
const ACTION_INCIDENT_B: StringName = &"incident_b"

# --- HUD control hints (appended to incident prompts) ----------------------

const HINT_DISTRESS: String = "[1] help  [2] ignore"
const HINT_INTERCEPT: String = "[1] resist  [2] submit"
const HINT_CUSTOMS: String = "[1] cooperate  [2] flee"

const HINT_SEPARATOR: String = "  "


## Append the [1]/[2] control hint for this incident kind.
static func prompt_with_controls(kind: StringName, base_prompt: String) -> String:
	var hint: String = control_hint_for_kind(kind)
	if hint.is_empty():
		return base_prompt
	if base_prompt.is_empty():
		return hint
	return base_prompt + HINT_SEPARATOR + hint


## Control-hint line for an incident kind (empty if unknown).
static func control_hint_for_kind(kind: StringName) -> String:
	if kind == BalanceIncident.KIND_DISTRESS:
		return HINT_DISTRESS
	if kind == BalanceIncident.KIND_INTERCEPT:
		return HINT_INTERCEPT
	if kind == BalanceIncident.KIND_CUSTOMS:
		return HINT_CUSTOMS
	return ""


## Primary key (1) choice for this kind.
static func primary_choice_for_kind(kind: StringName) -> StringName:
	if kind == BalanceIncident.KIND_DISTRESS:
		return BalanceIncident.CHOICE_HELP
	if kind == BalanceIncident.KIND_INTERCEPT:
		return BalanceIncident.CHOICE_RESIST
	if kind == BalanceIncident.KIND_CUSTOMS:
		return BalanceIncident.CHOICE_COOPERATE
	return &""


## Secondary key (2) choice for this kind.
static func secondary_choice_for_kind(kind: StringName) -> StringName:
	if kind == BalanceIncident.KIND_DISTRESS:
		return BalanceIncident.CHOICE_IGNORE
	if kind == BalanceIncident.KIND_INTERCEPT:
		return BalanceIncident.CHOICE_SUBMIT
	if kind == BalanceIncident.KIND_CUSTOMS:
		return BalanceIncident.CHOICE_FLEE
	return &""


## Heat magnitude for an attributed kill given system policing (0 if none).
static func kill_heat_for_policing(policing: StringName) -> float:
	if policing == StarSystem.POLICED_BY_PATROLS:
		return HEAT_KILL_PATROLLED
	if policing == StarSystem.POLICED_BY_CONTESTED:
		return HEAT_KILL_CONTESTED
	if policing == StarSystem.POLICED_BY_NOBODY:
		return HEAT_KILL_LAWLESS
	return HEAT_KILL_LAWLESS


## Heat magnitude for contraband seizure given system policing.
static func contraband_heat_for_policing(policing: StringName) -> float:
	if policing == StarSystem.POLICED_BY_PATROLS:
		return HEAT_CONTRABAND
	if policing == StarSystem.POLICED_BY_CONTESTED:
		return HEAT_CONTRABAND * HEAT_CONTRABAND_CONTESTED_FACTOR
	return 0.0
