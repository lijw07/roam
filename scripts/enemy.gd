extends CharacterBody3D
class_name Enemy

const BLEND_TIME := 0.15
const AIRBORNE_DELAY := 0.15
const HIT_ANIMATIONS: Array[StringName] = [&"general/Hit_A", &"general/Hit_B"]
const DEATH_POSES := {
	&"general/Death_A": &"general/Death_A_Pose",
	&"general/Death_B": &"general/Death_B_Pose",
}

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
@onready var health := get_node_or_null(^"Health") as Health
@onready var hurtbox := get_node_or_null(^"Hurtbox") as Hurtbox

var move_direction := Vector3.ZERO
var running := false
var dead := false

var _air_time := 0.0
var _reaction: StringName = &""


func _ready() -> void:
	_disable_held_collision()
	_connect_health()
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play(idle_animation)
	animation_player.seek(randf() * animation_player.current_animation_length, true)


func _physics_process(delta: float) -> void:
	if dead or _reaction != &"":
		_hold_still(delta)
		return
	var direction := Vector3(move_direction.x, 0.0, move_direction.z).limit_length()
	var speed := run_speed if running else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_apply_gravity(delta)
	move_and_slide()
	_face(direction, delta)
	_play(_locomotion_animation(direction))


func take_hit() -> void:
	if not dead:
		_react(HIT_ANIMATIONS.pick_random())


func die() -> void:
	if health != null:
		health.kill()
	else:
		_play_death()


func _connect_health() -> void:
	if health != null:
		health.died.connect(_play_death)
	if hurtbox != null:
		hurtbox.hit_taken.connect(_on_hit_taken)


func _on_hit_taken(_hit: Hit, damage: float) -> void:
	if damage > 0.0:
		take_hit()


func _play_death() -> void:
	if dead:
		return
	dead = true
	_react(DEATH_POSES.keys().pick_random())


func _react(animation: StringName) -> void:
	_reaction = animation
	animation_player.play(animation, BLEND_TIME)


func _on_animation_finished(animation: StringName) -> void:
	if animation != _reaction:
		return
	if dead:
		animation_player.play(DEATH_POSES[animation], 0.0)
		return
	_reaction = &""


func _hold_still(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()


func _disable_held_collision() -> void:
	for body in find_children("*", "CollisionObject3D", true, false):
		if body != self and not (body is Hurtbox):
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
