extends Area3D
class_name Shield

@export var grip_rotation_degrees := Vector3.ZERO
@export var grip_offset := Vector3(0.0, 0.0, 0.145)
@export var raise_animation: StringName = &"combat_melee/Melee_Block"
@export var hold_animation: StringName = &"combat_melee/Melee_Blocking"
@export var hit_animation: StringName = &"combat_melee/Melee_Block_Hit"
@export var bash_animation: StringName = &"combat_melee/Melee_Block_Attack"


func grip() -> Transform3D:
	return Transform3D(Basis.from_euler(grip_rotation_degrees * (PI / 180.0)), grip_offset)
