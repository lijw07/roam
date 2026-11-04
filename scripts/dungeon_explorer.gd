extends "res://scripts/player.gd"

## The playground player, moving relative to where the camera faces instead of along world axes.

const MIN_AIM_DISTANCE := 1.5

## Yaw of the camera following this character, in radians.
var camera_yaw := 0.0
var aim_point := Vector3.INF


func _input_direction() -> Vector3:
	return super().rotated(Vector3.UP, camera_yaw)


func _camera_yaw() -> float:
	return camera_yaw


func _view_yaw() -> float:
	var to_aim := aim_point - global_position
	to_aim.y = 0.0
	if not aim_point.is_finite() or to_aim.length() < MIN_AIM_DISTANCE:
		return super()
	return atan2(to_aim.x, to_aim.z)
