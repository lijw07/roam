extends HurtboxWatcher

const SPREAD := 0.3
const BLOCKED_TEXT := "Blocked"

@export var player: Node3D
@export var dealt_color := Color(1.0, 0.9, 0.5)
@export var taken_color := Color(1.0, 0.35, 0.3)
@export var blocked_color := Color(0.75, 0.8, 0.9)

func _on_hit_taken(_hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	if damage > 0.0:
		var color := taken_color if hurtbox.get_parent() == player else dealt_color
		_pop(str(roundi(damage)), color, hurtbox)


func _on_blocked(_hit: Hit, hurtbox: Hurtbox) -> void:
	_pop(BLOCKED_TEXT, blocked_color, hurtbox)


func _pop(value: String, color: Color, hurtbox: Hurtbox) -> void:
	var number := FloatingNumber.new()
	add_child(number)
	number.pop(value, color, hurtbox.top() + Vector3(randf_range(-SPREAD, SPREAD), 0.0, randf_range(-SPREAD, SPREAD)))
