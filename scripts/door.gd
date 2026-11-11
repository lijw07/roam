extends Node3D
class_name Door

## Swings a doorway's door leaf open and closed around its hinge.
## The leaf's origin sits on the hinge, so rotating it around Y opens the door.

signal opened
signal closed

const LEAF_GROUP := &"door_leaves"
const CLEAR_DISTANCE := 0.75
const OPEN_CREAK_START := 0.1
const CLOSE_LATCH_TIME := 1.8
const CREAK_FADE_TIME := 0.25
const CREAK_VOLUME_DB := -4.0
const SILENT_DB := -60.0

@export_node_path("Node3D") var leaf_path: NodePath
## Positive swings toward the wall's front (+Z), which faces into rooms.
@export var open_angle := 100.0
@export var swing_time := 0.6
@export var start_open := false

var is_open := false

var _leaf: Node3D
var _body: CollisionObject3D
var _solid_layer := 0
var _closed_yaw := 0.0
var _tween: Tween
var _creak: AudioStreamPlayer3D


func _ready() -> void:
	_leaf = get_node(leaf_path)
	_body = _collision_body_of(_leaf)
	_body.add_to_group(CameraBoom.IGNORED_GROUP)
	_body.add_to_group(LEAF_GROUP)
	_solid_layer = _body.collision_layer
	_closed_yaw = _leaf.rotation.y
	set_physics_process(false)
	if start_open:
		is_open = true
		_leaf.rotation.y = _target_yaw()


func open() -> void:
	set_open(true)


func close() -> void:
	set_open(false)


func toggle() -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	if _tween:
		_tween.kill()
	_pass_through_bodies()
	_play_creak()
	# Physics process so the leaf's AnimatableBody3D moves in step with the physics server.
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_leaf, "rotation:y", _target_yaw(), swing_time)
	if is_open:
		_tween.tween_callback(_fade_out_creak)
	_tween.tween_callback(set_physics_process.bind(true))


func _play_creak() -> void:
	_stop_creak()
	if is_open:
		_creak = AudioManager.play("door_open", global_position, Vector2(0.96, 1.04), CREAK_VOLUME_DB, OPEN_CREAK_START)
	else:
		_creak = AudioManager.play("door_close", global_position, Vector2.ONE, CREAK_VOLUME_DB, maxf(CLOSE_LATCH_TIME - swing_time, 0.0))


func _fade_out_creak() -> void:
	if not is_instance_valid(_creak):
		return
	var fade := _creak.create_tween()
	fade.tween_property(_creak, "volume_db", SILENT_DB, CREAK_FADE_TIME)
	fade.tween_callback(_creak.queue_free)


func _stop_creak() -> void:
	if is_instance_valid(_creak):
		_creak.queue_free()
	_creak = null


func _physics_process(_delta: float) -> void:
	if _push_out_characters():
		return
	_body.collision_layer = _solid_layer
	set_physics_process(false)
	(opened if is_open else closed).emit()


func _pass_through_bodies() -> void:
	set_physics_process(false)
	_body.collision_layer = 0


func _push_out_characters() -> bool:
	var pushed := false
	for child in _body.get_children():
		if child is CollisionShape3D:
			for character in _characters_inside(child as CollisionShape3D):
				_push_clear_of(character, child as CollisionShape3D)
				pushed = true
	return pushed


func _characters_inside(shape_node: CollisionShape3D) -> Array[CharacterBody3D]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = _solid_layer
	query.exclude = [_body.get_rid()]
	var characters: Array[CharacterBody3D] = []
	for hit in _body.get_world_3d().direct_space_state.intersect_shape(query):
		if hit.get("collider") is CharacterBody3D:
			characters.append(hit.get("collider") as CharacterBody3D)
	return characters


func _push_clear_of(character: CharacterBody3D, shape_node: CollisionShape3D) -> void:
	var normal := shape_node.global_basis.z.normalized()
	var offset := (character.global_position - shape_node.global_position).dot(normal)
	var side := 1.0 if offset >= 0.0 else -1.0
	character.global_position += normal * (side * CLEAR_DISTANCE - offset)


func _collision_body_of(leaf: Node3D) -> CollisionObject3D:
	for child in leaf.get_children():
		if child is CollisionObject3D:
			return child as CollisionObject3D
	return null


func _target_yaw() -> float:
	return _closed_yaw - deg_to_rad(open_angle) if is_open else _closed_yaw
