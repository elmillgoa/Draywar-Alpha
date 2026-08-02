class_name HostileNpc
extends CharacterBody3D

## Thin combat hostile — Path C B4 + Combat Fairness + E2.1 profiles.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B4, docs/BETA_E2_COMBAT_HULL.md E2.1
##
## Profile-driven stats (skirmisher / gunboat), jink engage AI, travel bolts at
## lead point, death reports a kill through AttributionService. Parent under
## SystemWorld so jump teardown frees it with clear_world.

const HostileProjectileScript = preload("res://src/world/HostileProjectile.gd")

var victim_entity_id: StringName = BalanceCombat.VICTIM_ENTITY_ID
var profile_id: StringName = BalanceCombat.PROFILE_DEFAULT
var max_hp: float = BalanceCombat.HOSTILE_HP
var hp: float = BalanceCombat.HOSTILE_HP

## Combat tunables copied from profile (instance so AI/fire use live values).
var _weapon_damage: float = BalanceCombat.HOSTILE_DAMAGE
var _fire_cooldown_max: float = BalanceCombat.HOSTILE_FIRE_COOLDOWN
var _engage_range: float = BalanceCombat.ENGAGE_RANGE
var _turn_rate: float = BalanceCombat.HOSTILE_TURN_RATE
var _move_speed: float = BalanceCombat.HOSTILE_MOVE_SPEED
var _hold_min: float = BalanceCombat.HOSTILE_HOLD_DISTANCE_MIN
var _hold_max: float = BalanceCombat.HOSTILE_HOLD_DISTANCE_MAX
var _jink_speed: float = BalanceCombat.HOSTILE_JINK_SPEED
var _jink_freq: float = BalanceCombat.HOSTILE_JINK_FREQ
var _color_body: Color = BalanceCombat.COLOR_HOSTILE
var _color_accent: Color = BalanceCombat.COLOR_HOSTILE_ACCENT
var _color_fin: Color = BalanceCombat.COLOR_HOSTILE_FIN

var _fire_cooldown: float = 0.0
var _dead: bool = false
## EventBus dock mirror — group lookup alone was missing docked state in play.
var _player_docked: bool = false
var _undock_grace: float = 0.0
var _body_mat: StandardMaterial3D = null
var _nose_mat: StandardMaterial3D = null
var _fin_mat: StandardMaterial3D = null
var _lock_highlighted: bool = false
var _hit_flash_left: float = 0.0
var _jink_time: float = 0.0
## instance_id → impact cooldown remaining (E6.1 soft bump vs statics / ships).
var _impact_cooldown: Dictionary = {}


func _ready() -> void:
	add_to_group(BalanceCombat.GROUP_HOSTILE)
	add_to_group(BalanceCombat.GROUP_LOCKABLE)
	add_to_group(BalanceCombat.GROUP_IMPACT_BODY)
	collision_layer = BalanceFlight.PHYSICS_LAYER_SHIPS
	collision_mask = BalanceFlight.PHYSICS_MASK_SHIPS_AND_STATICS
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_HOSTILE)
	# Ensure stats are applied even if spawn_under was not used.
	if max_hp <= 0.0 or hp <= 0.0:
		apply_profile(profile_id)
	_build_mesh()
	TimeScale.set_combat_lock(true)
	EventBus.on_docked.connect(_on_player_docked)
	EventBus.on_undocked.connect(_on_player_undocked)
	# If we spawn while already docked, do not open fire on the berth.
	_player_docked = _query_docked_now()


func _exit_tree() -> void:
	if EventBus.on_docked.is_connected(_on_player_docked):
		EventBus.on_docked.disconnect(_on_player_docked)
	if EventBus.on_undocked.is_connected(_on_player_undocked):
		EventBus.on_undocked.disconnect(_on_player_undocked)
	if not _dead:
		_release_combat_lock_if_last()


func _on_player_docked(_station_id: StringName) -> void:
	_player_docked = true
	_undock_grace = 0.0
	velocity = Vector3.ZERO


func _on_player_undocked(_station_id: StringName) -> void:
	_player_docked = false
	# Safe undock window so station airspace is not a free kill.
	_undock_grace = BalanceCombat.UNDOCK_GRACE_SECONDS


## Remaining hull.
func remaining_hp() -> float:
	return hp


## Full hull for this profile (HUD percent denominator).
func hull_max() -> float:
	return max_hp


## True until death starts queue_free.
func is_alive() -> bool:
	return not _dead and hp > 0.0


## Copy fight stats from a balance profile id. Safe before add_child.
func apply_profile(id: StringName) -> void:
	var resolved: StringName = id
	if not BalanceCombat.has_hostile_profile(resolved):
		resolved = BalanceCombat.PROFILE_DEFAULT
	profile_id = resolved
	max_hp = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_HP, BalanceCombat.HOSTILE_HP
	)
	hp = max_hp
	_weapon_damage = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_DAMAGE, BalanceCombat.HOSTILE_DAMAGE
	)
	_fire_cooldown_max = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_FIRE_COOLDOWN, BalanceCombat.HOSTILE_FIRE_COOLDOWN
	)
	_engage_range = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_ENGAGE_RANGE, BalanceCombat.ENGAGE_RANGE
	)
	_turn_rate = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_TURN_RATE, BalanceCombat.HOSTILE_TURN_RATE
	)
	_move_speed = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_MOVE_SPEED, BalanceCombat.HOSTILE_MOVE_SPEED
	)
	_hold_min = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_HOLD_MIN, BalanceCombat.HOSTILE_HOLD_DISTANCE_MIN
	)
	_hold_max = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_HOLD_MAX, BalanceCombat.HOSTILE_HOLD_DISTANCE_MAX
	)
	_jink_speed = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_JINK_SPEED, BalanceCombat.HOSTILE_JINK_SPEED
	)
	_jink_freq = BalanceCombat.profile_float(
		profile_id, BalanceCombat.PROFILE_KEY_JINK_FREQ, BalanceCombat.HOSTILE_JINK_FREQ
	)
	_color_body = BalanceCombat.profile_color(
		profile_id, BalanceCombat.PROFILE_KEY_COLOR, BalanceCombat.COLOR_HOSTILE
	)
	_color_accent = BalanceCombat.profile_color(
		profile_id, BalanceCombat.PROFILE_KEY_COLOR_ACCENT, BalanceCombat.COLOR_HOSTILE_ACCENT
	)
	_color_fin = BalanceCombat.profile_color(
		profile_id, BalanceCombat.PROFILE_KEY_COLOR_FIN, BalanceCombat.COLOR_HOSTILE_FIN
	)
	if _body_mat != null:
		_refresh_materials()


## Apply player (or test) damage. Emits bus; dies at 0 HP.
func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_start_hit_flash()
	EventBus.on_hostile_damaged.emit(hp)
	if hp <= 0.0:
		_die()


## Place a hostile under `parent` at `world_position`. Optional profile id.
static func spawn_under(
	parent: Node3D,
	world_position: Vector3,
	for_profile_id: StringName = BalanceCombat.PROFILE_DEFAULT
) -> HostileNpc:
	var hostile: HostileNpc = HostileNpc.new()
	hostile.name = "HostileNpc"
	hostile.apply_profile(for_profile_id)
	parent.add_child(hostile)
	hostile.global_position = world_position
	return hostile


## HUD / lock readout name — pirate role (E6.3); profile still distinct for combat.
func lock_display_name() -> String:
	return BalanceCombat.role_display_name(BalanceCombat.ROLE_PIRATE)


## World velocity for lead intercept (CharacterBody3D velocity).
func combat_velocity() -> Vector3:
	return velocity


## Brighten silhouette while the player has this ship locked.
func set_lock_highlight(on: bool) -> void:
	_lock_highlighted = on
	_refresh_materials()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var dt: float = TimeScale.scaled_delta(delta)
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(0.0, _fire_cooldown - dt)
	if _undock_grace > 0.0:
		_undock_grace = maxf(0.0, _undock_grace - dt)
	if _hit_flash_left > 0.0:
		_hit_flash_left = maxf(0.0, _hit_flash_left - dt)
		if _hit_flash_left <= 0.0:
			_refresh_materials()

	# Docked / station airspace / undock grace: hold fire.
	if _player_docked or _query_docked_now():
		_player_docked = true
		velocity = Vector3.ZERO
		return

	var player: Node3D = _player_ship()
	if player == null:
		return

	if _player_in_station_safe_zone(player.global_position):
		velocity = Vector3.ZERO
		return

	var to_player: Vector3 = player.global_position - global_position
	var distance: float = to_player.length()
	if distance > _engage_range or distance < BalanceFlight.DIRECTION_EPSILON:
		return

	_jink_time += dt
	_face_toward(to_player, dt)
	_close_distance(to_player, distance, dt)

	if _undock_grace > 0.0:
		return
	if _fire_cooldown <= 0.0 and _facing_player(to_player):
		_fire_at_player(player)


func _query_docked_now() -> bool:
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


## Station approaches stay peaceful; fight is out near the gate / open space.
func _player_in_station_safe_zone(player_pos: Vector3) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return (
			player_pos.distance_to(BalanceFlight.STATION_POSITION)
			<= BalanceCombat.STATION_SAFE_RADIUS
		)
	var world: Node = tree.get_first_node_in_group(BalanceSession.GROUP_SYSTEM_WORLD)
	if world != null and world.has_method(&"station_positions"):
		var positions_raw: Variant = world.call(&"station_positions")
		if typeof(positions_raw) == TYPE_DICTIONARY:
			var positions: Dictionary = positions_raw
			for key: Variant in positions.keys():
				var anchor: Variant = positions[key]
				if typeof(anchor) == TYPE_VECTOR3:
					var pos: Vector3 = anchor
					if player_pos.distance_to(pos) <= BalanceCombat.STATION_SAFE_RADIUS:
						return true
			if not positions.is_empty():
				return false
	return (
		player_pos.distance_to(BalanceFlight.STATION_POSITION) <= BalanceCombat.STATION_SAFE_RADIUS
	)


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
		var max_step: float = _turn_rate * dt
		if angle > max_step:
			var weight: float = max_step / angle
			to = from.slerp(to, weight).normalized()
	var up: Vector3 = Vector3.UP
	if absf(to.dot(up)) > BalanceFlight.AIM_UP_FLIP_DOT:
		up = global_transform.basis.y
	look_at(global_position + to, up)


func _facing_player(to_player: Vector3) -> bool:
	if to_player.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		return false
	var nose: Vector3 = -global_transform.basis.z
	if nose.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		return false
	return nose.normalized().dot(to_player.normalized()) >= BalanceCombat.HOSTILE_FIRE_CONE_DOT


func _close_distance(to_player: Vector3, distance: float, dt: float) -> void:
	var dir: Vector3 = to_player.normalized()
	if distance > _hold_max:
		# Close in from outside the hold band.
		velocity = dir * _move_speed
	elif distance < _hold_min:
		# Back off when too close.
		velocity = -dir * _move_speed
	else:
		# Weave sideways inside the hold band so shots are dodgeable.
		var lateral: Vector3 = dir.cross(Vector3.UP)
		if lateral.length_squared() < BalanceFlight.DIRECTION_EPSILON:
			lateral = dir.cross(Vector3.RIGHT)
		if lateral.length_squared() < BalanceFlight.DIRECTION_EPSILON:
			velocity = Vector3.ZERO
		else:
			lateral = lateral.normalized()
			var side: float = sin(_jink_time * _jink_freq)
			velocity = lateral * (_jink_speed * side)
	# Collision-aware step (E6.1): soft bump against statics / ships.
	move_and_slide()
	_resolve_soft_bumps(dt)


func _fire_at_player(player: Node3D) -> void:
	if _player_docked or _query_docked_now() or _undock_grace > 0.0:
		return
	if _player_in_station_safe_zone(player.global_position):
		return
	_fire_cooldown = _fire_cooldown_max
	EventBus.on_weapon_fired.emit()

	var player_vel: Vector3 = _player_velocity(player)
	var aim: Vector3 = HostileProjectileScript.lead_point(
		global_position, player.global_position, player_vel, BalanceCombat.HOSTILE_PROJECTILE_SPEED
	)
	var aim_dir: Vector3 = aim - global_position
	if aim_dir.length_squared() < BalanceFlight.DIRECTION_EPSILON:
		aim_dir = -global_transform.basis.z
	else:
		aim_dir = aim_dir.normalized()

	# Short muzzle flash only — damage is the travel bolt.
	var muzzle_end: Vector3 = global_position + aim_dir * BalanceCombat.MUZZLE_BEAM_LENGTH
	_spawn_beam(global_position, muzzle_end, BalanceCombat.COLOR_HOSTILE_BEAM)
	_spawn_projectile(aim_dir)


func _spawn_projectile(direction: Vector3) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var bolt: Node = HostileProjectileScript.new()
	parent.add_child(bolt)
	if bolt is Node3D:
		var bolt_3d: Node3D = bolt as Node3D
		bolt_3d.global_position = (
			global_position + direction * BalanceCombat.HOSTILE_PROJECTILE_LENGTH
		)
	if bolt.has_method(&"launch"):
		bolt.call(&"launch", direction, _weapon_damage)


func _player_velocity(player: Node3D) -> Vector3:
	if player is CharacterBody3D:
		var body: CharacterBody3D = player as CharacterBody3D
		return body.velocity
	if player.has_method(&"combat_velocity"):
		var raw: Variant = player.call(&"combat_velocity")
		if typeof(raw) == TYPE_VECTOR3:
			var v: Vector3 = raw
			return v
	return Vector3.ZERO


func _die() -> void:
	if _dead:
		return
	_dead = true
	var system_id: StringName = _current_system_id()
	EventBus.on_hostile_killed.emit(system_id, victim_entity_id)
	_report_kill(system_id)
	_release_combat_lock_if_last()
	_spawn_kill_flash()
	queue_free()


## Expanding unshaded flash parented to the world so it outlives this node.
func _spawn_kill_flash() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.name = "KillFlash"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = BalanceCombat.KILL_FLASH_RADIUS
	sphere.height = BalanceCombat.KILL_FLASH_RADIUS * BalanceCombat.KILL_FLASH_HEIGHT_FACTOR
	sphere.radial_segments = BalanceCombat.KILL_FLASH_RADIAL_SEGMENTS
	sphere.rings = BalanceCombat.KILL_FLASH_RINGS
	flash.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = BalanceCombat.COLOR_KILL_FLASH
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = mat
	var flash_pos: Vector3 = global_position
	parent.add_child(flash)
	flash.global_position = flash_pos
	# Tear-down safety: parent free mid-tween (tests / jump) must not leave a live FX node.
	var flash_id: int = flash.get_instance_id()
	var free_flash: Callable = func() -> void:
		var still: Object = instance_from_id(flash_id)
		if still is Node and is_instance_valid(still):
			(still as Node).queue_free()
	parent.tree_exiting.connect(free_flash, CONNECT_ONE_SHOT)
	var end_scale: float = BalanceCombat.KILL_FLASH_END_SCALE
	var duration: float = BalanceCombat.KILL_FLASH_DURATION
	var tween: Tween = flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(end_scale, end_scale, end_scale), duration)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(flash.queue_free)


func _report_kill(system_id: StringName) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var attribution: Node = tree.get_first_node_in_group(&"attribution_service")
	if attribution == null or not attribution.has_method(&"report_kill"):
		return
	# Contested needs live witnesses; patrolled ignores count; lawless needs evidence.
	attribution.call(
		&"report_kill",
		system_id,
		victim_entity_id,
		_live_witness_count(),
		BalanceCombat.KILL_EVIDENCE
	)


## Ambient orbit traffic in this system that would report a kill (not combat hostiles).
func _live_witness_count() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	var total: int = 0
	for node: Node in tree.get_nodes_in_group(BalanceEconomy.GROUP_NPC_TRAFFIC):
		if not is_instance_valid(node):
			continue
		if node is NpcTraffic:
			total += (node as NpcTraffic).live_ship_count()
	return total


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


func _start_hit_flash() -> void:
	_hit_flash_left = BalanceCombat.HIT_FLASH_SECONDS
	if _body_mat != null:
		_body_mat.albedo_color = BalanceCombat.COLOR_HOSTILE_HIT_FLASH
	if _nose_mat != null:
		_nose_mat.albedo_color = BalanceCombat.COLOR_HOSTILE_HIT_FLASH
	if _fin_mat != null:
		_fin_mat.albedo_color = BalanceCombat.COLOR_HOSTILE_HIT_FLASH


func _refresh_materials() -> void:
	if _body_mat == null or _nose_mat == null:
		return
	if _hit_flash_left > 0.0:
		_body_mat.albedo_color = BalanceCombat.COLOR_HOSTILE_HIT_FLASH
		_nose_mat.albedo_color = BalanceCombat.COLOR_HOSTILE_HIT_FLASH
		if _fin_mat != null:
			_fin_mat.albedo_color = BalanceCombat.COLOR_HOSTILE_HIT_FLASH
		return
	if _lock_highlighted:
		_body_mat.albedo_color = _color_body.lightened(BalanceCombat.LOCK_HIGHLIGHT_LIGHTEN)
		_nose_mat.albedo_color = _color_accent.lightened(BalanceCombat.LOCK_HIGHLIGHT_LIGHTEN)
		if _fin_mat != null:
			_fin_mat.albedo_color = _color_fin.lightened(BalanceCombat.LOCK_HIGHLIGHT_LIGHTEN)
	else:
		_body_mat.albedo_color = _color_body
		_nose_mat.albedo_color = _color_accent
		if _fin_mat != null:
			_fin_mat.albedo_color = _color_fin


func _build_mesh() -> void:
	var body: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = BalanceCombat.HOSTILE_CAPSULE_RADIUS
	capsule.height = BalanceCombat.HOSTILE_CAPSULE_HEIGHT
	capsule.radial_segments = BalanceCombat.HOSTILE_CAPSULE_RADIAL
	capsule.rings = BalanceCombat.HOSTILE_CAPSULE_RINGS
	body.mesh = capsule
	_body_mat = StandardMaterial3D.new()
	_body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body_mat.albedo_color = _color_body
	body.material_override = _body_mat
	# Lay capsule along forward (-Z) so it reads as a ship, not a buoy.
	body.rotation_degrees = Vector3(BalanceFlight.SHIP_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(body)

	var nose: MeshInstance3D = MeshInstance3D.new()
	var nose_box: BoxMesh = BoxMesh.new()
	nose_box.size = BalanceCombat.HOSTILE_NOSE_SIZE
	nose.mesh = nose_box
	_nose_mat = StandardMaterial3D.new()
	_nose_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_nose_mat.albedo_color = _color_accent
	nose.material_override = _nose_mat
	nose.position = Vector3(0.0, 0.0, BalanceCombat.HOSTILE_NOSE_Z)
	add_child(nose)

	# Wide swept fins — threat reads at range vs traffic's small dorsal fin.
	var fins: MeshInstance3D = MeshInstance3D.new()
	var fin_box: BoxMesh = BoxMesh.new()
	fin_box.size = BalanceCombat.HOSTILE_FIN_SIZE
	fins.mesh = fin_box
	_fin_mat = StandardMaterial3D.new()
	_fin_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fin_mat.albedo_color = _color_fin
	fins.material_override = _fin_mat
	fins.position = BalanceCombat.HOSTILE_FIN_OFFSET
	add_child(fins)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = BalanceCombat.HOSTILE_HITBOX_RADIUS
	shape.height = BalanceCombat.HOSTILE_HITBOX_HEIGHT
	collision.shape = shape
	collision.rotation_degrees = Vector3(BalanceFlight.SHIP_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(collision)


## Soft bump after move_and_slide — keep lateral, cancel into-normal (E6.1).
## Player impact damage is applied by PlayerShip (single writer for mutual hits).
func _resolve_soft_bumps(dt: float) -> void:
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
		velocity = BalanceFlight.apply_soft_bump(velocity, normal)
		if BalanceFlight.IMPACT_SEPARATION_METRES > 0.0:
			global_position = (
				global_position + normal.normalized() * BalanceFlight.IMPACT_SEPARATION_METRES
			)
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
