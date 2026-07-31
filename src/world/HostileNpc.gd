class_name HostileNpc
extends CharacterBody3D

## Thin combat hostile — Path C B4.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B4
##
## One silhouette, simple engage AI, hitscan fire at the player, death reports
## a kill through AttributionService. Parent under SystemWorld so jump teardown
## frees it with clear_world.

var victim_entity_id: StringName = BalanceCombat.VICTIM_ENTITY_ID
var hp: float = BalanceCombat.HOSTILE_HP

var _fire_cooldown: float = 0.0
var _dead: bool = false


func _ready() -> void:
	add_to_group(BalanceCombat.GROUP_HOSTILE)
	_build_mesh()
	TimeScale.set_combat_lock(true)


func _exit_tree() -> void:
	if not _dead:
		_release_combat_lock_if_last()


## Remaining hull.
func remaining_hp() -> float:
	return hp


## True until death starts queue_free.
func is_alive() -> bool:
	return not _dead and hp > 0.0


## Apply player (or test) damage. Emits bus; dies at 0 HP.
func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	EventBus.on_hostile_damaged.emit(hp)
	if hp <= 0.0:
		_die()


## Place a hostile under `parent` at `world_position`. Returns the node.
static func spawn_under(parent: Node3D, world_position: Vector3) -> HostileNpc:
	var hostile: HostileNpc = HostileNpc.new()
	hostile.name = "HostileNpc"
	parent.add_child(hostile)
	hostile.global_position = world_position
	return hostile


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var dt: float = TimeScale.scaled_delta(delta)
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(0.0, _fire_cooldown - dt)

	# Docked ships are not combat targets (station airspace / storyboard safe).
	if _player_is_docked():
		velocity = Vector3.ZERO
		return

	var player: Node3D = _player_ship()
	if player == null:
		return

	var to_player: Vector3 = player.global_position - global_position
	var distance: float = to_player.length()
	if distance > BalanceCombat.ENGAGE_RANGE or distance < BalanceFlight.DIRECTION_EPSILON:
		return

	_face_toward(to_player, dt)
	_close_distance(to_player, distance, dt)

	if _fire_cooldown <= 0.0:
		_fire_at_player(player)


func _player_is_docked() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var dock: Node = tree.get_first_node_in_group(&"docking_service")
	if dock == null or not dock.has_method(&"docked_station_id"):
		return false
	var station_raw: Variant = dock.call(&"docked_station_id")
	if typeof(station_raw) == TYPE_STRING_NAME:
		var as_name: StringName = station_raw
		return not String(as_name).is_empty()
	if typeof(station_raw) == TYPE_STRING:
		var as_text: String = station_raw
		return not as_text.is_empty()
	return false


func _face_toward(to_player: Vector3, dt: float) -> void:
	# Local turn (no FlightMath — world layer may not reference entities).
	var from: Vector3 = -global_transform.basis.z
	if from.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		from = Vector3(0.0, 0.0, -1.0)
	else:
		from = from.normalized()
	var to: Vector3 = to_player
	if to.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		return
	to = to.normalized()
	var angle: float = from.angle_to(to)
	if angle <= BalanceFlight.TURN_ANGLE_EPSILON:
		to = to
	else:
		var max_step: float = BalanceCombat.HOSTILE_TURN_RATE * dt
		if angle > max_step:
			var weight: float = max_step / angle
			to = from.slerp(to, weight).normalized()
	var up: Vector3 = Vector3.UP
	if absf(to.dot(up)) > BalanceFlight.AIM_UP_FLIP_DOT:
		up = global_transform.basis.y
	look_at(global_position + to, up)


func _close_distance(to_player: Vector3, distance: float, dt: float) -> void:
	if distance <= BalanceCombat.HOSTILE_HOLD_DISTANCE:
		velocity = Vector3.ZERO
		return
	var dir: Vector3 = to_player.normalized()
	velocity = dir * BalanceCombat.HOSTILE_MOVE_SPEED
	# CharacterBody3D move; scaled speed already in velocity * real frame is ok
	# via move_and_slide — multiply position manually for headless safety.
	global_position = global_position + velocity * dt


func _fire_at_player(player: Node3D) -> void:
	_fire_cooldown = BalanceCombat.HOSTILE_FIRE_COOLDOWN
	EventBus.on_weapon_fired.emit()
	_spawn_beam(global_position, player.global_position, BalanceCombat.COLOR_HOSTILE_BEAM)
	_apply_player_damage(BalanceCombat.HOSTILE_DAMAGE)


func _apply_player_damage(amount: float) -> void:
	var wallet: Node = _wallet_node()
	if wallet != null and wallet.has_method(&"apply_damage"):
		wallet.call(&"apply_damage", amount)


func _die() -> void:
	if _dead:
		return
	_dead = true
	var system_id: StringName = _current_system_id()
	EventBus.on_hostile_killed.emit(system_id, victim_entity_id)
	_report_kill(system_id)
	_release_combat_lock_if_last()
	queue_free()


func _report_kill(system_id: StringName) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var attribution: Node = tree.get_first_node_in_group(&"attribution_service")
	if attribution == null or not attribution.has_method(&"report_kill"):
		return
	attribution.call(
		&"report_kill",
		system_id,
		victim_entity_id,
		BalanceCombat.KILL_WITNESSES,
		BalanceCombat.KILL_EVIDENCE
	)


func _current_system_id() -> StringName:
	var tree: SceneTree = get_tree()
	if tree == null:
		return BalanceFlight.PLAYABLE_SYSTEM_ID
	var world: Node = tree.get_first_node_in_group(BalanceSession.GROUP_SYSTEM_WORLD)
	if world == null:
		return BalanceFlight.PLAYABLE_SYSTEM_ID
	var raw: Variant = world.get("system_id")
	if typeof(raw) == TYPE_STRING_NAME:
		var as_name: StringName = raw
		return as_name
	if typeof(raw) == TYPE_STRING:
		var as_text: String = raw
		return StringName(as_text)
	return BalanceFlight.PLAYABLE_SYSTEM_ID


func _player_ship() -> Node3D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP)
	return node as Node3D


func _wallet_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"wallet_service")


func _release_combat_lock_if_last() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		TimeScale.set_combat_lock(false)
		return
	var others: Array[Node] = tree.get_nodes_in_group(BalanceCombat.GROUP_HOSTILE)
	for node: Node in others:
		if node != self and is_instance_valid(node):
			return
	TimeScale.set_combat_lock(false)


func _build_mesh() -> void:
	var body: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = BalanceCombat.HOSTILE_CAPSULE_RADIUS
	capsule.height = BalanceCombat.HOSTILE_CAPSULE_HEIGHT
	capsule.radial_segments = BalanceCombat.HOSTILE_CAPSULE_RADIAL
	capsule.rings = BalanceCombat.HOSTILE_CAPSULE_RINGS
	body.mesh = capsule
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_mat.albedo_color = BalanceCombat.COLOR_HOSTILE
	body.material_override = body_mat
	# Lay capsule along forward (-Z) so it reads as a ship, not a buoy.
	body.rotation_degrees = Vector3(BalanceFlight.SHIP_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(body)

	var nose: MeshInstance3D = MeshInstance3D.new()
	var nose_box: BoxMesh = BoxMesh.new()
	nose_box.size = BalanceCombat.HOSTILE_NOSE_SIZE
	nose.mesh = nose_box
	var nose_mat: StandardMaterial3D = StandardMaterial3D.new()
	nose_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nose_mat.albedo_color = BalanceCombat.COLOR_HOSTILE_ACCENT
	nose.material_override = nose_mat
	nose.position = Vector3(0.0, 0.0, BalanceCombat.HOSTILE_NOSE_Z)
	add_child(nose)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = BalanceCombat.HOSTILE_HITBOX_RADIUS
	shape.height = BalanceCombat.HOSTILE_HITBOX_HEIGHT
	collision.shape = shape
	collision.rotation_degrees = Vector3(BalanceFlight.SHIP_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(collision)


func _spawn_beam(from: Vector3, to: Vector3, color: Color) -> void:
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
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat
	parent.add_child(beam)
	beam.global_position = from.lerp(to, BalanceCombat.BEAM_MIDPOINT)
	var mid_to: Vector3 = to - from
	if mid_to.length_squared() > BalanceFlight.DIRECTION_EPSILON:
		beam.look_at(to, Vector3.UP)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.create_timer(BalanceCombat.BEAM_DURATION).timeout.connect(beam.queue_free)
	else:
		beam.queue_free()
