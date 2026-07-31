class_name BalanceCombat
extends RefCounted

## Thin combat tunables — Path C B4.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B4
##
## One weapon class, one hostile type. Hitscan only. Session combat state;
## no save fields. Standing hits still go through AttributionService.

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

# --- Player weapon ---------------------------------------------------------

## Seconds between player shots.
const PLAYER_FIRE_COOLDOWN: float = 0.28

## Hitscan max range (metres).
const HITSCAN_RANGE: float = 220.0

## Damage applied to a hostile on a successful hitscan hit.
const PLAYER_WEAPON_DAMAGE: float = 40.0

## Cone half-angle (radians) for group-scan hitscan fallback (~35°).
const HITSCAN_CONE_HALF_ANGLE: float = 0.60

# --- Hostile ---------------------------------------------------------------

## Hostile hull points (dies at 0). ~3 player hits.
const HOSTILE_HP: float = 100.0

## Damage applied to player condition per hostile shot (not an instant melt).
const HOSTILE_DAMAGE: float = 8.0

## Seconds between hostile shots while engaged.
const HOSTILE_FIRE_COOLDOWN: float = 1.6

## Distance at which the hostile turns and fires on the player (metres).
const ENGAGE_RANGE: float = 110.0

## Hostile turn rate while tracking the player (radians / second).
const HOSTILE_TURN_RATE: float = 1.4

## Hostile closing speed while engaged (m/s).
const HOSTILE_MOVE_SPEED: float = 18.0

## Stop closing when closer than this (metres).
const HOSTILE_HOLD_DISTANCE: float = 40.0

## Red-tinted capsule silhouette.
const COLOR_HOSTILE: Color = Color(0.92, 0.22, 0.18)
const COLOR_HOSTILE_ACCENT: Color = Color(1.0, 0.45, 0.2)

## Capsule mesh size.
const HOSTILE_CAPSULE_RADIUS: float = 1.6
const HOSTILE_CAPSULE_HEIGHT: float = 5.5
const HOSTILE_CAPSULE_RINGS: int = 8
const HOSTILE_CAPSULE_RADIAL: int = 12

## Accent box on the nose so the hostile reads as a fighter, not traffic.
const HOSTILE_NOSE_SIZE: Vector3 = Vector3(0.9, 0.9, 2.2)
const HOSTILE_NOSE_Z: float = -2.4

## Collision shape (slightly larger than mesh for fair hits).
const HOSTILE_HITBOX_RADIUS: float = 2.2
const HOSTILE_HITBOX_HEIGHT: float = 6.0

# --- Spawn -----------------------------------------------------------------

## World offset from station anchor — near the gate line, NOT the undock pad.
## Station is at origin; gate sits around GATE_POSITION — keep pirates there.
const SPAWN_OFFSET: Vector3 = Vector3(200.0, 14.0, -130.0)

## No hostile fire / engage inside this radius of any station (safe undock).
const STATION_SAFE_RADIUS: float = 110.0

## After undock, hostiles wait this long before they may fire (seconds).
const UNDOCK_GRACE_SECONDS: float = 5.0

## Patrolled / government systems do not spawn combat hostiles (safe undock).
## Contested and lawless systems may place one thin pirate for B4 vetting.
const SPAWN_IN_PATROLLED: bool = false
const SPAWN_IN_CONTESTED: bool = true
const SPAWN_IN_LAWLESS: bool = true

# --- Beam flash (visual only) ----------------------------------------------

const BEAM_WIDTH: float = 0.18
const BEAM_DURATION: float = 0.08
## Midpoint blend along the beam (from → to) for MeshInstance placement.
const BEAM_MIDPOINT: float = 0.5
const COLOR_BEAM: Color = Color(1.0, 0.92, 0.35)
const COLOR_HOSTILE_BEAM: Color = Color(1.0, 0.35, 0.25)

# --- Attribution defaults for thin play kills ------------------------------

## Patrolled systems attribute with zero witnesses; contested needs threshold.
const KILL_WITNESSES: int = 1
const KILL_EVIDENCE: bool = false

# --- HUD -------------------------------------------------------------------

## Shown while a combat hostile exists and the ship is free-flying.
const HUD_COMBAT_PROMPT: String = "HOSTILE — TAB LOCK · SPACE / LMB FIRE"

## Locked target readout (name + range metres).
const HUD_TARGET_LOCK_FORMAT: String = "LOCK  %s  %dm"
const HUD_TARGET_LOCK_NONE: String = "LOCK  —"
const TARGET_LOCK_DEFAULT_NAME: String = "Hostile"

## Fail state when hull condition hits zero undocked.
const HUD_CRIPPLED_MESSAGE: String = "SHIP CRIPPLED — DOCK FOR REPAIR"

## Locked hostile accent brighten (0..1 mix toward white).
const LOCK_HIGHLIGHT_LIGHTEN: float = 0.45

## Fail-state console / status line (optional string reuse).
const FAIL_STATE_MESSAGE: String = "Ship crippled. Dock and repair to fly again."
