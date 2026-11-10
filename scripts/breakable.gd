extends Node3D

signal broken

const FOOTPRINT_MARGIN := 0.1
const BASE_CLEARANCE := 0.2
const TOP_REACH := 0.3

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	health.died.connect(_break)


func _break() -> void:
	var support := hurtbox.bounds()
	AudioManager.play_surface_impact(AudioManager.surface_for(self), global_position, 1.0)
	AudioManager.play("breakable_crack", global_position, Vector2(0.92, 1.08), -3.5)
	broken.emit()
	_release_resting_items(support)
	queue_free()


func _release_resting_items(support: AABB) -> void:
	for item in _nearby_items():
		if item is Node3D and _rests_on(item, support):
			_release(item, support)


func _nearby_items() -> Array[Node]:
	var items: Array[Node] = get_tree().get_nodes_in_group(ItemPickup.GROUP)
	var props := get_parent().get_parent() if get_parent() != null else null
	if props != null:
		for group in props.get_children():
			items.append_array(group.get_children())
	return items


func _rests_on(item: Node3D, support: AABB) -> bool:
	if item == self or is_ancestor_of(item) or item.is_queued_for_deletion():
		return false
	var spot := item.global_position
	return spot.x >= support.position.x - FOOTPRINT_MARGIN and spot.x <= support.end.x + FOOTPRINT_MARGIN \
		and spot.z >= support.position.z - FOOTPRINT_MARGIN and spot.z <= support.end.z + FOOTPRINT_MARGIN \
		and spot.y >= support.position.y + BASE_CLEARANCE and spot.y <= support.end.y + TOP_REACH


func _release(item: Node3D, support: AABB) -> void:
	if item is ItemPickup:
		var spot := item.global_position
		(item as ItemPickup).launch(spot, Vector3(spot.x, support.position.y, spot.z))
	elif item.get_node_or_null(^"Health") is Health:
		(item.get_node(^"Health") as Health).kill()
	else:
		item.queue_free()
