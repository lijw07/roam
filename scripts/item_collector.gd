class_name ItemCollector
extends Node

@export var inventory: Inventory
@export var reach := 1.6

@onready var body: Node3D = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_collect_nearest()


func nearest_pickup() -> ItemPickup:
	var nearest: ItemPickup = null
	var best := reach
	for pickup: ItemPickup in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var distance := _flat_distance_to(pickup)
		if distance < best:
			best = distance
			nearest = pickup
	return nearest


func _collect_nearest() -> void:
	var pickup := nearest_pickup()
	if pickup != null and inventory.has_room_for(pickup.item_name):
		body.collect(pickup, pickup.collect_into.bind(inventory))


func _flat_distance_to(pickup: ItemPickup) -> float:
	var offset := pickup.global_position - body.global_position
	return Vector2(offset.x, offset.z).length()
