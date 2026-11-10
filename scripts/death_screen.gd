extends Control

signal finished

const DEATH_ANIMATION_TIME := 1.5
const BLACKOUT_TIME := 1.0
const MESSAGE_FADE_IN := 0.8
const MESSAGE_HOLD := 1.6
const MESSAGE_FADE_OUT := 0.8

@onready var blackout: ColorRect = %Blackout
@onready var message: Label = %Message


func _ready() -> void:
	hide()


func play() -> void:
	blackout.modulate.a = 0.0
	message.modulate.a = 0.0
	show()
	var sequence := create_tween()
	sequence.tween_interval(DEATH_ANIMATION_TIME)
	sequence.tween_property(blackout, "modulate:a", 1.0, BLACKOUT_TIME)
	sequence.tween_property(message, "modulate:a", 1.0, MESSAGE_FADE_IN)
	sequence.tween_interval(MESSAGE_HOLD)
	sequence.tween_property(message, "modulate:a", 0.0, MESSAGE_FADE_OUT)
	sequence.tween_callback(finished.emit)
