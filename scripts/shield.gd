extends Area3D
class_name Shield

@export var grip_rotation_degrees := Vector3.ZERO
@export var grip_offset := Vector3(0.0, 0.0, 0.145)
@export var raise_animation: StringName = &"combat_melee/Melee_Block"
@export var hold_animation: StringName = &"combat_melee/Melee_Blocking"
@export var hit_animation: StringName = &"combat_melee/Melee_Block_Hit"
@export var bash_animation: StringName = &"combat_melee/Melee_Block_Attack"
@export var bash_damage := 8.0
@export var bash_hit_start := 0.32
@export var bash_hit_end := 0.45
@export_range(0.0, 180.0) var block_arc_degrees := 120.0


func _ready() -> void:
	set_collision_mask_value(Hurtbox.LAYER, true)


func bash_strikes_at(time: float) -> bool:
	return time >= bash_hit_start and time <= bash_hit_end


func grip() -> Transform3D:
	return Transform3D(Basis.from_euler(grip_rotation_degrees * (PI / 180.0)), grip_offset)
