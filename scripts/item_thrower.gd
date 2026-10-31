class_name ItemThrower
extends Node

const THROW_ANIMATION := &"general/Throw"
const RELEASE_TIME := 0.67
const HAND_BONE := &"handslot.r"
const MODEL_PATH := ^"Model"
const SKELETON_PATH := ^"Model/Rig_Medium/Skeleton3D"
const GROUND_PROBE_HEIGHT := 2.0
const GROUND_PROBE_DEPTH := 6.0

@export var inventory: Inventory
@export var throw_distance := 2.0

@onready var body: CharacterBody3D = get_parent()
@onready var model: Node3D = body.get_node(MODEL_PATH)
@onready var skeleton: Skeleton3D = body.get_node(SKELETON_PATH)


func _ready() -> void:
	inventory.thrown.connect(_on_thrown)


func _on_thrown(scene_path: String, count: int) -> void:
	body.throw()
	if body.current_animation() == THROW_ANIMATION:
		await get_tree().create_timer(RELEASE_TIME, false, true).timeout
	_release(load(scene_path), count)


func _release(scene: PackedScene, count: int) -> void:
	var pickup := scene.instantiate() as ItemPickup
	pickup.count = count
	body.get_parent().add_child(pickup)
	var target := body.global_position + _flat_forward() * throw_distance
	pickup.launch(_hand_position(), _ground_below(target))


func _hand_position() -> Vector3:
	var bone := skeleton.find_bone(HAND_BONE)
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin


func _flat_forward() -> Vector3:
	var forward := model.global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _ground_below(point: Vector3) -> Vector3:
	var from := point + Vector3.UP * GROUND_PROBE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * GROUND_PROBE_DEPTH, 0xFFFFFFFF, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3(point.x, body.global_position.y, point.z)
	return hit.position
