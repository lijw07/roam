class_name AimTargeting
extends Node

const WORLD_LAYER := 1
const AIM_DISTANCE := 40.0
const MAX_PASSES := 8
const PICKUP_AIM_RADIUS := 0.35
const CHEST_HEIGHT := 1.1
const START_MARGIN := 0.5
const SOFT_LOCK_RANGE := 3.0
const SOFT_LOCK_CONE_DEGREES := 50.0

@export var player: CharacterBody3D

var target: Enemy = null
var attack_target: Enemy = null
var looked_at: Node3D = null
var hovered_door: Door = null
var hovered_door_point := Vector3.ZERO

var _ray := PhysicsRayQueryParameters3D.new()
var _solid_ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = true
	_ray.collision_mask = (1 << (WORLD_LAYER - 1)) | (1 << (Hurtbox.LAYER - 1))
	_solid_ray.collide_with_areas = false
	_solid_ray.collision_mask = 1 << (WORLD_LAYER - 1)


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(player):
		looked_at = null
		target = null
		attack_target = null
		hovered_door = null
		return
	var forward := -camera.global_basis.z
	var chest := player.global_position + Vector3.UP * CHEST_HEIGHT
	var depth := maxf((chest - camera.global_position).dot(forward) - START_MARGIN, 0.0)
	var start := camera.global_position + forward * depth
	var end := start + forward * AIM_DISTANCE
	var hit := _first_hit(start, end)
	var aim_point: Vector3 = hit.get("position", end)
	looked_at = _outlinable_of(hit.get("collider"))
	if looked_at == null:
		looked_at = _pickup_near_ray(start, aim_point)
	target = looked_at as Enemy
	player.set("aim_point", aim_point)
	attack_target = _melee_target(forward) if _player_fights_in_melee() else target
	player.set("attack_target", attack_target)
	_find_hovered_door(start, end)


func _player_fights_in_melee() -> bool:
	return player.has_method(&"fights_in_melee") and player.fights_in_melee()


func _melee_target(camera_forward: Vector3) -> Enemy:
	if _within_soft_lock_range(target):
		return target
	var forward := Vector3(camera_forward.x, 0.0, camera_forward.z).normalized()
	var chest := player.global_position + Vector3.UP * CHEST_HEIGHT
	var nearest: Enemy = null
	var nearest_distance := SOFT_LOCK_RANGE
	for hurtbox: Hurtbox in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var enemy := hurtbox.get_parent() as Enemy
		if enemy == null or enemy.dead or not hurtbox.is_active():
			continue
		var offset := _flat_offset_to(enemy)
		if offset.length() < nearest_distance and _within_cone(offset, forward) and hurtbox.is_exposed_to(chest, player):
			nearest = enemy
			nearest_distance = offset.length()
	return nearest


func _within_soft_lock_range(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.dead and _flat_offset_to(enemy).length() <= SOFT_LOCK_RANGE


func _within_cone(offset: Vector3, forward: Vector3) -> bool:
	return offset.is_zero_approx() or forward.angle_to(offset) <= deg_to_rad(SOFT_LOCK_CONE_DEGREES)


func _flat_offset_to(node: Node3D) -> Vector3:
	var offset := node.global_position - player.global_position
	offset.y = 0.0
	return offset


func _find_hovered_door(start: Vector3, end: Vector3) -> void:
	var hit := _first_solid_hit(start, end)
	hovered_door = _door_of(hit.get("collider"))
	hovered_door_point = hit.get("position", end)


func _first_solid_hit(start: Vector3, end: Vector3) -> Dictionary:
	var exclude := _player_rids()
	_solid_ray.from = start
	_solid_ray.to = end
	for _pass in MAX_PASSES:
		_solid_ray.exclude = exclude
		var hit := player.get_world_3d().direct_space_state.intersect_ray(_solid_ray)
		if hit.is_empty() or not _passes_through(hit.collider):
			return hit
		exclude.append(hit.rid)
	return {}


func _door_of(collider: Object) -> Door:
	var node := collider as Node
	if node == null or not node.is_in_group(Door.LEAF_GROUP):
		return null
	while node != null and not (node is Door):
		node = node.get_parent()
	return node as Door


func _pickup_near_ray(start: Vector3, stop: Vector3) -> ItemPickup:
	var direction := (stop - start).normalized()
	var reach := start.distance_to(stop) + PICKUP_AIM_RADIUS
	var closest: ItemPickup = null
	var closest_offset := PICKUP_AIM_RADIUS
	for pickup: ItemPickup in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var offset := _offset_from_ray(pickup.global_position, start, direction, reach)
		if offset < closest_offset and not pickup.is_queued_for_deletion():
			closest = pickup
			closest_offset = offset
	return closest


func _offset_from_ray(point: Vector3, start: Vector3, direction: Vector3, reach: float) -> float:
	var along := (point - start).dot(direction)
	if along < 0.0 or along > reach:
		return INF
	return point.distance_to(start + direction * along)


func _first_hit(start: Vector3, end: Vector3) -> Dictionary:
	var exclude := _player_rids()
	_ray.from = start
	_ray.to = end
	for _pass in MAX_PASSES:
		_ray.exclude = exclude
		var hit := player.get_world_3d().direct_space_state.intersect_ray(_ray)
		if hit.is_empty() or not _passes_through(hit.collider):
			return hit
		exclude.append(hit.rid)
	return {}


func _passes_through(collider: Object) -> bool:
	if collider is Node and player.is_ancestor_of(collider as Node):
		return true
	if collider is Hurtbox:
		return not (collider as Hurtbox).is_active()
	return collider is Area3D and not (collider is ItemPickup)


func _outlinable_of(collider: Object) -> Node3D:
	if collider is ItemPickup:
		return collider as ItemPickup
	if collider is Node and (collider as Node).is_in_group(Door.LEAF_GROUP):
		return (collider as Node).get_parent() as Node3D
	var node := collider as Node
	while node != null:
		var hurtbox := _hurtbox_of(node)
		if hurtbox != null:
			return node as Node3D if hurtbox.is_active() else null
		node = node.get_parent()
	return null


func _hurtbox_of(node: Node) -> Hurtbox:
	for child in node.get_children():
		if child is Hurtbox:
			return child as Hurtbox
	return null


func _player_rids() -> Array[RID]:
	var rids: Array[RID] = [player.get_rid()]
	var hurtbox := player.get("hurtbox") as Hurtbox
	if hurtbox != null:
		rids.append(hurtbox.get_rid())
	return rids
