extends Resource
class_name AttackStep

@export var animation: StringName = &""
@export var combo_time := 0.0
@export var window_end := 0.0
@export var chain_start := 0.0
@export var continues_automatically := false
@export var mirrored := false
@export var uses_legs := false
@export var projectile_time := -1.0
@export var hit_start := -1.0
@export var hit_end := -1.0


func is_striking_at(time: float) -> bool:
	return hit_start >= 0.0 and time >= hit_start and time <= hit_end
