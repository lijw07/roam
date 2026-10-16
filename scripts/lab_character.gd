extends CharacterBody3D

const BLEND_TIME := 0.15
const SKELETON_PATH := ^"Model/Rig_Medium/Skeleton3D"
const RIGHT_HAND := &"handslot.r"
const LEFT_HAND := &"handslot.l"
const IDLE_ANIMATION := &"general/Idle_A"
const WALK_ANIMATION := &"movement_basic/Walking_A"
const RUN_ANIMATION := &"movement_basic/Running_A"
const JUMP_ANIMATION := &"movement_basic/Jump_Idle"
const HIT_HEIGHTS: Array[float] = [0.7, 1.15, 1.6]
const UNARMED_ATTACKS: Array[StringName] = [
	&"combat_melee/Melee_Unarmed_Attack_Punch_A",
	&"combat_melee/Melee_Unarmed_Attack_Kick",
]

signal character_changed(character_name: String)
signal loadout_changed(loadout_name: String)

@export var characters: Array[PackedScene] = []
@export var walk_speed := 3.0
@export var run_speed := 6.5
@export var jump_velocity := 8.0
@export var turn_speed := 12.0
@export var gravity_multiplier := 2.0

@onready var model: Node3D = $Model
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier

var character_index := 0
var loadout_name := "Unarmed"
var station: Node = null

var _instance: Node3D
var _animation_player: AnimationPlayer
var _attachments: Array[Node3D] = []
var _idle := IDLE_ANIMATION
var _walk := WALK_ANIMATION
var _run := RUN_ANIMATION
var _secondary: StringName = &""
var _attacks: Array[StringName] = UNARMED_ATTACKS
var _attack_index := 0
var _loadout: Dictionary = {}
var _override: StringName = &""
var _repeat := false
var _locked := false
var _attacking := false
var _nearby: Array[Node] = []
var _exit_to := Vector3.INF
var _effect_timer: Timer


func _ready() -> void:
	_effect_timer = Timer.new()
	_effect_timer.one_shot = true
	_effect_timer.timeout.connect(_spawn_effect)
	add_child(_effect_timer)
	set_character(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("attack"):
		attack()


func _physics_process(delta: float) -> void:
	if _locked:
		velocity = Vector3.ZERO
		return
	var direction := Vector3.ZERO if _holding_secondary() else _input_direction()
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_apply_vertical_motion(delta)
	move_and_slide()
	_face(direction, delta)
	if _override != &"":
		if direction.is_zero_approx():
			return
		_override = &""
		_repeat = false
	play(_locomotion(direction))


func set_character(index: int) -> void:
	if characters.is_empty():
		return
	character_index = wrapi(index, 0, characters.size())
	_clear_attachments()
	if _instance:
		model.remove_child(_instance)
		_instance.queue_free()
	_instance = characters[character_index].instantiate()
	_make_decorative(_instance)
	model.add_child(_instance)
	_adopt_collision_shape()
	_animation_player = _instance.get_node("AnimationPlayer")
	_animation_player.animation_finished.connect(_on_animation_finished)
	_apply_loadout()
	play(_idle)
	character_changed.emit(character_name())


func step_character(step: int) -> void:
	set_character(character_index + step)


func character_name() -> String:
	return _instance.name.capitalize() if _instance else ""


func current_animation() -> StringName:
	return StringName(_animation_player.current_animation)


func animation_list() -> PackedStringArray:
	return _animation_player.get_animation_list()


func play(animation: StringName, blend := BLEND_TIME) -> void:
	if not _animation_player.has_animation(animation):
		return
	if _animation_player.current_animation != animation:
		_animation_player.play(animation, blend)


func play_override(animation: StringName, repeat := false) -> bool:
	if not _animation_player.has_animation(animation):
		return false
	_override = animation
	_repeat = repeat
	play(animation)
	return true


func attack() -> void:
	if _locked or _attacking or _attacks.is_empty():
		return
	_attack_index = wrapi(_attack_index + 1, 0, _attacks.size())
	var animation := _attacks[_attack_index]
	if not play_override(animation):
		return
	if _loops(animation):
		return
	_attacking = true
	_locked = true
	_schedule_effect(animation)


func equip(loadout: Dictionary) -> void:
	_loadout = loadout
	_apply_loadout()
	loadout_changed.emit(loadout_name)


func unequip() -> void:
	equip({})


func reset() -> void:
	_override = &""
	_repeat = false
	_attacking = false
	station = null
	_unlock()
	unequip()


func station_entered(entered: Node) -> void:
	if not _nearby.has(entered):
		_nearby.append(entered)


func station_exited(exited: Node) -> void:
	_nearby.erase(exited)


func nearest_station() -> Node:
	var best: Node = null
	var best_distance := INF
	for candidate in _nearby:
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _interact() -> void:
	if _attacking:
		return
	if station:
		_leave_station()
		return
	var target := nearest_station()
	if target == null:
		return
	if target.is_loadout():
		equip({} if _loadout.get("label", "") == target.label else target.loadout())
	if target.is_action():
		_enter_station(target)


func _enter_station(target: Node) -> void:
	station = target
	_locked = true
	var anchor: Node3D = target.anchor
	if anchor:
		global_position = anchor.global_position
		model.rotation.y = anchor.global_rotation.y
	else:
		_face_towards(target.global_position)
	var started := play_override(target.enter_animation) if target.enter_animation != &"" else play_override(target.idle_animation)
	if not started:
		station = null
		_unlock()


func _leave_station() -> void:
	var leaving := station
	station = null
	if leaving.exit_point:
		_exit_to = leaving.exit_point.global_position
	if leaving.exit_animation != &"":
		play_override(leaving.exit_animation)
		return
	_override = &""
	_unlock()


func _unlock() -> void:
	_locked = false
	velocity = Vector3.ZERO
	if _exit_to != Vector3.INF:
		global_position = _exit_to
		_exit_to = Vector3.INF
	apply_floor_snap()


func _on_animation_finished(animation: StringName) -> void:
	if animation != _override:
		return
	if station and station.idle_animation != &"":
		play_override(station.idle_animation)
		return
	if _repeat:
		_animation_player.play(animation)
		return
	_override = &""
	station = null
	_attacking = false
	_unlock()


func _schedule_effect(animation: StringName) -> void:
	if not _loadout.has("effect"):
		return
	var only: Array = _loadout.get("effect_attacks", [])
	if not only.is_empty() and not only.has(animation):
		return
	_effect_timer.start(_loadout.get("effect_delay", 0.35))


func _spawn_effect() -> void:
	var scene: PackedScene = _loadout.get("effect")
	if scene == null:
		return
	var hit := {}
	if _loadout.get("effect_on_hit", false):
		hit = _swing_hit(_loadout.get("effect_reach", 1.4))
		if hit.is_empty():
			return
	var effect: Node3D = scene.instantiate()
	get_parent().add_child(effect)
	if hit.is_empty():
		var basis := model.global_transform.basis
		var offset: Vector3 = _loadout.get("effect_offset", Vector3.ZERO)
		effect.global_position = _bone_position(_loadout.get("effect_bone", RIGHT_HAND)) \
			+ basis.x * offset.x + Vector3.UP * offset.y + basis.z * offset.z
		effect.global_rotation = Vector3(0.0, model.global_rotation.y, 0.0)
		return
	var normal: Vector3 = hit["normal"]
	effect.global_position = hit["position"] + normal * 0.08
	if absf(normal.dot(Vector3.UP)) < 0.95:
		effect.look_at(effect.global_position - normal, Vector3.UP)


func _swing_hit(reach: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var forward := model.global_transform.basis.z
	for height in HIT_HEIGHTS:
		var origin: Vector3 = global_position + Vector3.UP * height
		var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * reach)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit
	return {}


func _bone_position(bone: StringName) -> Vector3:
	var skeleton: Skeleton3D = _instance.get_node(SKELETON_PATH)
	var index := skeleton.find_bone(bone)
	if index < 0:
		return global_position + Vector3.UP
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin


func _loops(animation: StringName) -> bool:
	var data := _animation_player.get_animation(animation)
	return data != null and data.loop_mode != Animation.LOOP_NONE


func _holding_secondary() -> bool:
	return _secondary != &"" and Input.is_action_pressed("secondary")


func _locomotion(direction: Vector3) -> StringName:
	if not is_on_floor():
		return JUMP_ANIMATION
	if _holding_secondary():
		return _secondary
	if direction.is_zero_approx():
		return _idle
	return _run if Input.is_action_pressed("sprint") else _walk


func _input_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0.0, input.y)
	var camera := get_viewport().get_camera_3d()
	return direction.rotated(Vector3.UP, camera.global_rotation.y) if camera else direction


func _apply_vertical_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity


func _face_towards(point: Vector3) -> void:
	var offset := point - global_position
	offset.y = 0.0
	if offset.length() < 0.1:
		return
	model.rotation.y = atan2(offset.x, offset.z)


func _face(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var target_yaw := atan2(direction.x, direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _apply_loadout() -> void:
	_clear_attachments()
	loadout_name = _loadout.get("label", "Unarmed")
	_idle = _loadout.get("idle", IDLE_ANIMATION)
	_walk = _loadout.get("walk", WALK_ANIMATION)
	_run = _loadout.get("run", RUN_ANIMATION)
	_secondary = _loadout.get("secondary", &"")
	_attacks = _loadout.get("attacks", UNARMED_ATTACKS)
	_attack_index = 0
	_attach(_loadout.get("main_hand"), RIGHT_HAND, _loadout.get("main_hand_rotation", Vector3.ZERO),
		_loadout.get("main_hand_offset", Vector3.ZERO))
	_attach(_loadout.get("off_hand"), LEFT_HAND, _loadout.get("off_hand_rotation", Vector3.ZERO),
		_loadout.get("off_hand_offset", Vector3.ZERO))


func _attach(scene: PackedScene, bone: StringName, rotation_offset: Vector3, position_offset: Vector3) -> void:
	if scene == null:
		return
	var skeleton: Skeleton3D = _instance.get_node(SKELETON_PATH)
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var item: Node3D = scene.instantiate()
	item.rotation_degrees = rotation_offset
	item.position = position_offset
	_make_decorative(item)
	attachment.add_child(item)
	_attachments.append(attachment)


func _clear_attachments() -> void:
	for attachment in _attachments:
		attachment.get_parent().remove_child(attachment)
		attachment.queue_free()
	_attachments.clear()


func _adopt_collision_shape() -> void:
	var inner := _instance.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if inner == null:
		return
	collision_shape.shape = inner.shape
	collision_shape.transform = inner.transform
	inner.disabled = true


func _make_decorative(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is Area3D:
		node.monitoring = false
		node.monitorable = false
	for child in node.get_children():
		_make_decorative(child)
