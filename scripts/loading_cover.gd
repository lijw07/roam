extends ColorRect

const HOLD_FRAMES := 20
const HOLD_TIME := 0.5
const FADE_TIME := 0.3


func _ready() -> void:
	_reveal()


func _reveal() -> void:
	var hold := get_tree().create_timer(HOLD_TIME)
	for _frame in HOLD_FRAMES:
		await get_tree().process_frame
	if hold.time_left > 0.0:
		await hold.timeout
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	fade.tween_callback(get_parent().queue_free)
