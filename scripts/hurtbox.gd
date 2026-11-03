class_name Hurtbox
extends Area3D

signal hit_taken(hit: Hit, damage: float)
signal blocked(hit: Hit)

const LAYER := 2
const GROUP := &"hurtboxes"

@export var health: Health
@export var body: CollisionObject3D

var block_check := Callable()


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(LAYER, true)
	monitoring = false
	if body == null:
		body = _find_body()
	if body != null:
		_copy_shapes_of(body)
	health.died.connect(_set_active.bind(false))
	health.revived.connect(_set_active.bind(true))


func is_active() -> bool:
	return monitorable and not health.is_dead()


func receive(hit: Hit) -> void:
	if hit.attacker == get_parent() or not is_active():
		return
	if block_check.is_valid() and block_check.call(hit):
		blocked.emit(hit)
		return
	hit_taken.emit(hit, health.take_damage(hit.amount, hit.attacker))


func top() -> Vector3:
	var box := bounds()
	return Vector3(box.get_center().x, box.end.y, box.get_center().z)


func closest_point(point: Vector3) -> Vector3:
	var box := bounds()
	return point.clamp(box.position, box.end)


func outward_toward(point: Vector3) -> Vector3:
	var outward := point - bounds().get_center()
	outward.y = 0.0
	return outward.normalized() if not outward.is_zero_approx() else Vector3.BACK


func bounds() -> AABB:
	var box := AABB(global_position, Vector3.ZERO)
	for shape: CollisionShape3D in find_children("*", "CollisionShape3D", false, false):
		box = box.merge(shape.global_transform * shape.shape.get_debug_mesh().get_aabb())
	return box


func _set_active(active: bool) -> void:
	set_deferred("monitorable", active)


func _find_body() -> CollisionObject3D:
	var parent := get_parent()
	if parent is CollisionObject3D and not (parent is Area3D):
		return parent
	for candidate: CollisionObject3D in parent.find_children("*", "CollisionObject3D", true, false):
		if not (candidate is Area3D):
			return candidate
	return null


func _copy_shapes_of(source: CollisionObject3D) -> void:
	for source_shape: CollisionShape3D in source.find_children("*", "CollisionShape3D", false, false):
		if source_shape.disabled or source_shape.shape == null:
			continue
		var copy := CollisionShape3D.new()
		copy.shape = source_shape.shape
		add_child(copy)
		copy.global_transform = source_shape.global_transform
