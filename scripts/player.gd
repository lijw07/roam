extends CharacterBody3D

signal animation_changed(animation: StringName)
signal item_released(item: Node3D)

enum Stance { STANDING, CROUCHING, CRAWLING }

const BLEND_TIME := 0.15
const RIGHT_HAND := &"handslot.r"
const LEFT_HAND := &"handslot.l"
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
const PICK_UP_GRAB_TIME := 0.5
const PICK_UP_HAND_OFFSET := Vector3(-0.36, 0.0, 0.43)
const PICK_UP_ALIGN_TIME := 0.2
const CHAIN_BLEND := 0.2
const COMBO_GRACE := 0.4
const LUNGE_DURATION := 0.7
const THROW_ANIMATION := &"general/Throw"
const USE_ITEM_ANIMATION := &"general/Use_Item"
const SPAWN_GROUND_ANIMATION := &"general/Spawn_Ground"
const SPAWN_AIR_ANIMATION := &"general/Spawn_Air"
const SPAWN_AIR_HEIGHT := 2.0
const AIRBORNE_DELAY := 0.15
const LANDING_AIR_TIME := 0.3
const STANCE_HEIGHT_RATIOS: Array[float] = [1.0, 0.94, 0.68]
const STANCE_LIBRARY := &"weapon_stance"
const UPPER_BODY_BONES: Array[StringName] = [
	&"chest", &"head",
	&"upperarm.l", &"lowerarm.l", &"wrist.l", &"hand.l", &"handslot.l",
	&"upperarm.r", &"lowerarm.r", &"wrist.r", &"hand.r", &"handslot.r",
]
const CANCEL_ACTIONS: Array[StringName] = [&"jump", &"dodge", &"crouch", &"crawl", &"attack"]

@export var walk_speed := 3.0
@export var run_speed := 6.5
@export var backwards_speed := 2.0
@export var strafe_speed := 4.5
@export var sneak_speed := 1.5
@export var crouch_run_speed := 3.0
@export var crawl_speed := 1.0
@export var dodge_speed := 6.0
@export var lunge_speed := 4.0
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
var held_item: Node3D = null
var shield: Shield = null

var _action: StringName = &""
var _action_cancellable := false
var _action_velocity := Vector3.ZERO
var _action_velocity_duration := INF
var _attacking := false
var _attack_queued := false
var _attack_step: AttackStep = null
var _combo_index := 0
var _combo_grace := 0.0
var _was_blocking := false
var _air_time := 0.0
var _idle_time := 0.0
var _capsule: CapsuleShape3D
var _standing_height := 0.0
var _hand_slots: Dictionary[StringName, BoneAttachment3D] = {}
var _pick_up_item: Node3D = null
var _held_hand := RIGHT_HAND
var _held_grip := Transform3D.IDENTITY
var _held_weapon: Weapon = null


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
	_update_held_item()
	_combo_grace = maxf(_combo_grace - delta, 0.0)
	var direction := _input_direction()
	_update_attack(direction)
	_lower_shield_if_released()
	if _action_cancellable and _has_new_input(direction):
		_end_action()
	if dead or is_acting():
		_move_with_action(delta)
	else:
		_move_with_input(direction, delta)
	_was_blocking = _is_blocking()


func is_acting() -> bool:
	return _action != &""


func current_animation() -> StringName:
	return StringName(animation_player.assigned_animation)


func interact() -> void:
	_perform(INTERACT_ANIMATION)


func pick_up(item: Node3D = null) -> void:
	if not _perform(PICK_UP_ANIMATION) or item == null:
		return
	_pick_up_item = item
	if not item is Shield:
		_held_hand = item.hand if item is Weapon else RIGHT_HAND
		_held_grip = item.grip() if item is Weapon else Transform3D.IDENTITY
	_align_hand_with(item.global_position)


func release_held_item() -> void:
	if held_item == null:
		return
	var item := held_item
	held_item = null
	_held_weapon = null
	item.reparent(get_parent())
	item_released.emit(item)


func release_shield() -> void:
	if shield == null:
		return
	var item := shield
	shield = null
	item.reparent(get_parent())
	item_released.emit(item)


func throw() -> void:
	_perform(THROW_ANIMATION)


func use_item() -> void:
	_perform(USE_ITEM_ANIMATION)


func take_hit() -> void:
	if dead:
		return
	if _is_blocking() and _can_react_with_shield():
		_start_action(shield.hit_animation)
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
		if _is_blocking() and not _was_blocking and direction.is_zero_approx():
			_start_action(shield.raise_animation, true)
			return
		if Input.is_action_just_pressed("attack") and _is_blocking():
			_start_action(shield.bash_animation)
			return
		if Input.is_action_just_pressed("attack") and _can_attack():
			_attack(direction)
			return
	var gait := _gait(direction)
	velocity.x = direction.x * gait.speed
	velocity.z = direction.z * gait.speed
	_apply_vertical_motion(delta)
	move_and_slide()
	if not _is_strafing():
		_face(direction, delta)
	_animate(direction, gait, delta)


func _update_held_item() -> void:
	_update_pick_up()
	_settle_held_item()


func _move_with_action(delta: float) -> void:
	var root_motion := skeleton.global_basis * animation_player.get_root_motion_position() / delta
	var action_velocity := _action_velocity if animation_player.current_animation_position < _action_velocity_duration else Vector3.ZERO
	velocity.x = action_velocity.x + root_motion.x
	velocity.z = action_velocity.z + root_motion.z
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


func _is_blocking() -> bool:
	return shield != null and _is_strafing()


func _can_react_with_shield() -> bool:
	return not is_acting() or _action in [shield.raise_animation, shield.hit_animation]


func _lower_shield_if_released() -> void:
	if shield != null and _action == shield.raise_animation and not _is_blocking():
		_end_action()


func _gait(direction: Vector3) -> Gait:
	var sprinting := Input.is_action_pressed("sprint") and not _is_blocking()
	match stance:
		Stance.CROUCHING:
			return Gait.new(CROUCH_RUN_ANIMATION, crouch_run_speed) if sprinting else Gait.new(SNEAK_ANIMATION, sneak_speed)
		Stance.CRAWLING:
			return Gait.new(CRAWL_ANIMATION, crawl_speed)
	if _is_strafing():
		return _strafe_gait(_to_local_direction(direction), sprinting)
	return _forward_gait(sprinting)


func _forward_gait(sprinting: bool) -> Gait:
	if sprinting:
		return Gait.new(_weapon_run_animation(), run_speed)
	return Gait.new(walk_animation, walk_speed)


func _weapon_run_animation() -> StringName:
	if _held_weapon != null and _held_weapon.run_animation != &"":
		return _held_weapon.run_animation
	return run_animation


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
		_play(_stanced(JUMP_START_ANIMATION), BLEND_TIME, JUMP_TAKEOFF_TIME)


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
		_play(_stanced(gait.animation))
	elif air_time >= LANDING_AIR_TIME and stance == Stance.STANDING:
		_start_action(_stanced(JUMP_LAND_ANIMATION), true)
	else:
		_animate_idle(delta)


func _animate_airborne() -> void:
	if _air_time < AIRBORNE_DELAY:
		return
	if current_animation() == _stanced(JUMP_START_ANIMATION) and animation_player.is_playing():
		return
	_play(_stanced(JUMP_AIR_ANIMATION))


func _animate_idle(delta: float) -> void:
	match stance:
		Stance.CROUCHING:
			_hold(_stanced(SNEAK_ANIMATION), SNEAK_HOLD_TIME)
		Stance.CRAWLING:
			_hold(CRAWL_ANIMATION, CRAWL_HOLD_TIME)
		Stance.STANDING:
			_animate_standing_idle(delta)


func _animate_standing_idle(delta: float) -> void:
	if _is_blocking():
		_play(shield.hold_animation)
		return
	if _held_weapon != null and _held_weapon.idle_animation != &"":
		_play(_held_weapon.idle_animation)
		return
	_idle_time += delta
	var fidget_length := animation_player.get_animation(fidget_animation).length
	if _idle_time >= fidget_delay + fidget_length:
		_idle_time = 0.0
	_play(fidget_animation if _idle_time >= fidget_delay else idle_animation)


func _dodge(direction: Vector3) -> void:
	var heading := -model.global_basis.z if direction.is_zero_approx() else direction.normalized()
	var animation := _dodge_animation(_to_local_direction(heading))
	_start_action(_stanced(animation), false, heading * dodge_speed)


func _dodge_animation(local_heading: Vector3) -> StringName:
	if absf(local_heading.x) > absf(local_heading.z):
		return DODGE_LEFT_ANIMATION if local_heading.x > 0.0 else DODGE_RIGHT_ANIMATION
	return DODGE_FORWARD_ANIMATION if local_heading.z > 0.0 else DODGE_BACKWARD_ANIMATION


func _can_attack() -> bool:
	return _held_weapon != null and _held_weapon.has_attacks()


func _attack(direction: Vector3) -> void:
	_set_stance(Stance.STANDING)
	_face_attack_direction(direction)
	if Input.is_action_pressed("sprint") and not direction.is_zero_approx() and _held_weapon.running_attack_animation != &"":
		_start_running_attack(direction)
		return
	if _combo_grace > 0.0:
		_continue_combo()
		return
	_combo_index = 0
	_start_attack_step(_held_weapon.combo[0], 0.0, BLEND_TIME)


func _start_running_attack(direction: Vector3) -> void:
	_start_action(_held_weapon.running_attack_animation, false, direction.normalized() * lunge_speed)
	_action_velocity_duration = LUNGE_DURATION
	_attacking = true
	_attack_queued = false
	_attack_step = null


func _face_attack_direction(direction: Vector3) -> void:
	if not direction.is_zero_approx() and not _is_strafing():
		model.rotation.y = atan2(direction.x, direction.z)


func _start_attack_step(step: AttackStep, from: float, blend: float) -> void:
	_start_action(step.animation, false, Vector3.ZERO, blend, from)
	_attacking = true
	_attack_queued = false
	_attack_step = step


func _update_attack(direction: Vector3) -> void:
	if not _attacking or _attack_step == null:
		return
	if Input.is_action_just_pressed("attack") and not _action_cancellable:
		_attack_queued = true
	var playback_time := animation_player.current_animation_position
	if _attack_queued and _has_next_attack_step() and playback_time >= _attack_step.combo_time:
		_chain_attack(direction)
	elif playback_time >= _attack_step.window_end and not _action_cancellable:
		_close_combo_window(direction)


func _has_next_attack_step() -> bool:
	return _combo_index + 1 < _held_weapon.combo.size()


func _chain_attack(direction: Vector3) -> void:
	_face_attack_direction(direction)
	_continue_combo()


func _continue_combo() -> void:
	_combo_index = _combo_index + 1 if _has_next_attack_step() else 0
	var step := _held_weapon.combo[_combo_index]
	_start_attack_step(step, step.chain_start, CHAIN_BLEND)


func _close_combo_window(direction: Vector3) -> void:
	if _attack_queued:
		_chain_attack(direction)
		return
	_action_cancellable = true
	_combo_grace = animation_player.current_animation_length - animation_player.current_animation_position + COMBO_GRACE


func _perform(animation: StringName) -> bool:
	if dead or (is_acting() and not _action_cancellable):
		return false
	_set_stance(Stance.STANDING)
	_start_action(animation)
	return true


func _align_hand_with(grip_position: Vector3) -> void:
	var hand_offset := PICK_UP_HAND_OFFSET * model.scale.x
	var to_grip := grip_position - global_position
	var yaw := atan2(to_grip.x, to_grip.z) - atan2(hand_offset.x, hand_offset.z)
	var target := grip_position - Basis(Vector3.UP, yaw) * hand_offset
	target.y = global_position.y
	var target_yaw := model.rotation.y + wrapf(yaw - model.rotation.y, -PI, PI)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(self, "global_position", target, PICK_UP_ALIGN_TIME)
	tween.tween_property(model, "rotation:y", target_yaw, PICK_UP_ALIGN_TIME)


func _update_pick_up() -> void:
	if _pick_up_item == null:
		return
	if _action != PICK_UP_ANIMATION or not is_instance_valid(_pick_up_item):
		_pick_up_item = null
		return
	if animation_player.current_animation_position < PICK_UP_GRAB_TIME:
		return
	var item := _pick_up_item
	_pick_up_item = null
	if item is Shield:
		_take_shield(item)
	else:
		_take_main_hand_item(item)


func _take_main_hand_item(item: Node3D) -> void:
	release_held_item()
	held_item = item
	_held_weapon = item as Weapon
	if not _allows_shield():
		release_shield()
	_attach_to_hand(item, RIGHT_HAND, _held_grip if _held_hand == RIGHT_HAND else Transform3D.IDENTITY)


func _take_shield(item: Shield) -> void:
	release_shield()
	if not _allows_shield():
		release_held_item()
	shield = item
	_attach_to_hand(item, LEFT_HAND, item.grip())


func _allows_shield() -> bool:
	return held_item == null or (_held_weapon != null and _held_weapon.allows_shield)


func _settle_held_item() -> void:
	if held_item == null or _action == PICK_UP_ANIMATION or held_item.get_parent() == _hand_slot(_held_hand):
		return
	_attach_to_hand(held_item, _held_hand, _held_grip)


func _attach_to_hand(item: Node3D, hand: StringName, grip: Transform3D) -> void:
	item.reparent(_hand_slot(hand), false)
	item.transform = grip


func _hand_slot(hand: StringName) -> BoneAttachment3D:
	if not _hand_slots.has(hand):
		var slot := BoneAttachment3D.new()
		slot.bone_name = hand
		skeleton.add_child(slot)
		_hand_slots[hand] = slot
	return _hand_slots[hand]


func _start_action(animation: StringName, cancellable := false, action_velocity := Vector3.ZERO, blend := BLEND_TIME, from := 0.0) -> void:
	_action = animation
	_action_cancellable = cancellable
	_action_velocity = action_velocity
	_action_velocity_duration = INF
	_attacking = false
	_attack_step = null
	_combo_grace = 0.0
	_idle_time = 0.0
	_play(animation, blend, from)


func _end_action() -> void:
	_action = &""
	_action_cancellable = false
	_action_velocity = Vector3.ZERO
	_action_velocity_duration = INF
	_attacking = false
	_attack_step = null


func _on_animation_finished(animation: StringName) -> void:
	if animation != _action:
		return
	var finished_combo_step := _attack_step != null
	_end_action()
	if finished_combo_step:
		_combo_grace = COMBO_GRACE
	if dead and DEATH_POSES.has(animation):
		_play(DEATH_POSES[animation], 0.0)


func _play(animation: StringName, blend := BLEND_TIME, from := -1.0) -> void:
	if from < 0.0 and _is_playing(animation):
		return
	animation_player.play(animation, blend)
	if from >= 0.0:
		animation_player.seek(from, true)
	animation_changed.emit(animation)


func _stanced(animation: StringName) -> StringName:
	var upper_body := _upper_body_animation()
	if upper_body == &"" or not _takes_upper_body(animation):
		return animation
	var stance_name := StringName("%s_with_%s" % [animation.get_file(), upper_body.get_file()])
	var path := StringName("%s/%s" % [STANCE_LIBRARY, stance_name])
	if not animation_player.has_animation(path):
		_stance_library().add_animation(stance_name, _with_upper_body(animation, upper_body))
	return path


func _upper_body_animation() -> StringName:
	if _is_blocking():
		return shield.hold_animation
	return _held_weapon.upper_body_animation if _held_weapon != null else &""


func _takes_upper_body(animation: StringName) -> bool:
	if animation == CRAWL_ANIMATION:
		return false
	return _held_weapon == null or animation not in [_held_weapon.idle_animation, _held_weapon.run_animation]


func _stance_library() -> AnimationLibrary:
	if not animation_player.has_animation_library(STANCE_LIBRARY):
		animation_player.add_animation_library(STANCE_LIBRARY, AnimationLibrary.new())
	return animation_player.get_animation_library(STANCE_LIBRARY)


func _with_upper_body(base_name: StringName, upper_name: StringName) -> Animation:
	var merged: Animation = animation_player.get_animation(base_name).duplicate(true)
	for track in range(merged.get_track_count() - 1, -1, -1):
		if _is_upper_body_track(merged, track):
			merged.remove_track(track)
	var upper := animation_player.get_animation(upper_name)
	var time_scale := merged.length / upper.length
	for track in upper.get_track_count():
		if _is_upper_body_track(upper, track):
			_copy_track(upper, track, merged, time_scale)
	return merged


func _is_upper_body_track(animation: Animation, track: int) -> bool:
	return StringName(animation.track_get_path(track).get_concatenated_subnames()) in UPPER_BODY_BONES


func _copy_track(source: Animation, track: int, target: Animation, time_scale: float) -> void:
	var copy := target.add_track(source.track_get_type(track))
	target.track_set_path(copy, source.track_get_path(track))
	target.track_set_interpolation_type(copy, source.track_get_interpolation_type(track))
	for key in source.track_get_key_count(track):
		target.track_insert_key(copy, source.track_get_key_time(track, key) * time_scale, source.track_get_key_value(track, key))


func _is_playing(animation: StringName) -> bool:
	return current_animation() == animation and animation_player.is_playing() and animation_player.get_playing_speed() > 0.0


func _hold(animation: StringName, time: float) -> void:
	if current_animation() == animation and is_zero_approx(animation_player.get_playing_speed()):
		return
	animation_player.play(animation, BLEND_TIME, 0.0)
	animation_player.seek(time, true)
	animation_changed.emit(animation)
