class_name ChaseCamera
extends Camera3D

## Soft chase camera behind the player ship — Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Follows with lag so motion stays readable and not nauseating. Uses
## TimeScale.scaled_delta so camera ease matches game time.

var _target: Node3D = null


func _ready() -> void:
	fov = BalanceFlight.CAMERA_FOV
	current = true


## Ship (or any Node3D) to follow.
func set_target(target: Node3D) -> void:
	_target = target
	if _target != null:
		global_position = _ideal_position()
		look_at(_look_point(), Vector3.UP)


func _process(delta: float) -> void:
	if _target == null:
		return
	var dt: float = TimeScale.scaled_delta(delta)
	var ideal: Vector3 = _ideal_position()
	var weight: float = clampf(BalanceFlight.CAMERA_FOLLOW_SPEED * dt, 0.0, 1.0)
	global_position = global_position.lerp(ideal, weight)
	look_at(_look_point(), Vector3.UP)


func _ideal_position() -> Vector3:
	var back: Vector3 = _target.global_transform.basis.z
	var up: Vector3 = _target.global_transform.basis.y
	return (
		_target.global_position
		+ back * BalanceFlight.CAMERA_DISTANCE
		+ up * BalanceFlight.CAMERA_HEIGHT
	)


func _look_point() -> Vector3:
	var forward: Vector3 = -_target.global_transform.basis.z
	return _target.global_position + forward * BalanceFlight.CAMERA_LOOK_AHEAD
