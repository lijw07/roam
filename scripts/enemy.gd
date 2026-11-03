extends CharacterBody3D
class_name Enemy

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


func _on_hit_taken(_hit: Hit, damage: float) -> void:
	if damage > 0.0:
		take_hit()


func _play_death() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	_react(DEATH_POSES.keys().pick_random(), DEATH_BLEND_IN)


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


func _play(animation: StringName, blend := BLEND_TIME) -> void:
	if animation_player.current_animation != animation:
		animation_player.play(animation, blend)
