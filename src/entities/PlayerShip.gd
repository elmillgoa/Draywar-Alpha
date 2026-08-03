class_name PlayerShip
extends CharacterBody3D

## Mouse-aim freighter flight — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Freelancer-style: ship turns toward the mouse aim point, W/S throttle,
## A/D strafe, Shift afterburner. Not six-axis Newtonian. Flight state is
## session-only (no save). Ignores input while the debug console is open or
## while docked.

const PlayerProjectileScript = preload("res://src/entities/PlayerProjectile.gd")

var hull_id: StringName = BalanceFlight.PLAYER_HULL_ID
var _max_speed: float = BalanceFlight.SHIP_MAX_SPEED
var _acceleration: float = BalanceFlight.SHIP_ACCELERATION
var _turn_rate: float = BalanceFlight.SHIP_TURN_RATE
var _strafe_speed: float = BalanceFlight.SHIP_STRAFE_SPEED
var _afterburner_multiplier: float = BalanceFlight.SHIP_AFTERBURNER_MULTIPLIER
var _drag: float = BalanceFlight.SHIP_DRAG
var _weapon_damage: float = BalanceCombat.PLAYER_WEAPON_DAMAGE
var _weapon_cooldown: float = BalanceCombat.PLAYER_FIRE_COOLDOWN
var _projectile_speed: float = BalanceCombat.PROJECTILE_SPEED

var _throttle: float = 0.0
var _flight_enabled: bool = true
var _input_blocked: bool = false
var _console_open: bool = false
var _pause_open: bool = false
var _camera: Camera3D = null
var _last_reported_speed: float = -1.0
var _fire_cooldown: float = 0.0
var _crippled: bool = false
var _locked_target: Node = null
## instance_id → seconds remaining before another impact hit on that body (E6.1).
var _impact_cooldown: Dictionary = {}


func _ready() -> void:
	FlightInput.ensure_actions()
	collision_layer = BalanceFlight.PHYSICS_LAYER_SHIPS
	collision_mask = BalanceFlight.PHYSICS_MASK_SHIPS_AND_STATICS
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_sync_hull_id_from_service()
	_apply_hull_from_library(hull_id)
	_build_mesh()
	EventBus.on_console_visibility_changed.connect(_on_console_visibility_changed)
	EventBus.on_pause_changed.connect(_on_pause_changed)
	EventBus.on_player_crippled.connect(_on_player_crippled)
	EventBus.on_player_repaired_from_cripple.connect(_on_player_repaired_from_cripple)
	EventBus.on_hostile_killed.connect(_on_hostile_killed_clear_lock)
	EventBus.on_hull_changed.connect(_on_hull_changed)
	EventBus.on_loadout_changed.connect(_on_loadout_changed)
	# Seed HUD listeners that connect before the first physics tick.
	EventBus.on_player_throttle_changed.emit(_throttle)
	EventBus.on_player_speed_changed.emit(0.0)
	EventBus.on_target_lock_changed.emit(false, "", 0.0)


func _exit_tree() -> void:
	_clear_target_lock(false)
	if EventBus.on_console_visibility_changed.is_connected(_on_console_visibility_changed):
		EventBus.on_console_visibility_changed.disconnect(_on_console_visibility_changed)
	if EventBus.on_pause_changed.is_connected(_on_pause_changed):
		EventBus.on_pause_changed.disconnect(_on_pause_changed)
	if EventBus.on_player_crippled.is_connected(_on_player_crippled):
		EventBus.on_player_crippled.disconnect(_on_player_crippled)
	if EventBus.on_player_repaired_from_cripple.is_connected(_on_player_repaired_from_cripple):
		EventBus.on_player_repaired_from_cripple.disconnect(_on_player_repaired_from_cripple)
	if EventBus.on_hostile_killed.is_connected(_on_hostile_killed_clear_lock):
		EventBus.on_hostile_killed.disconnect(_on_hostile_killed_clear_lock)
	if EventBus.on_hull_changed.is_connected(_on_hull_changed):
		EventBus.on_hull_changed.disconnect(_on_hull_changed)
	if EventBus.on_loadout_changed.is_connected(_on_loadout_changed):
		EventBus.on_loadout_changed.disconnect(_on_loadout_changed)


## Wire the chase camera used for mouse-aim raycasts.
func set_aim_camera(camera: Camera3D) -> void:
	_camera = camera


## Enable or disable pilot control (docked ships are frozen).
func set_flight_enabled(enabled: bool) -> void:
	# Crippled ships stay dead in the water until repair (dock still allowed).
	if enabled and _crippled:
		_flight_enabled = false
		velocity = Vector3.ZERO
		return
	_flight_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO


## True when pilot control is on (not docked / not crippled lock).
func is_flight_enabled() -> bool:
	return _flight_enabled


## True after condition hit zero until repair.
func is_crippled() -> bool:
	return _crippled


## Current throttle 0..1.
func throttle() -> float:
	return _throttle


## Force throttle (e.g. soft start after undock).
func set_throttle(value: float) -> void:
	_throttle = FlightMath.clamp_throttle(value)
	EventBus.on_player_throttle_changed.emit(_throttle)


## Load profile numbers from a Hull content id (falls back to Balance* defaults).
## Weapon stats + turn/afterburner bonuses come from ShipService loadout when present.
func _apply_hull_from_library(id: StringName) -> void:
	if not ContentLibrary.has_item(id):
		return
	var item: ContentItem = ContentLibrary.item(id)
	var hull: Hull = item as Hull
	if hull == null:
		return
	_max_speed = hull.max_speed
	_acceleration = hull.acceleration
	_turn_rate = hull.turn_rate
	_strafe_speed = hull.strafe_speed
	_afterburner_multiplier = hull.afterburner_multiplier
	_drag = hull.drag
	if hull.weapon_damage > 0.0:
		_weapon_damage = hull.weapon_damage
	if hull.weapon_cooldown > 0.0:
		_weapon_cooldown = hull.weapon_cooldown
	if hull.projectile_speed > 0.0:
		_projectile_speed = hull.projectile_speed
	_apply_loadout_overrides()


## Active bolt travel speed (lead pip / aim plane). Exposed for CombatReticle.
func projectile_speed() -> float:
	return _projectile_speed


## Active weapon damage per hit.
func weapon_damage() -> float:
	return _weapon_damage


## Active fire cooldown (seconds between shots).
func weapon_cooldown() -> float:
	return _weapon_cooldown


## Re-apply numbers + silhouette from `hull_id` (station switch / load).
func reapply_active_hull() -> void:
	_apply_hull_from_library(hull_id)
	_rebuild_mesh()


## Role tag for the active mesh path (hauler gold wings vs fighter steel fin).
## Used by tests and any UI that needs a stable silhouette marker.
func role_silhouette() -> StringName:
	if _is_fighter_hull():
		return Hull.ROLE_FIGHTER
	return Hull.ROLE_HAULER


func _on_hull_changed(_old_hull_id: StringName, new_hull_id: StringName) -> void:
	if String(new_hull_id).is_empty():
		return
	hull_id = new_hull_id
	reapply_active_hull()


func _on_loadout_changed(changed_hull_id: StringName) -> void:
	if changed_hull_id != hull_id and not String(changed_hull_id).is_empty():
		return
	_apply_loadout_overrides()


## Pull effective weapons + equipment bonuses from ShipService (S5).
func _apply_loadout_overrides() -> void:
	var ships: Node = _ship_service_node()
	if ships == null:
		return
	if ships.has_method(&"effective_weapon_damage"):
		_weapon_damage = _as_float(ships.call(&"effective_weapon_damage"), _weapon_damage)
	if ships.has_method(&"effective_weapon_cooldown"):
		_weapon_cooldown = _as_float(ships.call(&"effective_weapon_cooldown"), _weapon_cooldown)
	if ships.has_method(&"effective_weapon_projectile_speed"):
		_projectile_speed = _as_float(
			ships.call(&"effective_weapon_projectile_speed"), _projectile_speed
		)
	if ships.has_method(&"turn_rate_bonus") and ContentLibrary.has_item(hull_id):
		var hull_item: ContentItem = ContentLibrary.item(hull_id)
		if hull_item is Hull:
			var base_turn: float = (hull_item as Hull).turn_rate
			_turn_rate = base_turn + _as_float(ships.call(&"turn_rate_bonus"), 0.0)
	if ships.has_method(&"afterburner_bonus") and ContentLibrary.has_item(hull_id):
		var hull_ab: ContentItem = ContentLibrary.item(hull_id)
		if hull_ab is Hull:
			var base_ab: float = (hull_ab as Hull).afterburner_multiplier
			_afterburner_multiplier = base_ab + _as_float(ships.call(&"afterburner_bonus"), 0.0)


func _as_float(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_FLOAT:
		var as_f: float = value
		return as_f
	if typeof(value) == TYPE_INT:
		var as_i: int = value
		return float(as_i)
	return fallback


func _ship_service_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(BalanceFlight.GROUP_SHIP_SERVICE)


func _sync_hull_id_from_service() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var ships: Node = tree.get_first_node_in_group(BalanceFlight.GROUP_SHIP_SERVICE)
	if ships == null or not ships.has_method(&"active_hull_id"):
		return
	var raw: Variant = ships.call(&"active_hull_id")
	if typeof(raw) == TYPE_STRING_NAME:
		var as_name: StringName = raw
		if not String(as_name).is_empty():
			hull_id = as_name
	elif typeof(raw) == TYPE_STRING:
		var as_text: String = raw
		if not as_text.is_empty():
			hull_id = StringName(as_text)


func _physics_process(delta: float) -> void:
	var dt: float = TimeScale.scaled_delta(delta)
	# E3.1 upkeep lives on WorldClock (S1) — not the ship physics heartbeat.
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(0.0, _fire_cooldown - dt)

	# Weapons + target lock work free-flying even when hull is crippled.
	if not _input_blocked and not _is_docked():
		if Input.is_action_just_pressed(FlightInput.ACTION_TARGET_LOCK):
			cycle_target_lock()
		if Input.is_action_just_pressed(FlightInput.ACTION_FIRE):
			try_fire()
	_refresh_lock_hud_if_needed()

	if not _flight_enabled or _input_blocked:
		return

	_update_throttle(dt)
	_update_facing(dt)

	var strafe_axis: float = 0.0
	if Input.is_action_pressed(FlightInput.ACTION_STRAFE_RIGHT):
		strafe_axis += 1.0
	if Input.is_action_pressed(FlightInput.ACTION_STRAFE_LEFT):
		strafe_axis -= 1.0

	var afterburning: bool = Input.is_action_pressed(FlightInput.ACTION_AFTERBURNER)
	var fuel_ok: bool = _wallet_has_fuel()
	var effective_throttle: float = _throttle if fuel_ok else 0.0
	var effective_afterburn: bool = afterburning and fuel_ok
	if fuel_ok:
		_wallet_burn(dt, _throttle, afterburning)
		if afterburning:
			_wallet_wear(dt, true)

	var speed_factor: float = _wallet_speed_factor()
	# Godot forward is -Z.
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var desired: Vector3 = FlightMath.desired_velocity(
		forward,
		right,
		effective_throttle,
		strafe_axis,
		_max_speed * speed_factor,
		_strafe_speed * speed_factor,
		_afterburner_multiplier,
		effective_afterburn
	)
	velocity = FlightMath.integrate_velocity(velocity, desired, _acceleration, _drag, dt)
	# Closing speed must use pre-slide velocity: move_and_slide strips the
	# into-wall component, so post-slide closing is ~0 and impact never fires.
	var pre_slide_velocity: Vector3 = velocity
	move_and_slide()
	_resolve_soft_bumps_and_impact(dt, pre_slide_velocity)

	var speed: float = velocity.length()
	if speed != _last_reported_speed:
		_last_reported_speed = speed
		EventBus.on_player_speed_changed.emit(speed)


## Cycle target lock: first Tab = nearest; further Tabs = next furthest; wrap.
func cycle_target_lock() -> void:
	if _input_blocked or _is_docked():
		return
	# Drop a freed/dead lock before ranking so highlight clear cannot see a freed node.
	if locked_target() == null and _locked_target != null:
		_clear_target_lock(false)
	var ranked: Array[Node] = _hostiles_ranked_by_distance()
	if ranked.is_empty():
		_clear_target_lock(true)
		return
	var next_index: int = 0
	if _locked_target != null and is_instance_valid(_locked_target):
		var found: int = ranked.find(_locked_target)
		if found >= 0:
			next_index = (found + 1) % ranked.size()
	_set_target_lock(ranked[next_index])


## Current locked combat target, or null.
func locked_target() -> Node:
	if _locked_target == null:
		return null
	if not is_instance_valid(_locked_target):
		return null
	if _locked_target.has_method(&"is_alive") and _locked_target.call(&"is_alive") != true:
		return null
	return _locked_target


## Fire a bolt along the mouse aim. No auto-hit on lock (beginner freighter).
## Lock only marks the target; put the reticle on the lead pip to score.
func try_fire() -> bool:
	if _input_blocked or _is_docked():
		return false
	if _fire_cooldown > 0.0:
		return false
	_fire_cooldown = _weapon_cooldown
	EventBus.on_weapon_fired.emit()

	var origin: Vector3 = global_position
	var aim_point: Vector3 = _mouse_aim_point()
	var aim_dir: Vector3 = aim_point - origin
	if aim_dir.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		aim_dir = -global_transform.basis.z
	else:
		aim_dir = aim_dir.normalized()

	var parent: Node = get_parent()
	if parent == null:
		return false
	var bolt: Node = PlayerProjectileScript.new()
	parent.add_child(bolt)
	if bolt is Node3D:
		var bolt_3d: Node3D = bolt as Node3D
		bolt_3d.global_position = origin + aim_dir * BalanceCombat.PROJECTILE_LENGTH
	if bolt.has_method(&"launch"):
		bolt.call(&"launch", aim_dir, _weapon_damage, _projectile_speed)
	return true


func _hostiles_ranked_by_distance() -> Array[Node]:
	# Name kept for call sites; ranks all lockable ships (hostiles + traffic).
	var ranked: Array[Node] = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return ranked
	var entries: Array[Dictionary] = []
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_LOCKABLE):
		if not is_instance_valid(node):
			continue
		if node.has_method(&"is_alive") and node.call(&"is_alive") != true:
			continue
		var body: Node3D = node as Node3D
		if body == null:
			continue
		var dist: float = global_position.distance_to(body.global_position)
		if dist > BalanceCombat.TARGET_LOCK_RANGE:
			continue
		entries.append({&"node": node, &"dist": dist})
	entries.sort_custom(_sort_hostiles_near_to_far)
	for entry: Dictionary in entries:
		var n: Node = entry[&"node"]
		ranked.append(n)
	return ranked


func _sort_hostiles_near_to_far(a: Dictionary, b: Dictionary) -> bool:
	var da: float = a[&"dist"]
	var db: float = b[&"dist"]
	return da < db


func _set_target_lock(target: Node) -> void:
	if _locked_target == target and target != null and is_instance_valid(target):
		_emit_lock_hud()
		return
	_apply_lock_highlight(_locked_target, false)
	_locked_target = target
	_apply_lock_highlight(_locked_target, true)
	_emit_lock_hud()


func _clear_target_lock(emit_bus: bool) -> void:
	_apply_lock_highlight(_locked_target, false)
	_locked_target = null
	if emit_bus:
		EventBus.on_target_lock_changed.emit(false, "", 0.0)


## Variant arg: locked ref may be freed; typed Node rejects freed objects.
func _apply_lock_highlight(target: Variant, on: bool) -> void:
	if target == null:
		return
	if not is_instance_valid(target):
		return
	if typeof(target) != TYPE_OBJECT:
		return
	var obj: Object = target
	if not obj.has_method(&"set_lock_highlight"):
		return
	obj.call(&"set_lock_highlight", on)


func _emit_lock_hud() -> void:
	var target: Node = locked_target()
	if target == null:
		if _locked_target != null:
			_locked_target = null
		EventBus.on_target_lock_changed.emit(false, "", 0.0)
		return
	var body: Node3D = target as Node3D
	var dist: float = 0.0
	if body != null:
		dist = global_position.distance_to(body.global_position)
	var label: String = BalanceCombat.TARGET_LOCK_DEFAULT_NAME
	if target.has_method(&"lock_display_name"):
		var raw: Variant = target.call(&"lock_display_name")
		if typeof(raw) == TYPE_STRING:
			var as_text: String = raw
			if not as_text.is_empty():
				label = as_text
	EventBus.on_target_lock_changed.emit(true, label, dist)


func _refresh_lock_hud_if_needed() -> void:
	if _locked_target == null:
		return
	if locked_target() == null:
		_clear_target_lock(true)
		return
	_emit_lock_hud()


func _on_hostile_killed_clear_lock(_system_id: StringName, _victim_entity_id: StringName) -> void:
	# Death frees the node next frame; drop lock if it is gone or dead.
	if locked_target() == null and _locked_target != null:
		_clear_target_lock(true)


func _update_throttle(dt: float) -> void:
	var before: float = _throttle
	if Input.is_action_pressed(FlightInput.ACTION_THROTTLE_UP):
		_throttle += BalanceFlight.SHIP_THROTTLE_RATE * dt
	if Input.is_action_pressed(FlightInput.ACTION_THROTTLE_DOWN):
		_throttle -= BalanceFlight.SHIP_THROTTLE_RATE * dt
	_throttle = FlightMath.clamp_throttle(_throttle)
	if _throttle != before:
		EventBus.on_player_throttle_changed.emit(_throttle)


func _update_facing(dt: float) -> void:
	var aim_point: Vector3 = _mouse_aim_point()
	var to_aim: Vector3 = aim_point - global_position
	if to_aim.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		return
	var current_forward: Vector3 = -global_transform.basis.z
	var new_forward: Vector3 = FlightMath.turn_toward(current_forward, to_aim, _turn_rate, dt)
	if new_forward.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		return
	# Keep a stable up; bank lightly by reconstructing basis.
	var up: Vector3 = Vector3.UP
	if absf(new_forward.dot(up)) > BalanceFlight.AIM_UP_FLIP_DOT:
		up = global_transform.basis.y
	look_at(global_position + new_forward, up)


func _mouse_aim_point() -> Vector3:
	if _camera == null:
		return (
			global_position
			+ (-global_transform.basis.z * BalanceFlight.MOUSE_AIM_FALLBACK_DISTANCE)
		)

	var viewport: Viewport = get_viewport()
	var mouse: Vector2 = viewport.get_mouse_position()
	var origin: Vector3 = _camera.project_ray_origin(mouse)
	var direction: Vector3 = _camera.project_ray_normal(mouse)
	# Free-fire: point ON the camera ray under the reticle (classic mouse-aim
	# convergence). Ship turns and bolts fly ship → that point. Using a plane at
	# ship-forward combat depth fails with a chase camera offset behind/above —
	# that plane is not what the reticle sees.
	var lock: Node = locked_target()
	if not (lock is Node3D):
		return origin + direction * BalanceFlight.MOUSE_AIM_FALLBACK_DISTANCE

	# Locked: ray × plane through lead intercept (plane normal = camera forward).
	var lock_body: Node3D = lock as Node3D
	var target_pos: Vector3 = lock_body.global_position
	var target_vel: Vector3 = _lock_combat_velocity(lock)
	var plane_point: Vector3 = FlightMath.lead_point(
		global_position, target_pos, target_vel, _projectile_speed
	)
	var plane_normal: Vector3 = _camera.global_transform.basis.z
	var denom: float = direction.dot(plane_normal)
	if absf(denom) < BalanceFlight.DIRECTION_EPSILON:
		return origin + direction * BalanceFlight.MOUSE_AIM_FALLBACK_DISTANCE
	var t: float = (plane_point - origin).dot(plane_normal) / denom
	if t < 0.0:
		return origin + direction * BalanceFlight.MOUSE_AIM_FALLBACK_DISTANCE
	return origin + direction * t


## Velocity of a lock target for lead aim plane (combat_velocity → CB3D.velocity → ZERO).
func _lock_combat_velocity(target: Node) -> Vector3:
	if target.has_method(&"combat_velocity"):
		var raw: Variant = target.call(&"combat_velocity")
		if typeof(raw) == TYPE_VECTOR3:
			var v: Vector3 = raw
			return v
	if target is CharacterBody3D:
		var body: CharacterBody3D = target as CharacterBody3D
		return body.velocity
	return Vector3.ZERO


func _build_mesh() -> void:
	_rebuild_visual_mesh()
	# Sphere hurtbox so hostile travel bolts can score hits fairly.
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Hurtbox"
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = BalanceCombat.PLAYER_HURTBOX_RADIUS
	collision.shape = shape
	add_child(collision)


## Drop mesh children and rebuild for the active hull role (keep hurtbox).
func _rebuild_mesh() -> void:
	_clear_visual_meshes()
	_rebuild_visual_mesh()


func _clear_visual_meshes() -> void:
	var doomed: Array[Node] = []
	for child: Node in get_children():
		if child is MeshInstance3D:
			doomed.append(child)
	for child: Node in doomed:
		remove_child(child)
		child.queue_free()


func _rebuild_visual_mesh() -> void:
	var fighter: bool = _is_fighter_hull()
	if fighter:
		_build_fighter_mesh()
	else:
		_build_hauler_mesh()


func _is_fighter_hull() -> bool:
	if hull_id == BalanceFlight.FIGHTER_HULL_ID:
		return true
	if ContentLibrary.has_item(hull_id):
		var item: ContentItem = ContentLibrary.item(hull_id)
		if item is Hull:
			var hull: Hull = item as Hull
			return hull.role == Hull.ROLE_FIGHTER
	return false


func _build_hauler_mesh() -> void:
	# Pointed freighter: prism hull, engine, canopy, wings — gold Hauler.
	var body: MeshInstance3D = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = BalanceFlight.SHIP_PRISM_SIZE
	body.mesh = prism
	var hull_mat: StandardMaterial3D = StandardMaterial3D.new()
	hull_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hull_mat.albedo_color = BalanceFlight.COLOR_SHIP
	body.material_override = hull_mat
	# Prism default points +Y; lay it so the point faces ship forward (-Z).
	body.rotation_degrees = Vector3(BalanceFlight.SHIP_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(body)

	var engine: MeshInstance3D = MeshInstance3D.new()
	var engine_box: BoxMesh = BoxMesh.new()
	engine_box.size = BalanceFlight.SHIP_ENGINE_SIZE
	engine.mesh = engine_box
	var engine_mat: StandardMaterial3D = StandardMaterial3D.new()
	engine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	engine_mat.albedo_color = BalanceFlight.COLOR_SHIP_ENGINE
	engine.material_override = engine_mat
	engine.position = Vector3(
		0.0, 0.0, BalanceFlight.SHIP_PRISM_SIZE.z * BalanceFlight.SHIP_ENGINE_Z_FACTOR
	)
	add_child(engine)

	var canopy: MeshInstance3D = MeshInstance3D.new()
	var canopy_box: BoxMesh = BoxMesh.new()
	canopy_box.size = BalanceFlight.SHIP_CANOPY_SIZE
	canopy.mesh = canopy_box
	var canopy_mat: StandardMaterial3D = StandardMaterial3D.new()
	canopy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canopy_mat.albedo_color = BalanceFlight.COLOR_SHIP_CANOPY
	canopy.material_override = canopy_mat
	canopy.position = BalanceFlight.SHIP_CANOPY_OFFSET
	add_child(canopy)

	var wings: MeshInstance3D = MeshInstance3D.new()
	var wing_box: BoxMesh = BoxMesh.new()
	wing_box.size = BalanceFlight.SHIP_WING_SIZE
	wings.mesh = wing_box
	var wing_mat: StandardMaterial3D = StandardMaterial3D.new()
	wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wing_mat.albedo_color = BalanceFlight.COLOR_SHIP_WING
	wings.material_override = wing_mat
	wings.position = BalanceFlight.SHIP_WING_OFFSET
	add_child(wings)


func _build_fighter_mesh() -> void:
	# Slim steel body + tall dorsal fin — reads different from Hauler wings.
	var body: MeshInstance3D = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = BalanceFlight.SHIP_FIGHTER_PRISM_SIZE
	body.mesh = prism
	var hull_mat: StandardMaterial3D = StandardMaterial3D.new()
	hull_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hull_mat.albedo_color = BalanceFlight.COLOR_SHIP_FIGHTER
	body.material_override = hull_mat
	body.rotation_degrees = Vector3(BalanceFlight.SHIP_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(body)

	var engine: MeshInstance3D = MeshInstance3D.new()
	var engine_box: BoxMesh = BoxMesh.new()
	engine_box.size = BalanceFlight.SHIP_FIGHTER_ENGINE_SIZE
	engine.mesh = engine_box
	var engine_mat: StandardMaterial3D = StandardMaterial3D.new()
	engine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	engine_mat.albedo_color = BalanceFlight.COLOR_SHIP_FIGHTER_ENGINE
	engine.material_override = engine_mat
	engine.position = Vector3(
		0.0,
		0.0,
		BalanceFlight.SHIP_FIGHTER_PRISM_SIZE.z * BalanceFlight.SHIP_FIGHTER_ENGINE_Z_FACTOR
	)
	add_child(engine)

	var canopy: MeshInstance3D = MeshInstance3D.new()
	var canopy_box: BoxMesh = BoxMesh.new()
	canopy_box.size = BalanceFlight.SHIP_FIGHTER_CANOPY_SIZE
	canopy.mesh = canopy_box
	var canopy_mat: StandardMaterial3D = StandardMaterial3D.new()
	canopy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canopy_mat.albedo_color = BalanceFlight.COLOR_SHIP_FIGHTER_CANOPY
	canopy.material_override = canopy_mat
	canopy.position = BalanceFlight.SHIP_FIGHTER_CANOPY_OFFSET
	add_child(canopy)

	var fin: MeshInstance3D = MeshInstance3D.new()
	var fin_box: BoxMesh = BoxMesh.new()
	fin_box.size = BalanceFlight.SHIP_FIGHTER_FIN_SIZE
	fin.mesh = fin_box
	var fin_mat: StandardMaterial3D = StandardMaterial3D.new()
	fin_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fin_mat.albedo_color = BalanceFlight.COLOR_SHIP_FIGHTER_FIN
	fin.material_override = fin_mat
	fin.position = BalanceFlight.SHIP_FIGHTER_FIN_OFFSET
	add_child(fin)


func _on_console_visibility_changed(open: bool) -> void:
	_console_open = open
	_refresh_input_blocked()


func _on_pause_changed(open: bool) -> void:
	_pause_open = open
	_refresh_input_blocked()


func _refresh_input_blocked() -> void:
	_input_blocked = _console_open or _pause_open


func _fuel_service_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"fuel_service")


func _hull_service_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"hull_condition_service")


func _wallet_has_fuel() -> bool:
	var fuel: Node = _fuel_service_node()
	if fuel == null or not fuel.has_method(&"has_fuel"):
		return true
	return fuel.call(&"has_fuel") == true


func _wallet_burn(dt: float, throttle_value: float, afterburning: bool) -> void:
	var fuel: Node = _fuel_service_node()
	if fuel != null and fuel.has_method(&"burn_fuel"):
		fuel.call(&"burn_fuel", dt, throttle_value, afterburning)


func _wallet_wear(dt: float, afterburning: bool) -> void:
	var hull: Node = _hull_service_node()
	if hull != null and hull.has_method(&"wear_condition"):
		hull.call(&"wear_condition", dt, afterburning)


func _wallet_speed_factor() -> float:
	var hull: Node = _hull_service_node()
	if hull == null or not hull.has_method(&"speed_factor"):
		return 1.0
	var factor: Variant = hull.call(&"speed_factor")
	if typeof(factor) == TYPE_FLOAT:
		var as_float: float = factor
		return as_float
	if typeof(factor) == TYPE_INT:
		var as_int: int = factor
		return float(as_int)
	return 1.0


func _on_player_crippled() -> void:
	_crippled = true
	set_flight_enabled(false)
	_throttle = BalanceFlight.THROTTLE_MIN
	EventBus.on_player_throttle_changed.emit(_throttle)


func _on_player_repaired_from_cripple() -> void:
	_crippled = false
	# Stay frozen while docked; DockingService undock re-enables flight.
	if _is_docked():
		return
	set_flight_enabled(true)


func _is_docked() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var docking: Node = tree.get_first_node_in_group(&"docking_service")
	if docking == null or not docking.has_method(&"docked_station_id"):
		return false
	var station_raw: Variant = docking.call(&"docked_station_id")
	if typeof(station_raw) == TYPE_STRING_NAME:
		var as_name: StringName = station_raw
		return as_name != &""
	if typeof(station_raw) == TYPE_STRING:
		var as_text: String = station_raw
		return not as_text.is_empty()
	return false


## Soft bump + impact damage after move_and_slide (E6.1). Lateral motion kept.
## `impact_velocity` is pre-slide velocity (required for real closing speed).
func _resolve_soft_bumps_and_impact(dt: float, impact_velocity: Vector3) -> void:
	_tick_impact_cooldowns(dt)
	var count: int = get_slide_collision_count()
	if count <= 0:
		return
	var i: int = 0
	while i < count:
		var col: KinematicCollision3D = get_slide_collision(i)
		if col == null:
			i += 1
			continue
		var normal: Vector3 = col.get_normal()
		var relative: Vector3 = impact_velocity
		var collider: Object = col.get_collider()
		if collider is CharacterBody3D:
			var other_body: CharacterBody3D = collider as CharacterBody3D
			relative = impact_velocity - other_body.velocity
		var closing: float = maxf(0.0, -relative.dot(normal))
		# Soft bump still acts on post-slide velocity (keep lateral slide).
		velocity = BalanceFlight.apply_soft_bump(velocity, normal)
		# Mild separation if still pressed into the surface.
		if closing > 0.0 and BalanceFlight.IMPACT_SEPARATION_METRES > 0.0:
			global_position = (
				global_position + normal.normalized() * BalanceFlight.IMPACT_SEPARATION_METRES
			)
		var mass_class: StringName = _mass_class_from_collider(collider)
		if mass_class != &"":
			_try_impact_damage(mass_class, closing, collider)
		i += 1


func _tick_impact_cooldowns(dt: float) -> void:
	if _impact_cooldown.is_empty():
		return
	var doomed: Array = []
	for key: Variant in _impact_cooldown.keys():
		var prev: float = _impact_cooldown_value(key)
		var left: float = prev - dt
		if left <= 0.0:
			doomed.append(key)
		else:
			_impact_cooldown[key] = left
	for key: Variant in doomed:
		_impact_cooldown.erase(key)


func _impact_cooldown_value(key: Variant) -> float:
	if not _impact_cooldown.has(key):
		return 0.0
	var raw: Variant = _impact_cooldown[key]
	if typeof(raw) == TYPE_FLOAT:
		var as_f: float = raw
		return as_f
	if typeof(raw) == TYPE_INT:
		var as_i: int = raw
		return float(as_i)
	return 0.0


func _mass_class_from_collider(collider: Object) -> StringName:
	var node: Node = collider as Node
	while node != null:
		if node.has_meta(BalanceCombat.META_MASS_CLASS):
			var raw: Variant = node.get_meta(BalanceCombat.META_MASS_CLASS)
			if typeof(raw) == TYPE_STRING_NAME:
				var as_name: StringName = raw
				return as_name
			if typeof(raw) == TYPE_STRING:
				var as_text: String = raw
				return StringName(as_text)
		node = node.get_parent()
	return &""


func _try_impact_damage(mass_class: StringName, closing_speed: float, collider: Object) -> void:
	var damage: float = BalanceCombat.impact_damage(mass_class, closing_speed)
	if damage <= 0.0:
		return
	var pair_id: int = 0
	if collider is Object:
		pair_id = (collider as Object).get_instance_id()
	if _impact_cooldown.has(pair_id):
		return
	_impact_cooldown[pair_id] = BalanceCombat.IMPACT_COOLDOWN_SECONDS
	var hull: Node = _hull_service_node()
	if hull != null and hull.has_method(&"apply_damage"):
		hull.call(&"apply_damage", damage)
	# Mutual: lockable ships (hostiles + traffic) take impact (D3 / E6.3).
	if collider is Node:
		var target: Node = _lockable_from_collider(collider as Node)
		if target != null and target.has_method(&"take_damage"):
			var other_dmg: float = BalanceCombat.impact_damage(
				BalanceCombat.IMPACT_PLAYER_AS_MASS_CLASS, closing_speed
			)
			if other_dmg > 0.0:
				target.call(&"take_damage", other_dmg)


func _lockable_from_collider(node: Node) -> Node:
	var walk: Node = node
	while walk != null:
		if walk.is_in_group(BalanceCombat.GROUP_LOCKABLE):
			if walk.has_method(&"is_alive") and walk.call(&"is_alive") != true:
				return null
			return walk
		walk = walk.get_parent()
	return null
