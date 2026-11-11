class_name ShoulderCamera
extends Node3D

@export var player: Node3D
@export var shoulder_boom: SpringArm3D
@export var camera_boom: SpringArm3D
@export var camera: Camera3D
@export var transition_speed := 10.0

@export_group("Explore")
@export var explore_distance := 4.0
@export var explore_shoulder := 1.0
@export var explore_fov := 65.0

@export_group("Melee")
@export var melee_distance := 4.4
@export var melee_shoulder := 0.25

@export_group("Aim")
@export var aim_distance := 2.2
@export var aim_shoulder := 0.8
@export var aim_fov := 48.0


func _ready() -> void:
	camera_boom.spring_length = explore_distance
	shoulder_boom.spring_length = explore_shoulder
	camera.fov = explore_fov


func _process(delta: float) -> void:
	var aiming := _player_aiming()
	var melee := not aiming and _player_fights_in_melee()
	var blend := 1.0 - exp(-transition_speed * delta)
	var distance := aim_distance if aiming else melee_distance if melee else explore_distance
	var shoulder := aim_shoulder if aiming else melee_shoulder if melee else explore_shoulder
	camera_boom.spring_length = lerpf(camera_boom.spring_length, distance, blend)
	shoulder_boom.spring_length = lerpf(shoulder_boom.spring_length, shoulder, blend)
	camera.fov = lerpf(camera.fov, aim_fov if aiming else explore_fov, blend)


func look_scale() -> float:
	return camera.fov / explore_fov


func _player_fights_in_melee() -> bool:
	return is_instance_valid(player) and player.has_method(&"fights_in_melee") and player.fights_in_melee()


func _player_aiming() -> bool:
	return is_instance_valid(player) and player.has_method(&"is_aiming") and player.is_aiming()
