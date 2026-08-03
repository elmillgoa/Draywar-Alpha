class_name BalanceIncident
extends RefCounted

## Opportunistic space incidents + news/traffic lite — Steam S3b.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S3 S3b
##
## Incidents are **not** MissionService jobs. They may promote into a mission
## when the one-active slot is free. Tunables only — no game state.

# --- Tick cadence (security category) ----------------------------------------

## One security / incident evaluation interval in game seconds (2 game hours).
## Steps derive as floor(elapsed / INCIDENT_STEP_SECONDS) — same style as board
## and market, so jump away-time and live time share arithmetic.
const INCIDENT_STEP_SECONDS: float = 7200.0

## INCIDENT_STEP_SECONDS in game hours.
const INCIDENT_STEP_HOURS: float = 2.0

# --- Save (optional; S3b expires offered incidents on load) ------------------

const SAVE_SECTION_KEY: StringName = &"incidents"

const SAVE_KEY_STEPS: StringName = &"steps_done"

## Policy note for save_schema.md: offered incidents do not survive load.
## Mid-flight prompts depend on live ships/world; reload expires them cleanly.

# --- Kinds / states / choices ------------------------------------------------

const KIND_DISTRESS: StringName = &"distress"
const KIND_INTERCEPT: StringName = &"intercept"
const KIND_CUSTOMS: StringName = &"customs"

const STATE_OFFERED: StringName = &"offered"
const STATE_RESOLVED: StringName = &"resolved"
const STATE_EXPIRED: StringName = &"expired"
const STATE_PROMOTED: StringName = &"promoted"

const CHOICE_HELP: StringName = &"help"
const CHOICE_IGNORE: StringName = &"ignore"
const CHOICE_COOPERATE: StringName = &"cooperate"
const CHOICE_FLEE: StringName = &"flee"
const CHOICE_RESIST: StringName = &"resist"
const CHOICE_SUBMIT: StringName = &"submit"

# --- Caps / cooldowns --------------------------------------------------------

## Max concurrent offered incidents across the sector (prompts, not ships).
const MAX_OFFERED: int = 3

## Ship slots claimed while a distress freighter prop is live.
const SHIPS_DISTRESS: int = 1

## Ship slots claimed while an intercept pressure contact is live.
const SHIPS_INTERCEPT: int = 1

## Customs is a scan prompt — no extra hull.
const SHIPS_CUSTOMS: int = 0

## How many security steps an offered incident stays before auto-expire.
const OFFER_TTL_STEPS: int = 2

## Min security steps between two offers of the same kind in one system.
const COOLDOWN_STEPS_SAME_KIND: int = 1

# --- Deterministic mix (no RNG) ----------------------------------------------

const HASH_A: int = 374761393
const HASH_B: int = 668265263
const HASH_C: int = 1274126177
const HASH_D: int = 1103515245
const HASH_E: int = 12345
const HASH_MASK: int = 0x7fffffff

const SALT_DISTRESS: int = 101
const SALT_INTERCEPT: int = 202
const SALT_CUSTOMS: int = 303
const SALT_DEST: int = 404
const SALT_PAY: int = 505

## Kind fires this step when mix % this == 0 (lower = more frequent).
const FIRE_MOD_DISTRESS: int = 3
const FIRE_MOD_INTERCEPT: int = 4
const FIRE_MOD_CUSTOMS: int = 3

# --- Pay / promote (wallet only on non-promote help — no new standing law) ---

## Small cash when player helps distress while already on a mission.
const DISTRESS_HELP_PAY_ACTIVE_MISSION: int = 40

## Credits when distress promotes to a short delivery-style mission.
const DISTRESS_PROMOTE_PAY: int = 160

## Wallet payout when intercept is submitted (pay off / drop threat) while free.
const INTERCEPT_SUBMIT_PAY_LOSS: int = 30

## Wallet payout when intercept is resisted and "cleared" without mission.
const INTERCEPT_RESIST_PAY: int = 50

## Mission kind used when distress promotes (reuse delivery turn-in).
const PROMOTE_KIND: StringName = &"delivery"

## Label templates (plain English).
const LABEL_DISTRESS: String = "Distress call — freighter in trouble"
const LABEL_DISTRESS_MISSION: String = "Rescue haul to %s"
const LABEL_INTERCEPT: String = "Hostile intercept — cargo threat"
const LABEL_CUSTOMS: String = "Customs scan — restricted cargo flagged"

const PROMPT_DISTRESS: String = "Distress beacon nearby. Help or ignore?"
const PROMPT_INTERCEPT: String = "Hostile contact demanding cargo. Submit or resist?"
const PROMPT_CUSTOMS: String = "Patrol scan. Cooperate or flee?"

# --- Incident dictionary keys ------------------------------------------------

const KEY_ID: StringName = &"incident_id"
const KEY_KIND: StringName = &"kind"
const KEY_STATE: StringName = &"state"
const KEY_SYSTEM: StringName = &"system_id"
const KEY_STEP: StringName = &"step"
const KEY_EXPIRE_STEP: StringName = &"expire_step"
const KEY_LABEL: StringName = &"label"
const KEY_PROMPT: StringName = &"prompt"
const KEY_SHIP_SLOTS: StringName = &"ship_slots"
const KEY_DESTINATION: StringName = &"destination_station_id"
const KEY_OFFERING_ENTITY: StringName = &"offering_entity_id"
const KEY_PAY: StringName = &"pay_credits"

# --- News / policing lines ---------------------------------------------------

const NEWS_PATROLLED_FORMAT: String = "Patrols active through %s."
const NEWS_CONTESTED_FORMAT: String = "Skirmish reports in %s."
const NEWS_LAWLESS_FORMAT: String = "No patrols — %s runs hot."
const NEWS_DISTRESS_ECHO: String = "Distress traffic reported near %s."
const NEWS_INTERCEPT_ECHO: String = "Intercept pressure noted in %s."
const NEWS_CUSTOMS_ECHO: String = "Customs checks tighter around %s."
const NEWS_INCIDENT_QUIET: String = "Local channels quiet."

## How many recent incident echoes feed the news rotation pool.
const NEWS_ECHO_CAP: int = 4

## Wallet / money-log reason for non-mission incident pay.
const REASON_INCIDENT_PAY: StringName = &"incident_pay"
const REASON_INCIDENT_LOSS: StringName = &"incident_loss"

# --- Traffic purpose lite ----------------------------------------------------

const PURPOSE_ORBIT: StringName = &"orbit"
const PURPOSE_DOCK_CYCLE: StringName = &"dock_cycle"
const PURPOSE_SHORTAGE_RUN: StringName = &"shortage_run"

## Fraction of civilian traffic that uses a dock approach cycle (0–1).
const TRAFFIC_DOCK_CYCLE_FRACTION: float = 0.25

## Max freighters retasked toward a shortage station at once.
const TRAFFIC_SHORTAGE_FREIGHTERS_MAX: int = 1

## stock/target at or below this counts as shortage for traffic retask.
const TRAFFIC_SHORTAGE_RATIO: float = 0.55

## Dock-cycle lerp: approach pad then return to orbit radius.
const TRAFFIC_DOCK_APPROACH_SECONDS: float = 12.0
const TRAFFIC_DOCK_HOLD_SECONDS: float = 4.0
const TRAFFIC_DOCK_DEPART_SECONDS: float = 10.0

## Shortage freighter cruise speed (units/sec toward station).
const TRAFFIC_SHORTAGE_SPEED: float = 8.0

## How close a shortage freighter must get before parking as orbit.
const TRAFFIC_SHORTAGE_ARRIVE_DIST: float = 18.0

## Vertical scale when holding at a pad during dock cycle (× orbit height).
const TRAFFIC_DOCK_HOLD_HEIGHT_FACTOR: float = 0.25

## Dock-cycle phase indices (approach / hold / depart).
const TRAFFIC_DOCK_PHASE_APPROACH: int = 0
const TRAFFIC_DOCK_PHASE_HOLD: int = 1
const TRAFFIC_DOCK_PHASE_DEPART: int = 2


## Deterministic non-negative mix (same family as BalanceBoard).
static func mix4(a: int, b: int, c: int, d: int) -> int:
	var x: int = a * HASH_A + b * HASH_B + c * HASH_C + d * HASH_D + HASH_E
	x = (x ^ (x >> 13)) * HASH_C
	x = x ^ (x >> 16)
	return x & HASH_MASK


## Pick index in [0, count) from a deterministic mix.
static func pick_index(count: int, a: int, b: int, c: int, d: int) -> int:
	if count <= 1:
		return 0
	return mix4(a, b, c, d) % count


## True when this kind should fire at (system, step) — pure, no RNG.
static func kind_fires(kind: StringName, system_id: StringName, step: int) -> bool:
	var salt: int = SALT_DISTRESS
	var mod_n: int = FIRE_MOD_DISTRESS
	if kind == KIND_INTERCEPT:
		salt = SALT_INTERCEPT
		mod_n = FIRE_MOD_INTERCEPT
	elif kind == KIND_CUSTOMS:
		salt = SALT_CUSTOMS
		mod_n = FIRE_MOD_CUSTOMS
	var mix: int = mix4(String(system_id).hash(), step, salt, 0)
	return (mix % mod_n) == 0
