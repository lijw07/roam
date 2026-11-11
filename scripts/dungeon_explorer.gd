extends "res://scripts/player.gd"

const MIN_AIM_DISTANCE := 1.5
const MIN_TARGET_DISTANCE := 0.3

var camera_yaw := 0.0
var aim_point := Vector3.INF
var attack_target: Enemy = null


func _input_direction() -> Vector3:
	return super().rotated(Vector3.UP, camera_yaw)


func _camera_yaw() -> float:
	return camera_yaw


func _aim_point() -> Vector3:
	return aim_point


func _view_yaw() -> float:
	if _has_live_target():
		var to_target := _flat_offset_to(attack_target.global_position)
		if to_target.length() >= MIN_TARGET_DISTANCE:
			return atan2(to_target.x, to_target.z)
	if fights_in_melee():
		return super()
	var to_aim := _flat_offset_to(aim_point)
	if not aim_point.is_finite() or to_aim.length() < MIN_AIM_DISTANCE:
		return super()
	return atan2(to_aim.x, to_aim.z)


func _has_live_target() -> bool:
	return is_instance_valid(attack_target) and not attack_target.dead


func _flat_offset_to(point: Vector3) -> Vector3:
	var offset := point - global_position
	offset.y = 0.0
	return offset
