class_name Inventory
extends Node

signal changed
signal thrown(scene_path: String, count: int)

@export var columns := 3
@export var rows := 3

var slots: Array[Slot] = []


class Slot:
	var item_name := ""
	var scene_path := ""
	var count := 0
	var max_stack := 0


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
		var amount := mini(pickup.count - stored, pickup.max_stack - slot.count)
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


func count_at(index: int) -> int:
	return slots[index].count


func movable_amount(from_index: int, to_index: int) -> int:
	var source := slots[from_index]
	var target := slots[to_index]
	if from_index == to_index:
		return 0
	if target.count == 0:
		return source.count
	if target.item_name == source.item_name:
		return mini(source.count, target.max_stack - target.count)
	return 0


func move(from_index: int, to_index: int, amount: int) -> void:
	var moved := mini(amount, movable_amount(from_index, to_index))
	if moved <= 0:
		return
	var source := slots[from_index]
	var target := slots[to_index]
	target.item_name = source.item_name
	target.scene_path = source.scene_path
	target.max_stack = source.max_stack
	target.count += moved
	_take(from_index, moved)
	changed.emit()


func throw_out(index: int, amount: int) -> void:
	var thrown_amount := mini(amount, count_at(index))
	if thrown_amount <= 0:
		return
	var scene_path := slots[index].scene_path
	_take(index, thrown_amount)
	changed.emit()
	thrown.emit(scene_path, thrown_amount)


func _take(index: int, amount: int) -> void:
	slots[index].count -= amount
	if slots[index].count == 0:
		slots[index] = Slot.new()


func _fill(slot: Slot, pickup: ItemPickup, amount: int) -> void:
	slot.item_name = pickup.item_name
	slot.scene_path = pickup.item_scene_path()
	slot.max_stack = pickup.max_stack
	slot.count += amount


func _slot_for(item_name: String) -> Slot:
	var slot := _stack_with_room_for(item_name)
	return slot if slot != null else _first_empty_slot()


func _stack_with_room_for(item_name: String) -> Slot:
	for slot in slots:
		if slot.count > 0 and slot.item_name == item_name and slot.count < slot.max_stack:
			return slot
	return null


func _first_empty_slot() -> Slot:
	for slot in slots:
		if slot.count == 0:
			return slot
	return null
