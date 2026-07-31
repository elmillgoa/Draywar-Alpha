class_name BalanceFlight
extends RefCounted

## Flight, docking, camera, and one-system world tunables — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Every number used by the flight loop, gray-box system layout, chase camera,
## dock ranges, and HUD layout lives here. Ship profile defaults are mirrored
## into the `hull_courier` content resource so content stays data.

# --- Playable boot targets -------------------------------------------------

## First playable system ContentLibrary id.
const PLAYABLE_SYSTEM_ID: StringName = &"system_alpha"

## Hull the player flies in A1.
const PLAYER_HULL_ID: StringName = &"hull_courier"

# --- Ship motion (courier defaults; Hull.tres may override) ----------------

## Maximum forward speed at full throttle without afterburner (m/s).
## Softened after A1 flight gate: was 80; still readable, less whip.
const SHIP_MAX_SPEED: float = 70.0

## How fast the ship closes on its desired velocity (m/s^2).
## Softened after A1 flight gate: was 45 (too snappy).
const SHIP_ACCELERATION: float = 28.0

## Maximum turn rate while aiming (radians per second).
## Softened after A1 flight gate: was 2.2 (too responsive / nauseating).
const SHIP_TURN_RATE: float = 1.35

## Lateral strafe speed at full strafe input (m/s).
const SHIP_STRAFE_SPEED: float = 18.0

## Multiplier applied to max speed while afterburner is held.
const SHIP_AFTERBURNER_MULTIPLIER: float = 1.55

## Exponential velocity bleed when desired velocity is lower (1/s).
const SHIP_DRAG: float = 2.2

## Throttle units gained or lost per second while W/S held.
const SHIP_THROTTLE_RATE: float = 0.5

## Throttle range (inclusive).
const THROTTLE_MIN: float = 0.0
const THROTTLE_MAX: float = 1.0

## Near-zero direction length; below this, aim/turn treats the vector as empty.
const DIRECTION_EPSILON: float = 0.0001

## Near-zero angle (radians); below this, snap to target facing.
const TURN_ANGLE_EPSILON: float = 0.0001

# --- Docking ---------------------------------------------------------------

## Distance at which the HUD shows a dock prompt (metres).
const DOCK_APPROACH_RADIUS: float = 90.0

## Distance at which the dock action is accepted (metres).
const DOCK_INTERACT_RADIUS: float = 45.0

## Where the ship reappears relative to the station on undock (local +Z out).
const UNDOCK_OFFSET: Vector3 = Vector3(0.0, 5.0, 55.0)

## Throttle forced after undock so the player is not stuck at full burn.
const UNDOCK_THROTTLE: float = 0.15

# --- Chase camera ----------------------------------------------------------

## Distance behind the ship along its reverse-forward axis.
## Softened after A1 flight gate: farther reduces nausea.
const CAMERA_DISTANCE: float = 36.0

## Height above the ship.
const CAMERA_HEIGHT: float = 12.0

## How fast the camera eases toward the ideal pose (higher = snappier).
## Softened after A1 flight gate: was 6.5 (too locked to ship turns).
const CAMERA_FOLLOW_SPEED: float = 3.2

## How fast the look target eases (separate from position lag).
const CAMERA_LOOK_SPEED: float = 4.0

## Camera field of view in degrees.
const CAMERA_FOV: float = 65.0

## How far ahead of the ship the camera looks (metres along forward).
const CAMERA_LOOK_AHEAD: float = 8.0

# --- World layout (system_alpha gray box) ----------------------------------

## Station world position for the first playable system.
const STATION_POSITION: Vector3 = Vector3(0.0, 0.0, 0.0)

## Gate world position (visual marker; jump not required for A1).
const GATE_POSITION: Vector3 = Vector3(220.0, 0.0, -160.0)

## Player spawn offset from the station (starts clear of the dock bubble).
const PLAYER_SPAWN_OFFSET: Vector3 = Vector3(0.0, 8.0, 130.0)

## Gray-box mesh extents.
const STATION_MESH_SIZE: Vector3 = Vector3(36.0, 22.0, 36.0)
const GATE_MESH_SIZE: Vector3 = Vector3(12.0, 28.0, 6.0)
const SHIP_MESH_SIZE: Vector3 = Vector3(2.2, 0.9, 4.5)

## Unshaded gray-box colours.
const COLOR_STATION: Color = Color(0.48, 0.52, 0.58)
const COLOR_GATE: Color = Color(0.32, 0.55, 0.78)
const COLOR_SHIP: Color = Color(0.9, 0.78, 0.28)
const COLOR_SPACE: Color = Color(0.015, 0.02, 0.04)
const COLOR_AMBIENT: Color = Color(0.12, 0.14, 0.18)

## Directional light pitch (degrees, negative looks down).
const SUN_PITCH_DEGREES: float = -42.0

## How far the mouse aim ray is projected when no geometry is hit (metres).
const MOUSE_AIM_FALLBACK_DISTANCE: float = 250.0

# --- HUD / station menu layout ---------------------------------------------

const HUD_MARGIN: float = 18.0
const HUD_FONT_SIZE: int = 22
const HUD_TITLE_FONT_SIZE: int = 30
const HUD_PROMPT_FONT_SIZE: int = 26
const HUD_CANVAS_LAYER: int = 10
const STATION_MENU_CANVAS_LAYER: int = 20

## Speed readout rounds to this many whole units for stable text.
const HUD_SPEED_DISPLAY_SCALE: float = 1.0

## Absolute |forward · up| above this uses ship local up for look_at stability.
const AIM_UP_FLIP_DOT: float = 0.95

## Throttle fraction → percent readout (0..1 becomes 0..100).
const THROTTLE_PERCENT_SCALE: float = 100.0

## Station menu layout (taller for A3 Accept courier job button).
const STATION_MENU_WIDTH: float = 360.0
const STATION_MENU_HEIGHT: float = 260.0
const STATION_MENU_HALF_WIDTH: float = 180.0
const STATION_MENU_HALF_HEIGHT: float = 130.0
const STATION_MENU_BUTTON_WIDTH: float = 220.0
const STATION_MENU_BUTTON_HEIGHT: float = 40.0
const STATION_MENU_DIM_ALPHA: float = 0.55

## HUD vertical line slots below the title (speed=1, throttle=2, status=3).
const HUD_LINE_SPEED: float = 1.0
const HUD_LINE_THROTTLE: float = 2.0
const HUD_LINE_STATUS: float = 3.0
