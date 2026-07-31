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
var _console_open: bool = false
var _camera: Camera3D = null
var _last_reported_speed: float = -1.0


func _ready() -> void:
	FlightInput.ensure_actions()
	_apply_hull_from_library(hull_id)
	_build_mesh()
	EventBus.on_console_visibility_changed.connect(_on_console_visibility_changed)
	# Seed HUD listeners that connect before the first physics tick.
	EventBus.on_player_throttle_changed.emit(_throttle)
	EventBus.on_player_speed_changed.emit(0.0)


func _exit_tree() -> void:
	if EventBus.on_console_visibility_changed.is_connected(_on_console_visibility_changed):
		EventBus.on_console_visibility_changed.disconnect(_on_console_visibility_changed)


## Wire the chase camera used for mouse-aim raycasts.
func set_aim_camera(camera: Camera3D) -> void:
	_camera = camera


## Enable or disable pilot control (docked ships are frozen).
func set_flight_enabled(enabled: bool) -> void:
	_flight_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO


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
	if not _flight_enabled or _console_open:
		return

	var dt: float = TimeScale.scaled_delta(delta)
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
