class_name TrafficShip
extends AnimatableBody3D

## Ambient traffic hull — lockable, damageable, attributable (E6.3).
##
## Implements: docs/BETA_E6_LIVED_IN_SPACE.md E6.3 Package B
##
## Thin freighter / patrol boat. Not combat AI. Bolts and impact use
## take_damage; death reports through AttributionService only (never
## on_hostile_killed — that would break bounty). Parent NpcTraffic orbits.

var role_id: StringName = BalanceCombat.ROLE_CIVILIAN
var victim_entity_id: StringName = BalanceCombat.VICTIM_ENTITY_ID
var max_hp: float = BalanceCombat.TRAFFIC_HULL_HP_CIVILIAN
var hp: float = BalanceCombat.TRAFFIC_HULL_HP_CIVILIAN
## S3b purpose lite (orbit / dock_cycle / shortage_run) — display + parent drive.
var purpose_id: StringName = BalanceIncident.PURPOSE_ORBIT

var _dead: bool = false
var _body_mat: StandardMaterial3D = null
var _fin_mat: StandardMaterial3D = null
var _color_body: Color = BalanceCombat.COLOR_TRAFFIC_CIVILIAN
var _lock_highlighted: bool = false
var _hit_flash_left: float = 0.0


func _ready() -> void:
	add_to_group(BalanceCombat.GROUP_LOCKABLE)
	add_to_group(BalanceCombat.GROUP_IMPACT_BODY)
	if max_hp <= 0.0 or hp <= 0.0:
		apply_role(role_id)


func _process(delta: float) -> void:
	if _hit_flash_left <= 0.0:
		return
	var dt: float = TimeScale.scaled_delta(delta)
	_hit_flash_left = maxf(0.0, _hit_flash_left - dt)
	if _hit_flash_left <= 0.0:
		_refresh_materials()


## S3b: purpose tag for traffic AI lite (parent NpcTraffic drives motion).
func set_purpose(new_purpose: StringName) -> void:
	if String(new_purpose).is_empty():
		purpose_id = BalanceIncident.PURPOSE_ORBIT
	else:
		purpose_id = new_purpose


## Current purpose id (tests / HUD).
func get_purpose() -> StringName:
	return purpose_id


## Copy role stats (HP, colour, mass class). Safe before add_child.
func apply_role(id: StringName) -> void:
	if id == BalanceCombat.ROLE_PATROL:
		role_id = BalanceCombat.ROLE_PATROL
		max_hp = BalanceCombat.TRAFFIC_HULL_HP_PATROL
		_color_body = BalanceCombat.COLOR_TRAFFIC_PATROL
		set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_TRAFFIC_HEAVY)
	else:
		role_id = BalanceCombat.ROLE_CIVILIAN
		max_hp = BalanceCombat.TRAFFIC_HULL_HP_CIVILIAN
		_color_body = BalanceCombat.COLOR_TRAFFIC_CIVILIAN
		set_meta(BalanceCombat.META_MASS_CLASS, BalanceCombat.MASS_CLASS_TRAFFIC_LIGHT)
	hp = max_hp
	if _body_mat != null:
		_refresh_materials()


## Remaining hull.
func remaining_hp() -> float:
	return hp


## Full hull for HUD percent.
func hull_max() -> float:
	return max_hp


## True until death starts queue_free.
func is_alive() -> bool:
	return not _dead and hp > 0.0


## Apply player bolt / impact damage. Dies at 0 HP.
func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_start_hit_flash()
	# Reuse hostile-damaged so locked HUD hull % updates (same readout path).
	EventBus.on_hostile_damaged.emit(hp)
	if hp <= 0.0:
		_die()


## Lock HUD role string (Civilian / Patrol).
func lock_display_name() -> String:
	return BalanceCombat.role_display_name(role_id)


## Ambient traffic has no own velocity; orbit is parent-driven.
func combat_velocity() -> Vector3:
	return Vector3.ZERO


## Brighten silhouette while the player has this ship locked.
func set_lock_highlight(on: bool) -> void:
	_lock_highlighted = on
	_refresh_materials()


## Build mesh + collider. Called by NpcTraffic factory after apply_role.
func build_visual(color: Color) -> void:
	_color_body = color
	collision_layer = BalanceFlight.PHYSICS_LAYER_SHIPS
	collision_mask = 0

	var hull: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = BalanceEconomy.NPC_MESH_SIZE.x * BalanceEconomy.NPC_CAPSULE_RADIUS_FACTOR
	capsule.height = BalanceEconomy.NPC_MESH_SIZE.z
	capsule.radial_segments = BalanceEconomy.NPC_CAPSULE_RADIAL_SEGMENTS
	hull.mesh = capsule
	_body_mat = StandardMaterial3D.new()
	_body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body_mat.albedo_color = _color_body
	hull.material_override = _body_mat
	hull.rotation_degrees = Vector3(BalanceEconomy.NPC_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(hull)

	var fin: MeshInstance3D = MeshInstance3D.new()
	var fin_box: BoxMesh = BoxMesh.new()
	fin_box.size = BalanceEconomy.NPC_FIN_SIZE
	fin.mesh = fin_box
	_fin_mat = StandardMaterial3D.new()
	_fin_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fin_mat.albedo_color = _color_body.lightened(BalanceEconomy.NPC_FIN_LIGHTEN)
	fin.material_override = _fin_mat
	fin.position = BalanceEconomy.NPC_FIN_OFFSET
	add_child(fin)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "TrafficCollider"
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = BalanceEconomy.NPC_MESH_SIZE.x * BalanceEconomy.NPC_CAPSULE_RADIUS_FACTOR
	shape.height = BalanceEconomy.NPC_MESH_SIZE.z
	collision.shape = shape
	collision.rotation_degrees = Vector3(BalanceEconomy.NPC_MESH_PITCH_DEGREES, 0.0, 0.0)
	add_child(collision)


func _die() -> void:
	if _dead:
		return
	_dead = true
	var system_id: StringName = _current_system_id()
	_unregister_from_traffic()
	_report_kill(system_id)
	queue_free()


func _unregister_from_traffic() -> void:
	var parent: Node = get_parent()
	if parent != null and parent.has_method(&"unregister_ship"):
		parent.call(&"unregister_ship", self)


func _report_kill(system_id: StringName) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var attribution: Node = tree.get_first_node_in_group(&"attribution_service")
	if attribution == null or not attribution.has_method(&"report_kill"):
		return
	# Same law as combat kills: evidence=false; witnesses = other live traffic.
	attribution.call(
		&"report_kill",
		system_id,
		victim_entity_id,
		_live_witness_count(),
		BalanceCombat.KILL_EVIDENCE
	)


## Other live ambient traffic in this system (not this ship — already unregistered).
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


func _start_hit_flash() -> void:
	_hit_flash_left = BalanceCombat.HIT_FLASH_SECONDS
	if _body_mat != null:
		_body_mat.albedo_color = BalanceCombat.COLOR_TRAFFIC_HIT_FLASH
	if _fin_mat != null:
		_fin_mat.albedo_color = BalanceCombat.COLOR_TRAFFIC_HIT_FLASH


func _refresh_materials() -> void:
	if _body_mat == null:
		return
	if _hit_flash_left > 0.0:
		_body_mat.albedo_color = BalanceCombat.COLOR_TRAFFIC_HIT_FLASH
		if _fin_mat != null:
			_fin_mat.albedo_color = BalanceCombat.COLOR_TRAFFIC_HIT_FLASH
		return
	if _lock_highlighted:
		_body_mat.albedo_color = _color_body.lightened(BalanceCombat.LOCK_HIGHLIGHT_LIGHTEN)
		if _fin_mat != null:
			_fin_mat.albedo_color = _color_body.lightened(
				BalanceEconomy.NPC_FIN_LIGHTEN + BalanceCombat.LOCK_HIGHLIGHT_LIGHTEN
			)
	else:
		_body_mat.albedo_color = _color_body
		if _fin_mat != null:
			_fin_mat.albedo_color = _color_body.lightened(BalanceEconomy.NPC_FIN_LIGHTEN)
