extends CharacterBody3D

signal animation_changed(animation: StringName)
signal item_released(item: Node3D)

const BLEND_TIME := 0.15
const RIGHT_HAND := &"handslot.r"
const LEFT_HAND := &"handslot.l"
const SKELETON_PATH := ^"Model/Rig_Medium/Skeleton3D"
const JUMP_START_ANIMATION := &"movement_basic/Jump_Start"
const JUMP_AIR_ANIMATION := &"movement_basic/Jump_Idle"
const JUMP_LAND_ANIMATION := &"movement_basic/Jump_Land"
const JUMP_TAKEOFF_TIME := 0.27
const WALK_BACKWARDS_ANIMATION := &"movement_advanced/Walking_Backwards"
const BACKWARD_ARC := deg_to_rad(100.0)
const MAX_TWIST := deg_to_rad(90.0)
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
const AIRBORNE_DELAY := 0.15
const LANDING_AIR_TIME := 0.3
const STANCE_LIBRARY := &"weapon_stance"
const UPPER_BODY_BONES: Array[StringName] = [
	&"chest", &"head",
	&"upperarm.l", &"lowerarm.l", &"wrist.l", &"hand.l", &"handslot.l",
	&"upperarm.r", &"lowerarm.r", &"wrist.r", &"hand.r", &"handslot.r",
]
const ROOT_TRACK := ^"Rig_Medium/Skeleton3D:root"
const HIPS_TRACK := ^"Rig_Medium/Skeleton3D:hips"
const IN_PLACE_LIBRARY := &"in_place"
const MIRRORED_LIBRARY := &"mirrored"
const AIM_HOLD_LIBRARY := &"aim_hold"
const MIRROR_ACROSS_X := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)), Vector3.ZERO)
const BONE_TRACK_TYPES: Array[Animation.TrackType] = [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
const SPINE_TRACK := ^"Rig_Medium/Skeleton3D:spine"
const LAYER_SAMPLE_STEP := 1.0 / 30.0
const CANCEL_ACTIONS: Array[StringName] = [&"jump", &"dodge", &"attack"]

@export var walk_speed := 3.0
@export var run_speed := 6.5
@export var backwards_speed := 2.5
@export var dodge_speed := 6.0
@export var lunge_speed := 4.0
@export var jump_velocity := 8.0
@export var turn_speed := 12.0
@export var gravity_multiplier := 2.0
@export var fidget_delay := 6.0

@export var unarmed_combo: Array[AttackStep] = [
	preload("res://resources/attacks/unarmed/punch.tres"),
	preload("res://resources/attacks/unarmed/kick.tres"),
]
@export var dual_wield_combo: Array[AttackStep] = [
	preload("res://resources/attacks/dual_wield/chop.tres"),
	preload("res://resources/attacks/dual_wield/stab.tres"),
	preload("res://resources/attacks/dual_wield/slice.tres"),
]

@export_group("Animations")
@export var idle_animation: StringName = &"general/Idle_A"
@export var fidget_animation: StringName = &"general/Idle_B"
@export var walk_animation: StringName = &"movement_basic/Walking_A"
@export var run_animation: StringName = &"movement_basic/Running_A"

@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton3D = get_node(SKELETON_PATH)
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier

var dead := false
var held_item: Node3D = null
var shield: Shield = null
var off_hand_weapon: Weapon = null

var _action: StringName = &""
var _action_cancellable := false
var _action_velocity := Vector3.ZERO
var _action_velocity_duration := INF
var _attacking := false
var _attack_queued := false
var _attack_step: AttackStep = null
var _combo_index := 0
var _attack_combo: Array[AttackStep] = []
var _attack_input := &"attack"
var _combo_grace := 0.0
var _shield_raised := false
var _aim_raised := false
var _shot_queued := false
var _shot_step := -1
var _air_time := 0.0
var _idle_time := 0.0
var _hand_slots: Dictionary[StringName, BoneAttachment3D] = {}
var _pick_up_item: Node3D = null
var _pick_up_animation := PICK_UP_ANIMATION
var _held_weapon: Weapon = null
var _upper_body_twist := UpperBodyTwist.new()
var _facing_yaw := 0.0


class Gait:
	var animation: StringName
	var speed: float
	var facing_offset: float

	func _init(gait_animation: StringName, gait_speed: float, gait_facing_offset := 0.0) -> void:
		animation = gait_animation
		speed = gait_speed
		facing_offset = gait_facing_offset


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	skeleton.add_child(_upper_body_twist)
	_facing_yaw = model.rotation.y


func _physics_process(delta: float) -> void:
	_update_pick_up()
	_combo_grace = maxf(_combo_grace - delta, 0.0)
	var direction := _input_direction()
	_update_attack()
	_update_aim_raise()
	_update_aim_return()
	_lower_shield_if_released()
	if _action_cancellable and _has_new_input(direction):
		_end_action()
	if dead or is_acting():
		_move_with_action(delta)
	else:
		_move_with_input(direction, delta)
	_update_facing(direction, delta)
	_update_upper_body_twist(direction, delta)
	if not _is_blocking():
		_shield_raised = false
	if not _is_aiming():
		_aim_raised = false


func is_acting() -> bool:
	return _action != &""


func current_animation() -> StringName:
	return StringName(animation_player.assigned_animation)


func interact() -> void:
	_perform(INTERACT_ANIMATION)


func pick_up(item: Node3D = null) -> void:
	var with_left_hand := _pick_up_hand(item) == LEFT_HAND
	var animation := _mirrored(PICK_UP_ANIMATION) if with_left_hand else PICK_UP_ANIMATION
	if not _perform(animation):
		return
	_pick_up_animation = animation
	if item == null:
		return
	_pick_up_item = item
	_align_hand_with(item.global_position, MIRROR_ACROSS_X * PICK_UP_HAND_OFFSET if with_left_hand else PICK_UP_HAND_OFFSET)


func release_held_item() -> void:
	if held_item == null:
		return
	release_off_hand_weapon()
	var item := held_item
	held_item = null
	_held_weapon = null
	item.reparent(get_parent())
	item_released.emit(item)


func release_off_hand_weapon() -> void:
	if off_hand_weapon == null:
		return
	var item := off_hand_weapon
	off_hand_weapon = null
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
	_start_action(HIT_ANIMATIONS.pick_random())


func die() -> void:
	if dead:
		return
	dead = true
	_start_action(DEATH_POSES.keys().pick_random())


func spawn(from_air := false) -> void:
	dead = false
	velocity = Vector3.ZERO
	_start_action(SPAWN_AIR_ANIMATION if from_air else SPAWN_GROUND_ANIMATION, false, Vector3.ZERO, 0.0)


func preview(animation: StringName) -> void:
	if dead or not animation_player.has_animation(animation):
		return
	_start_action(animation, true)


func _has_new_input(direction: Vector3) -> bool:
	if not direction.is_zero_approx() and not _is_planted():
		return true
	return CANCEL_ACTIONS.any(func(action: StringName) -> bool: return Input.is_action_just_pressed(action))


func _camera_yaw() -> float:
	return 0.0


func _input_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Vector3(input.x, 0.0, input.y)


func _move_with_input(direction: Vector3, delta: float) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("dodge"):
			_dodge(direction)
			return
		if _is_blocking() and not _shield_raised:
			_shield_raised = true
			_start_action(shield.raise_animation, true)
			return
		if Input.is_action_just_pressed("attack") and _is_blocking():
			_start_action(shield.bash_animation)
			return
		if _is_aiming() and not _aim_raised:
			_raise_aim(false)
			return
		if Input.is_action_just_pressed("attack") and _ranged_weapon() != null:
			_shoot()
			return
		if Input.is_action_just_pressed("secondary") and not _secondary_combo().is_empty():
			_attack_with(_secondary_combo(), &"secondary")
			return
		if Input.is_action_just_pressed("attack") and _can_attack():
			_attack(direction)
			return
	if _is_planted():
		direction = Vector3.ZERO
	var gait := _gait(direction)
	velocity.x = direction.x * gait.speed
	velocity.z = direction.z * gait.speed
	_apply_vertical_motion(delta)
	move_and_slide()
	if not direction.is_zero_approx():
		_turn_toward(atan2(direction.x, direction.z) + gait.facing_offset, delta)
	_animate(direction, gait, delta)


func _move_with_action(delta: float) -> void:
	var action_velocity := _action_velocity if animation_player.current_animation_position < _action_velocity_duration else Vector3.ZERO
	velocity.x = action_velocity.x
	velocity.z = action_velocity.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


func _is_blocking() -> bool:
	return shield != null and is_on_floor() and Input.is_action_pressed("secondary")


func _is_aiming() -> bool:
	return _ranged_weapon() != null and is_on_floor() and Input.is_action_pressed("secondary")


func _is_planted() -> bool:
	return _is_blocking() or _is_aiming()


func _ranged_weapon() -> Weapon:
	return _held_weapon if _held_weapon != null and _held_weapon.is_ranged() else null


func _follows_camera() -> bool:
	return not dead and (_attacking or _is_planted())


func _update_facing(direction: Vector3, delta: float) -> void:
	if dead:
		return
	if _follows_camera() or (not is_acting() and not direction.is_zero_approx()):
		_facing_yaw = _view_yaw()
	if _follows_camera():
		_turn_toward(_facing_yaw, delta)
	elif not is_acting() and direction.is_zero_approx():
		_turn_toward(_facing_yaw, delta)


func _view_yaw() -> float:
	return _camera_yaw() + PI


func _update_upper_body_twist(direction: Vector3, delta: float) -> void:
	var twisting := not dead and not is_acting() and not direction.is_zero_approx()
	var target := clampf(wrapf(_view_yaw() - model.rotation.y, -PI, PI), -MAX_TWIST, MAX_TWIST) if twisting else 0.0
	_upper_body_twist.twist = lerp_angle(_upper_body_twist.twist, target, 1.0 - exp(-turn_speed * delta))


func _turn_toward(target_yaw: float, delta: float) -> void:
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _can_react_with_shield() -> bool:
	return not is_acting() or _action in [shield.raise_animation, shield.hit_animation]


func _lower_shield_if_released() -> void:
	if shield != null and _action == shield.raise_animation and not _is_blocking():
		_end_action()


func _gait(direction: Vector3) -> Gait:
	var travel_from_view := wrapf(atan2(direction.x, direction.z) - _view_yaw(), -PI, PI)
	if absf(travel_from_view) > BACKWARD_ARC:
		return Gait.new(WALK_BACKWARDS_ANIMATION, backwards_speed, PI)
	if Input.is_action_pressed("sprint"):
		return Gait.new(_weapon_run_animation(), run_speed)
	return Gait.new(walk_animation, walk_speed)


func _weapon_run_animation() -> StringName:
	if _held_weapon != null and _held_weapon.run_animation != &"":
		return _held_weapon.run_animation
	return run_animation


func _to_local_direction(direction: Vector3) -> Vector3:
	return model.global_basis.inverse() * direction


func _apply_vertical_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		_air_time += delta
	elif not _is_planted() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		_air_time = AIRBORNE_DELAY
		_play(_stanced(JUMP_START_ANIMATION), BLEND_TIME, JUMP_TAKEOFF_TIME)


func _animate(direction: Vector3, gait: Gait, delta: float) -> void:
	if not is_on_floor():
		_animate_airborne()
		return
	var air_time := _air_time
	_air_time = 0.0
	if not direction.is_zero_approx():
		_idle_time = 0.0
		_play(_stanced(gait.animation))
	elif air_time >= LANDING_AIR_TIME:
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
	if _is_blocking():
		_play(shield.hold_animation)
		return
	if _is_aiming():
		_play(_aim_hold_animation())
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
	_start_action(_stanced(_in_place(animation)), false, heading * dodge_speed)


func _dodge_animation(local_heading: Vector3) -> StringName:
	if absf(local_heading.x) > absf(local_heading.z):
		return DODGE_LEFT_ANIMATION if local_heading.x > 0.0 else DODGE_RIGHT_ANIMATION
	return DODGE_FORWARD_ANIMATION if local_heading.z > 0.0 else DODGE_BACKWARD_ANIMATION


func _can_attack() -> bool:
	return not _combo().is_empty()


func _combo() -> Array[AttackStep]:
	if off_hand_weapon != null:
		return dual_wield_combo
	if _held_weapon != null:
		return _held_weapon.combo
	return unarmed_combo if held_item == null else ([] as Array[AttackStep])


func _secondary_combo() -> Array[AttackStep]:
	return _held_weapon.secondary_combo if _held_weapon != null else ([] as Array[AttackStep])


func _running_attack_animation() -> StringName:
	return _held_weapon.running_attack_animation if _held_weapon != null else &""


func _attack(direction: Vector3) -> void:
	if Input.is_action_pressed("sprint") and not direction.is_zero_approx() and _running_attack_animation() != &"":
		_start_running_attack(direction)
		return
	_attack_with(_combo(), &"attack")


func _attack_with(combo: Array[AttackStep], input: StringName) -> void:
	if _combo_grace > 0.0 and _attack_input == input and _attack_combo == combo:
		_continue_combo()
		return
	_attack_combo = combo
	_attack_input = input
	_combo_index = 0
	_start_attack_step(combo[0], 0.0, BLEND_TIME)


func _start_running_attack(direction: Vector3) -> void:
	_start_action(_running_attack_animation(), false, direction.normalized() * lunge_speed)
	_action_velocity_duration = LUNGE_DURATION
	_attacking = true
	_attack_queued = false
	_attack_step = null


func _start_attack_step(step: AttackStep, from: float, blend: float) -> void:
	_start_action(step.animation, false, Vector3.ZERO, blend, from)
	_attacking = true
	_attack_queued = false
	_attack_step = step


func _update_attack() -> void:
	if not _attacking or _attack_step == null:
		return
	if Input.is_action_just_pressed(_attack_input) and not _action_cancellable:
		_attack_queued = true
	var playback_time := animation_player.current_animation_position
	var wants_next := _attack_queued or _attack_step.continues_automatically
	if wants_next and _has_next_attack_step() and playback_time >= _attack_step.combo_time:
		_continue_combo()
	elif playback_time >= _attack_step.window_end and not _action_cancellable:
		_close_combo_window()


func _has_next_attack_step() -> bool:
	return _combo_index + 1 < _attack_combo.size()


func _continue_combo() -> void:
	_combo_index = _combo_index + 1 if _has_next_attack_step() else 0
	var step := _attack_combo[_combo_index]
	_start_attack_step(step, step.chain_start, CHAIN_BLEND)


func _close_combo_window() -> void:
	if _attack_queued:
		_continue_combo()
		return
	_action_cancellable = true
	_combo_grace = animation_player.current_animation_length - animation_player.current_animation_position + COMBO_GRACE


func _raise_aim(then_shoot: bool) -> void:
	var weapon := _ranged_weapon()
	_aim_raised = true
	_start_action(weapon.aim_animation, false, Vector3.ZERO, BLEND_TIME, weapon.aim_start)
	_attacking = true
	_shot_queued = then_shoot


func _update_aim_raise() -> void:
	var weapon := _ranged_weapon()
	if weapon == null or _action != weapon.aim_animation:
		return
	if Input.is_action_just_pressed("attack"):
		_shot_queued = true
	if animation_player.current_animation_position >= weapon.aim_ready_time:
		_finish_aim_raise()
	elif not _shot_queued and not _is_aiming():
		_end_action()


func _finish_aim_raise() -> void:
	if _shot_queued:
		_start_shot_step(0, _ranged_weapon().aimed_shot_start)
	else:
		_end_action()


func _shoot() -> void:
	if _is_aiming():
		_start_shot_step(0, _ranged_weapon().aimed_shot_start)
	else:
		_raise_aim(true)


func _start_shot_step(step: int, from: float) -> void:
	_start_action(_held_weapon.shot_animations[step], false, Vector3.ZERO, BLEND_TIME, from)
	_attacking = true
	_shot_step = step


func _continue_shot(finished_step: int) -> void:
	var weapon := _ranged_weapon()
	if finished_step + 1 < weapon.shot_animations.size():
		_start_shot_step(finished_step + 1, 0.0)
	else:
		_aim_raised = false


func _update_aim_return() -> void:
	var weapon := _ranged_weapon()
	if weapon == null or weapon.aim_return_time <= 0.0 or _shot_step != weapon.shot_animations.size() - 1:
		return
	if _is_aiming() and animation_player.current_animation_position >= weapon.aim_return_time:
		_end_action()


func _aim_hold_animation() -> StringName:
	var weapon := _ranged_weapon()
	if weapon.aim_hold_animation != &"":
		return weapon.aim_hold_animation
	return _derived_animation(AIM_HOLD_LIBRARY, weapon.aim_animation, _looping_tail.bind(weapon.aim_ready_time))


func _perform(animation: StringName) -> bool:
	if dead or (is_acting() and not _action_cancellable):
		return false
	_start_action(animation)
	return true


func _align_hand_with(grip_position: Vector3, reach: Vector3) -> void:
	var hand_offset := reach * model.scale.x
	var to_grip := grip_position - global_position
	var yaw := atan2(to_grip.x, to_grip.z) - atan2(hand_offset.x, hand_offset.z)
	var target := grip_position - Basis(Vector3.UP, yaw) * hand_offset
	target.y = global_position.y
	var target_yaw := model.rotation.y + wrapf(yaw - model.rotation.y, -PI, PI)
	_facing_yaw = target_yaw
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(self, "global_position", target, PICK_UP_ALIGN_TIME)
	tween.tween_property(model, "rotation:y", target_yaw, PICK_UP_ALIGN_TIME)


func _update_pick_up() -> void:
	if _pick_up_item == null:
		return
	if _action != _pick_up_animation or not is_instance_valid(_pick_up_item):
		_pick_up_item = null
		return
	if animation_player.current_animation_position < PICK_UP_GRAB_TIME:
		return
	var item := _pick_up_item
	_pick_up_item = null
	if item is Shield:
		_take_shield(item)
	elif _fits_off_hand(item):
		_take_off_hand_weapon(item)
	else:
		_take_main_hand_item(item)


func _take_main_hand_item(item: Node3D) -> void:
	release_held_item()
	held_item = item
	_held_weapon = item as Weapon
	if not _allows_shield():
		release_shield()
	_attach_to_hand(item, _main_hand_for(item), _held_weapon.grip() if _held_weapon != null else Transform3D.IDENTITY)


func _pick_up_hand(item: Node3D) -> StringName:
	if item != null and _fits_off_hand(item):
		return LEFT_HAND
	return _main_hand_for(item)


func _main_hand_for(item: Node3D) -> StringName:
	return item.hand if item is Weapon else RIGHT_HAND


func _take_off_hand_weapon(item: Weapon) -> void:
	release_off_hand_weapon()
	off_hand_weapon = item
	_attach_to_hand(item, LEFT_HAND, item.off_hand_grip())


func _fits_off_hand(item: Node3D) -> bool:
	return item is Weapon and item.dual_wieldable and shield == null and _held_weapon != null and _held_weapon.dual_wieldable


func _take_shield(item: Shield) -> void:
	release_shield()
	release_off_hand_weapon()
	if not _allows_shield():
		release_held_item()
	shield = item
	_attach_to_hand(item, LEFT_HAND, item.grip())


func _allows_shield() -> bool:
	return held_item == null or (_held_weapon != null and _held_weapon.allows_shield)


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
	_shot_queued = false
	_shot_step = -1
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
	_shot_queued = false
	_shot_step = -1


func _on_animation_finished(animation: StringName) -> void:
	if animation != _action:
		return
	var finished_combo_step := _attack_step != null
	var finished_shot_step := _shot_step
	_end_action()
	if finished_combo_step:
		_combo_grace = COMBO_GRACE
	if finished_shot_step >= 0:
		_continue_shot(finished_shot_step)
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
	return _held_weapon.upper_body_animation if _held_weapon != null else &""


func _takes_upper_body(animation: StringName) -> bool:
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
	_face_spine_like_upper_body(merged, upper, time_scale)
	return merged


func _face_spine_like_upper_body(merged: Animation, upper: Animation, time_scale: float) -> void:
	var times: Array[float] = []
	var rotations: Array[Quaternion] = []
	var time := 0.0
	while time < merged.length + LAYER_SAMPLE_STEP:
		var sample_time := minf(time, merged.length)
		var upper_time := sample_time / time_scale
		var upper_spine := _pelvis_rotation_at(upper, upper_time) * _rotation_at(upper, SPINE_TRACK, upper_time)
		times.append(sample_time)
		rotations.append(_pelvis_rotation_at(merged, sample_time).inverse() * upper_spine)
		time += LAYER_SAMPLE_STEP
	var base_spine := merged.find_track(SPINE_TRACK, Animation.TYPE_ROTATION_3D)
	if base_spine >= 0:
		merged.remove_track(base_spine)
	var spine := merged.add_track(Animation.TYPE_ROTATION_3D)
	merged.track_set_path(spine, SPINE_TRACK)
	for i in times.size():
		merged.rotation_track_insert_key(spine, times[i], rotations[i])


func _pelvis_rotation_at(animation: Animation, time: float) -> Quaternion:
	return _rotation_at(animation, ROOT_TRACK, time) * _rotation_at(animation, HIPS_TRACK, time)


func _in_place(animation: StringName) -> StringName:
	return _derived_animation(IN_PLACE_LIBRARY, animation, _without_root_slide)


func _mirrored(animation: StringName) -> StringName:
	return _derived_animation(MIRRORED_LIBRARY, animation, _mirror)


func _derived_animation(library: StringName, animation: StringName, derive: Callable) -> StringName:
	var path := StringName("%s/%s" % [library, animation.get_file()])
	if animation_player.has_animation(path):
		return path
	if not animation_player.has_animation_library(library):
		animation_player.add_animation_library(library, AnimationLibrary.new())
	animation_player.get_animation_library(library).add_animation(animation.get_file(), derive.call(animation_player.get_animation(animation)))
	return path


func _looping_tail(source: Animation, start: float) -> Animation:
	var tail := Animation.new()
	tail.length = source.length - start
	tail.loop_mode = Animation.LOOP_LINEAR
	for track in source.get_track_count():
		var type := source.track_get_type(track)
		if type not in BONE_TRACK_TYPES:
			continue
		var copy := tail.add_track(type)
		tail.track_set_path(copy, source.track_get_path(track))
		tail.track_insert_key(copy, 0.0, _track_value_at(source, track, start))
		for key in source.track_get_key_count(track):
			var time := source.track_get_key_time(track, key)
			if time > start:
				tail.track_insert_key(copy, time - start, source.track_get_key_value(track, key))
	return tail


func _track_value_at(animation: Animation, track: int, time: float) -> Variant:
	match animation.track_get_type(track):
		Animation.TYPE_POSITION_3D:
			return animation.position_track_interpolate(track, time)
		Animation.TYPE_ROTATION_3D:
			return animation.rotation_track_interpolate(track, time)
		_:
			return animation.scale_track_interpolate(track, time)


func _without_root_slide(source: Animation) -> Animation:
	var copy: Animation = source.duplicate(true)
	var root_slide := copy.find_track(ROOT_TRACK, Animation.TYPE_POSITION_3D)
	if root_slide >= 0:
		copy.remove_track(root_slide)
	return copy


func _mirror(source: Animation) -> Animation:
	var mirrored := Animation.new()
	mirrored.length = source.length
	mirrored.loop_mode = source.loop_mode
	var tracks := _mirrored_tracks(source, mirrored)
	var rest_corrections := _mirror_rest_corrections()
	var time := 0.0
	while time < source.length + LAYER_SAMPLE_STEP:
		var sample_time := minf(time, source.length)
		var poses := _skeleton_poses(_animated_bone_pose.bind(source, sample_time))
		var mirrored_poses: Array[Transform3D] = []
		for bone in skeleton.get_bone_count():
			mirrored_poses.append(MIRROR_ACROSS_X * poses[_mirror_bone(bone)] * rest_corrections[bone])
		for bone: int in tracks:
			_insert_bone_keys(mirrored, tracks[bone], sample_time, _local_pose(mirrored_poses, bone))
		time += LAYER_SAMPLE_STEP
	return mirrored


func _mirrored_tracks(source: Animation, mirrored: Animation) -> Dictionary[int, Dictionary]:
	var tracks: Dictionary[int, Dictionary] = {}
	for bone in skeleton.get_bone_count():
		var bone_tracks := {}
		for type in BONE_TRACK_TYPES:
			if source.find_track(_bone_track_path(_mirror_bone(bone)), type) < 0:
				continue
			var track := mirrored.add_track(type)
			mirrored.track_set_path(track, _bone_track_path(bone))
			bone_tracks[type] = track
		if not bone_tracks.is_empty():
			tracks[bone] = bone_tracks
	return tracks


func _mirror_rest_corrections() -> Array[Transform3D]:
	var rests := _skeleton_poses(skeleton.get_bone_rest)
	var corrections: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		corrections.append((MIRROR_ACROSS_X * rests[_mirror_bone(bone)]).affine_inverse() * rests[bone])
	return corrections


func _skeleton_poses(local_pose: Callable) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		var local: Transform3D = local_pose.call(bone)
		var parent := skeleton.get_bone_parent(bone)
		poses.append(local if parent < 0 else poses[parent] * local)
	return poses


func _local_pose(poses: Array[Transform3D], bone: int) -> Transform3D:
	var parent := skeleton.get_bone_parent(bone)
	return poses[bone] if parent < 0 else poses[parent].affine_inverse() * poses[bone]


func _animated_bone_pose(bone: int, animation: Animation, time: float) -> Transform3D:
	var path := _bone_track_path(bone)
	var rest := skeleton.get_bone_rest(bone)
	var position := rest.origin
	var scale := rest.basis.get_scale()
	var position_track := animation.find_track(path, Animation.TYPE_POSITION_3D)
	if position_track >= 0:
		position = animation.position_track_interpolate(position_track, time)
	var scale_track := animation.find_track(path, Animation.TYPE_SCALE_3D)
	if scale_track >= 0:
		scale = animation.scale_track_interpolate(scale_track, time)
	return Transform3D(Basis(_rotation_at(animation, path, time)) * Basis.from_scale(scale), position)


func _insert_bone_keys(animation: Animation, tracks: Dictionary, time: float, pose: Transform3D) -> void:
	if tracks.has(Animation.TYPE_POSITION_3D):
		animation.position_track_insert_key(tracks[Animation.TYPE_POSITION_3D], time, pose.origin)
	if tracks.has(Animation.TYPE_ROTATION_3D):
		animation.rotation_track_insert_key(tracks[Animation.TYPE_ROTATION_3D], time, pose.basis.get_rotation_quaternion())
	if tracks.has(Animation.TYPE_SCALE_3D):
		animation.scale_track_insert_key(tracks[Animation.TYPE_SCALE_3D], time, pose.basis.get_scale())


func _mirror_bone(bone: int) -> int:
	var name := skeleton.get_bone_name(bone)
	if name.ends_with(".l"):
		return skeleton.find_bone(name.trim_suffix(".l") + ".r")
	if name.ends_with(".r"):
		return skeleton.find_bone(name.trim_suffix(".r") + ".l")
	return bone


func _bone_track_path(bone: int) -> NodePath:
	return NodePath("%s:%s" % [ROOT_TRACK.get_concatenated_names(), skeleton.get_bone_name(bone)])


func _rotation_at(animation: Animation, path: NodePath, time: float) -> Quaternion:
	var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
	if track >= 0:
		return animation.rotation_track_interpolate(track, time)
	var bone := skeleton.find_bone(path.get_concatenated_subnames())
	return skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()


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
