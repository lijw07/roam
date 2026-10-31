class_name Inventory
extends Node

signal changed
signal thrown(scene_path: String, count: int)

@export var columns := 3
@export var rows := 3
@export var max_stack := 5

var slots: Array[Slot] = []


class Slot:
	var item_name := ""
	var scene_path := ""
	var count := 0


func _ready() -> void:
	for _index in slot_count():
		slots.append(Slot.new())


func slot_count() -> int:
	return columns * rows


func add(pickup: ItemPickup) -> int:
	var stored := 0
	while stored < pickup.count:
		var slot := _slot_for(pickup.item_name)
		if slot == null:
			break
		var amount := mini(pickup.count - stored, max_stack - slot.count)
		_fill(slot, pickup, amount)
		stored += amount
	if stored > 0:
		changed.emit()
	return stored


func has_room_for(item_name: String) -> bool:
	return _slot_for(item_name) != null


func swap(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return
	var moved := slots[from_index]
	slots[from_index] = slots[to_index]
	slots[to_index] = moved
	changed.emit()


func throw_out(index: int) -> void:
	var slot := slots[index]
	if slot.count == 0:
		return
	slots[index] = Slot.new()
	changed.emit()
	thrown.emit(slot.scene_path, slot.count)


func _fill(slot: Slot, pickup: ItemPickup, amount: int) -> void:
	slot.item_name = pickup.item_name
	slot.scene_path = pickup.item_scene_path()
	slot.count += amount


func _slot_for(item_name: String) -> Slot:
	var slot := _stack_with_room_for(item_name)
	return slot if slot != null else _first_empty_slot()


func _stack_with_room_for(item_name: String) -> Slot:
	for slot in slots:
		if slot.count > 0 and slot.item_name == item_name and slot.count < max_stack:
			return slot
	return null


func _first_empty_slot() -> Slot:
	for slot in slots:
		if slot.count == 0:
			return slot
	return null
