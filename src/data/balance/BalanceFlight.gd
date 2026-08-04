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

## Starter / default active hull id (content id kept as hull_courier; display Hauler).
const PLAYER_HULL_ID: StringName = &"hull_courier"

## Fighter hull content id (E2.5 buy-once combat hull).
const FIGHTER_HULL_ID: StringName = &"hull_fighter"

## Scene-tree group for the session ShipService (single writer for active hull).
const GROUP_SHIP_SERVICE: StringName = &"ship_service"

## Scene-tree group for chase cameras that should receive FOV from SettingsService (S10).
const GROUP_CHASE_CAMERA: StringName = &"chase_camera"

## Optional save section `ship` (schema v1, no envelope bump) — E2.5.
const SAVE_SECTION_SHIP: StringName = &"ship"
const SAVE_KEY_ACTIVE_HULL_ID: StringName = &"active_hull_id"
const SAVE_KEY_OWNED_HULL_IDS: StringName = &"owned_hull_ids"
## Per-hull weapons/equipment loadouts (S5). Nested dict; optional.
const SAVE_KEY_LOADOUTS: StringName = &"loadouts"

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
## Outside station StaticBody (disc radius ~22 + hurtbox); E6.1 stretched pad.
const UNDOCK_OFFSET: Vector3 = Vector3(0.0, 5.0, 80.0)

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

# --- Physics layers (E6.1) -------------------------------------------------
# Layer bit values: layer 1 → value 1, layer 2 → value 2.
# Ships (player/hostile/traffic) on SHIPS; station/gate/rock on STATICS.
# Projectiles keep mask SHIPS only so they ignore static props.

## Collision layer for ships (player, hostiles, traffic colliders).
const PHYSICS_LAYER_SHIPS: int = 1

## Collision layer for static world props (station, gate, rock).
const PHYSICS_LAYER_STATICS: int = 2

## Mask for bodies that collide with ships and statics (player / hostiles).
const PHYSICS_MASK_SHIPS_AND_STATICS: int = PHYSICS_LAYER_SHIPS | PHYSICS_LAYER_STATICS

# --- World layout (system gray box) — E6.1 stretch -------------------------

## Station world position for the first playable system.
const STATION_POSITION: Vector3 = Vector3(0.0, 0.0, 0.0)

## Minimum pad → nearest gate separation (metres). Order-of-magnitude over pre-E6 ~272.
const LAYOUT_MIN_STATION_GATE_SEPARATION: float = 1200.0

## Minimum primary → secondary dock separation (metres) in multi-dock systems.
const LAYOUT_MIN_DOCK_SEPARATION: float = 450.0

## Gate world position (primary arc anchor). Length ≥ LAYOUT_MIN_STATION_GATE_SEPARATION.
const GATE_POSITION: Vector3 = Vector3(1100.0, 0.0, -800.0)

## Player spawn offset from the station (starts clear of the dock bubble / collider).
const PLAYER_SPAWN_OFFSET: Vector3 = Vector3(0.0, 8.0, 130.0)

## Soft-bump restitution (0 = cancel into-normal only; small = slight push-out).
const SOFT_BUMP_RESTITUTION: float = 0.05

## Extra separation along contact normal after slide if still overlapping (metres).
const IMPACT_SEPARATION_METRES: float = 0.2

## Gray-box mesh extents.
const STATION_MESH_SIZE: Vector3 = Vector3(36.0, 22.0, 36.0)
const GATE_MESH_SIZE: Vector3 = Vector3(12.0, 28.0, 6.0)
const SHIP_MESH_SIZE: Vector3 = Vector3(2.2, 0.9, 4.5)

## Unshaded silhouette colours (distinct shapes + colours — B1 / E1.1).
const COLOR_STATION: Color = Color(0.55, 0.58, 0.64)
const COLOR_GATE: Color = Color(0.20, 0.80, 1.0)
const COLOR_GATE_CORE: Color = Color(0.95, 1.0, 1.0)
const COLOR_SHIP: Color = Color(0.95, 0.78, 0.22)
const COLOR_SHIP_ENGINE: Color = Color(0.35, 0.75, 1.0)
const COLOR_SHIP_CANOPY: Color = Color(0.45, 0.72, 0.95)
const COLOR_SHIP_WING: Color = Color(0.78, 0.62, 0.28)
## Fighter silhouette (steel/cool) — distinct from Hauler gold at a glance (E2.5).
const COLOR_SHIP_FIGHTER: Color = Color(0.42, 0.58, 0.92)
const COLOR_SHIP_FIGHTER_ENGINE: Color = Color(0.55, 0.95, 1.0)
const COLOR_SHIP_FIGHTER_CANOPY: Color = Color(0.75, 0.9, 1.0)
const COLOR_SHIP_FIGHTER_FIN: Color = Color(0.28, 0.38, 0.72)
const COLOR_SPACE: Color = Color(0.015, 0.02, 0.04)
const COLOR_AMBIENT: Color = Color(0.12, 0.14, 0.18)

## Per-system backdrop / ambient (E1.1 — strong cool / warm / sickly split).
## UNSHADED meshes ignore sun alone; BG + ambient carry system identity.
const COLOR_SPACE_ALPHA: Color = Color(0.008, 0.025, 0.12)
const COLOR_AMBIENT_ALPHA: Color = Color(0.18, 0.30, 0.55)
const COLOR_SPACE_BETA: Color = Color(0.14, 0.04, 0.008)
const COLOR_AMBIENT_BETA: Color = Color(0.50, 0.24, 0.08)
const COLOR_SPACE_GAMMA: Color = Color(0.008, 0.09, 0.065)
const COLOR_AMBIENT_GAMMA: Color = Color(0.08, 0.36, 0.28)
## E5.2 new systems — distinct from Alpha/Beta/Gamma (violet / copper / ash).
const COLOR_SPACE_DELTA: Color = Color(0.05, 0.02, 0.12)
const COLOR_AMBIENT_DELTA: Color = Color(0.32, 0.18, 0.55)
const COLOR_SPACE_EPSILON: Color = Color(0.12, 0.06, 0.02)
const COLOR_AMBIENT_EPSILON: Color = Color(0.48, 0.30, 0.12)
const COLOR_SPACE_ZETA: Color = Color(0.04, 0.04, 0.05)
const COLOR_AMBIENT_ZETA: Color = Color(0.22, 0.24, 0.28)
## S9 outer arm — rust-ore Eta / cold-steel Theta.
const COLOR_SPACE_ETA: Color = Color(0.10, 0.05, 0.02)
const COLOR_AMBIENT_ETA: Color = Color(0.42, 0.28, 0.14)
const COLOR_SPACE_THETA: Color = Color(0.02, 0.06, 0.10)
const COLOR_AMBIENT_THETA: Color = Color(0.20, 0.36, 0.48)

## Ambient fill energy (Environment.ambient_light_energy) per system.
const AMBIENT_ENERGY_DEFAULT: float = 0.85
const AMBIENT_ENERGY_ALPHA: float = 1.05
const AMBIENT_ENERGY_BETA: float = 1.15
const AMBIENT_ENERGY_GAMMA: float = 0.95
const AMBIENT_ENERGY_DELTA: float = 1.0
const AMBIENT_ENERGY_EPSILON: float = 1.1
const AMBIENT_ENERGY_ZETA: float = 0.8
const AMBIENT_ENERGY_ETA: float = 1.05
const AMBIENT_ENERGY_THETA: float = 1.0

## Station silhouette colour per system (still readable as a station).
const COLOR_STATION_ALPHA: Color = Color(0.48, 0.58, 0.82)
const COLOR_STATION_BETA: Color = Color(0.82, 0.42, 0.28)
const COLOR_STATION_GAMMA: Color = Color(0.32, 0.70, 0.52)
const COLOR_STATION_DELTA: Color = Color(0.58, 0.42, 0.88)
const COLOR_STATION_EPSILON: Color = Color(0.88, 0.55, 0.22)
const COLOR_STATION_ZETA: Color = Color(0.55, 0.58, 0.62)
const COLOR_STATION_ETA: Color = Color(0.78, 0.48, 0.28)
const COLOR_STATION_THETA: Color = Color(0.40, 0.62, 0.78)

## Starfield (procedural points — not pure black void).
const STARFIELD_COUNT: int = 220
const STARFIELD_COUNT_ALPHA: int = 260
const STARFIELD_COUNT_BETA: int = 180
const STARFIELD_COUNT_GAMMA: int = 230
const STARFIELD_COUNT_DELTA: int = 240
const STARFIELD_COUNT_EPSILON: int = 190
const STARFIELD_COUNT_ZETA: int = 200
const STARFIELD_COUNT_ETA: int = 210
const STARFIELD_COUNT_THETA: int = 250
const STARFIELD_RADIUS_MIN: float = 380.0
const STARFIELD_RADIUS_MAX: float = 720.0
const STARFIELD_STAR_SIZE: float = 1.6
const COLOR_STAR: Color = Color(0.85, 0.9, 1.0)
const COLOR_STAR_WARM: Color = Color(1.0, 0.88, 0.7)
## Per-system star cool / warm tints (mix reads colder, hotter, or teal).
const COLOR_STAR_ALPHA: Color = Color(0.75, 0.88, 1.0)
const COLOR_STAR_WARM_ALPHA: Color = Color(0.92, 0.94, 1.0)
const COLOR_STAR_BETA: Color = Color(1.0, 0.82, 0.55)
const COLOR_STAR_WARM_BETA: Color = Color(1.0, 0.62, 0.28)
const COLOR_STAR_GAMMA: Color = Color(0.65, 1.0, 0.85)
const COLOR_STAR_WARM_GAMMA: Color = Color(0.85, 1.0, 0.55)
const COLOR_STAR_DELTA: Color = Color(0.78, 0.7, 1.0)
const COLOR_STAR_WARM_DELTA: Color = Color(0.95, 0.85, 1.0)
const COLOR_STAR_EPSILON: Color = Color(1.0, 0.78, 0.45)
const COLOR_STAR_WARM_EPSILON: Color = Color(1.0, 0.55, 0.25)
const COLOR_STAR_ZETA: Color = Color(0.8, 0.82, 0.88)
const COLOR_STAR_WARM_ZETA: Color = Color(0.9, 0.88, 0.8)
const COLOR_STAR_ETA: Color = Color(1.0, 0.8, 0.5)
const COLOR_STAR_WARM_ETA: Color = Color(1.0, 0.6, 0.3)
const COLOR_STAR_THETA: Color = Color(0.7, 0.88, 1.0)
const COLOR_STAR_WARM_THETA: Color = Color(0.85, 0.92, 1.0)

## Gate world label (Label3D) — discoverable without HUD.
const GATE_LABEL_HEIGHT: float = 22.0
const GATE_LABEL_FONT_SIZE: int = 48
const GATE_LABEL_PIXEL_SIZE: float = 0.12
const GATE_LABEL_OUTLINE_SIZE: int = 8
const GATE_LABEL_OUTLINE_ALPHA: float = 0.85
const GATE_BEACON_HEIGHT: float = 36.0
const GATE_BEACON_RADIUS: float = 1.6
const GATE_BEACON_Y_FACTOR: float = 0.5
const GATE_BEACON_LIGHTEN: float = 0.35
const GATE_RING_INNER: float = 4.0
const GATE_RING_OUTER: float = 15.0
const GATE_RING_HEIGHT: float = 2.2
const GATE_RING_SEGMENTS: int = 24
const GATE_RING_RING_SEGMENTS: int = 12
## Thicker/brighter gate core so the aperture reads at range (E1.1).
const GATE_CORE_RADIUS_FACTOR: float = 0.78
const GATE_CORE_HEIGHT_FACTOR: float = 1.35
const GATE_RING_PITCH_DEGREES: float = 90.0
## Cylinder collider height as a factor of GATE_RING_OUTER (upright ring approx).
const GATE_COLLIDER_HEIGHT_FACTOR: float = 1.2
const STATION_CYLINDER_RADIUS: float = 16.0
const STATION_CYLINDER_HEIGHT: float = 28.0
const STATION_CYLINDER_SEGMENTS: int = 12
const STATION_DISC_RADIUS: float = 22.0
const STATION_DISC_HEIGHT: float = 3.5
const STATION_DISC_SEGMENTS: int = 16
const STATION_DISC_LIGHTEN: float = 0.18
## Antenna / tower module on top of the station core (E1.1 silhouette).
const STATION_TOWER_RADIUS: float = 2.4
const STATION_TOWER_TOP_RADIUS_FACTOR: float = 0.45
const STATION_TOWER_HEIGHT: float = 16.0
const STATION_TOWER_Y: float = 20.0
const STATION_TOWER_LIGHTEN: float = 0.28
## Horizontal spoke module through the disc so stations ≠ fat barrels.
const STATION_SPOKE_SIZE: Vector3 = Vector3(44.0, 2.2, 4.5)
const STATION_SPOKE_LIGHTEN: float = 0.08
const STATION_LABEL_HEIGHT_FACTOR: float = 0.65
const SHIP_PRISM_SIZE: Vector3 = Vector3(2.4, 1.1, 5.2)
const SHIP_ENGINE_SIZE: Vector3 = Vector3(1.0, 0.55, 1.4)
const SHIP_MESH_PITCH_DEGREES: float = 90.0
const SHIP_ENGINE_Z_FACTOR: float = 0.35
## Canopy + wing fins so the freighter reads at combat range (E1.1).
const SHIP_CANOPY_SIZE: Vector3 = Vector3(1.05, 0.5, 1.7)
const SHIP_CANOPY_OFFSET: Vector3 = Vector3(0.0, 0.72, -0.35)
const SHIP_WING_SIZE: Vector3 = Vector3(3.6, 0.16, 1.5)
const SHIP_WING_OFFSET: Vector3 = Vector3(0.0, -0.2, 0.45)
## Fighter mesh (slimmer body, tall dorsal fin — silhouette vs Hauler wings).
const SHIP_FIGHTER_PRISM_SIZE: Vector3 = Vector3(1.8, 0.95, 5.6)
const SHIP_FIGHTER_ENGINE_SIZE: Vector3 = Vector3(0.85, 0.5, 1.2)
const SHIP_FIGHTER_ENGINE_Z_FACTOR: float = 0.38
const SHIP_FIGHTER_CANOPY_SIZE: Vector3 = Vector3(0.85, 0.42, 1.5)
const SHIP_FIGHTER_CANOPY_OFFSET: Vector3 = Vector3(0.0, 0.55, -0.55)
const SHIP_FIGHTER_FIN_SIZE: Vector3 = Vector3(0.18, 2.4, 1.6)
const SHIP_FIGHTER_FIN_OFFSET: Vector3 = Vector3(0.0, 1.1, 0.55)
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

# --- Celestial sky (E6.2 Package C) ----------------------------------------
# Backdrop + landmarks only. No landing, mining, or orbital physics (D7).
# Planets/moons/sun disc are unshaded meshes far from the play bubble.
# Belt rocks (when present) use mass class rock + STATICS layer (E6.1 soft bump).

## Scene root name for all sky bodies under SystemWorld.
const CELESTIAL_ROOT_NAME: StringName = &"CelestialSky"

## Child name for the visible sun disc mesh (DirectionalLight stays SystemSun).
const CELESTIAL_SUN_DISC_NAME: StringName = &"SunDisc"

## Child name for the belt band root (rocks parented under it).
const CELESTIAL_BELT_ROOT_NAME: StringName = &"BeltBand"

## Meta key on celestial nodes: "sun" | "planet" | "moon" | "rock".
const META_CELESTIAL_KIND: StringName = &"celestial_kind"
const CELESTIAL_KIND_SUN: StringName = &"sun"
const CELESTIAL_KIND_PLANET: StringName = &"planet"
const CELESTIAL_KIND_MOON: StringName = &"moon"
const CELESTIAL_KIND_ROCK: StringName = &"rock"

## Meta: body index within kind (planet 0/1, moon 0, rock slot).
const META_CELESTIAL_INDEX: StringName = &"celestial_index"

## Minimum distance (m) from STATION_POSITION for planet/moon/sun disc centres.
## Keeps backdrop outside pad/gate transit (~1.3 km gate stretch).
const CELESTIAL_MIN_DISTANCE: float = 2800.0

## Rocks must stay this far from every station and gate world position.
const CELESTIAL_ROCK_PLAY_CLEARANCE: float = 900.0

## Default sun disc radius (metres) at layout distance — large angular size.
const CELESTIAL_SUN_DISC_RADIUS: float = 110.0

## Default sun disc distance from system origin along layout direction.
const CELESTIAL_SUN_DISC_DISTANCE: float = 4200.0

## Sphere mesh segments for large backdrop bodies (perf-cheap).
const CELESTIAL_PLANET_SEGMENTS: int = 16
const CELESTIAL_PLANET_RINGS: int = 12
const CELESTIAL_ROCK_SEGMENTS: int = 8
const CELESTIAL_ROCK_RINGS: int = 6

## Default rock sphere radius range when belt places colliders.
const CELESTIAL_ROCK_RADIUS_MIN: float = 4.0
const CELESTIAL_ROCK_RADIUS_MAX: float = 14.0

## Vertical jitter on belt rocks (metres half-range).
const CELESTIAL_BELT_Y_SPREAD: float = 35.0

## Fallback sun direction when layout dir is zero.
const CELESTIAL_DEFAULT_SUN_DIR: Vector3 = Vector3(0.0, 0.5, -1.0)

## SphereMesh height = radius * this factor (diameter).
const CELESTIAL_SPHERE_HEIGHT_FACTOR: float = 2.0

## Fallback planet radius/colour when a layout entry is incomplete.
const CELESTIAL_FALLBACK_PLANET_RADIUS: float = 200.0
const COLOR_CELESTIAL_FALLBACK_PLANET: Color = Color(0.5, 0.5, 0.55)

## Fallback moon radius/colour when a layout entry is incomplete.
const CELESTIAL_FALLBACK_MOON_RADIUS: float = 50.0
const COLOR_CELESTIAL_FALLBACK_MOON: Color = Color(0.65, 0.65, 0.68)

## Fallback belt ring radius when layout omits belt_radius.
const CELESTIAL_FALLBACK_BELT_RADIUS: float = 500.0

## Rock placement: attempt multiplier and angular/radial jitter.
const CELESTIAL_ROCK_ATTEMPT_MULT: int = 8
const CELESTIAL_ROCK_ANGLE_JITTER: float = 0.12
const CELESTIAL_ROCK_RADIAL_MIN: float = 0.82
const CELESTIAL_ROCK_RADIAL_MAX: float = 1.12

## Unshaded rock mesh colour (shared across belt systems).
const COLOR_CELESTIAL_ROCK: Color = Color(0.42, 0.36, 0.3)

## Per-system sun disc colour (unshaded emissive cue).
const COLOR_SUN_DISC_ALPHA: Color = Color(0.95, 0.97, 1.0)
const COLOR_SUN_DISC_BETA: Color = Color(1.0, 0.72, 0.28)
const COLOR_SUN_DISC_GAMMA: Color = Color(0.75, 1.0, 0.82)
const COLOR_SUN_DISC_DELTA: Color = Color(0.82, 0.72, 1.0)
const COLOR_SUN_DISC_EPSILON: Color = Color(1.0, 0.68, 0.32)
const COLOR_SUN_DISC_ZETA: Color = Color(0.72, 0.74, 0.78)
const COLOR_SUN_DISC_DEFAULT: Color = Color(1.0, 0.95, 0.85)

## Hand-layout planet/moon colours (keyed by system in celestial_layout_for).
const COLOR_PLANET_ALPHA_A: Color = Color(0.42, 0.62, 0.95)
const COLOR_PLANET_ALPHA_B: Color = Color(0.55, 0.78, 0.92)
const COLOR_MOON_ALPHA: Color = Color(0.72, 0.76, 0.82)
const COLOR_PLANET_BETA: Color = Color(0.92, 0.48, 0.18)
const COLOR_PLANET_GAMMA: Color = Color(0.22, 0.68, 0.48)
const COLOR_MOON_GAMMA: Color = Color(0.55, 0.7, 0.58)
const COLOR_PLANET_DELTA_A: Color = Color(0.52, 0.32, 0.88)
const COLOR_PLANET_DELTA_B: Color = Color(0.68, 0.52, 0.92)
const COLOR_PLANET_EPSILON: Color = Color(0.82, 0.48, 0.22)
const COLOR_PLANET_ZETA: Color = Color(0.48, 0.5, 0.52)
const COLOR_PLANET_DEFAULT: Color = Color(0.5, 0.55, 0.65)

## Hand-layout body radii.
const CELESTIAL_RADIUS_ALPHA_A: float = 320.0
const CELESTIAL_RADIUS_ALPHA_B: float = 180.0
const CELESTIAL_RADIUS_ALPHA_MOON: float = 55.0
const CELESTIAL_RADIUS_BETA: float = 420.0
const CELESTIAL_RADIUS_GAMMA: float = 280.0
const CELESTIAL_RADIUS_GAMMA_MOON: float = 48.0
const CELESTIAL_RADIUS_DELTA_A: float = 360.0
const CELESTIAL_RADIUS_DELTA_B: float = 140.0
const CELESTIAL_RADIUS_EPSILON: float = 240.0
const CELESTIAL_RADIUS_ZETA: float = 300.0
const CELESTIAL_RADIUS_DEFAULT: float = 250.0

## Per-system sun disc distance / radius overrides.
const CELESTIAL_SUN_DIST_BETA: float = 4000.0
const CELESTIAL_SUN_RADIUS_BETA: float = 130.0
const CELESTIAL_SUN_DIST_GAMMA: float = 4100.0
const CELESTIAL_SUN_RADIUS_GAMMA: float = 100.0
const CELESTIAL_SUN_DIST_DELTA: float = 4300.0
const CELESTIAL_SUN_RADIUS_DELTA: float = 105.0
const CELESTIAL_SUN_DIST_EPSILON: float = 3900.0
const CELESTIAL_SUN_RADIUS_EPSILON: float = 115.0
const CELESTIAL_SUN_DIST_ZETA: float = 4500.0
const CELESTIAL_SUN_RADIUS_ZETA: float = 85.0

## Belt band params (Gamma sparse, Epsilon dense).
const CELESTIAL_BELT_CENTER_GAMMA: Vector3 = Vector3(-2400.0, 0.0, 2100.0)
const CELESTIAL_BELT_RADIUS_GAMMA: float = 520.0
const CELESTIAL_ROCK_COUNT_GAMMA: int = 6
const CELESTIAL_BELT_CENTER_EPSILON: Vector3 = Vector3(-2600.0, 20.0, 1900.0)
const CELESTIAL_BELT_RADIUS_EPSILON: float = 680.0
const CELESTIAL_ROCK_COUNT_EPSILON: int = 12

## Planet / moon world positions (far from play bubble).
const CELESTIAL_POS_ALPHA_A: Vector3 = Vector3(-3400.0, 180.0, -2200.0)
const CELESTIAL_POS_ALPHA_B: Vector3 = Vector3(2800.0, -120.0, 3100.0)
const CELESTIAL_POS_ALPHA_MOON: Vector3 = Vector3(-3000.0, 260.0, -1950.0)
const CELESTIAL_POS_BETA: Vector3 = Vector3(3600.0, 200.0, -2400.0)
const CELESTIAL_POS_GAMMA: Vector3 = Vector3(-2900.0, 80.0, 3300.0)
const CELESTIAL_POS_GAMMA_MOON: Vector3 = Vector3(-2550.0, 140.0, 3050.0)
const CELESTIAL_POS_DELTA_A: Vector3 = Vector3(2200.0, 250.0, 3600.0)
const CELESTIAL_POS_DELTA_B: Vector3 = Vector3(-3100.0, -90.0, 2600.0)
const CELESTIAL_POS_EPSILON: Vector3 = Vector3(3200.0, 120.0, 2800.0)
const CELESTIAL_POS_ZETA: Vector3 = Vector3(-3800.0, 60.0, -1800.0)
const CELESTIAL_POS_DEFAULT: Vector3 = Vector3(0.0, 0.0, -3200.0)

## Sun direction vectors (normalized at use time).
const CELESTIAL_SUN_DIR_ALPHA: Vector3 = Vector3(0.35, 0.55, -0.75)
const CELESTIAL_SUN_DIR_BETA: Vector3 = Vector3(-0.55, 0.4, -0.7)
const CELESTIAL_SUN_DIR_GAMMA: Vector3 = Vector3(0.2, 0.65, 0.7)
const CELESTIAL_SUN_DIR_DELTA: Vector3 = Vector3(0.7, 0.45, 0.35)
const CELESTIAL_SUN_DIR_EPSILON: Vector3 = Vector3(-0.4, 0.5, -0.75)
const CELESTIAL_SUN_DIR_ZETA: Vector3 = Vector3(0.15, 0.35, 0.9)


## Soft bump: cancel velocity into the contact normal; keep lateral slide (E6.1).
## `normal` points out of the surface toward the body. When moving into the
## surface (dot < 0), the into-component is removed and a small restitution
## push-out is applied. Never hard-zeros the full velocity vector.
static func apply_soft_bump(
	velocity: Vector3, normal: Vector3, restitution: float = -1.0
) -> Vector3:
	var rest: float = restitution
	if rest < 0.0:
		rest = SOFT_BUMP_RESTITUTION
	if normal.length_squared() < DIRECTION_EPSILON:
		return velocity
	var n: Vector3 = normal.normalized()
	var into: float = velocity.dot(n)
	if into >= 0.0:
		return velocity
	return velocity - n * into * (1.0 + rest)


## Backdrop colour for a system id (falls back to default space colour).
static func space_color_for(system_id: StringName) -> Color:
	match system_id:
		&"system_alpha":
			return COLOR_SPACE_ALPHA
		&"system_beta":
			return COLOR_SPACE_BETA
		&"system_gamma":
			return COLOR_SPACE_GAMMA
		&"system_delta":
			return COLOR_SPACE_DELTA
		&"system_epsilon":
			return COLOR_SPACE_EPSILON
		&"system_zeta":
			return COLOR_SPACE_ZETA
		&"system_eta":
			return COLOR_SPACE_ETA
		&"system_theta":
			return COLOR_SPACE_THETA
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
		&"system_delta":
			return COLOR_AMBIENT_DELTA
		&"system_epsilon":
			return COLOR_AMBIENT_EPSILON
		&"system_zeta":
			return COLOR_AMBIENT_ZETA
		&"system_eta":
			return COLOR_AMBIENT_ETA
		&"system_theta":
			return COLOR_AMBIENT_THETA
		_:
			return COLOR_AMBIENT


## Ambient light energy for a system id.
static func ambient_energy_for(system_id: StringName) -> float:
	match system_id:
		&"system_alpha":
			return AMBIENT_ENERGY_ALPHA
		&"system_beta":
			return AMBIENT_ENERGY_BETA
		&"system_gamma":
			return AMBIENT_ENERGY_GAMMA
		&"system_delta":
			return AMBIENT_ENERGY_DELTA
		&"system_epsilon":
			return AMBIENT_ENERGY_EPSILON
		&"system_zeta":
			return AMBIENT_ENERGY_ZETA
		&"system_eta":
			return AMBIENT_ENERGY_ETA
		&"system_theta":
			return AMBIENT_ENERGY_THETA
		_:
			return AMBIENT_ENERGY_DEFAULT


## Station mesh colour for a system id.
static func station_color_for(system_id: StringName) -> Color:
	match system_id:
		&"system_alpha":
			return COLOR_STATION_ALPHA
		&"system_beta":
			return COLOR_STATION_BETA
		&"system_gamma":
			return COLOR_STATION_GAMMA
		&"system_delta":
			return COLOR_STATION_DELTA
		&"system_epsilon":
			return COLOR_STATION_EPSILON
		&"system_zeta":
			return COLOR_STATION_ZETA
		&"system_eta":
			return COLOR_STATION_ETA
		&"system_theta":
			return COLOR_STATION_THETA
		_:
			return COLOR_STATION


## Starfield point count for a system id (density cue without HUD).
static func starfield_count_for(system_id: StringName) -> int:
	match system_id:
		&"system_alpha":
			return STARFIELD_COUNT_ALPHA
		&"system_beta":
			return STARFIELD_COUNT_BETA
		&"system_gamma":
			return STARFIELD_COUNT_GAMMA
		&"system_delta":
			return STARFIELD_COUNT_DELTA
		&"system_epsilon":
			return STARFIELD_COUNT_EPSILON
		&"system_zeta":
			return STARFIELD_COUNT_ZETA
		&"system_eta":
			return STARFIELD_COUNT_ETA
		&"system_theta":
			return STARFIELD_COUNT_THETA
		_:
			return STARFIELD_COUNT


## Cool star tint for a system id.
static func star_color_cool_for(system_id: StringName) -> Color:
	match system_id:
		&"system_alpha":
			return COLOR_STAR_ALPHA
		&"system_beta":
			return COLOR_STAR_BETA
		&"system_gamma":
			return COLOR_STAR_GAMMA
		&"system_delta":
			return COLOR_STAR_DELTA
		&"system_epsilon":
			return COLOR_STAR_EPSILON
		&"system_zeta":
			return COLOR_STAR_ZETA
		&"system_eta":
			return COLOR_STAR_ETA
		&"system_theta":
			return COLOR_STAR_THETA
		_:
			return COLOR_STAR


## Warm star tint for a system id.
static func star_color_warm_for(system_id: StringName) -> Color:
	match system_id:
		&"system_alpha":
			return COLOR_STAR_WARM_ALPHA
		&"system_beta":
			return COLOR_STAR_WARM_BETA
		&"system_gamma":
			return COLOR_STAR_WARM_GAMMA
		&"system_delta":
			return COLOR_STAR_WARM_DELTA
		&"system_epsilon":
			return COLOR_STAR_WARM_EPSILON
		&"system_zeta":
			return COLOR_STAR_WARM_ZETA
		&"system_eta":
			return COLOR_STAR_WARM_ETA
		&"system_theta":
			return COLOR_STAR_WARM_THETA
		_:
			return COLOR_STAR_WARM


## Sun pitch for a system id.
static func sun_pitch_for(system_id: StringName) -> float:
	match system_id:
		&"system_beta":
			return SUN_PITCH_BETA_DEGREES
		&"system_gamma":
			return SUN_PITCH_GAMMA_DEGREES
		&"system_epsilon":
			return SUN_PITCH_BETA_DEGREES
		&"system_zeta":
			return SUN_PITCH_GAMMA_DEGREES
		&"system_eta":
			return SUN_PITCH_BETA_DEGREES
		&"system_theta":
			return SUN_PITCH_DEGREES
		_:
			return SUN_PITCH_DEGREES


## Sun disc albedo for a system id.
static func sun_disc_color_for(system_id: StringName) -> Color:
	match system_id:
		&"system_alpha":
			return COLOR_SUN_DISC_ALPHA
		&"system_beta":
			return COLOR_SUN_DISC_BETA
		&"system_gamma":
			return COLOR_SUN_DISC_GAMMA
		&"system_delta":
			return COLOR_SUN_DISC_DELTA
		&"system_epsilon":
			return COLOR_SUN_DISC_EPSILON
		&"system_zeta":
			return COLOR_SUN_DISC_ZETA
		_:
			return COLOR_SUN_DISC_DEFAULT


## One planet/moon entry for celestial_layout_for tables.
static func _celestial_body(position: Vector3, radius: float, color: Color) -> Dictionary:
	return {
		"position": position,
		"radius": radius,
		"color": color,
	}


## Hand layout for one system: sun direction, planets, optional moons, belt rocks.
## Full-sized fields always present; empty arrays mean "none" for that slot.
## Positions are world metres relative to system origin (STATION_POSITION).
static func celestial_layout_for(system_id: StringName) -> Dictionary:
	match system_id:
		&"system_alpha":
			# Cool Authority home — twin ice worlds + moon, no belt.
			return {
				"sun_dir": CELESTIAL_SUN_DIR_ALPHA.normalized(),
				"sun_distance": CELESTIAL_SUN_DISC_DISTANCE,
				"sun_radius": CELESTIAL_SUN_DISC_RADIUS,
				"planets":
				[
					_celestial_body(
						CELESTIAL_POS_ALPHA_A, CELESTIAL_RADIUS_ALPHA_A, COLOR_PLANET_ALPHA_A
					),
					_celestial_body(
						CELESTIAL_POS_ALPHA_B, CELESTIAL_RADIUS_ALPHA_B, COLOR_PLANET_ALPHA_B
					),
				],
				"moons":
				[
					_celestial_body(
						CELESTIAL_POS_ALPHA_MOON, CELESTIAL_RADIUS_ALPHA_MOON, COLOR_MOON_ALPHA
					),
				],
				"belt_enabled": false,
				"belt_center": Vector3.ZERO,
				"belt_radius": 0.0,
				"rock_count": 0,
			}
		&"system_beta":
			# Warm contested hub — single orange gas giant, no moon/belt.
			return {
				"sun_dir": CELESTIAL_SUN_DIR_BETA.normalized(),
				"sun_distance": CELESTIAL_SUN_DIST_BETA,
				"sun_radius": CELESTIAL_SUN_RADIUS_BETA,
				"planets":
				[
					_celestial_body(CELESTIAL_POS_BETA, CELESTIAL_RADIUS_BETA, COLOR_PLANET_BETA),
				],
				"moons": [],
				"belt_enabled": false,
				"belt_center": Vector3.ZERO,
				"belt_radius": 0.0,
				"rock_count": 0,
			}
		&"system_gamma":
			# Lawless fringe — teal world, moon, sparse rock belt.
			return {
				"sun_dir": CELESTIAL_SUN_DIR_GAMMA.normalized(),
				"sun_distance": CELESTIAL_SUN_DIST_GAMMA,
				"sun_radius": CELESTIAL_SUN_RADIUS_GAMMA,
				"planets":
				[
					_celestial_body(
						CELESTIAL_POS_GAMMA, CELESTIAL_RADIUS_GAMMA, COLOR_PLANET_GAMMA
					),
				],
				"moons":
				[
					_celestial_body(
						CELESTIAL_POS_GAMMA_MOON, CELESTIAL_RADIUS_GAMMA_MOON, COLOR_MOON_GAMMA
					),
				],
				"belt_enabled": true,
				"belt_center": CELESTIAL_BELT_CENTER_GAMMA,
				"belt_radius": CELESTIAL_BELT_RADIUS_GAMMA,
				"rock_count": CELESTIAL_ROCK_COUNT_GAMMA,
			}
		&"system_delta":
			# Violet Reach spur — twin purple bodies, no belt.
			return {
				"sun_dir": CELESTIAL_SUN_DIR_DELTA.normalized(),
				"sun_distance": CELESTIAL_SUN_DIST_DELTA,
				"sun_radius": CELESTIAL_SUN_RADIUS_DELTA,
				"planets":
				[
					_celestial_body(
						CELESTIAL_POS_DELTA_A, CELESTIAL_RADIUS_DELTA_A, COLOR_PLANET_DELTA_A
					),
					_celestial_body(
						CELESTIAL_POS_DELTA_B, CELESTIAL_RADIUS_DELTA_B, COLOR_PLANET_DELTA_B
					),
				],
				"moons": [],
				"belt_enabled": false,
				"belt_center": Vector3.ZERO,
				"belt_radius": 0.0,
				"rock_count": 0,
			}
		&"system_epsilon":
			# Named belt system — copper world + dense rock band (colliders).
			return {
				"sun_dir": CELESTIAL_SUN_DIR_EPSILON.normalized(),
				"sun_distance": CELESTIAL_SUN_DIST_EPSILON,
				"sun_radius": CELESTIAL_SUN_RADIUS_EPSILON,
				"planets":
				[
					_celestial_body(
						CELESTIAL_POS_EPSILON, CELESTIAL_RADIUS_EPSILON, COLOR_PLANET_EPSILON
					),
				],
				"moons": [],
				"belt_enabled": true,
				"belt_center": CELESTIAL_BELT_CENTER_EPSILON,
				"belt_radius": CELESTIAL_BELT_RADIUS_EPSILON,
				"rock_count": CELESTIAL_ROCK_COUNT_EPSILON,
			}
		&"system_zeta":
			# Ash far spur — single grey world, dim sun, empty sky otherwise.
			return {
				"sun_dir": CELESTIAL_SUN_DIR_ZETA.normalized(),
				"sun_distance": CELESTIAL_SUN_DIST_ZETA,
				"sun_radius": CELESTIAL_SUN_RADIUS_ZETA,
				"planets":
				[
					_celestial_body(CELESTIAL_POS_ZETA, CELESTIAL_RADIUS_ZETA, COLOR_PLANET_ZETA),
				],
				"moons": [],
				"belt_enabled": false,
				"belt_center": Vector3.ZERO,
				"belt_radius": 0.0,
				"rock_count": 0,
			}
		_:
			# Safe default so unknown ids still get a sun + one planet.
			return {
				"sun_dir": CELESTIAL_DEFAULT_SUN_DIR.normalized(),
				"sun_distance": CELESTIAL_SUN_DISC_DISTANCE,
				"sun_radius": CELESTIAL_SUN_DISC_RADIUS,
				"planets":
				[
					_celestial_body(
						CELESTIAL_POS_DEFAULT, CELESTIAL_RADIUS_DEFAULT, COLOR_PLANET_DEFAULT
					),
				],
				"moons": [],
				"belt_enabled": false,
				"belt_center": Vector3.ZERO,
				"belt_radius": 0.0,
				"rock_count": 0,
			}


## Typed planets array from a layout dictionary (strict-safe).
static func celestial_planets(layout: Dictionary) -> Array:
	var out: Array = []
	if not layout.has("planets"):
		return out
	var raw: Variant = layout["planets"]
	if typeof(raw) == TYPE_ARRAY:
		var as_array: Array = raw
		return as_array
	return out


## Typed moons array from a layout dictionary (strict-safe).
static func celestial_moons(layout: Dictionary) -> Array:
	var out: Array = []
	if not layout.has("moons"):
		return out
	var raw: Variant = layout["moons"]
	if typeof(raw) == TYPE_ARRAY:
		var as_array: Array = raw
		return as_array
	return out


## Rock count from layout (0 when absent).
static func celestial_rock_count(layout: Dictionary) -> int:
	if not layout.has("rock_count"):
		return 0
	var raw: Variant = layout["rock_count"]
	if typeof(raw) == TYPE_INT:
		var as_i: int = raw
		return as_i
	if typeof(raw) == TYPE_FLOAT:
		var as_f: float = raw
		return int(as_f)
	return 0


## Whether layout enables a belt band.
static func celestial_belt_enabled(layout: Dictionary) -> bool:
	if not layout.has("belt_enabled"):
		return false
	var raw: Variant = layout["belt_enabled"]
	if typeof(raw) == TYPE_BOOL:
		var as_b: bool = raw
		return as_b
	return false


## Compact layout signature for tests / scene queries (counts + primary colour).
static func celestial_fingerprint(system_id: StringName) -> Dictionary:
	var layout: Dictionary = celestial_layout_for(system_id)
	var planets: Array = celestial_planets(layout)
	var moons: Array = celestial_moons(layout)
	var primary: Color = Color.BLACK
	if not planets.is_empty():
		var first_raw: Variant = planets[0]
		if typeof(first_raw) == TYPE_DICTIONARY:
			var first: Dictionary = first_raw
			if first.has("color"):
				var color_raw: Variant = first["color"]
				if typeof(color_raw) == TYPE_COLOR:
					var as_color: Color = color_raw
					primary = as_color
	return {
		"planet_count": planets.size(),
		"moon_count": moons.size(),
		"rock_count": celestial_rock_count(layout),
		"belt_enabled": celestial_belt_enabled(layout),
		"primary_planet_color": primary,
	}
