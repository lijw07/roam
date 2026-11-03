class_name ContextSteering
extends RefCounted

const SLOT_COUNT := 16
const PROBE_HEIGHT := 0.6
const WORLD_MASK := 1
const SIDEWAYS_INTEREST := 0.35
const SMOOTHING := 0.3

var look_ahead := 1.4
var separation_radius := 1.4

var _directions: Array[Vector3] = []
var _previous := Vector3.ZERO
var _ray := PhysicsRayQueryParameters3D.new()


func _init() -> void:
	for slot in SLOT_COUNT:
		var angle := TAU * slot / SLOT_COUNT
		_directions.append(Vector3(sin(angle), 0.0, cos(angle)))
	_ray.collision_mask = WORLD_MASK


func steer(body: CharacterBody3D, desired: Vector3, neighbours: Array[Node3D], exclude: Array[RID]) -> Vector3:
	if desired.is_zero_approx():
		_previous = Vector3.ZERO
		return separate(body, neighbours)
	var heading := desired.normalized()
	var danger := _danger_map(body, neighbours, exclude)
	var best := -1
	var best_score := 0.0
	for slot in SLOT_COUNT:
		var score := _interest(heading, _directions[slot]) * (1.0 - danger[slot])
		if score > best_score:
			best_score = score
			best = slot
	if best < 0:
		return separate(body, neighbours)
	_previous = _smoothed(_directions[best])
	return _previous * minf(desired.length(), 1.0)


func separate(body: Node3D, neighbours: Array[Node3D]) -> Vector3:
	var push := Vector3.ZERO
	for neighbour in neighbours:
		var away := _flat(body.global_position - neighbour.global_position)
		var distance := away.length()
		if distance > 0.0 and distance < separation_radius:
			push += away / distance * (1.0 - distance / separation_radius)
	return push.limit_length()


func _smoothed(direction: Vector3) -> Vector3:
	var blended := _previous.lerp(direction, 1.0 - SMOOTHING)
	return direction if blended.is_zero_approx() else blended.normalized()


func _interest(heading: Vector3, direction: Vector3) -> float:
	return clampf((heading.dot(direction) + SIDEWAYS_INTEREST) / (1.0 + SIDEWAYS_INTEREST), 0.0, 1.0)


func _danger_map(body: CharacterBody3D, neighbours: Array[Node3D], exclude: Array[RID]) -> PackedFloat32Array:
	var danger := PackedFloat32Array()
	danger.resize(SLOT_COUNT)
	var space := body.get_world_3d().direct_space_state
	var origin := body.global_position + Vector3.UP * PROBE_HEIGHT
	_ray.exclude = exclude
	for slot in SLOT_COUNT:
		danger[slot] = _obstacle_danger(space, origin, _directions[slot])
	for neighbour in neighbours:
		_add_crowd_danger(danger, body.global_position, neighbour.global_position)
	return danger


func _obstacle_danger(space: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3) -> float:
	_ray.from = origin
	_ray.to = origin + direction * look_ahead
	var hit := space.intersect_ray(_ray)
	if hit.is_empty() or hit.collider is CharacterBody3D:
		return 0.0
	return 1.0 - origin.distance_to(hit.position) / look_ahead


func _add_crowd_danger(danger: PackedFloat32Array, from: Vector3, neighbour: Vector3) -> void:
	var toward := _flat(neighbour - from)
	var distance := toward.length()
	if distance <= 0.0 or distance >= separation_radius:
		return
	var closeness := 1.0 - distance / separation_radius
	var bearing := toward / distance
	for slot in SLOT_COUNT:
		danger[slot] = maxf(danger[slot], _directions[slot].dot(bearing) * closeness)


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
