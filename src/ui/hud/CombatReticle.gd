class_name CombatReticle
extends Control

## Screen combat overlays: aim reticle, lock brackets, lead pip.
##
## Classic mouse-flight space combat. Lock marks the target; you still aim
## the reticle at the lead pip to hit. Not an auto-turret.

var _camera: Camera3D = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1


func _process(_delta: float) -> void:
	queue_redraw()


## Optional chase camera; falls back to viewport camera.
func set_camera(camera: Camera3D) -> void:
	_camera = camera


func _draw() -> void:
	if not _combat_hud_active():
		return
	var cam: Camera3D = _resolve_camera()
	if cam == null:
		return
	# Aim reticle = mouse (where bolts are directed).
	_draw_aim_reticle(get_viewport().get_mouse_position())
	_draw_lock_and_lead(cam)


## Lead intercept so a bolt at `shot_speed` meets a moving target.
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
	while i < BalanceCombat.LEAD_SOLVE_ITERATIONS:
		var predicted: Vector3 = target_pos + target_vel * t
		var dist: float = shooter_pos.distance_to(predicted)
		if dist < BalanceFlight.DIRECTION_EPSILON:
			return predicted
		t = dist / shot_speed
		i += 1
	return target_pos + target_vel * t


func _draw_lock_and_lead(cam: Camera3D) -> void:
	var ship: Node3D = _player_ship()
	if ship == null:
		return
	var lock: Node = _locked_node(ship)
	if lock == null:
		return
	var body: Node3D = lock as Node3D
	if body == null:
		return
	if not _screen_point_ok(cam, body.global_position):
		return
	_draw_lock_brackets(cam.unproject_position(body.global_position))
	var lead: Vector3 = lead_point(
		ship.global_position,
		body.global_position,
		_target_velocity(lock),
		BalanceCombat.PROJECTILE_SPEED
	)
	if _screen_point_ok(cam, lead):
		_draw_lead_pip(cam.unproject_position(lead))


func _locked_node(ship: Node) -> Node:
	if not ship.has_method(&"locked_target"):
		return null
	var raw: Variant = ship.call(&"locked_target")
	if raw == null:
		return null
	if not (raw is Node):
		return null
	# Narrowed by `is Node` — assign without cast for strict typing.
	var node: Node = raw
	if is_instance_valid(node):
		return node
	return null


func _combat_hud_active() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var docking: Node = tree.get_first_node_in_group(&"docking_service")
	if docking == null or not docking.has_method(&"docked_station_id"):
		return true
	var station_raw: Variant = docking.call(&"docked_station_id")
	if typeof(station_raw) == TYPE_STRING_NAME:
		var as_name: StringName = station_raw
		return String(as_name).is_empty()
	if typeof(station_raw) == TYPE_STRING:
		var as_text: String = station_raw
		return as_text.is_empty()
	return true


func _resolve_camera() -> Camera3D:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()


func _player_ship() -> Node3D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP)
	return node as Node3D


func _target_velocity(target: Node) -> Vector3:
	if target.has_method(&"combat_velocity"):
		var raw: Variant = target.call(&"combat_velocity")
		if typeof(raw) == TYPE_VECTOR3:
			var v: Vector3 = raw
			return v
	if target is CharacterBody3D:
		var body: CharacterBody3D = target as CharacterBody3D
		return body.velocity
	return Vector3.ZERO


func _screen_point_ok(cam: Camera3D, world_pos: Vector3) -> bool:
	if cam.is_position_behind(world_pos):
		return false
	var depth: float = cam.global_position.distance_to(world_pos)
	return depth >= BalanceCombat.COMBAT_HUD_MIN_DEPTH


func _draw_aim_reticle(center: Vector2) -> void:
	var r: float = BalanceCombat.RETICLE_RADIUS
	var gap: float = BalanceCombat.RETICLE_GAP
	var arm: float = BalanceCombat.RETICLE_ARM
	var w: float = BalanceCombat.RETICLE_LINE_WIDTH
	var c: Color = BalanceCombat.COLOR_RETICLE
	draw_line(center + Vector2(-r - arm, 0.0), center + Vector2(-gap, 0.0), c, w)
	draw_line(center + Vector2(gap, 0.0), center + Vector2(r + arm, 0.0), c, w)
	draw_line(center + Vector2(0.0, -r - arm), center + Vector2(0.0, -gap), c, w)
	draw_line(center + Vector2(0.0, gap), center + Vector2(0.0, r + arm), c, w)
	draw_arc(center, r, 0.0, TAU, BalanceCombat.RETICLE_ARC_SEGMENTS, c, w)


func _draw_lock_brackets(center: Vector2) -> void:
	var half: float = BalanceCombat.LOCK_BRACKET_HALF
	var corner: float = BalanceCombat.LOCK_BRACKET_CORNER
	var w: float = BalanceCombat.LOCK_BRACKET_WIDTH
	var c: Color = BalanceCombat.COLOR_LOCK_BRACKET
	draw_line(center + Vector2(-half, -half), center + Vector2(-half + corner, -half), c, w)
	draw_line(center + Vector2(-half, -half), center + Vector2(-half, -half + corner), c, w)
	draw_line(center + Vector2(half, -half), center + Vector2(half - corner, -half), c, w)
	draw_line(center + Vector2(half, -half), center + Vector2(half, -half + corner), c, w)
	draw_line(center + Vector2(-half, half), center + Vector2(-half + corner, half), c, w)
	draw_line(center + Vector2(-half, half), center + Vector2(-half, half - corner), c, w)
	draw_line(center + Vector2(half, half), center + Vector2(half - corner, half), c, w)
	draw_line(center + Vector2(half, half), center + Vector2(half, half - corner), c, w)


func _draw_lead_pip(center: Vector2) -> void:
	var h: float = BalanceCombat.LEAD_PIP_HALF
	var w: float = BalanceCombat.LEAD_PIP_WIDTH
	var c: Color = BalanceCombat.COLOR_LEAD_PIP
	var n: Vector2 = center + Vector2(0.0, -h)
	var e: Vector2 = center + Vector2(h, 0.0)
	var s: Vector2 = center + Vector2(0.0, h)
	var west: Vector2 = center + Vector2(-h, 0.0)
	draw_line(n, e, c, w)
	draw_line(e, s, c, w)
	draw_line(s, west, c, w)
	draw_line(west, n, c, w)
