extends Node3D
class_name Door

## Swings a doorway's door leaf open and closed around its hinge.
## The leaf's origin sits on the hinge, so rotating it around Y opens the door.

signal opened
signal closed

@export_node_path("Node3D") var leaf_path: NodePath
## Positive swings toward the wall's front (+Z), which faces into rooms.
@export var open_angle := 100.0
@export var swing_time := 0.6
@export var start_open := false

var is_open := false

var _leaf: Node3D
var _closed_yaw := 0.0
var _tween: Tween


func _ready() -> void:
	_leaf = get_node(leaf_path)
	_closed_yaw = _leaf.rotation.y
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
	# Physics process so the leaf's AnimatableBody3D moves in step with the physics server.
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_leaf, "rotation:y", _target_yaw(), swing_time)
	_tween.tween_callback(opened.emit if is_open else closed.emit)


func _target_yaw() -> float:
	return _closed_yaw - deg_to_rad(open_angle) if is_open else _closed_yaw
