class_name ItemPickup
extends Area3D

const GROUP := &"item_pickups"
const SHAPE_PATH := ^"CollisionShape3D"
const FLIGHT_TIME := 0.45
const ARC_HEIGHT := 0.6
const PULL_START_SPEED := 2.0
const PULL_ACCELERATION := 30.0
const PULL_TARGET_HEIGHT := 0.8
const CATCH_DISTANCE := 0.3

@export var item_name := ""
@export var auto_pick_up := true
@export var count := 1
@export_file("*.tscn") var full_stack_scene := ""
@export_file("*.tscn") var single_item_scene := ""

var _landed := true
var _puller: Node3D = null
var _pull_inventory: Inventory = null
var _pull_speed := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	set_physics_process(false)


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


func can_be_pulled() -> bool:
	return auto_pick_up and _landed and _puller == null and not is_queued_for_deletion()


func pull_into(puller: Node3D, inventory: Inventory) -> void:
	_puller = puller
	_pull_inventory = inventory
	_pull_speed = PULL_START_SPEED
	set_physics_process(true)


func launch(from: Vector3, ground: Vector3) -> void:
	_landed = false
	var landing := ground + Vector3.UP * _rest_height()
	global_position = from
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(_fly.bind(from, landing), 0.0, 1.0, FLIGHT_TIME)
	tween.tween_callback(_land)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_puller):
		_stop_pull()
		return
	var target := _puller.global_position + Vector3.UP * PULL_TARGET_HEIGHT
	_pull_speed += PULL_ACCELERATION * delta
	global_position = global_position.move_toward(target, _pull_speed * delta)
	if global_position.distance_to(target) <= CATCH_DISTANCE:
		_arrive()


func _arrive() -> void:
	var feet := _puller.global_position
	collect_into(_pull_inventory)
	_stop_pull()
	if not is_queued_for_deletion():
		launch(global_position, feet)


func _stop_pull() -> void:
	_puller = null
	_pull_inventory = null
	set_physics_process(false)


func _fly(progress: float, from: Vector3, landing: Vector3) -> void:
	var lift := ARC_HEIGHT * 4.0 * progress * (1.0 - progress)
	global_position = from.lerp(landing, progress) + Vector3.UP * lift


func _land() -> void:
	_landed = true


func _rest_height() -> float:
	var shape := (get_node(SHAPE_PATH) as CollisionShape3D).shape
	return maxf(-shape.get_debug_mesh().get_aabb().position.y, 0.0)
