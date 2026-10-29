extends Area3D
class_name Weapon

const FLIP_FOREARM_AXIS := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
const FLIP_THICKNESS_AXIS := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))

@export var hand: StringName = &"handslot.r"
@export var grip_rotation_degrees := Vector3.ZERO
@export var combo: Array[AttackStep] = []
@export var running_attack_animation: StringName = &""
@export var allows_shield := false
@export var dual_wieldable := false

@export_group("Stance")
@export var idle_animation: StringName = &""
@export var run_animation: StringName = &""
@export var upper_body_animation: StringName = &""


func grip() -> Transform3D:
	return Transform3D(Basis.from_euler(grip_rotation_degrees * (PI / 180.0)), Vector3.ZERO)


func off_hand_grip() -> Transform3D:
	return Transform3D(FLIP_FOREARM_AXIS * grip().basis * FLIP_THICKNESS_AXIS, Vector3.ZERO)
