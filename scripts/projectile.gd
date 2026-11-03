class_name Projectile
extends Node3D

const WORLD_LAYER := 1
const PREFER_HURTBOX_MARGIN := 0.05

@export var speed := 0.0
@export var lifetime := 2.0
@export var damage := 10.0

var shooter: Node3D = null

var _age := 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if speed > 0.0 and _fly(global_transform.basis.z * speed * delta):
		queue_free()
		return
	if _age >= lifetime:
		queue_free()


func _fly(motion: Vector3) -> bool:
	var from := global_position
	var to := from + motion
	var hurtbox_hit := _active_hurtbox_hit(_cast(from, to, true))
	var world_hit := _cast(from, to, false)
	if not hurtbox_hit.is_empty() and (world_hit.is_empty() or _distance(from, hurtbox_hit) <= _distance(from, world_hit) + PREFER_HURTBOX_MARGIN):
		(hurtbox_hit.collider as Hurtbox).receive(Hit.new(damage, shooter, hurtbox_hit.position))
		return true
	if not world_hit.is_empty():
		return true
	global_position = to
	return false


func _cast(from: Vector3, to: Vector3, hurtboxes: bool) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = hurtboxes
	query.collide_with_bodies = not hurtboxes
	query.collision_mask = 1 << ((Hurtbox.LAYER if hurtboxes else WORLD_LAYER) - 1)
	query.exclude = _shooter_rids()
	return get_world_3d().direct_space_state.intersect_ray(query)


func _active_hurtbox_hit(ray_hit: Dictionary) -> Dictionary:
	if ray_hit.is_empty() or not (ray_hit.collider as Hurtbox).is_active():
		return {}
	return ray_hit


func _shooter_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if not is_instance_valid(shooter):
		return rids
	if shooter is CollisionObject3D:
		rids.append(shooter.get_rid())
	for child in shooter.get_children():
		if child is Hurtbox:
			rids.append(child.get_rid())
	return rids


func _distance(from: Vector3, ray_hit: Dictionary) -> float:
	return from.distance_to(ray_hit.position)
