class_name Crosshair
extends Control

const ARMS: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]

@export var color := Color(1.0, 1.0, 1.0, 0.85)
@export var gap := 4.0
@export var arm_length := 7.0
@export var thickness := 2.0


func _draw() -> void:
	for arm in ARMS:
		draw_line(arm * gap, arm * (gap + arm_length), color, thickness)
	draw_circle(Vector2.ZERO, thickness * 0.5, color)
