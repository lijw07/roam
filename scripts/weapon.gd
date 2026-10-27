extends Area3D
class_name Weapon

@export var hand: StringName = &"handslot.r"
@export var grip_rotation_degrees := Vector3.ZERO
@export var combo: Array[AttackStep] = []
@export var running_attack_animation: StringName = &""

@export_group("Stance")
@export var idle_animation: StringName = &""
@export var run_animation: StringName = &""
@export var upper_body_animation: StringName = &""


func grip() -> Transform3D:
	return Transform3D(Basis.from_euler(grip_rotation_degrees * (PI / 180.0)), Vector3.ZERO)


func has_attacks() -> bool:
	return not combo.is_empty()
