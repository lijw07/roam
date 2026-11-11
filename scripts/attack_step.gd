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
@export var extra_hit_windows: Array[Vector2] = []


func is_striking_at(time: float) -> bool:
	return hit_window_at(time) >= 0


func hit_window_at(time: float) -> int:
	if hit_start >= 0.0 and time >= hit_start and time <= hit_end:
		return 0
	for index in extra_hit_windows.size():
		var window := extra_hit_windows[index]
		if time >= window.x and time <= window.y:
			return index + 1
	return -1
