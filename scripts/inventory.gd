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
	var potion: Potion = null


func _ready() -> void:
	for _index in slot_count():
		slots.append(Slot.new())


func slot_count() -> int:
	return columns * rows


func add(pickup: ItemPickup) -> int:
	return add_item(pickup.item_name, pickup.item_scene_path(), pickup.max_stack, pickup.count, pickup.potion)


func add_item(item_name: String, scene_path: String, max_stack: int, count: int, potion: Potion = null) -> int:
	var stored := 0
	while stored < count:
		var slot := _slot_for(item_name)
		if slot == null:
			break
		var amount := mini(count - stored, max_stack - slot.count)
		_fill(slot, item_name, scene_path, max_stack, potion, amount)
		stored += amount
	if stored > 0:
		changed.emit()
	return stored


func has_room_for(item_name: String) -> bool:
	return _slot_for(item_name) != null


func room_for(item_name: String, max_stack: int) -> int:
	var room := 0
	for slot in slots:
		if slot.count == 0:
			room += max_stack
		elif slot.item_name == item_name:
			room += slot.max_stack - slot.count
	return room


func count_of(item_name: String) -> int:
	var total := 0
	for slot in slots:
		if slot.item_name == item_name:
			total += slot.count
	return total


func take(index: int, amount: int) -> void:
	_take(index, mini(amount, count_at(index)))
	changed.emit()


func remove_item(item_name: String, amount: int) -> void:
	var left := amount
	for index in slots.size():
		if left == 0:
			break
		if slots[index].item_name == item_name and slots[index].count > 0:
			var taken := mini(left, slots[index].count)
			_take(index, taken)
			left -= taken
	changed.emit()


func swap(from_index: int, to_index: int) -> void:
	swap_from(self, from_index, to_index)


func swap_from(source: Inventory, from_index: int, to_index: int) -> void:
	if source == self and from_index == to_index:
		return
	var moved := source.slots[from_index]
	source.slots[from_index] = slots[to_index]
	slots[to_index] = moved
	if source != self:
		source.changed.emit()
	changed.emit()


func count_at(index: int) -> int:
	return slots[index].count


func potion_at(index: int) -> Potion:
	return slots[index].potion if count_at(index) > 0 else null


func use_one(index: int) -> void:
	if count_at(index) == 0:
		return
	_take(index, 1)
	changed.emit()


func movable_amount(from_index: int, to_index: int) -> int:
	return movable_amount_from(self, from_index, to_index)


func movable_amount_from(source: Inventory, from_index: int, to_index: int) -> int:
	var moving := source.slots[from_index]
	var target := slots[to_index]
	if source == self and from_index == to_index:
		return 0
	if target.count == 0:
		return moving.count
	if target.item_name == moving.item_name:
		return mini(moving.count, target.max_stack - target.count)
	return 0


func move(from_index: int, to_index: int, amount: int) -> void:
	move_from(self, from_index, to_index, amount)


func move_from(source: Inventory, from_index: int, to_index: int, amount: int) -> void:
	var moved := mini(amount, movable_amount_from(source, from_index, to_index))
	if moved <= 0:
		return
	var moving := source.slots[from_index]
	_fill(slots[to_index], moving.item_name, moving.scene_path, moving.max_stack, moving.potion, moved)
	source._take(from_index, moved)
	if source != self:
		source.changed.emit()
	changed.emit()


func deposit_into(target: Inventory) -> void:
	for index in slots.size():
		var slot := slots[index]
		if slot.count > 0:
			_take(index, target.add_item(slot.item_name, slot.scene_path, slot.max_stack, slot.count, slot.potion))
	changed.emit()


func clear() -> void:
	for index in slots.size():
		slots[index] = Slot.new()
	changed.emit()


func throw_out(index: int, amount: int) -> void:
	var thrown_amount := mini(amount, count_at(index))
	if thrown_amount <= 0:
		return
	var scene_path := slots[index].scene_path
	_take(index, thrown_amount)
	changed.emit()
	thrown.emit(scene_path, thrown_amount)


func to_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for slot in slots:
		data.append({
			"item_name": slot.item_name,
			"scene_path": slot.scene_path,
			"count": slot.count,
			"max_stack": slot.max_stack,
			"potion": slot.potion.resource_path if slot.potion != null else "",
		})
	return data


func load_data(data: Array) -> void:
	for index in mini(data.size(), slots.size()):
		slots[index] = _slot_from(data[index])
	changed.emit()


func _slot_from(entry: Dictionary) -> Slot:
	var slot := Slot.new()
	if int(entry.get("count", 0)) <= 0:
		return slot
	slot.item_name = entry.get("item_name", "")
	slot.scene_path = entry.get("scene_path", "")
	slot.count = int(entry.get("count", 0))
	slot.max_stack = int(entry.get("max_stack", 1))
	var potion_path: String = entry.get("potion", "")
	slot.potion = load(potion_path) as Potion if not potion_path.is_empty() else null
	return slot


func _take(index: int, amount: int) -> void:
	slots[index].count -= amount
	if slots[index].count == 0:
		slots[index] = Slot.new()


func _fill(slot: Slot, item_name: String, scene_path: String, max_stack: int, potion: Potion, amount: int) -> void:
	slot.item_name = item_name
	slot.scene_path = scene_path
	slot.max_stack = max_stack
	slot.potion = potion
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
