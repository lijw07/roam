extends CharacterBody3D

const IDLE_ANIMATION := &"general/Idle_A"
const WALK_ANIMATION := &"movement_basic/Walking_A"
const RUN_ANIMATION := &"movement_basic/Running_A"
const JUMP_ANIMATION := &"movement_basic/Jump_Idle"
const BLEND_TIME := 0.15

@export var walk_speed := 3.0
@export var run_speed := 6.5
@export var jump_velocity := 8.0
@export var turn_speed := 12.0
@export var gravity_multiplier := 2.0

@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier


func _physics_process(delta: float) -> void:
	var direction := _input_direction()
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_apply_vertical_motion(delta)
	move_and_slide()
	_face(direction, delta)
	_play(_current_animation(direction))


func _input_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Vector3(input.x, 0.0, input.y)


func _apply_vertical_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity


func _face(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var target_yaw := atan2(direction.x, direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _current_animation(direction: Vector3) -> StringName:
	if not is_on_floor():
		return JUMP_ANIMATION
	if direction.is_zero_approx():
		return IDLE_ANIMATION
	return RUN_ANIMATION if Input.is_action_pressed("sprint") else WALK_ANIMATION


func _play(animation: StringName) -> void:
	if animation_player.current_animation != animation:
		animation_player.play(animation, BLEND_TIME)
