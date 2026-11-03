extends Area3D
class_name Weapon

const FLIP_FOREARM_AXIS := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
const FLIP_THICKNESS_AXIS := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))

@export var hand: StringName = &"handslot.r"
@export var damage := 10.0
@export var grip_rotation_degrees := Vector3.ZERO
@export var combo: Array[AttackStep] = []
@export var secondary_combo: Array[AttackStep] = []
@export var running_attack_animation: StringName = &""
@export var running_attack_hit_start := -1.0
@export var running_attack_hit_end := -1.0
@export var allows_shield := false
@export var dual_wieldable := false
@export var worn_on_both_hands := false
@export var projectile: PackedScene
@export var secondary_projectile: PackedScene
@export var projectile_origin := Vector3.ZERO

@export_group("Stance")
@export var idle_animation: StringName = &""
@export var run_animation: StringName = &""
@export var upper_body_animation: StringName = &""

@export_group("Ranged")
@export var aim_animation: StringName = &""
@export var aim_start := 0.0
@export var aim_ready_time := 0.0
@export var aim_hold_animation: StringName = &""
@export var shot_animations: Array[StringName] = []
@export var aimed_shot_start := 0.0
@export var aim_return_time := 0.0
@export var shot_release_time := -1.0


func _ready() -> void:
	set_collision_mask_value(Hurtbox.LAYER, true)


func is_ranged() -> bool:
	return aim_animation != &""


func running_attack_strikes_at(time: float) -> bool:
	return running_attack_hit_start >= 0.0 and time >= running_attack_hit_start and time <= running_attack_hit_end


func grip() -> Transform3D:
	return Transform3D(Basis.from_euler(grip_rotation_degrees * (PI / 180.0)), Vector3.ZERO)


func off_hand_grip() -> Transform3D:
	return Transform3D(FLIP_FOREARM_AXIS * grip().basis * FLIP_THICKNESS_AXIS, Vector3.ZERO)
