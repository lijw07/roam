extends HurtboxWatcher

const SPREAD := 0.3
const BLOCKED_TEXT := "Blocked"
const WARM_UP_TEXT := "0123456789 Blocked"

@export var player: Node3D
@export var dealt_color := Color(1.0, 0.9, 0.5)
@export var taken_color := Color(1.0, 0.35, 0.3)
@export var blocked_color := Color(0.75, 0.8, 0.9)


func _ready() -> void:
	super()
	_warm_up_numbers.call_deferred()


func _on_hit_taken(_hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	if damage > 0.0:
		var color := taken_color if hurtbox.get_parent() == player else dealt_color
		_pop_over(str(roundi(damage)), color, hurtbox)


func _on_blocked(_hit: Hit, hurtbox: Hurtbox) -> void:
	_pop_over(BLOCKED_TEXT, blocked_color, hurtbox)


func _warm_up_numbers() -> void:
	if player != null:
		_pop(WARM_UP_TEXT, Color.TRANSPARENT, player.global_position)


func _pop_over(value: String, color: Color, hurtbox: Hurtbox) -> void:
	_pop(value, color, hurtbox.top() + Vector3(randf_range(-SPREAD, SPREAD), 0.0, randf_range(-SPREAD, SPREAD)))


func _pop(value: String, color: Color, at: Vector3) -> void:
	var number := FloatingNumber.new()
	add_child(number)
	number.pop(value, color, at)
