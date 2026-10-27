extends CharacterBody3D

signal animation_changed(animation: StringName)

enum Stance { STANDING, CROUCHING, CRAWLING }

const BLEND_TIME := 0.15
const ROOT_MOTION_TRACK := ^"Rig_Medium/Skeleton3D:root"
const SKELETON_PATH := ^"Model/Rig_Medium/Skeleton3D"
const JUMP_START_ANIMATION := &"movement_basic/Jump_Start"
const JUMP_AIR_ANIMATION := &"movement_basic/Jump_Idle"
const JUMP_LAND_ANIMATION := &"movement_basic/Jump_Land"
const JUMP_TAKEOFF_TIME := 0.27
const WALK_BACKWARDS_ANIMATION := &"movement_advanced/Walking_Backwards"
const STRAFE_LEFT_ANIMATION := &"movement_advanced/Running_Strafe_Left"
const STRAFE_RIGHT_ANIMATION := &"movement_advanced/Running_Strafe_Right"
const SNEAK_ANIMATION := &"movement_advanced/Sneaking"
const SNEAK_HOLD_TIME := 0.72
const CROUCH_RUN_ANIMATION := &"movement_advanced/Crouching"
const CRAWL_ANIMATION := &"movement_advanced/Crawling"
const CRAWL_HOLD_TIME := 0.28
const DODGE_FORWARD_ANIMATION := &"movement_advanced/Dodge_Forward"
const DODGE_BACKWARD_ANIMATION := &"movement_advanced/Dodge_Backward"
const DODGE_LEFT_ANIMATION := &"movement_advanced/Dodge_Left"
const DODGE_RIGHT_ANIMATION := &"movement_advanced/Dodge_Right"
const HIT_ANIMATIONS: Array[StringName] = [&"general/Hit_A", &"general/Hit_B"]
const DEATH_POSES := {
	&"general/Death_A": &"general/Death_A_Pose",
	&"general/Death_B": &"general/Death_B_Pose",
}
const INTERACT_ANIMATION := &"general/Interact"
const PICK_UP_ANIMATION := &"general/PickUp"
const THROW_ANIMATION := &"general/Throw"
const USE_ITEM_ANIMATION := &"general/Use_Item"
const SPAWN_GROUND_ANIMATION := &"general/Spawn_Ground"
const SPAWN_AIR_ANIMATION := &"general/Spawn_Air"
const SPAWN_AIR_HEIGHT := 2.0
const AIRBORNE_DELAY := 0.15
const LANDING_AIR_TIME := 0.3
const STANCE_HEIGHT_RATIOS: Array[float] = [1.0, 0.94, 0.68]
const CANCEL_ACTIONS: Array[StringName] = [&"jump", &"dodge", &"crouch", &"crawl"]

@export var walk_speed := 3.0
@export var run_speed := 6.5
@export var backwards_speed := 2.0
@export var strafe_speed := 4.5
@export var sneak_speed := 1.5
@export var crouch_run_speed := 3.0
@export var crawl_speed := 1.0
@export var dodge_speed := 6.0
@export var jump_velocity := 8.0
@export var turn_speed := 12.0
@export var gravity_multiplier := 2.0
@export var fidget_delay := 6.0

@export_group("Animations")
@export var idle_animation: StringName = &"general/Idle_A"
@export var fidget_animation: StringName = &"general/Idle_B"
@export var walk_animation: StringName = &"movement_basic/Walking_A"
@export var run_animation: StringName = &"movement_basic/Running_A"

@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton3D = get_node(SKELETON_PATH)
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier

var stance := Stance.STANDING
var dead := false

var _action: StringName = &""
var _action_cancellable := false
var _action_velocity := Vector3.ZERO
var _air_time := 0.0
var _idle_time := 0.0
var _capsule: CapsuleShape3D
var _standing_height := 0.0


class Gait:
	var animation: StringName
	var speed: float

	func _init(gait_animation: StringName, gait_speed: float) -> void:
		animation = gait_animation
		speed = gait_speed


func _ready() -> void:
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	animation_player.root_motion_track = ROOT_MOTION_TRACK
	animation_player.animation_finished.connect(_on_animation_finished)
	_capsule = collision_shape.shape.duplicate()
	collision_shape.shape = _capsule
	_standing_height = _capsule.height


func _physics_process(delta: float) -> void:
	var direction := _input_direction()
	if _action_cancellable and _has_new_input(direction):
		_end_action()
	if dead or is_acting():
		_move_with_action(delta)
	else:
		_move_with_input(direction, delta)


func is_acting() -> bool:
	return _action != &""


func current_animation() -> StringName:
	return StringName(animation_player.assigned_animation)


func interact() -> void:
	_perform(INTERACT_ANIMATION)


func pick_up() -> void:
	_perform(PICK_UP_ANIMATION)


func throw() -> void:
	_perform(THROW_ANIMATION)


func use_item() -> void:
	_perform(USE_ITEM_ANIMATION)


func take_hit() -> void:
	if dead:
		return
	_set_stance(Stance.STANDING)
	_start_action(HIT_ANIMATIONS.pick_random())


func die() -> void:
	if dead:
		return
	dead = true
	_set_stance(Stance.STANDING)
	_start_action(DEATH_POSES.keys().pick_random())


func spawn(from_air := false) -> void:
	dead = false
	_set_stance(Stance.STANDING)
	velocity = Vector3.ZERO
	if from_air:
		global_position.y += SPAWN_AIR_HEIGHT
	_start_action(SPAWN_AIR_ANIMATION if from_air else SPAWN_GROUND_ANIMATION, false, Vector3.ZERO, 0.0)


func preview(animation: StringName) -> void:
	if dead or not animation_player.has_animation(animation):
		return
	_set_stance(Stance.STANDING)
	_start_action(animation, true)


func _has_new_input(direction: Vector3) -> bool:
	if not direction.is_zero_approx():
		return true
	return CANCEL_ACTIONS.any(func(action: StringName) -> bool: return Input.is_action_just_pressed(action))


func _input_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Vector3(input.x, 0.0, input.y)


func _move_with_input(direction: Vector3, delta: float) -> void:
	if is_on_floor():
		_update_stance()
		if stance == Stance.STANDING and Input.is_action_just_pressed("dodge"):
			_dodge(direction)
			return
	var gait := _gait(direction)
	velocity.x = direction.x * gait.speed
	velocity.z = direction.z * gait.speed
	_apply_vertical_motion(delta)
	move_and_slide()
	if not _is_strafing():
		_face(direction, delta)
	_animate(direction, gait, delta)


func _move_with_action(delta: float) -> void:
	var root_motion := skeleton.global_basis * animation_player.get_root_motion_position() / delta
	velocity.x = _action_velocity.x + root_motion.x
	velocity.z = _action_velocity.z + root_motion.z
	if _action == SPAWN_AIR_ANIMATION:
		velocity.y = root_motion.y
	elif not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


func _update_stance() -> void:
	if Input.is_action_just_pressed("crouch"):
		_set_stance(Stance.STANDING if stance == Stance.CROUCHING else Stance.CROUCHING)
	elif Input.is_action_just_pressed("crawl"):
		_set_stance(Stance.STANDING if stance == Stance.CRAWLING else Stance.CRAWLING)


func _set_stance(new_stance: Stance) -> void:
	var height := _standing_height * STANCE_HEIGHT_RATIOS[new_stance]
	var growth := height - _capsule.height
	if growth > 0.0 and test_move(global_transform, Vector3.UP * growth):
		return
	stance = new_stance
	_capsule.height = height
	collision_shape.position.y = height / 2.0


func _is_strafing() -> bool:
	return stance == Stance.STANDING and Input.is_action_pressed("secondary")


func _gait(direction: Vector3) -> Gait:
	var sprinting := Input.is_action_pressed("sprint")
	match stance:
		Stance.CROUCHING:
			return Gait.new(CROUCH_RUN_ANIMATION, crouch_run_speed) if sprinting else Gait.new(SNEAK_ANIMATION, sneak_speed)
		Stance.CRAWLING:
			return Gait.new(CRAWL_ANIMATION, crawl_speed)
	if _is_strafing():
		return _strafe_gait(_to_local_direction(direction), sprinting)
	return _forward_gait(sprinting)


func _forward_gait(sprinting: bool) -> Gait:
	return Gait.new(run_animation, run_speed) if sprinting else Gait.new(walk_animation, walk_speed)


func _strafe_gait(local_direction: Vector3, sprinting: bool) -> Gait:
	if absf(local_direction.x) > absf(local_direction.z):
		return Gait.new(STRAFE_LEFT_ANIMATION if local_direction.x > 0.0 else STRAFE_RIGHT_ANIMATION, strafe_speed)
	if local_direction.z < 0.0:
		return Gait.new(WALK_BACKWARDS_ANIMATION, backwards_speed)
	return _forward_gait(sprinting)


func _to_local_direction(direction: Vector3) -> Vector3:
	return model.global_basis.inverse() * direction


func _apply_vertical_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		_air_time += delta
	elif stance == Stance.STANDING and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		_air_time = AIRBORNE_DELAY
		_play(JUMP_START_ANIMATION, BLEND_TIME, JUMP_TAKEOFF_TIME)


func _face(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var target_yaw := atan2(direction.x, direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _animate(direction: Vector3, gait: Gait, delta: float) -> void:
	if not is_on_floor():
		_animate_airborne()
		return
	var air_time := _air_time
	_air_time = 0.0
	if not direction.is_zero_approx():
		_idle_time = 0.0
		_play(gait.animation)
	elif air_time >= LANDING_AIR_TIME and stance == Stance.STANDING:
		_start_action(JUMP_LAND_ANIMATION, true)
	else:
		_animate_idle(delta)


func _animate_airborne() -> void:
	if _air_time < AIRBORNE_DELAY:
		return
	if current_animation() == JUMP_START_ANIMATION and animation_player.is_playing():
		return
	_play(JUMP_AIR_ANIMATION)


func _animate_idle(delta: float) -> void:
	match stance:
		Stance.CROUCHING:
			_hold(SNEAK_ANIMATION, SNEAK_HOLD_TIME)
		Stance.CRAWLING:
			_hold(CRAWL_ANIMATION, CRAWL_HOLD_TIME)
		Stance.STANDING:
			_animate_standing_idle(delta)


func _animate_standing_idle(delta: float) -> void:
	_idle_time += delta
	var fidget_length := animation_player.get_animation(fidget_animation).length
	if _idle_time >= fidget_delay + fidget_length:
		_idle_time = 0.0
	_play(fidget_animation if _idle_time >= fidget_delay else idle_animation)


func _dodge(direction: Vector3) -> void:
	var heading := -model.global_basis.z if direction.is_zero_approx() else direction.normalized()
	var animation := _dodge_animation(_to_local_direction(heading))
	_start_action(animation, false, heading * dodge_speed)


func _dodge_animation(local_heading: Vector3) -> StringName:
	if absf(local_heading.x) > absf(local_heading.z):
		return DODGE_LEFT_ANIMATION if local_heading.x > 0.0 else DODGE_RIGHT_ANIMATION
	return DODGE_FORWARD_ANIMATION if local_heading.z > 0.0 else DODGE_BACKWARD_ANIMATION


func _perform(animation: StringName) -> void:
	if dead or (is_acting() and not _action_cancellable):
		return
	_set_stance(Stance.STANDING)
	_start_action(animation)


func _start_action(animation: StringName, cancellable := false, action_velocity := Vector3.ZERO, blend := BLEND_TIME) -> void:
	_action = animation
	_action_cancellable = cancellable
	_action_velocity = action_velocity
	_idle_time = 0.0
	_play(animation, blend, 0.0)


func _end_action() -> void:
	_action = &""
	_action_cancellable = false
	_action_velocity = Vector3.ZERO


func _on_animation_finished(animation: StringName) -> void:
	if animation != _action:
		return
	_end_action()
	if dead and DEATH_POSES.has(animation):
		_play(DEATH_POSES[animation], 0.0)


func _play(animation: StringName, blend := BLEND_TIME, from := -1.0) -> void:
	if from < 0.0 and _is_playing(animation):
		return
	animation_player.play(animation, blend)
	if from >= 0.0:
		animation_player.seek(from, true)
	animation_changed.emit(animation)


func _is_playing(animation: StringName) -> bool:
	return current_animation() == animation and animation_player.is_playing() and animation_player.get_playing_speed() > 0.0


func _hold(animation: StringName, time: float) -> void:
	if current_animation() == animation and is_zero_approx(animation_player.get_playing_speed()):
		return
	animation_player.play(animation, BLEND_TIME, 0.0)
	animation_player.seek(time, true)
	animation_changed.emit(animation)
