extends Control

signal finished

const BANNER_FADE_TIME := 0.6
const HOLD_TIME := 2.5
const BLACKOUT_TIME := 0.8

@onready var banner: Control = %Banner
@onready var blackout: ColorRect = %Blackout


func _ready() -> void:
	hide()


func play() -> void:
	banner.modulate.a = 0.0
	blackout.modulate.a = 0.0
	show()
	var sequence := create_tween()
	sequence.tween_property(banner, "modulate:a", 1.0, BANNER_FADE_TIME)
	sequence.tween_interval(HOLD_TIME)
	sequence.tween_property(blackout, "modulate:a", 1.0, BLACKOUT_TIME)
	sequence.tween_callback(finished.emit)
