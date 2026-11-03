class_name FloatingNumber
extends Label3D

const RISE := 0.9
const DURATION := 0.8
const FADE_START := 0.5


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = 0.0008
	font_size = 40
	outline_size = 10
	outline_modulate = Color.BLACK


func pop(value: String, color: Color, at: Vector3) -> void:
	text = value
	modulate = color
	global_position = at
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "global_position:y", at.y + RISE, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, DURATION * (1.0 - FADE_START)).set_delay(DURATION * FADE_START)
	tween.chain().tween_callback(queue_free)
