extends CharacterBody3D
class_name Enemy

const BLEND_TIME := 0.15
const AIRBORNE_DELAY := 0.15

@export var threat := 2
@export var walk_speed := 3.0
@export var run_speed := 6.5
@export var turn_speed := 8.0
@export var gravity_multiplier := 2.0

@export_group("Animations")
@export var idle_animation: StringName = &"general/Idle_A"
@export var walk_animation: StringName = &"movement_basic/Walking_A"
@export var run_animation: StringName = &"movement_basic/Running_A"
@export var fall_animation: StringName = &"movement_basic/Jump_Idle"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier

var move_direction := Vector3.ZERO
var running := false

var _air_time := 0.0


func _ready() -> void:
	_disable_held_collision()
	animation_player.play(idle_animation)
	animation_player.seek(randf() * animation_player.current_animation_length, true)


func _physics_process(delta: float) -> void:
	var direction := Vector3(move_direction.x, 0.0, move_direction.z).limit_length()
	var speed := run_speed if running else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_apply_gravity(delta)
	move_and_slide()
	_face(direction, delta)
	_play(_locomotion_animation(direction))


func _disable_held_collision() -> void:
	for body in find_children("*", "CollisionObject3D", true, false):
		if body != self:
			body.collision_layer = 0
			body.collision_mask = 0
			if body is Area3D:
				body.monitoring = false
				body.monitorable = false


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_air_time = 0.0
	else:
		velocity.y -= gravity * delta
		_air_time += delta


func _face(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _locomotion_animation(direction: Vector3) -> StringName:
	if _air_time >= AIRBORNE_DELAY:
		return fall_animation
	if direction.is_zero_approx():
		return idle_animation
	return run_animation if running else walk_animation


func _play(animation: StringName) -> void:
	if animation_player.current_animation != animation:
		animation_player.play(animation, BLEND_TIME)
