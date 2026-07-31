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

## Unshaded silhouette colours (distinct shapes + colours — B1).
const COLOR_STATION: Color = Color(0.55, 0.58, 0.64)
const COLOR_GATE: Color = Color(0.25, 0.75, 0.95)
const COLOR_GATE_CORE: Color = Color(0.85, 0.95, 1.0)
const COLOR_SHIP: Color = Color(0.95, 0.78, 0.22)
const COLOR_SHIP_ENGINE: Color = Color(0.35, 0.75, 1.0)
const COLOR_SPACE: Color = Color(0.015, 0.02, 0.04)
const COLOR_AMBIENT: Color = Color(0.12, 0.14, 0.18)

## Per-system backdrop / ambient (B0 readable distinction + B1 presentation).
const COLOR_SPACE_ALPHA: Color = Color(0.02, 0.04, 0.09)
const COLOR_AMBIENT_ALPHA: Color = Color(0.14, 0.18, 0.28)
const COLOR_SPACE_BETA: Color = Color(0.07, 0.03, 0.02)
const COLOR_AMBIENT_BETA: Color = Color(0.28, 0.14, 0.10)
const COLOR_SPACE_GAMMA: Color = Color(0.03, 0.06, 0.03)
const COLOR_AMBIENT_GAMMA: Color = Color(0.12, 0.22, 0.14)

## Station silhouette colour per system (still readable as a station).
const COLOR_STATION_ALPHA: Color = Color(0.52, 0.58, 0.72)
const COLOR_STATION_BETA: Color = Color(0.72, 0.48, 0.38)
const COLOR_STATION_GAMMA: Color = Color(0.42, 0.62, 0.48)

## Starfield (procedural points — not pure black void).
const STARFIELD_COUNT: int = 220
const STARFIELD_RADIUS_MIN: float = 380.0
const STARFIELD_RADIUS_MAX: float = 720.0
const STARFIELD_STAR_SIZE: float = 1.6
const COLOR_STAR: Color = Color(0.85, 0.9, 1.0)
const COLOR_STAR_WARM: Color = Color(1.0, 0.88, 0.7)

## Gate world label (Label3D) — discoverable without HUD.
const GATE_LABEL_HEIGHT: float = 22.0
const GATE_LABEL_FONT_SIZE: int = 48
const GATE_LABEL_PIXEL_SIZE: float = 0.12
const GATE_LABEL_OUTLINE_SIZE: int = 8
const GATE_LABEL_OUTLINE_ALPHA: float = 0.85
const GATE_BEACON_HEIGHT: float = 36.0
const GATE_BEACON_RADIUS: float = 1.4
const GATE_BEACON_Y_FACTOR: float = 0.5
const GATE_BEACON_LIGHTEN: float = 0.25
const GATE_RING_INNER: float = 4.0
const GATE_RING_OUTER: float = 14.0
const GATE_RING_HEIGHT: float = 2.2
const GATE_RING_SEGMENTS: int = 24
const GATE_RING_RING_SEGMENTS: int = 12
const GATE_CORE_RADIUS_FACTOR: float = 0.55
const GATE_CORE_HEIGHT_FACTOR: float = 1.1
const GATE_RING_PITCH_DEGREES: float = 90.0
const STATION_CYLINDER_RADIUS: float = 16.0
const STATION_CYLINDER_HEIGHT: float = 28.0
const STATION_CYLINDER_SEGMENTS: int = 12
const STATION_DISC_RADIUS: float = 22.0
const STATION_DISC_HEIGHT: float = 3.5
const STATION_DISC_SEGMENTS: int = 16
const STATION_DISC_LIGHTEN: float = 0.15
const STATION_LABEL_HEIGHT_FACTOR: float = 0.65
const SHIP_PRISM_SIZE: Vector3 = Vector3(2.4, 1.1, 5.2)
const SHIP_ENGINE_SIZE: Vector3 = Vector3(1.0, 0.55, 1.4)
const SHIP_MESH_PITCH_DEGREES: float = 90.0
const SHIP_ENGINE_Z_FACTOR: float = 0.35
const STARFIELD_Y_SPREAD: float = 0.55
const STARFIELD_SPHERE_RADIUS_FACTOR: float = 0.5
const STARFIELD_RADIAL_SEGMENTS: int = 4
const STARFIELD_RINGS: int = 2
const STARFIELD_WARM_EVERY: int = 3

## Directional light pitch (degrees, negative looks down).
const SUN_PITCH_DEGREES: float = -42.0
const SUN_PITCH_BETA_DEGREES: float = -28.0
const SUN_PITCH_GAMMA_DEGREES: float = -55.0

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


## Backdrop colour for a system id (falls back to default space colour).
static func space_color_for(system_id: StringName) -> Color:
	match system_id:
		&"system_alpha":
			return COLOR_SPACE_ALPHA
		&"system_beta":
			return COLOR_SPACE_BETA
		&"system_gamma":
			return COLOR_SPACE_GAMMA
		_:
			return COLOR_SPACE


## Ambient fill colour for a system id.
static func ambient_color_for(system_id: StringName) -> Color:
	match system_id:
		&"system_alpha":
			return COLOR_AMBIENT_ALPHA
		&"system_beta":
			return COLOR_AMBIENT_BETA
		&"system_gamma":
			return COLOR_AMBIENT_GAMMA
		_:
			return COLOR_AMBIENT


## Station mesh colour for a system id.
static func station_color_for(system_id: StringName) -> Color:
	match system_id:
		&"system_alpha":
			return COLOR_STATION_ALPHA
		&"system_beta":
			return COLOR_STATION_BETA
		&"system_gamma":
			return COLOR_STATION_GAMMA
		_:
			return COLOR_STATION


## Sun pitch for a system id.
static func sun_pitch_for(system_id: StringName) -> float:
	match system_id:
		&"system_beta":
			return SUN_PITCH_BETA_DEGREES
		&"system_gamma":
			return SUN_PITCH_GAMMA_DEGREES
		_:
			return SUN_PITCH_DEGREES
