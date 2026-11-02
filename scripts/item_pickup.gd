class_name ItemPickup
extends Area3D

const GROUP := &"item_pickups"
const INVENTORY_PATH := ^"Inventory"
const SHAPE_PATH := ^"CollisionShape3D"
const FLIGHT_TIME := 0.45
const ARC_HEIGHT := 0.6

@export var item_name := ""
@export var auto_pick_up := false
@export var count := 1
@export_file("*.tscn") var full_stack_scene := ""
@export_file("*.tscn") var single_item_scene := ""


func _ready() -> void:
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)


func collect_into(inventory: Inventory) -> bool:
	if is_queued_for_deletion():
		return false
	var stored := inventory.add(self)
	count -= stored
	if count == 0:
		queue_free()
	return stored > 0


func item_scene_path() -> String:
	return scene_file_path if single_item_scene.is_empty() else single_item_scene


func launch(from: Vector3, ground: Vector3) -> void:
	monitoring = false
	var landing := ground + Vector3.UP * _rest_height()
	global_position = from
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(_fly.bind(from, landing), 0.0, 1.0, FLIGHT_TIME)
	tween.tween_callback(_land)


func _fly(progress: float, from: Vector3, landing: Vector3) -> void:
	var lift := ARC_HEIGHT * 4.0 * progress * (1.0 - progress)
	global_position = from.lerp(landing, progress) + Vector3.UP * lift


func _land() -> void:
	monitoring = true


func _rest_height() -> float:
	var shape := (get_node(SHAPE_PATH) as CollisionShape3D).shape
	return maxf(-shape.get_debug_mesh().get_aabb().position.y, 0.0)


func _on_body_entered(body: Node3D) -> void:
	if not auto_pick_up:
		return
	var inventory := body.get_node_or_null(INVENTORY_PATH) as Inventory
	if inventory != null:
		collect_into(inventory)
