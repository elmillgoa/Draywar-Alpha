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
const GROUP_HOSTILE: StringName = &"hostile_npc"

## Victim Entity tag on kill reports (attribution target is still the
## local system controller when one holds the system — Reach in alpha).
const VICTIM_ENTITY_ID: StringName = &"entity_free_haulers"

# --- Input -----------------------------------------------------------------

## Fire action registered by FlightInput (Space + left mouse).
const ACTION_FIRE: StringName = &"fire_weapon"
const FIRE_KEY: Key = KEY_SPACE
const FIRE_MOUSE_BUTTON: MouseButton = MOUSE_BUTTON_LEFT

## Target lock cycle (Tab). Closest first, then next furthest, wrap.
const ACTION_TARGET_LOCK: StringName = &"target_lock"
const TARGET_LOCK_KEY: Key = KEY_TAB

## Max distance to include a hostile in the lock cycle (metres).
const TARGET_LOCK_RANGE: float = 400.0

# --- Player weapon (bolts — no auto-hit on lock) ----------------------------

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

## Bolt visual size.
const PROJECTILE_RADIUS: float = 0.45
const PROJECTILE_LENGTH: float = 2.8
const COLOR_PROJECTILE: Color = Color(1.0, 0.85, 0.25)

## Lead intercept solver iterations (classic space-combat lead pip).
const LEAD_SOLVE_ITERATIONS: int = 4

# --- Hostile ---------------------------------------------------------------

## Hostile hull points (dies at 0). ~3 player hits.
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

## Red-tinted capsule silhouette.
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

# --- Spawn -----------------------------------------------------------------

## World offset from station anchor — near the gate line, NOT the undock pad.
## Station is at origin; gate sits around GATE_POSITION — keep pirates there.
const SPAWN_OFFSET: Vector3 = Vector3(200.0, 14.0, -130.0)

## Offset from the player (or request point) when a bounty needs a live hostile
## and none remain. Length must exceed STATION_SAFE_RADIUS so undock airspace
## stays clear; ensure_hostile_near still rechecks every station safe radius.
const BOUNTY_SPAWN_OFFSET: Vector3 = Vector3(180.0, 12.0, -100.0)

## Extra push past STATION_SAFE_RADIUS when the first offset still lands in a
## station bubble (secondary docks / tight geometry).
const BOUNTY_SPAWN_SAFE_MARGIN: float = 25.0

## No hostile fire / engage inside this radius of any station (safe undock).
const STATION_SAFE_RADIUS: float = 110.0

## After undock, hostiles wait this long before they may fire (seconds).
const UNDOCK_GRACE_SECONDS: float = 5.0

## Patrolled / government systems do not spawn combat hostiles (safe undock).
## Contested and lawless systems may place one thin pirate for B4 vetting.
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

## Patrolled systems attribute with zero witnesses; contested needs threshold.
const KILL_WITNESSES: int = 1
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


## Hull remaining as integer percent of HOSTILE_HP.
static func hostile_hull_percent(remaining_hp: float) -> int:
	if HOSTILE_HP <= 0.0:
		return 0
	return clampi(
		int(roundf((remaining_hp / HOSTILE_HP) * float(HULL_PERCENT_FULL))), 0, HULL_PERCENT_FULL
	)


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
