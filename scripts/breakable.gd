extends Node3D

@onready var health: Health = $Health


func _ready() -> void:
	health.died.connect(_break)


func _break() -> void:
	AudioManager.play_surface_impact(AudioManager.surface_for(self), global_position, 1.0)
	AudioManager.play("breakable_crack", global_position, Vector2(0.92, 1.08), -3.5)
	queue_free()
