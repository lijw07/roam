extends Node3D

@onready var health: Health = $Health


func _ready() -> void:
	health.died.connect(queue_free)
