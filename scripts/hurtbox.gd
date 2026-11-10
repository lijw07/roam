class_name Hurtbox
extends Area3D

signal hit_taken(hit: Hit, damage: float)
signal blocked(hit: Hit)

const LAYER := 2
const GROUP := &"hurtboxes"
const WORLD_LAYER := 1
const SIGHT_PASSES := 4

@export var health: Health
@export var body: CollisionObject3D
@export var padding := 0.0

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
		AudioManager.play("block_metal", global_position, Vector2(0.92, 1.08), -3.0)
		blocked.emit(hit)
		return
	var damage := health.take_damage(hit.amount, hit.attacker)
	if damage > 0.0:
		if hit.is_punch:
			AudioManager.play("impact_flesh", global_position, Vector2(0.9, 1.08), -3.5)
		else:
			AudioManager.play("impact_flesh" if damage < 25.0 else "impact_heavy", global_position, Vector2(0.9, 1.08), -3.5)
	hit_taken.emit(hit, damage)


func is_exposed_to(origin: Vector3, attacker: CollisionObject3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, bounds().get_center(), 1 << (WORLD_LAYER - 1))
	var excluded: Array[RID] = [attacker.get_rid()]
	if is_instance_valid(body):
		excluded.append(body.get_rid())
	var space := get_world_3d().direct_space_state
	for _pass in SIGHT_PASSES:
		query.exclude = excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		if hit.collider is StaticBody3D:
			return false
		excluded.append(hit.rid)
	return true


func top() -> Vector3:
	var box := bounds()
	return Vector3(box.get_center().x, box.end.y, box.get_center().z)


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
		copy.shape = _padded(source_shape.shape)
		add_child(copy)
		copy.global_transform = source_shape.global_transform


func _padded(shape: Shape3D) -> Shape3D:
	if padding <= 0.0:
		return shape
	var padded: Shape3D = shape.duplicate()
	if padded is CapsuleShape3D:
		var capsule := padded as CapsuleShape3D
		capsule.radius += padding
		capsule.height += padding * 2.0
	elif padded is CylinderShape3D:
		var cylinder := padded as CylinderShape3D
		cylinder.radius += padding
		cylinder.height += padding * 2.0
	elif padded is SphereShape3D:
		var sphere := padded as SphereShape3D
		sphere.radius += padding
	elif padded is BoxShape3D:
		var box := padded as BoxShape3D
		box.size += Vector3.ONE * padding * 2.0
	return padded
