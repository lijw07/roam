extends "res://scripts/player.gd"

## The playground player, moving relative to where the camera faces instead of along world axes.

## Yaw of the camera following this character, in radians.
var camera_yaw := 0.0


func _input_direction() -> Vector3:
	return super().rotated(Vector3.UP, camera_yaw)


func _camera_yaw() -> float:
	return camera_yaw
