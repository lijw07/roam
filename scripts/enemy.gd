extends CharacterBody3D
class_name Enemy

signal guard_broken

const BLEND_TIME := 0.15
const AIRBORNE_DELAY := 0.15
const REACTION_BLEND_IN := 0.06
const DEATH_BLEND_IN := 0.2
const REACTION_BLEND_OUT := 0.25
const FLINCH_LIBRARY := &"flinch_in_stance"
const HIT_ANIMATIONS: Array[StringName] = [&"general/Hit_A", &"general/Hit_B"]
const DEATH_POSES := {
	&"general/Death_A": &"general/Death_A_Pose",
	&"general/Death_B": &"general/Death_B_Pose",
}
const SKELETON_PATH := ^"Model/Rig_Medium/Skeleton3D"
const MAIN_HAND := &"handslot.r"
const LIMB_BONES: Array[StringName] = [&"hand.l", &"hand.r", &"foot.l", &"foot.r"]
const LIMB_STRIKE_RADIUS := 0.18
const STRAFE_LEFT_ANIMATION := &"movement_advanced/Running_Strafe_Left"
const STRAFE_RIGHT_ANIMATION := &"movement_advanced/Running_Strafe_Right"
const BACKWARD_ANIMATION := &"movement_advanced/Walking_Backwards"
const FORWARD_ARC := deg_to_rad(50.0)
const BACKWARD_ARC := deg_to_rad(130.0)
const AIM_HEIGHT := 1.1
const UNARMED_PROJECTILE_ORIGIN := Vector3(0.0, 1.4, 0.5)

@export var threat := 2
@export var walk_speed := 3.0
@export var run_speed := 6.5
@export var strafe_speed := 2.2
@export var turn_speed := 8.0
@export var attack_turn_speed := 5.0
@export var gravity_multiplier := 2.0

@export_group("Animations")
@export var idle_animation: StringName = &"general/Idle_A"
@export var walk_animation: StringName = &"movement_basic/Walking_A"
@export var run_animation: StringName = &"movement_basic/Running_A"
@export var fall_animation: StringName = &"movement_basic/Jump_Idle"
@export var strafe_animation_speed := 0.7
@export var guard_raise_animation: StringName = &"combat_melee/Melee_Block"
@export var guard_hold_animation: StringName = &"combat_melee/Melee_Blocking"
@export var guard_hit_animation: StringName = &"combat_melee/Melee_Block_Hit"

@export_group("Combat")
@export var attacks: Array[AttackStep] = []
@export var lead_in: AttackStep
@export var attack_damage := 10.0
@export var projectile: PackedScene
@export var block_stamina_per_damage := 1.0
@export_range(0.0, 180.0) var block_arc_degrees := 140.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton3D = get_node(SKELETON_PATH)
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier
@onready var health := get_node_or_null(^"Health") as Health
@onready var hurtbox := get_node_or_null(^"Hurtbox") as Hurtbox
@onready var stamina := get_node_or_null(^"Stamina") as StatPool

var move_direction := Vector3.ZERO
var running := false
var dead := false
var focus: Node3D = null

var _air_time := 0.0
var _reaction: StringName = &""
var _attack_step: AttackStep = null
var _queued_step: AttackStep = null
var _windup_speed := 1.0
var _projectile_fired := false
var _struck: Array[Hurtbox] = []
var _guarding := false
var _guard_ready := false
var _main_hand: BoneAttachment3D = null
var _strike_shapes: Dictionary[CollisionShape3D, Vector3] = {}
var _limb_bones: Array[int] = []
var _limb_sphere := SphereShape3D.new()
var _strike_query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_main_hand = _find_main_hand()
	_disable_held_collision()
	_prepare_strikes()
	_prepare_flinches()
	_connect_health()
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play(idle_animation)
	animation_player.seek(randf() * animation_player.current_animation_length, true)


func _physics_process(delta: float) -> void:
	if dead:
		_settle_corpse(delta)
		return
	if _reaction != &"":
		_hold_still(delta)
		_recover_from_reaction_when_due()
		return
	if _attack_step != null:
		_hold_still(delta)
		_update_attack(delta)
		return
	if _guarding:
		_hold_guard(delta)
		return
	_travel(delta)


func can_act() -> bool:
	return not dead and _reaction == &"" and _attack_step == null


func is_attacking() -> bool:
	return _attack_step != null


func is_guarding() -> bool:
	return _guarding


func is_ranged() -> bool:
	return projectile != null


func attack(step: AttackStep, windup_speed := 1.0) -> bool:
	if not can_act() or step == null:
		return false
	lower_guard()
	_windup_speed = windup_speed
	_queued_step = step if lead_in != null else null
	_begin_step(lead_in if lead_in != null else step)
	return true


func _begin_step(step: AttackStep) -> void:
	_attack_step = step
	_projectile_fired = false
	_struck.clear()
	animation_player.play(step.animation, BLEND_TIME)
	animation_player.speed_scale = _windup_speed


func raise_guard() -> bool:
	if not can_act() or _guarding:
		return false
	_guarding = true
	_guard_ready = false
	_play(guard_raise_animation)
	return true


func lower_guard() -> void:
	_guarding = false
	_guard_ready = false


func take_hit() -> void:
	if not dead:
		_interrupt()
		_react(_flinch_in_stance(HIT_ANIMATIONS.pick_random()), REACTION_BLEND_IN)


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
		hurtbox.blocked.connect(_on_blocked)
		hurtbox.block_check = _blocks


func _on_hit_taken(_hit: Hit, damage: float) -> void:
	if damage > 0.0:
		take_hit()


func _on_blocked(_hit: Hit) -> void:
	_guard_ready = true
	_react(guard_hit_animation, REACTION_BLEND_IN)


func _blocks(hit: Hit) -> bool:
	if not _guarding or not _faces(hit.origin):
		return false
	if stamina == null:
		return true
	var cost := hit.amount * block_stamina_per_damage
	var holds := stamina.can_spend(cost)
	stamina.drain(cost)
	if not holds:
		_break_guard()
	return holds


func _break_guard() -> void:
	lower_guard()
	guard_broken.emit()


func _faces(point: Vector3) -> bool:
	var to_point := _flat(point - global_position)
	if to_point.is_zero_approx():
		return true
	return _forward().angle_to(to_point) <= deg_to_rad(block_arc_degrees) * 0.5


func _play_death() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	_interrupt()
	_react(DEATH_POSES.keys().pick_random(), DEATH_BLEND_IN)


func _interrupt() -> void:
	lower_guard()
	_end_attack()


func _end_attack() -> void:
	_attack_step = null
	_queued_step = null
	animation_player.speed_scale = 1.0


func _advance_attack() -> void:
	if _queued_step == null:
		_finish_attack()
		return
	var next := _queued_step
	_queued_step = null
	_begin_step(next)


func _finish_attack() -> void:
	_end_attack()
	_play(_stance_animation(), REACTION_BLEND_OUT)


func _update_attack(delta: float) -> void:
	var time := animation_player.current_animation_position
	if time < _strike_start():
		_turn_toward_focus(delta, attack_turn_speed)
	else:
		animation_player.speed_scale = 1.0
	_strike_targets(time)
	_fire_projectile_when_due(time)
	if _attack_step != null and time >= _attack_step.window_end:
		_advance_attack()


func _strike_start() -> float:
	if is_ranged() and _attack_step.projectile_time >= 0.0:
		return _attack_step.projectile_time
	if _attack_step.hit_start >= 0.0:
		return _attack_step.hit_start
	return INF


func _find_main_hand() -> BoneAttachment3D:
	for attachment: BoneAttachment3D in find_children("*", "BoneAttachment3D", true, false):
		if attachment.bone_name == MAIN_HAND:
			return attachment
	return null


func _prepare_strikes() -> void:
	_strike_query.collide_with_areas = true
	_strike_query.collide_with_bodies = false
	_strike_query.collision_mask = 1 << (Hurtbox.LAYER - 1)
	_limb_sphere.radius = LIMB_STRIKE_RADIUS
	if _main_hand != null:
		for shape: CollisionShape3D in _main_hand.find_children("*", "CollisionShape3D", true, false):
			if shape.shape != null:
				_strike_shapes[shape] = shape.shape.get_debug_mesh().get_aabb().get_center()
	if _strike_shapes.is_empty():
		for bone in LIMB_BONES:
			_limb_bones.append(skeleton.find_bone(bone))


func _strike_targets(time: float) -> void:
	if _attack_step == null or not _attack_step.is_striking_at(time):
		return
	for shape in _strike_shapes:
		_strike_with(shape.shape, shape.global_transform, shape.global_transform * _strike_shapes[shape])
	for bone in _limb_bones:
		var limb := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
		_strike_with(_limb_sphere, Transform3D(Basis.IDENTITY, limb), limb)


func _strike_with(shape: Shape3D, shape_transform: Transform3D, origin: Vector3) -> void:
	_strike_query.shape = shape
	_strike_query.transform = shape_transform
	for contact in get_world_3d().direct_space_state.intersect_shape(_strike_query):
		var target := contact.collider as Hurtbox
		if target != null and _can_strike(target):
			_struck.append(target)
			target.receive(Hit.new(attack_damage, self, origin))


func _can_strike(target: Hurtbox) -> bool:
	return target != hurtbox and target not in _struck and not (target.get_parent() is Enemy)


func _fire_projectile_when_due(time: float) -> void:
	if not is_ranged() or _attack_step == null or _projectile_fired:
		return
	if _attack_step.projectile_time < 0.0 or time < _attack_step.projectile_time:
		return
	_projectile_fired = true
	var bolt: Projectile = projectile.instantiate()
	bolt.shooter = self
	bolt.ignored = _ally_hurtbox_rids()
	get_parent().add_child(bolt)
	var origin := _projectile_origin()
	bolt.global_transform = Transform3D(_aim_basis(_aim_point(origin, bolt.speed, bolt.max_range) - origin), origin)


func _ally_hurtbox_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for ally: Hurtbox in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		if ally.get_parent() is Enemy:
			rids.append(ally.get_rid())
	return rids


func _projectile_origin() -> Vector3:
	if _main_hand != null:
		return _main_hand.global_position
	return global_transform * UNARMED_PROJECTILE_ORIGIN


func _aim_point(origin: Vector3, speed: float, max_range: float) -> Vector3:
	if not is_instance_valid(focus):
		return origin + _forward()
	var target := focus.global_position + Vector3.UP * AIM_HEIGHT
	var target_velocity := _flat(_velocity_of(focus))
	var lead_time := minf(_intercept_time(target - origin, target_velocity, speed), max_range / speed if speed > 0.0 else 0.0)
	return target + target_velocity * lead_time


func _velocity_of(node: Node3D) -> Vector3:
	return (node as CharacterBody3D).get_real_velocity() if node is CharacterBody3D else Vector3.ZERO


func _intercept_time(offset: Vector3, target_velocity: Vector3, speed: float) -> float:
	if speed <= 0.0:
		return 0.0
	var a := target_velocity.length_squared() - speed * speed
	var b := 2.0 * offset.dot(target_velocity)
	var c := offset.length_squared()
	if is_zero_approx(a):
		return -c / b if b < 0.0 else 0.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return 0.0
	var root := sqrt(discriminant)
	var times := [(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)].filter(func(time: float) -> bool: return time > 0.0)
	return times.min() if not times.is_empty() else 0.0


func _aim_basis(aim: Vector3) -> Basis:
	if aim.is_zero_approx():
		return global_basis.orthonormalized()
	return Basis.looking_at(aim, Vector3.UP, true)


func _travel(delta: float) -> void:
	var direction := _flat(move_direction).limit_length()
	var speed := _speed_for(direction)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_apply_gravity(delta)
	move_and_slide()
	_face(_facing_direction(direction), delta, turn_speed)
	var clip := _locomotion_animation(direction)
	_play(clip, BLEND_TIME, strafe_animation_speed if clip in [STRAFE_LEFT_ANIMATION, STRAFE_RIGHT_ANIMATION] else 1.0)


func _hold_guard(delta: float) -> void:
	_hold_still(delta)
	_turn_toward_focus(delta, turn_speed)
	if stamina != null:
		stamina.pause_regen()
	if _guard_ready or animation_player.current_animation != guard_raise_animation:
		_play(guard_hold_animation)


func _speed_for(direction: Vector3) -> float:
	if _is_strafing(direction):
		return strafe_speed
	return run_speed if running else walk_speed


func _is_strafing(direction: Vector3) -> bool:
	return is_instance_valid(focus) and not direction.is_zero_approx() and _forward().angle_to(direction) > FORWARD_ARC


func _facing_direction(direction: Vector3) -> Vector3:
	if is_instance_valid(focus):
		return _flat(focus.global_position - global_position)
	return direction


func _turn_toward_focus(delta: float, speed: float) -> void:
	if is_instance_valid(focus):
		_face(_flat(focus.global_position - global_position), delta, speed)


func _forward() -> Vector3:
	return _flat(global_basis.z).normalized()


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _stance_animation() -> StringName:
	return guard_hold_animation if _guarding else idle_animation


func _prepare_flinches() -> void:
	for hit in HIT_ANIMATIONS:
		_flinch_in_stance(hit)


func _flinch_in_stance(hit: StringName) -> StringName:
	var clip_name := StringName(hit.get_file())
	var path := StringName("%s/%s" % [FLINCH_LIBRARY, clip_name])
	if not animation_player.has_animation(path):
		_flinch_library().add_animation(clip_name, _flinch_over(animation_player.get_animation(hit), animation_player.get_animation(idle_animation)))
	return path


func _flinch_library() -> AnimationLibrary:
	if not animation_player.has_animation_library(FLINCH_LIBRARY):
		animation_player.add_animation_library(FLINCH_LIBRARY, AnimationLibrary.new())
	return animation_player.get_animation_library(FLINCH_LIBRARY)


func _flinch_over(hit: Animation, stance: Animation) -> Animation:
	var flinch: Animation = hit.duplicate(true)
	for track in flinch.get_track_count():
		var stance_track := stance.find_track(flinch.track_get_path(track), flinch.track_get_type(track))
		if stance_track >= 0:
			_shift_track_onto(flinch, track, hit, stance, stance_track)
	_hold_stance_tracks_missing_from(flinch, stance)
	return flinch


func _shift_track_onto(flinch: Animation, track: int, hit: Animation, stance: Animation, stance_track: int) -> void:
	match flinch.track_get_type(track):
		Animation.TYPE_ROTATION_3D:
			var correction := stance.rotation_track_interpolate(stance_track, 0.0) * hit.rotation_track_interpolate(track, 0.0).inverse()
			for key in flinch.track_get_key_count(track):
				flinch.track_set_key_value(track, key, correction * flinch.track_get_key_value(track, key))
		Animation.TYPE_POSITION_3D:
			var offset := stance.position_track_interpolate(stance_track, 0.0) - hit.position_track_interpolate(track, 0.0)
			for key in flinch.track_get_key_count(track):
				flinch.track_set_key_value(track, key, flinch.track_get_key_value(track, key) + offset)


func _hold_stance_tracks_missing_from(flinch: Animation, stance: Animation) -> void:
	for stance_track in stance.get_track_count():
		var type := stance.track_get_type(stance_track)
		var path := stance.track_get_path(stance_track)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D] or flinch.find_track(path, type) >= 0:
			continue
		var track := flinch.add_track(type)
		flinch.track_set_path(track, path)
		flinch.track_insert_key(track, 0.0, stance.track_get_key_value(stance_track, 0))


func _react(animation: StringName, blend: float) -> void:
	_reaction = animation
	animation_player.play(animation, blend)


func _recover_from_reaction_when_due() -> void:
	var time_left := animation_player.current_animation_length - animation_player.current_animation_position
	if time_left <= REACTION_BLEND_OUT:
		_reaction = &""
		_play(_locomotion_animation(Vector3.ZERO), REACTION_BLEND_OUT)


func _on_animation_finished(animation: StringName) -> void:
	if _attack_step != null and animation == _attack_step.animation:
		_advance_attack()
		return
	if _guarding and animation == guard_raise_animation:
		_guard_ready = true
		return
	if animation != _reaction:
		return
	if dead:
		animation_player.play(DEATH_POSES[animation], 0.0)
		return
	_reaction = &""


func _settle_corpse(delta: float) -> void:
	_hold_still(delta)
	if is_on_floor():
		_remove_collision()


func _remove_collision() -> void:
	set_physics_process(false)
	for shape: CollisionShape3D in find_children("*", "CollisionShape3D", true, false):
		shape.set_deferred("disabled", true)


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


func _face(direction: Vector3, delta: float, speed: float) -> void:
	if direction.is_zero_approx():
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-speed * delta))


func _locomotion_animation(direction: Vector3) -> StringName:
	if _air_time >= AIRBORNE_DELAY:
		return fall_animation
	if direction.is_zero_approx():
		return _stance_animation()
	if not _is_strafing(direction):
		return run_animation if running else walk_animation
	if _forward().angle_to(direction) >= BACKWARD_ARC:
		return BACKWARD_ANIMATION
	return STRAFE_LEFT_ANIMATION if _forward().cross(direction).y > 0.0 else STRAFE_RIGHT_ANIMATION


func _play(animation: StringName, blend := BLEND_TIME, speed := 1.0) -> void:
	if animation_player.current_animation != animation:
		animation_player.play(animation, blend, speed)
