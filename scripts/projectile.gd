class_name Projectile
extends Node3D

const WORLD_LAYER := 1
const PREFER_HURTBOX_MARGIN := 0.05
const SMALLEST_SCALE := 0.01

@export var speed := 0.0
@export var lifetime := 2.0
@export var damage := 10.0
@export var max_range := 30.0
@export_range(0.0, 1.0) var shrink_from := 1.0

var shooter: Node3D = null
var ignored: Array[RID] = []

var _age := 0.0
var _launch_checked := false
var _travelled := 0.0
var _light_energies: Dictionary[Light3D, float] = {}
var _particle_scales: Dictionary[CPUParticles3D, Vector2] = {}


func _ready() -> void:
	for light: Light3D in find_children("*", "Light3D", true, false):
		_light_energies[light] = light.light_energy
	for particles: CPUParticles3D in find_children("*", "CPUParticles3D", true, false):
		_particle_scales[particles] = Vector2(particles.scale_amount_min, particles.scale_amount_max)


func _physics_process(delta: float) -> void:
	if not _launch_checked:
		_launch_checked = true
		if _launched_inside_world():
			queue_free()
			return
	_age += delta
	if speed > 0.0 and _fly(_next_motion(delta)):
		queue_free()
		return
	if _age >= lifetime or _travelled >= max_range:
		queue_free()
		return
	if _travelled > max_range * shrink_from:
		_shrink_to(_size_left())


func _next_motion(delta: float) -> Vector3:
	return (global_transform.basis.z.normalized() * speed * delta).limit_length(max_range - _travelled)


func _size_left() -> float:
	return 1.0 - (_travelled / max_range - shrink_from) / (1.0 - shrink_from)


func _shrink_to(size: float) -> void:
	scale = Vector3.ONE * maxf(size, SMALLEST_SCALE)
	for light in _light_energies:
		light.light_energy = _light_energies[light] * size
	for particles in _particle_scales:
		particles.scale_amount_min = _particle_scales[particles].x * size
		particles.scale_amount_max = _particle_scales[particles].y * size


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
	_travelled += motion.length()
	return false


func _launched_inside_world() -> bool:
	if not is_instance_valid(shooter):
		return false
	var body_center := Vector3(shooter.global_position.x, global_position.y, shooter.global_position.z)
	return not _cast(body_center, global_position, false).is_empty()


func _cast(from: Vector3, to: Vector3, hurtboxes: bool) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = hurtboxes
	query.collide_with_bodies = not hurtboxes
	query.hit_from_inside = not hurtboxes
	query.collision_mask = 1 << ((Hurtbox.LAYER if hurtboxes else WORLD_LAYER) - 1)
	query.exclude = _shooter_rids()
	return get_world_3d().direct_space_state.intersect_ray(query)


func _active_hurtbox_hit(ray_hit: Dictionary) -> Dictionary:
	if ray_hit.is_empty() or not (ray_hit.collider as Hurtbox).is_active():
		return {}
	return ray_hit


func _shooter_rids() -> Array[RID]:
	var rids: Array[RID] = ignored.duplicate()
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
