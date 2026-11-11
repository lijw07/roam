class_name StepClimber
extends RefCounted

const STEP_HEIGHT := 0.5
const STEP_PROBE := 0.15
const SNAP_MARGIN := 0.05


static func snap_length() -> float:
	return STEP_HEIGHT + SNAP_MARGIN


static func step_up_if_blocked(body: CharacterBody3D, motion: Vector3) -> void:
	if not body.is_on_floor() or motion.is_zero_approx():
		return
	var probe := motion.normalized() * maxf(motion.length(), STEP_PROBE)
	var collision := KinematicCollision3D.new()
	if not body.test_move(body.global_transform, probe, collision) or _is_walkable(body, collision.get_normal()):
		return
	var lift := Vector3.UP * STEP_HEIGHT
	if body.test_move(body.global_transform, lift) or body.test_move(body.global_transform.translated(lift), probe):
		return
	body.global_position += lift


static func _is_walkable(body: CharacterBody3D, normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) <= body.floor_max_angle
