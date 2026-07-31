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

var hull_id: StringName = BalanceFlight.PLAYER_HULL_ID
var _max_speed: float = BalanceFlight.SHIP_MAX_SPEED
var _acceleration: float = BalanceFlight.SHIP_ACCELERATION
var _turn_rate: float = BalanceFlight.SHIP_TURN_RATE
var _strafe_speed: float = BalanceFlight.SHIP_STRAFE_SPEED
var _afterburner_multiplier: float = BalanceFlight.SHIP_AFTERBURNER_MULTIPLIER
var _drag: float = BalanceFlight.SHIP_DRAG

var _throttle: float = 0.0
var _flight_enabled: bool = true
var _input_blocked: bool = false
var _console_open: bool = false
var _pause_open: bool = false
var _camera: Camera3D = null
var _last_reported_speed: float = -1.0
var _fire_cooldown: float = 0.0
var _crippled: bool = false


func _ready() -> void:
	FlightInput.ensure_actions()
	_apply_hull_from_library(hull_id)
	_build_mesh()
	EventBus.on_console_visibility_changed.connect(_on_console_visibility_changed)
	EventBus.on_pause_changed.connect(_on_pause_changed)
	EventBus.on_player_crippled.connect(_on_player_crippled)
	EventBus.on_player_repaired_from_cripple.connect(_on_player_repaired_from_cripple)
	# Seed HUD listeners that connect before the first physics tick.
	EventBus.on_player_throttle_changed.emit(_throttle)
	EventBus.on_player_speed_changed.emit(0.0)


func _exit_tree() -> void:
	if EventBus.on_console_visibility_changed.is_connected(_on_console_visibility_changed):
		EventBus.on_console_visibility_changed.disconnect(_on_console_visibility_changed)
	if EventBus.on_pause_changed.is_connected(_on_pause_changed):
		EventBus.on_pause_changed.disconnect(_on_pause_changed)
	if EventBus.on_player_crippled.is_connected(_on_player_crippled):
		EventBus.on_player_crippled.disconnect(_on_player_crippled)
	if EventBus.on_player_repaired_from_cripple.is_connected(_on_player_repaired_from_cripple):
		EventBus.on_player_repaired_from_cripple.disconnect(_on_player_repaired_from_cripple)


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


## Load profile numbers from a Hull content id (falls back to BalanceFlight).
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


func _physics_process(delta: float) -> void:
	var dt: float = TimeScale.scaled_delta(delta)
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(0.0, _fire_cooldown - dt)

	# Weapons work free-flying even when hull is crippled (last stand).
	# Flight throttle still gated below.
	if not _input_blocked and not _is_docked():
		if Input.is_action_just_pressed(FlightInput.ACTION_FIRE):
			try_fire()

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
	move_and_slide()

	var speed: float = velocity.length()
	if speed != _last_reported_speed:
		_last_reported_speed = speed
		EventBus.on_player_speed_changed.emit(speed)


## Fire hitscan if cooldown allows. Returns true when a shot went out.
## Free-flying only (not docked / not menu-blocked). Aim follows mouse.
func try_fire() -> bool:
	if _input_blocked or _is_docked():
		return false
	if _fire_cooldown > 0.0:
		return false
	_fire_cooldown = BalanceCombat.PLAYER_FIRE_COOLDOWN
	EventBus.on_weapon_fired.emit()

	var origin: Vector3 = global_position
	# Shoot toward mouse aim (same point the ship turns toward), not only nose.
	var aim_point: Vector3 = _mouse_aim_point()
	var aim_dir: Vector3 = aim_point - origin
	if aim_dir.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		aim_dir = -global_transform.basis.z
	else:
		aim_dir = aim_dir.normalized()
	var hit_point: Vector3 = origin + aim_dir * BalanceCombat.HITSCAN_RANGE
	# World-layer hostiles: group + method only (no class_name cross-layer).
	var target: Node = _hitscan_hostile(origin, aim_dir)
	if target != null:
		var as_node3d: Node3D = target as Node3D
		if as_node3d != null:
			hit_point = as_node3d.global_position
		if target.has_method(&"take_damage"):
			target.call(&"take_damage", BalanceCombat.PLAYER_WEAPON_DAMAGE)
	_spawn_beam_flash(origin, hit_point, BalanceCombat.COLOR_BEAM)
	return true


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
	# Intersect a plane through the ship, facing the camera (stable aim depth).
	var plane_normal: Vector3 = _camera.global_transform.basis.z
	var denom: float = direction.dot(plane_normal)
	if absf(denom) < BalanceFlight.DIRECTION_EPSILON:
		return origin + direction * BalanceFlight.MOUSE_AIM_FALLBACK_DISTANCE
	var t: float = (global_position - origin).dot(plane_normal) / denom
	if t < 0.0:
		return origin + direction * BalanceFlight.MOUSE_AIM_FALLBACK_DISTANCE
	return origin + direction * t


func _build_mesh() -> void:
	# Pointed freighter silhouette (prism hull + rear engine block) — not a box.
	var hull: MeshInstance3D = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = BalanceFlight.SHIP_PRISM_SIZE
	hull.mesh = prism
	var hull_mat: StandardMaterial3D = StandardMaterial3D.new()
	hull_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hull_mat.albedo_color = BalanceFlight.COLOR_SHIP
	hull.material_override = hull_mat
	# Prism default points +Y; lay it so the point faces ship forward (-Z).
	hull.rotation_degrees = Vector3(BalanceFlight.SHIP_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(hull)

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

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = BalanceFlight.SHIP_PRISM_SIZE
	collision.shape = shape
	add_child(collision)


func _on_console_visibility_changed(open: bool) -> void:
	_console_open = open
	_refresh_input_blocked()


func _on_pause_changed(open: bool) -> void:
	_pause_open = open
	_refresh_input_blocked()


func _refresh_input_blocked() -> void:
	_input_blocked = _console_open or _pause_open


func _wallet_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"wallet_service")


func _wallet_has_fuel() -> bool:
	var wallet: Node = _wallet_node()
	if wallet == null or not wallet.has_method(&"has_fuel"):
		return true
	return wallet.call(&"has_fuel") == true


func _wallet_burn(dt: float, throttle_value: float, afterburning: bool) -> void:
	var wallet: Node = _wallet_node()
	if wallet != null and wallet.has_method(&"burn_fuel"):
		wallet.call(&"burn_fuel", dt, throttle_value, afterburning)


func _wallet_wear(dt: float, afterburning: bool) -> void:
	var wallet: Node = _wallet_node()
	if wallet != null and wallet.has_method(&"wear_condition"):
		wallet.call(&"wear_condition", dt, afterburning)


func _wallet_speed_factor() -> float:
	var wallet: Node = _wallet_node()
	if wallet == null or not wallet.has_method(&"speed_factor"):
		return 1.0
	var factor: Variant = wallet.call(&"speed_factor")
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


func _hitscan_hostile(origin: Vector3, forward: Vector3) -> Node:
	var dir: Vector3 = forward.normalized()
	var world: World3D = get_world_3d()
	if world != null:
		var space: PhysicsDirectSpaceState3D = world.direct_space_state
		if space != null:
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				origin, origin + dir * BalanceCombat.HITSCAN_RANGE
			)
			query.exclude = [get_rid()]
			var result: Dictionary = space.intersect_ray(query)
			if not result.is_empty() and result.has("collider"):
				var found: Node = _as_hostile_node(result["collider"])
				if found != null:
					return found

	# Group-scan fallback (reliable in headless / before physics settle).
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var best: Node = null
	var best_dist: float = BalanceCombat.HITSCAN_RANGE + 1.0
	var cos_limit: float = cos(BalanceCombat.HITSCAN_CONE_HALF_ANGLE)
	for node: Node in tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE):
		if not is_instance_valid(node):
			continue
		if node.has_method(&"is_alive") and node.call(&"is_alive") != true:
			continue
		var body: Node3D = node as Node3D
		if body == null:
			continue
		var to_target: Vector3 = body.global_position - origin
		var dist: float = to_target.length()
		if dist > BalanceCombat.HITSCAN_RANGE or dist < BalanceFlight.DIRECTION_EPSILON:
			continue
		var toward: Vector3 = to_target / dist
		if toward.dot(dir) < cos_limit:
			continue
		if dist < best_dist:
			best_dist = dist
			best = node
	return best


func _as_hostile_node(collider: Variant) -> Node:
	if not (collider is Node):
		return null
	var node: Node = collider
	while node != null:
		if node.is_in_group(BalanceCombat.GROUP_HOSTILE):
			return node
		node = node.get_parent()
	return null


func _spawn_beam_flash(from: Vector3, to: Vector3, color: Color) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var beam: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	var length: float = maxf(from.distance_to(to), BalanceCombat.BEAM_WIDTH)
	box.size = Vector3(BalanceCombat.BEAM_WIDTH, BalanceCombat.BEAM_WIDTH, length)
	beam.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	beam.material_override = mat
	parent.add_child(beam)
	beam.global_position = from.lerp(to, BalanceCombat.BEAM_MIDPOINT)
	if (to - from).length_squared() > BalanceFlight.DIRECTION_EPSILON:
		beam.look_at(to, Vector3.UP)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.create_timer(BalanceCombat.BEAM_DURATION).timeout.connect(beam.queue_free)
	else:
		beam.queue_free()
