class_name BalanceStanding
extends RefCounted

## Standing scale, tiers, attribution, mission, recovery, and trade tunables.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A2–A4
## Source of truth for numbers: docs/reputation_and_standing.md
##
## Stickiness, combat attribution, mission outcomes, personal recovery, light
## trade, and one-hop ripples all live here. Logic reads these; nothing under
## src/ invents magnitudes.

# --- Scale -----------------------------------------------------------------

const STANDING_MIN: float = -100.0
const STANDING_MAX: float = 100.0
const DEFAULT_STANDING: float = 0.0

## Standing at or below this refuses docking when the entity uses the default.
## Hostile and below refuse; the open gap in the reputation doc lives in data.
const DEFAULT_DOCK_REFUSAL_THRESHOLD: float = -50.0

# --- Display tiers (inclusive ranges) --------------------------------------

const TIER_REVERED: StringName = &"revered"
const TIER_ALLIED: StringName = &"allied"
const TIER_FRIENDLY: StringName = &"friendly"
const TIER_NEUTRAL: StringName = &"neutral"
const TIER_UNFRIENDLY: StringName = &"unfriendly"
const TIER_HOSTILE: StringName = &"hostile"
const TIER_HATED: StringName = &"hated"

const TIER_REVERED_MIN: float = 80.0
const TIER_ALLIED_MIN: float = 50.0
const TIER_FRIENDLY_MIN: float = 20.0
const TIER_NEUTRAL_MIN: float = -19.0
const TIER_UNFRIENDLY_MIN: float = -20.0
const TIER_HOSTILE_MIN: float = -50.0
const TIER_HATED_MIN: float = -80.0

## Upper bounds (inclusive) for each tier.
const TIER_REVERED_MAX: float = 100.0
const TIER_ALLIED_MAX: float = 79.0
const TIER_FRIENDLY_MAX: float = 49.0
const TIER_NEUTRAL_MAX: float = 19.0
const TIER_UNFRIENDLY_MAX: float = -49.0
const TIER_HOSTILE_MAX: float = -79.0
const TIER_HATED_MAX: float = -100.0

const KNOWN_TIERS: Array[StringName] = [
	TIER_REVERED,
	TIER_ALLIED,
	TIER_FRIENDLY,
	TIER_NEUTRAL,
	TIER_UNFRIENDLY,
	TIER_HOSTILE,
	TIER_HATED,
]

const TIER_DISPLAY_REVERED: String = "Revered"
const TIER_DISPLAY_ALLIED: String = "Allied"
const TIER_DISPLAY_FRIENDLY: String = "Friendly"
const TIER_DISPLAY_NEUTRAL: String = "Neutral"
const TIER_DISPLAY_UNFRIENDLY: String = "Unfriendly"
const TIER_DISPLAY_HOSTILE: String = "Hostile"
const TIER_DISPLAY_HATED: String = "Hated"

# --- Stickiness (A3) -------------------------------------------------------

## Everyday positives lose most effect at or below this floor.
const STICKY_NEGATIVE_FLOOR: float = -40.0

## Multiply positive deltas by this when standing is at or below the floor.
## Negative deltas always apply at full force.
const STICKY_POSITIVE_FACTOR: float = 0.25

# --- Combat attribution (A3) -----------------------------------------------

## Standing hit for an attributed kill (local system controller).
const COMBAT_KILL_DELTA: float = -12.0

## Contested space: attribute when witness_count is at least this (or evidence).
const ATTRIBUTION_WITNESS_THRESHOLD: int = 1

## Default witness count when the console omits it.
const ATTRIBUTION_DEFAULT_WITNESSES: int = 0

## report_kill / EventBus result dictionary keys.
const REPORT_KEY_ATTRIBUTED: StringName = &"attributed"
const REPORT_KEY_ENTITY_ID: StringName = &"entity_id"
const REPORT_KEY_DELTA: StringName = &"delta"
const REPORT_KEY_REASON: StringName = &"reason"
const REPORT_KEY_SYSTEM_ID: StringName = &"system_id"
const REPORT_KEY_VICTIM_ENTITY_ID: StringName = &"victim_entity_id"

# --- Mission outcomes (A3) -------------------------------------------------

## Default standing deltas when a ContractType does not override.
const MISSION_COMPLETE_DELTA: float = 8.0
const MISSION_FAIL_DELTA: float = -3.0
const MISSION_ABANDON_DELTA: float = -8.0

## ContractType.kind value for Alpha courier work.
const MISSION_KIND_DELIVERY: StringName = &"delivery"

## ContractType.kind value for E1.3 patrol/bounty (kill then turn in).
const MISSION_KIND_BOUNTY: StringName = &"bounty"

## ContractType.kind value for E3.4 smuggle (load cargo, deliver still held).
const MISSION_KIND_SMUGGLE: StringName = &"smuggle"

## Hostiles that must die in the target system before bounty turn-in.
const BOUNTY_KILLS_REQUIRED: int = 1

## Content category directory for mission templates.
const MISSION_CONTENT_CATEGORY: StringName = &"contract_types"

# --- Personal recovery (A4) ------------------------------------------------

## Content category for RecoveryChain resources. Alpha ceiling is 1.
const RECOVERY_CONTENT_CATEGORY: StringName = &"recovery_chains"

## Alpha chain step count bounds (law §5: short chain of further jobs).
const RECOVERY_CHAIN_MIN_STEPS: int = 3
const RECOVERY_CHAIN_MAX_STEPS: int = 5

## Default step deltas when a RecoveryStep does not override (low-rank scale).
const RECOVERY_DEFAULT_PERSONAL_DELTA: float = 10.0
const RECOVERY_DEFAULT_ENTITY_DELTA: float = 2.0

## Authored low-rank deniable first job (trust test — tiny Entity movement).
const RECOVERY_DENIABLE_PERSONAL_DELTA: float = 12.0
const RECOVERY_DENIABLE_ENTITY_DELTA: float = 2.0

## Later low-rank steps (still small Entity movement; slightly larger late).
const RECOVERY_LOW_STEP2_PERSONAL_DELTA: float = 10.0
const RECOVERY_LOW_STEP2_ENTITY_DELTA: float = 2.0
const RECOVERY_LOW_STEP3_PERSONAL_DELTA: float = 8.0
const RECOVERY_LOW_STEP3_ENTITY_DELTA: float = 3.0
const RECOVERY_LOW_STEP4_PERSONAL_DELTA: float = 8.0
const RECOVERY_LOW_STEP4_ENTITY_DELTA: float = 4.0

## Mid-rank reference magnitudes (not used by Alpha's low-rank chain content).
## Rank influence proof: mid deniable Entity delta is larger than low.
const RECOVERY_MID_DENIABLE_ENTITY_DELTA: float = 4.0

## Favor: small personal standing gift to bootstrap toward Friendly.
const RECOVERY_FAVOR_PERSONAL_DELTA: float = 5.0

## Fail / abandon personal hits while a recovery step is active.
const RECOVERY_FAIL_PERSONAL_DELTA: float = -2.0
const RECOVERY_ABANDON_PERSONAL_DELTA: float = -6.0

## Betrayal: close the Person, dump personal standing, mild Entity hit.
const RECOVERY_BETRAYAL_PERSONAL_DELTA: float = -40.0
const RECOVERY_BETRAYAL_ENTITY_DELTA: float = -5.0

## Close reasons (tags for close_person / save).
const RECOVERY_CLOSE_REASON_BETRAYAL: StringName = &"betrayal"
const RECOVERY_CLOSE_REASON_NONE: StringName = &""

## Minimum personal successes before follow-on recovery (history flag).
## Alpha §5 bootstrap: the deniable first job needs Friendly only; completing
## it records success so follow-ons satisfy this count.
const RECOVERY_MIN_SUCCESS_FOR_FOLLOW_ON: int = 1

# --- Legal trade (A3, light) -----------------------------------------------

## Small standing gain from one legal trade action.
const TRADE_LEGAL_DELTA: float = 1.0

## Soft cap: trade alone cannot push standing above this (Neutral band top).
const TRADE_STANDING_SOFT_CAP: float = 19.0

# --- One-hop ripple (A3) ---------------------------------------------------

## Allied / subsidiary / member_of: fraction of source applied delta (same sign).
const RIPPLE_ALLY_FRACTION: float = 0.25

## Rival / enemy: fraction of source applied delta, inverted.
const RIPPLE_RIVAL_FRACTION: float = 0.15

## Absolute cap on any single ripple delta (cannot alone cross a major tier).
const RIPPLE_MAX_ABS: float = 5.0

# --- Mutation reasons (StringName tags for apply_* / logs) -----------------

const REASON_COMBAT_KILL: StringName = &"combat_kill"
const REASON_MISSION_COMPLETE: StringName = &"mission_complete"
const REASON_MISSION_FAIL: StringName = &"mission_fail"
const REASON_MISSION_ABANDON: StringName = &"mission_abandon"
const REASON_TRADE_LEGAL: StringName = &"trade_legal"
const REASON_RIPPLE: StringName = &"ripple"
const REASON_RECOVERY_COMPLETE: StringName = &"recovery_complete"
const REASON_RECOVERY_FAIL: StringName = &"recovery_fail"
const REASON_RECOVERY_ABANDON: StringName = &"recovery_abandon"
const REASON_RECOVERY_BETRAYAL: StringName = &"recovery_betrayal"
const REASON_RECOVERY_FAVOR: StringName = &"recovery_favor"
## E3.2: emergency loan grace expired (Free Haulers Entity only).
const REASON_DEBT_GRACE_EXPIRED: StringName = &"debt_grace_expired"

## E3.3: dock inspection found jurisdictional contraband for the controller.
const REASON_CONTRABAND: StringName = &"contraband"

# --- Debt grace standing hit (E3.2) ----------------------------------------
# Magnitude lives here (standing law). Wallet only requests the write via
# StandingService. No dock ban invent; no ship loss.

## Free Haulers standing delta when grace docks are exhausted with unpaid debt.
## Mild-hard Unfriendly lean from Neutral; not Hostile-floor.
const DEBT_GRACE_EXPIRED_DELTA: float = -12.0

# --- Contraband dock inspection (E3.3 / D3) --------------------------------
# Magnitude lives here. CargoService requests the write via StandingService.
# Per-Entity jurisdiction only — not a global ban. No new tiers.

## Controller standing hit when docked with restricted goods in hold.
## Mild Unfriendly lean from Neutral; not Hostile-floor (same band as debt).
const CONTRABAND_STANDING_DELTA: float = -10.0

# --- Status moment / HUD copy ----------------------------------------------

## HUD standing line: tier display name, then controller display name.
const STATUS_LINE_FORMAT: String = "STANDING  %s — %s"

## When system/station has no controller entity.
const STATUS_UNCONTROLLED_LABEL: String = "Uncontrolled"

## Dock prompt when standing blocks: tier display, entity display.
const DOCK_REFUSED_PROMPT_FORMAT: String = "DOCKING REFUSED — %s (%s)"

## Docked status with standing: station name, tier, entity.
const DOCKED_STATUS_FORMAT: String = "DOCKED — %s · %s — %s"

## Status moment kinds carried on EventBus.on_status_moment.
const STATUS_KIND_SYSTEM: StringName = &"system"
const STATUS_KIND_STATION: StringName = &"station"

# --- Kill attribution HUD feedback (E2.3) ----------------------------------

## Temporary toast after an attributed kill. Arg = local controller display name.
const HUD_KILL_ATTRIBUTED_FORMAT: String = "Kill recorded — %s standing fell."

## Temporary toast when the kill was not attributed (no standing change).
const HUD_KILL_UNATTRIBUTED: String = "Kill not recorded — no standing change."

## How long the kill toast stays on the HUD (seconds).
const HUD_KILL_TOAST_SECONDS: float = 4.0

# --- Save section keys -----------------------------------------------------

const SAVE_SECTION_KEY: StringName = &"standing"
const SAVE_KEY_ENTITIES: StringName = &"entities"
const SAVE_KEY_PEOPLE: StringName = &"people"
## Optional A4 maps inside the standing section (no envelope version bump).
const SAVE_KEY_PERSON_SUCCESS: StringName = &"person_success"
const SAVE_KEY_PERSON_CLOSED: StringName = &"person_closed"
const SAVE_KEY_RECOVERY_PROGRESS: StringName = &"recovery_progress"

# --- Console ---------------------------------------------------------------

## `standing show <kind> <id>` and `standing entity|person <id> <value>` each
## take this many tokens after the verb.
const CONSOLE_PAIR_ARG_COUNT: int = 2

## `kill <system_id>` minimum args after the verb.
const CONSOLE_KILL_MIN_ARGS: int = 1

## Optional kill args: witnesses, evidence, victim → max tokens after verb.
const CONSOLE_KILL_MAX_ARGS: int = 4

## Arg counts (size of args array) when optional kill tokens are present.
const CONSOLE_KILL_SIZE_WITH_WITNESSES: int = 2
const CONSOLE_KILL_SIZE_WITH_EVIDENCE: int = 3
const CONSOLE_KILL_SIZE_WITH_VICTIM: int = 4

## Indices into kill args (0 = system_id).
const CONSOLE_KILL_INDEX_SYSTEM: int = 0
const CONSOLE_KILL_INDEX_WITNESSES: int = 1
const CONSOLE_KILL_INDEX_EVIDENCE: int = 2
const CONSOLE_KILL_INDEX_VICTIM: int = 3

## `trade legal <entity_id>` tokens after the verb.
const CONSOLE_TRADE_LEGAL_ARGS: int = 2

## Index of the entity id in `trade legal <entity_id>`.
const CONSOLE_TRADE_ENTITY_INDEX: int = 1

## `mission accept <id>` tokens after the verb (action + id).
const CONSOLE_MISSION_ACCEPT_ARGS: int = 2

## Index of the template id in `mission accept <id>` args.
const CONSOLE_MISSION_ID_INDEX: int = 1

## Evidence console token truthy values parse as true when equal to these.
const CONSOLE_EVIDENCE_TRUE: String = "1"
const CONSOLE_EVIDENCE_ON: String = "on"
const CONSOLE_EVIDENCE_YES: String = "yes"
const CONSOLE_EVIDENCE_TRUE_WORD: String = "true"

## Station menu: accept job button label.
const STATION_ACCEPT_JOB_LABEL: String = "Accept courier job"

## Station menu: accept job with destination (display name).
const STATION_ACCEPT_JOB_TO_FORMAT: String = "Accept job → %s"

## Station menu: accept bounty (no system name fallback).
const STATION_ACCEPT_BOUNTY_LABEL: String = "Accept bounty"

## Station menu: accept bounty with target system display name.
const STATION_ACCEPT_BOUNTY_FORMAT: String = "Accept bounty — clear %s"

## Station menu: accept smuggle (no destination fallback).
const STATION_ACCEPT_SMUGGLE_LABEL: String = "Accept smuggle"

## Station menu: accept smuggle with destination display name.
const STATION_ACCEPT_SMUGGLE_FORMAT: String = "Accept smuggle → %s"

## Station menu: talk to recovery contact when a step is available.
const STATION_RECOVERY_TALK_FORMAT: String = "Talk to %s"

## HUD active mission line: template name, destination display name.
const HUD_MISSION_FORMAT: String = "JOB  %s → %s"

## HUD when a mission has no destination station set.
const HUD_MISSION_NO_DEST_FORMAT: String = "JOB  %s"

## HUD bounty objective (kill still outstanding); arg = system display name.
const HUD_MISSION_BOUNTY_FORMAT: String = "BOUNTY  clear hostiles in %s"

## HUD bounty ready for turn-in; arg = destination station display name.
const HUD_MISSION_BOUNTY_READY_FORMAT: String = "BOUNTY  turn in at %s"

## HUD smuggle active; args = commodity display, destination display.
const HUD_MISSION_SMUGGLE_FORMAT: String = "SMUGGLE  %s → %s"

## HUD smuggle without destination (should not ship in content).
const HUD_MISSION_SMUGGLE_NO_DEST_FORMAT: String = "SMUGGLE  %s"

## `recovery accept` / `favor` arg counts (tokens after the verb).
const CONSOLE_RECOVERY_ACCEPT_ARGS: int = 2
const CONSOLE_FAVOR_ARGS: int = 1

## Index of person id in `recovery accept <person_id>` args.
const CONSOLE_RECOVERY_PERSON_INDEX: int = 1

## Index of person id in `favor <person_id>` args.
const CONSOLE_FAVOR_PERSON_INDEX: int = 0

## Console feedback formats.
const CONSOLE_KILL_ATTRIBUTED_FORMAT: String = "Kill attributed in %s → %s standing %s (delta %s)."
const CONSOLE_KILL_UNATTRIBUTED_FORMAT: String = "Kill in %s not attributed."
const CONSOLE_MISSION_ACCEPTED_FORMAT: String = "Accepted mission %s (%s)."
const CONSOLE_MISSION_OUTCOME_FORMAT: String = "Mission %s %s → %s standing %s (delta %s)."
const CONSOLE_TRADE_FORMAT: String = "Legal trade with %s → standing %s (delta %s)."
const CONSOLE_TRADE_CAPPED_FORMAT: String = "Legal trade with %s → no gain (at/above soft cap %s)."
const CONSOLE_RECOVERY_ACCEPTED_FORMAT: String = "Accepted recovery %s step %s with %s."
const CONSOLE_RECOVERY_OUTCOME_FORMAT: String = "Recovery %s %s → p %s (Δ %s) e %s (Δ %s)."
const CONSOLE_RECOVERY_BETRAY_FORMAT: String = "Betrayed %s — closed. p %s (Δ %s); e %s (Δ %s)."
const CONSOLE_FAVOR_FORMAT: String = "Favor with %s → personal standing %s (delta %s)."
const CONSOLE_FAVOR_CLOSED_FORMAT: String = "Favor refused — %s is closed (%s)."

## Plain-English recovery status / list lines (console).
const CONSOLE_RECOVERY_NO_ACTIVE: String = "No job in progress."
## Args: job display name, person display name.
const CONSOLE_RECOVERY_JOB_AVAILABLE: String = 'JOB AVAILABLE: "%s" from %s.'
## Arg: person id for the accept command.
const CONSOLE_RECOVERY_ACCEPT_HINT: String = "Type: recovery accept %s"
## Args: person display, Friendly threshold, current personal standing.
const CONSOLE_RECOVERY_NOT_YET: String = "No job from %s yet (need personal >= %s; have %s)."
const CONSOLE_RECOVERY_CLOSED_LINE: String = "Route with %s is closed - no recovery."
const CONSOLE_RECOVERY_CHAIN_DONE: String = "Chain with %s is finished (%d/%d steps)."
const CONSOLE_RECOVERY_PROGRESS_LINE: String = "  Progress on %s: %d of %d steps done."
const CONSOLE_RECOVERY_ACTIVE_LINE: String = 'IN PROGRESS: "%s" with %s.'
const CONSOLE_RECOVERY_COMPLETE_HINT: String = "Type: recovery complete"
const CONSOLE_RECOVERY_LIST_HEADER: String = "Recovery contacts:"
const CONSOLE_RECOVERY_LIST_OFFER: String = '  %s - "%s" available (id %s)'
const CONSOLE_RECOVERY_LIST_GATED: String = "  %s - no offer yet (id %s)"
const CONSOLE_RECOVERY_LIST_CLOSED: String = "  %s - CLOSED (id %s)"
const CONSOLE_RECOVERY_LIST_DONE: String = "  %s - chain complete (id %s)"


## Plain-language attributed-kill line for HUD / tests. Pure formatter.
static func format_kill_attributed(entity_display_name: String) -> String:
	var name: String = entity_display_name.strip_edges()
	if name.is_empty():
		name = STATUS_UNCONTROLLED_LABEL
	return HUD_KILL_ATTRIBUTED_FORMAT % name


## Plain-language unattributed-kill line for HUD / tests. Pure formatter.
static func format_kill_unattributed() -> String:
	return HUD_KILL_UNATTRIBUTED
