class_name MissionEscortShip
extends TrafficShip

## Thin mission escort freighter — Steam S3a.
##
## Spawns near the player while an escort job is active. Not elite AI: can be
## shot; if hostiles (or the player) destroy it, MissionService fails the job.
## System rebuild frees it without counting as death (queue_free, not _die).


func _ready() -> void:
	add_to_group(BalanceBoard.GROUP_MISSION_ESCORT)
	set_meta(BalanceBoard.META_MISSION_ESCORT, true)
	role_id = BalanceCombat.ROLE_CIVILIAN
	max_hp = BalanceBoard.ESCORT_HULL_HP
	hp = BalanceBoard.ESCORT_HULL_HP
	super._ready()


func lock_display_name() -> String:
	return BalanceBoard.ESCORT_LOCK_LABEL


func _die() -> void:
	if _dead:
		return
	_dead = true
	_notify_mission_destroyed()
	queue_free()


func _notify_mission_destroyed() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var mission: Node = tree.get_first_node_in_group(&"mission_service")
	if mission == null or not mission.has_method(&"notify_escort_destroyed"):
		return
	mission.call(&"notify_escort_destroyed")
