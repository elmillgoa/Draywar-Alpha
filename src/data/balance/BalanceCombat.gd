class_name BalanceCombat
extends RefCounted

## Thin combat tunables — Path C B4 + Combat Fairness.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B4
##
## One weapon class, one hostile type. Both sides fire travel bolts so motion
## can dodge. Session combat only. Standing via AttributionService.

# --- Groups / identity -----------------------------------------------------

## Scene-tree group for combat hostiles (not ambient NpcTraffic).
## Bounty, combat AI, combat lock prompt. Pirates only.
const GROUP_HOSTILE: StringName = &"hostile_npc"

## Scene-tree group for lockable/damageable ships (hostiles + traffic).
## Tab lock, player bolts, and mutual impact use this — not GROUP_HOSTILE alone.
const GROUP_LOCKABLE: StringName = &"lockable_ship"

## Scene-tree group for collidable impact bodies (station/gate/traffic/hostile).
const GROUP_IMPACT_BODY: StringName = &"impact_body"

## Meta key storing mass class StringName on colliders (E6.1).
const META_MASS_CLASS: StringName = &"mass_class"

## Victim Entity tag on kill reports (attribution target is still the
## local system controller when one holds the system — Reach in alpha).
const VICTIM_ENTITY_ID: StringName = &"entity_free_haulers"

# --- Ship roles (E6.3 lock/HUD — civilian / patrol / pirate) ----------------

const ROLE_CIVILIAN: StringName = &"civilian"
const ROLE_PATROL: StringName = &"patrol"
const ROLE_PIRATE: StringName = &"pirate"

## Lock HUD display strings (source of truth for role legibility).
const ROLE_DISPLAY_CIVILIAN: String = "Civilian"
const ROLE_DISPLAY_PATROL: String = "Patrol"
const ROLE_DISPLAY_PIRATE: String = "Pirate"

## Ambient traffic hull HP by role (player bolts ~40; light freighter dies faster).
const TRAFFIC_HULL_HP_CIVILIAN: float = 80.0
const TRAFFIC_HULL_HP_PATROL: float = 120.0

## Legacy alias — civilian freighter default.
const TRAFFIC_HULL_HP: float = TRAFFIC_HULL_HP_CIVILIAN

## Fraction of ambient traffic that spawns as non-hostile patrol boats.
## Patrolled: mixed patrol + civilian. Contested: mostly civilian. Lawless: none.
const TRAFFIC_PATROL_SHARE_PATROLLED: float = 0.375
const TRAFFIC_PATROL_SHARE_CONTESTED: float = 0.125
const TRAFFIC_PATROL_SHARE_LAWLESS: float = 0.0

## Unshaded colours for traffic roles (patrol reads as authority, civilian soft).
const COLOR_TRAFFIC_CIVILIAN: Color = Color(0.55, 0.52, 0.48)
const COLOR_TRAFFIC_PATROL: Color = Color(0.28, 0.48, 0.82)
const COLOR_TRAFFIC_HIT_FLASH: Color = Color(1.0, 0.9, 0.75)

# --- Impact mass classes / damage (E6.1 Package A) -------------------------

const MASS_CLASS_STATION: StringName = &"station"
const MASS_CLASS_GATE: StringName = &"gate"
const MASS_CLASS_ROCK: StringName = &"rock"
const MASS_CLASS_HOSTILE: StringName = &"hostile"
const MASS_CLASS_TRAFFIC_LIGHT: StringName = &"traffic_light"
const MASS_CLASS_TRAFFIC_HEAVY: StringName = &"traffic_heavy"

## Base impact damage before mass × speed factors.
const IMPACT_BASE: float = 12.0

## Closing speed (m/s) below this → soft bump only, no hull damage.
const IMPACT_SPEED_THRESHOLD: float = 8.0

## Reference closing speed above threshold for speed_factor ≈ 1.0.
const IMPACT_SPEED_REF: float = 20.0

## Per-pair contact cooldown so one scrape does not multi-hit every frame.
const IMPACT_COOLDOWN_SECONDS: float = 0.35

## Mass class multipliers (player damage when ramming that class).
const IMPACT_MASS_FACTOR: Dictionary = {
	MASS_CLASS_STATION: 3.5,
	MASS_CLASS_GATE: 3.0,
	MASS_CLASS_ROCK: 1.5,
	MASS_CLASS_HOSTILE: 1.2,
	MASS_CLASS_TRAFFIC_LIGHT: 0.7,
	MASS_CLASS_TRAFFIC_HEAVY: 1.8,
}

## When the player rams another damageable ship, that ship takes impact as if
## hit by this class (hauler / freighter mass — no separate player mass class).
const IMPACT_PLAYER_AS_MASS_CLASS: StringName = MASS_CLASS_TRAFFIC_HEAVY

# --- Input -----------------------------------------------------------------

## Fire action registered by FlightInput (Space + left mouse).
const ACTION_FIRE: StringName = &"fire_weapon"
const FIRE_KEY: Key = KEY_SPACE
const FIRE_MOUSE_BUTTON: MouseButton = MOUSE_BUTTON_LEFT

## Target lock cycle (Tab). Closest first, then next furthest, wrap.
const ACTION_TARGET_LOCK: StringName = &"target_lock"
const TARGET_LOCK_KEY: Key = KEY_TAB

## Max distance to include a hostile in the lock cycle (metres).
## Raised E6.1 with stretched layout so bounty prey remains lockable across pad→lane.
const TARGET_LOCK_RANGE: float = 800.0

# --- Player weapon (bolts — no auto-hit on lock) ----------------------------
# Defaults / no-hull fallback. Live play reads active Hull weapon fields (E2.4).
# Hauler content is slightly softer than these so fighter baseline wins math.

## Seconds between player shots.
const PLAYER_FIRE_COOLDOWN: float = 0.28

## Bolt travel speed (m/s). Lead pip uses this; beginner ship is not hitscan.
const PROJECTILE_SPEED: float = 280.0

## Bolt lifetime (seconds) before it fizzles.
const PROJECTILE_LIFETIME: float = 1.4

## Max range derived from speed * life (used for UI / ranking).
const HITSCAN_RANGE: float = 392.0

## Damage applied to a hostile on a successful bolt hit.
const PLAYER_WEAPON_DAMAGE: float = 40.0

# --- Fighter baseline (mirrored into hull_fighter.tres content — E2.5) ------
# Pure balance numbers so Hauler vs hard profile TTK/DPS can be asserted without
# spawning a Fighter scene. Content `hull_fighter` must match these weapons.

## Fighter baseline bolt damage (higher than Hauler content).
const FIGHTER_BASELINE_WEAPON_DAMAGE: float = 50.0

## Fighter baseline seconds between shots (faster than Hauler content).
const FIGHTER_BASELINE_WEAPON_COOLDOWN: float = 0.22

## Fighter baseline bolt travel speed (m/s).
const FIGHTER_BASELINE_PROJECTILE_SPEED: float = 320.0

## Fighter baseline hold capacity (near-zero; grain routes refuse).
const FIGHTER_BASELINE_CARGO_CAPACITY: int = 1

## Bolt visual size.
const PROJECTILE_RADIUS: float = 0.45
const PROJECTILE_LENGTH: float = 2.8
const COLOR_PROJECTILE: Color = Color(1.0, 0.85, 0.25)

## Lead intercept solver iterations (classic space-combat lead pip).
const LEAD_SOLVE_ITERATIONS: int = 4

# --- Hostile profiles (E2.1) -----------------------------------------------
## Two fight shapes: glass-cannon skirmisher vs hard gunboat. Legacy HOSTILE_*
## constants match the default (skirmisher) so older tests keep working.

const PROFILE_SKIRMISHER: StringName = &"skirmisher"
const PROFILE_GUNBOAT: StringName = &"gunboat"
const PROFILE_DEFAULT: StringName = PROFILE_SKIRMISHER

## Bounty ensure uses the softer profile so Hauler-era bounties stay completable.
const BOUNTY_HOSTILE_PROFILE: StringName = PROFILE_SKIRMISHER

## Ambient spawn by policing: contested → skirmisher, lawless → gunboat.
## One session that visits both contested and lawless meets both shapes.
const AMBIENT_PROFILE_CONTESTED: StringName = PROFILE_SKIRMISHER
const AMBIENT_PROFILE_LAWLESS: StringName = PROFILE_GUNBOAT

## Profile dictionary keys (String for Dictionary access).
const PROFILE_KEY_DISPLAY_NAME: String = "display_name"
const PROFILE_KEY_HP: String = "hp"
const PROFILE_KEY_DAMAGE: String = "damage"
const PROFILE_KEY_FIRE_COOLDOWN: String = "fire_cooldown"
const PROFILE_KEY_ENGAGE_RANGE: String = "engage_range"
const PROFILE_KEY_TURN_RATE: String = "turn_rate"
const PROFILE_KEY_MOVE_SPEED: String = "move_speed"
const PROFILE_KEY_HOLD_MIN: String = "hold_distance_min"
const PROFILE_KEY_HOLD_MAX: String = "hold_distance_max"
const PROFILE_KEY_JINK_SPEED: String = "jink_speed"
const PROFILE_KEY_JINK_FREQ: String = "jink_freq"
const PROFILE_KEY_COLOR: String = "color"
const PROFILE_KEY_COLOR_ACCENT: String = "color_accent"
const PROFILE_KEY_COLOR_FIN: String = "color_fin"

## Full profile table. Numbers are the source of truth; HOSTILE_* mirror default.
const HOSTILE_PROFILES: Dictionary = {
	PROFILE_SKIRMISHER:
	{
		PROFILE_KEY_DISPLAY_NAME: "Skirmisher",
		PROFILE_KEY_HP: 100.0,
		PROFILE_KEY_DAMAGE: 8.0,
		PROFILE_KEY_FIRE_COOLDOWN: 1.4,
		PROFILE_KEY_ENGAGE_RANGE: 110.0,
		PROFILE_KEY_TURN_RATE: 1.4,
		PROFILE_KEY_MOVE_SPEED: 18.0,
		PROFILE_KEY_HOLD_MIN: 35.0,
		PROFILE_KEY_HOLD_MAX: 55.0,
		PROFILE_KEY_JINK_SPEED: 12.0,
		PROFILE_KEY_JINK_FREQ: 2.0,
		PROFILE_KEY_COLOR: Color(0.92, 0.22, 0.18),
		PROFILE_KEY_COLOR_ACCENT: Color(1.0, 0.45, 0.2),
		PROFILE_KEY_COLOR_FIN: Color(0.75, 0.12, 0.1),
	},
	PROFILE_GUNBOAT:
	{
		PROFILE_KEY_DISPLAY_NAME: "Gunboat",
		PROFILE_KEY_HP: 200.0,
		PROFILE_KEY_DAMAGE: 14.0,
		PROFILE_KEY_FIRE_COOLDOWN: 2.2,
		PROFILE_KEY_ENGAGE_RANGE: 150.0,
		PROFILE_KEY_TURN_RATE: 0.85,
		PROFILE_KEY_MOVE_SPEED: 10.0,
		PROFILE_KEY_HOLD_MIN: 50.0,
		PROFILE_KEY_HOLD_MAX: 75.0,
		PROFILE_KEY_JINK_SPEED: 7.0,
		PROFILE_KEY_JINK_FREQ: 1.2,
		PROFILE_KEY_COLOR: Color(0.72, 0.14, 0.2),
		PROFILE_KEY_COLOR_ACCENT: Color(0.95, 0.35, 0.18),
		PROFILE_KEY_COLOR_FIN: Color(0.55, 0.08, 0.12),
	},
}

# --- Hostile (legacy aliases = skirmisher / PROFILE_DEFAULT) ---------------

## Hostile hull points (dies at 0). ~3 player hits at PLAYER_WEAPON_DAMAGE.
const HOSTILE_HP: float = 100.0

## Damage applied to player condition per hostile bolt hit.
const HOSTILE_DAMAGE: float = 8.0

## Seconds between hostile shots while engaged (slightly fast to offset misses).
const HOSTILE_FIRE_COOLDOWN: float = 1.4

## Distance at which the hostile turns and fires on the player (metres).
const ENGAGE_RANGE: float = 110.0

## Hostile turn rate while tracking the player (radians / second).
const HOSTILE_TURN_RATE: float = 1.4

## Hostile closing speed while engaged (m/s).
const HOSTILE_MOVE_SPEED: float = 18.0

## Hold-band centre (legacy alias; prefer MIN/MAX).
const HOSTILE_HOLD_DISTANCE: float = 45.0

## Jink within this band instead of ramming the player.
const HOSTILE_HOLD_DISTANCE_MIN: float = 35.0
const HOSTILE_HOLD_DISTANCE_MAX: float = 55.0

## Lateral weave speed while in the hold band (m/s).
const HOSTILE_JINK_SPEED: float = 12.0

## Angular rate for sin jink weave (radians-ish scale on _jink_time).
const HOSTILE_JINK_FREQ: float = 2.0

## Full hull percent for HUD defaults.
const HULL_PERCENT_FULL: int = 100

## Hostile travel bolt.
const HOSTILE_PROJECTILE_SPEED: float = 220.0
const HOSTILE_PROJECTILE_LIFETIME: float = 1.2
const HOSTILE_PROJECTILE_RADIUS: float = 0.4
const HOSTILE_PROJECTILE_HIT_RADIUS_SCALE: float = 2.5
const HOSTILE_PROJECTILE_LENGTH: float = 2.4
const COLOR_HOSTILE_PROJECTILE: Color = Color(1.0, 0.35, 0.28)

## Nose must face the player at least this much (dot of forward vs to-player).
const HOSTILE_FIRE_CONE_DOT: float = 0.65

## Player CharacterBody3D hurtbox sphere radius (metres).
const PLAYER_HURTBOX_RADIUS: float = 2.8

## Brief material / HUD flash after a hit (seconds).
const HIT_FLASH_SECONDS: float = 0.12

## Red-tinted capsule silhouette (skirmisher / default).
const COLOR_HOSTILE: Color = Color(0.92, 0.22, 0.18)
const COLOR_HOSTILE_ACCENT: Color = Color(1.0, 0.45, 0.2)
const COLOR_HOSTILE_HIT_FLASH: Color = Color(1.0, 0.85, 0.8)
const COLOR_HOSTILE_FIN: Color = Color(0.75, 0.12, 0.1)

## Capsule mesh size.
const HOSTILE_CAPSULE_RADIUS: float = 1.6
const HOSTILE_CAPSULE_HEIGHT: float = 5.5
const HOSTILE_CAPSULE_RINGS: int = 8
const HOSTILE_CAPSULE_RADIAL: int = 12

## Accent box on the nose so the hostile reads as a fighter, not traffic.
const HOSTILE_NOSE_SIZE: Vector3 = Vector3(0.9, 0.9, 2.2)
const HOSTILE_NOSE_Z: float = -2.4

## Large swept fins — threat silhouette vs thin traffic fin (E1.1).
const HOSTILE_FIN_SIZE: Vector3 = Vector3(4.8, 0.22, 1.8)
const HOSTILE_FIN_OFFSET: Vector3 = Vector3(0.0, 0.0, 0.6)

## Collision shape (slightly larger than mesh for fair hits).
const HOSTILE_HITBOX_RADIUS: float = 2.2
const HOSTILE_HITBOX_HEIGHT: float = 6.0

## Kill flash before free (expanding unshaded sphere — E1.1).
const KILL_FLASH_RADIUS: float = 1.8
const KILL_FLASH_HEIGHT_FACTOR: float = 2.0
const KILL_FLASH_END_SCALE: float = 4.5
const KILL_FLASH_DURATION: float = 0.38
const KILL_FLASH_RADIAL_SEGMENTS: int = 8
const KILL_FLASH_RINGS: int = 4
const COLOR_KILL_FLASH: Color = Color(1.0, 0.72, 0.35)

# --- Spawn / encounter rules (E2.2) ----------------------------------------

## Hard ceiling on live combat hostiles in one system (E2 cap). Ambient spawn
## and bounty ensure refuse new spawns at this count.
const MAX_CONCURRENT_HOSTILES: int = 3

## Ambient combat hostiles placed at system build by policing tier.
## Patrolled stays zero; lawless is denser than contested.
const AMBIENT_HOSTILE_COUNT_PATROLLED: int = 0
const AMBIENT_HOSTILE_COUNT_CONTESTED: int = 1
const AMBIENT_HOSTILE_COUNT_LAWLESS: int = 2

## Legacy / contested mid-lane ambient offsets (E6.1 ecology).
## Contested: mid-system / lane / belt — far from undock pad, not gate-camping.
## Length must exceed STATION_SAFE_RADIUS. SPAWN_OFFSET aliases primary for tests.
const SPAWN_OFFSET_CONTESTED_PRIMARY: Vector3 = Vector3(700.0, 20.0, 400.0)
const SPAWN_OFFSET_CONTESTED_SECONDARY: Vector3 = Vector3(-520.0, 25.0, 580.0)
const SPAWN_OFFSET_CONTESTED_TERTIARY: Vector3 = Vector3(380.0, 18.0, -560.0)

## Lawless ambient: nearer the gate line than contested (meaner approach feel).
const SPAWN_OFFSET_LAWLESS_PRIMARY: Vector3 = Vector3(950.0, 20.0, -650.0)
const SPAWN_OFFSET_LAWLESS_SECONDARY: Vector3 = Vector3(1000.0, 18.0, -900.0)
const SPAWN_OFFSET_LAWLESS_TERTIARY: Vector3 = Vector3(850.0, 22.0, -700.0)

## Backward-compatible aliases → contested table (tests / single-offset callers).
const SPAWN_OFFSET: Vector3 = SPAWN_OFFSET_CONTESTED_PRIMARY
const SPAWN_OFFSET_SECONDARY: Vector3 = SPAWN_OFFSET_CONTESTED_SECONDARY
const SPAWN_OFFSET_TERTIARY: Vector3 = SPAWN_OFFSET_CONTESTED_TERTIARY

## How many named ambient offsets exist (index wraps if count exceeds this).
const AMBIENT_SPAWN_OFFSET_SLOT_COUNT: int = 3

## Offset from the player (or request point) when a bounty needs a live hostile
## and none remain. Length must exceed STATION_SAFE_RADIUS so undock airspace
## stays clear; ensure_hostile_near still rechecks every station safe radius.
const BOUNTY_SPAWN_OFFSET: Vector3 = Vector3(320.0, 16.0, -200.0)

## Extra push past STATION_SAFE_RADIUS when the first offset still lands in a
## station bubble (secondary docks / tight geometry).
const BOUNTY_SPAWN_SAFE_MARGIN: float = 40.0

## No hostile fire / engage inside this radius of any station (safe undock).
## Raised E6.1 with larger station pads / secondary dock spacing.
const STATION_SAFE_RADIUS: float = 180.0

## Ambient hostiles must not sit inside this radius of any gate (patrolled assert;
## contested preferred mid-lane also clears it). Centre-based metres.
const GATE_ENCOUNTER_APPROACH_RADIUS: float = 120.0

## After undock, hostiles wait this long before they may fire (seconds).
const UNDOCK_GRACE_SECONDS: float = 5.0

## Patrolled / government systems do not spawn combat hostiles (safe undock).
## Contested and lawless systems place ambient hostiles per count constants.
const SPAWN_IN_PATROLLED: bool = false
const SPAWN_IN_CONTESTED: bool = true
const SPAWN_IN_LAWLESS: bool = true

# --- Beam flash (visual only — muzzle VFX, not damage) ---------------------

const BEAM_WIDTH: float = 0.18
const BEAM_DURATION: float = 0.08
## Midpoint blend along the beam (from → to) for MeshInstance placement.
const BEAM_MIDPOINT: float = 0.5
## Short muzzle flash length (metres); damage is from travel projectiles.
const MUZZLE_BEAM_LENGTH: float = 6.0
const COLOR_BEAM: Color = Color(1.0, 0.92, 0.35)
const COLOR_HOSTILE_BEAM: Color = Color(1.0, 0.35, 0.25)

# --- Attribution defaults for thin play kills ------------------------------

## Evidence trail for ambient combat kills (none by default — standing law §7).
## Witness count is live ambient NpcTraffic ship count (not a fixed constant).
const KILL_EVIDENCE: bool = false

# --- HUD -------------------------------------------------------------------

## Shown while a combat hostile exists and the ship is free-flying.
const HUD_COMBAT_PROMPT: String = "TAB LOCK · AIM LEAD · STRAFE TO DODGE · FIRE"

## Locked target readout (name + range metres + live hull percent).
const HUD_TARGET_LOCK_FORMAT: String = "LOCK  %s  %dm  HULL %d%%"
const HUD_TARGET_LOCK_NONE: String = "LOCK  —"
const TARGET_LOCK_DEFAULT_NAME: String = "Hostile"

## Fail state when hull condition hits zero undocked.
const HUD_CRIPPLED_MESSAGE: String = "SHIP CRIPPLED — DOCK FOR REPAIR"

## Locked hostile accent brighten (0..1 mix toward white).
const LOCK_HIGHLIGHT_LIGHTEN: float = 0.45

## Fail-state console / status line (optional string reuse).
const FAIL_STATE_MESSAGE: String = "Ship crippled. Dock and repair to fly again."

## Player hull condition flash when hit.
const COLOR_CONDITION_HIT_FLASH: Color = Color(1.0, 0.25, 0.2)

# --- Combat HUD: reticle, lock brackets, lead pip --------------------------

## Aim reticle (where shots go — mouse).
const RETICLE_RADIUS: float = 10.0
const RETICLE_GAP: float = 4.0
const RETICLE_ARM: float = 8.0
const RETICLE_LINE_WIDTH: float = 2.0
const COLOR_RETICLE: Color = Color(0.95, 0.95, 0.85, 0.9)

## World-space lock brackets around locked target (corner ticks).
const LOCK_BRACKET_HALF: float = 22.0
const LOCK_BRACKET_CORNER: float = 10.0
const LOCK_BRACKET_WIDTH: float = 2.0
const COLOR_LOCK_BRACKET: Color = Color(0.35, 0.85, 1.0, 0.95)

## Lead pip (where to aim so a bolt arrives as the target does).
const LEAD_PIP_HALF: float = 7.0
const LEAD_PIP_WIDTH: float = 2.0
const COLOR_LEAD_PIP: Color = Color(1.0, 0.35, 0.25, 0.95)

## Hide combat overlays while docked / no camera.
const COMBAT_HUD_MIN_DEPTH: float = 0.5

## Aim reticle arc segment count (circle smoothness).
const RETICLE_ARC_SEGMENTS: int = 32

## Projectile collision sphere scale vs visual radius.
const PROJECTILE_HIT_RADIUS_SCALE: float = 2.0


## Format locked-target HUD line (name, metres, hull 0–100). Pure for tests.
static func format_target_lock_line(label: String, distance_m: float, hull_percent: int) -> String:
	return (
		HUD_TARGET_LOCK_FORMAT
		% [label, int(roundf(distance_m)), clampi(hull_percent, 0, HULL_PERCENT_FULL)]
	)


## Lock HUD role string (civilian / patrol / pirate). Unknown → empty.
static func role_display_name(role_id: StringName) -> String:
	if role_id == ROLE_CIVILIAN:
		return ROLE_DISPLAY_CIVILIAN
	if role_id == ROLE_PATROL:
		return ROLE_DISPLAY_PATROL
	if role_id == ROLE_PIRATE:
		return ROLE_DISPLAY_PIRATE
	return ""


## Traffic hull max for a role (unknown → civilian).
static func traffic_hull_hp_for_role(role_id: StringName) -> float:
	if role_id == ROLE_PATROL:
		return TRAFFIC_HULL_HP_PATROL
	return TRAFFIC_HULL_HP_CIVILIAN


## Patrol share of ambient traffic for a policing tag (0..1).
static func traffic_patrol_share_for_policing(policing: StringName) -> float:
	if policing == &"patrolled":
		return TRAFFIC_PATROL_SHARE_PATROLLED
	if policing == &"contested":
		return TRAFFIC_PATROL_SHARE_CONTESTED
	if policing == &"lawless":
		return TRAFFIC_PATROL_SHARE_LAWLESS
	return TRAFFIC_PATROL_SHARE_CONTESTED


## How many of `total` ambient slots should be patrol boats (rounded).
static func traffic_patrol_count(total: int, policing: StringName) -> int:
	if total <= 0:
		return 0
	var share: float = traffic_patrol_share_for_policing(policing)
	if share <= 0.0:
		return 0
	return clampi(int(roundf(float(total) * share)), 0, total)


## Hull remaining as integer percent of max HP (default: legacy HOSTILE_HP).
static func hostile_hull_percent(remaining_hp: float, max_hp: float = -1.0) -> int:
	var cap: float = max_hp if max_hp > 0.0 else HOSTILE_HP
	if cap <= 0.0:
		return 0
	return clampi(
		int(roundf((remaining_hp / cap) * float(HULL_PERCENT_FULL))), 0, HULL_PERCENT_FULL
	)


## Resolved profile dict (falls back to default skirmisher if unknown id).
static func hostile_profile(profile_id: StringName) -> Dictionary:
	if HOSTILE_PROFILES.has(profile_id):
		var raw: Variant = HOSTILE_PROFILES[profile_id]
		if typeof(raw) == TYPE_DICTIONARY:
			return raw
	var fallback: Variant = HOSTILE_PROFILES[PROFILE_DEFAULT]
	if typeof(fallback) == TYPE_DICTIONARY:
		return fallback
	return {}


## True when `profile_id` is a registered hostile profile.
static func has_hostile_profile(profile_id: StringName) -> bool:
	return HOSTILE_PROFILES.has(profile_id)


## Registered profile ids (for tests / pickers).
static func hostile_profile_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in HOSTILE_PROFILES.keys():
		if typeof(key) == TYPE_STRING_NAME:
			var as_name: StringName = key
			out.append(as_name)
		elif typeof(key) == TYPE_STRING:
			var as_text: String = key
			out.append(StringName(as_text))
	return out


## Float stat from a profile (unknown key → `default_value`).
static func profile_float(profile_id: StringName, key: String, default_value: float) -> float:
	var profile: Dictionary = hostile_profile(profile_id)
	if not profile.has(key):
		return default_value
	var raw: Variant = profile[key]
	if typeof(raw) == TYPE_FLOAT:
		var as_f: float = raw
		return as_f
	if typeof(raw) == TYPE_INT:
		var as_i: int = raw
		return float(as_i)
	return default_value


## Display name for lock HUD (unknown → TARGET_LOCK_DEFAULT_NAME).
static func profile_display_name(profile_id: StringName) -> String:
	var profile: Dictionary = hostile_profile(profile_id)
	if profile.has(PROFILE_KEY_DISPLAY_NAME):
		var raw: Variant = profile[PROFILE_KEY_DISPLAY_NAME]
		if typeof(raw) == TYPE_STRING:
			var as_text: String = raw
			if not as_text.is_empty():
				return as_text
	return TARGET_LOCK_DEFAULT_NAME


## Color from profile (unknown → `default_color`).
static func profile_color(profile_id: StringName, key: String, default_color: Color) -> Color:
	var profile: Dictionary = hostile_profile(profile_id)
	if not profile.has(key):
		return default_color
	var raw: Variant = profile[key]
	if typeof(raw) == TYPE_COLOR:
		var as_color: Color = raw
		return as_color
	return default_color


## Player bolt hits needed to kill this profile (ceil division).
static func player_hits_to_kill(
	profile_id: StringName, damage_per_hit: float = PLAYER_WEAPON_DAMAGE
) -> int:
	if damage_per_hit <= 0.0:
		return 0
	var hp: float = profile_float(profile_id, PROFILE_KEY_HP, HOSTILE_HP)
	return int(ceili(hp / damage_per_hit))


## Sustained damage per second for a weapon (damage / cooldown). Pure for tests.
static func weapon_dps(damage_per_hit: float, fire_cooldown: float) -> float:
	if damage_per_hit <= 0.0 or fire_cooldown <= 0.0:
		return 0.0
	return damage_per_hit / fire_cooldown


## Ideal time-to-kill (seconds) at perfect hit rate: first shot at t=0, then
## cooldown between remaining hits. Pure balance math for hull comparisons.
static func time_to_kill(hp: float, damage_per_hit: float, fire_cooldown: float) -> float:
	if hp <= 0.0:
		return 0.0
	if damage_per_hit <= 0.0 or fire_cooldown <= 0.0:
		return 0.0
	var hits: int = int(ceili(hp / damage_per_hit))
	if hits <= 1:
		return 0.0
	return float(hits - 1) * fire_cooldown


## Ambient hostile profile for a policing tag string (contested/lawless/other).
## Uses bare StringNames so balance does not depend on StarSystem shapes.
static func ambient_profile_for_policing(policing: StringName) -> StringName:
	if policing == &"lawless":
		return AMBIENT_PROFILE_LAWLESS
	if policing == &"contested":
		return AMBIENT_PROFILE_CONTESTED
	return PROFILE_DEFAULT


## Ambient hostile count for a policing tag (E2.2). Patrolled = 0; lawless denser.
static func ambient_count_for_policing(policing: StringName) -> int:
	if policing == &"lawless":
		return AMBIENT_HOSTILE_COUNT_LAWLESS
	if policing == &"contested":
		return AMBIENT_HOSTILE_COUNT_CONTESTED
	if policing == &"patrolled":
		return AMBIENT_HOSTILE_COUNT_PATROLLED
	return AMBIENT_HOSTILE_COUNT_PATROLLED


## World offset from station for ambient slot `index` (wraps; contested table).
## Prefer `ambient_spawn_offset_for_policing` for live ecology (E6.1).
static func ambient_spawn_offset(index: int) -> Vector3:
	return ambient_spawn_offset_for_policing(&"contested", index)


## Ambient spawn offset by policing tier (E6.1 encounter ecology).
## Patrolled returns contested slots for safety (count is 0 so unused).
## Lawless uses nearer-gate slots; contested uses mid/lane/belt slots.
static func ambient_spawn_offset_for_policing(policing: StringName, index: int) -> Vector3:
	var slot: int = index
	if AMBIENT_SPAWN_OFFSET_SLOT_COUNT > 0:
		slot = posmod(index, AMBIENT_SPAWN_OFFSET_SLOT_COUNT)
	if policing == &"lawless":
		match slot:
			0:
				return SPAWN_OFFSET_LAWLESS_PRIMARY
			1:
				return SPAWN_OFFSET_LAWLESS_SECONDARY
			2:
				return SPAWN_OFFSET_LAWLESS_TERTIARY
			_:
				return SPAWN_OFFSET_LAWLESS_PRIMARY
	# contested, patrolled, unknown → mid-lane table
	match slot:
		0:
			return SPAWN_OFFSET_CONTESTED_PRIMARY
		1:
			return SPAWN_OFFSET_CONTESTED_SECONDARY
		2:
			return SPAWN_OFFSET_CONTESTED_TERTIARY
		_:
			return SPAWN_OFFSET_CONTESTED_PRIMARY


## Mass-class multiplier for impact (unknown → 1.0).
static func mass_factor(mass_class: StringName) -> float:
	if IMPACT_MASS_FACTOR.has(mass_class):
		var raw: Variant = IMPACT_MASS_FACTOR[mass_class]
		if typeof(raw) == TYPE_FLOAT:
			var as_f: float = raw
			return as_f
		if typeof(raw) == TYPE_INT:
			var as_i: int = raw
			return float(as_i)
	return 1.0


## Speed factor for impact. Below threshold → 0; scales by excess over threshold.
static func speed_factor(closing_speed: float) -> float:
	if closing_speed < IMPACT_SPEED_THRESHOLD:
		return 0.0
	if IMPACT_SPEED_REF <= 0.0:
		return 0.0
	return maxf(0.0, closing_speed - IMPACT_SPEED_THRESHOLD) / IMPACT_SPEED_REF


## Hull damage from ramming `mass_class` at `closing_speed` (0 below threshold).
static func impact_damage(mass_class: StringName, closing_speed: float) -> float:
	if closing_speed < IMPACT_SPEED_THRESHOLD:
		return 0.0
	return IMPACT_BASE * mass_factor(mass_class) * speed_factor(closing_speed)


## Lead intercept so a bolt at `shot_speed` meets a moving target.
## Pure math in the data layer so entities / ui / world share one solver.
static func lead_point(
	shooter_pos: Vector3, target_pos: Vector3, target_vel: Vector3, shot_speed: float
) -> Vector3:
	if shot_speed <= BalanceFlight.DIRECTION_EPSILON:
		return target_pos
	var to_target: Vector3 = target_pos - shooter_pos
	var distance: float = to_target.length()
	if distance < BalanceFlight.DIRECTION_EPSILON:
		return target_pos
	var t: float = distance / shot_speed
	var i: int = 0
	while i < LEAD_SOLVE_ITERATIONS:
		var predicted: Vector3 = target_pos + target_vel * t
		var dist: float = shooter_pos.distance_to(predicted)
		if dist < BalanceFlight.DIRECTION_EPSILON:
			return predicted
		t = dist / shot_speed
		i += 1
	return target_pos + target_vel * t
