extends CharacterBody3D
class_name Enemy

## An enemy DungeonGenerator can spawn into rooms. Stands in its idle animation.

## How much of a room's enemy budget this enemy uses up.
@export var threat := 2
@export var idle_animation: StringName = &"general/Idle_A"

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	# Held weapons come with their own collision (their scene roots are collision objects);
	# switch it off so the enemy's capsule is its only body.
	for body in find_children("*", "CollisionObject3D", true, false):
		if body != self:
			body.collision_layer = 0
			body.collision_mask = 0
			if body is Area3D:
				body.monitoring = false
				body.monitorable = false
	animation_player.play(idle_animation)
	# Start each idle at a different point so a room of enemies doesn't sway in step.
	animation_player.seek(randf() * animation_player.current_animation_length, true)
