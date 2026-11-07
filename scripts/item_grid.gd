class_name ItemGrid
extends GridContainer

signal slot_dropped(source: Inventory, from_index: int, target: Inventory, to_index: int)
signal slot_focused(inventory: Inventory, index: int, slot: InventorySlot)
signal slot_unfocused
signal slot_activated(inventory: Inventory, index: int)

@export var icon_renderer: ItemIconRenderer

var inventory: Inventory

var _slots: Array[InventorySlot] = []


func bind(target: Inventory) -> void:
	inventory = target
	columns = target.columns
	for index in target.slot_count():
		_slots.append(_create_slot(index))
	target.changed.connect(_refresh)
	_refresh()


func _create_slot(index: int) -> InventorySlot:
	var slot := InventorySlot.new()
	slot.index = index
	slot.inventory = inventory
	slot.dropped_on.connect(_on_dropped_on)
	slot.activated.connect(func(at: int) -> void: slot_activated.emit(inventory, at))
	slot.drag_started.connect(func(_at: int) -> void: slot_unfocused.emit())
	slot.focus_entered.connect(func() -> void: slot_focused.emit(inventory, index, slot))
	slot.focus_exited.connect(func() -> void: slot_unfocused.emit())
	add_child(slot)
	return slot


func _refresh() -> void:
	for index in _slots.size():
		var slot := inventory.slots[index]
		_slots[index].show_item(_icon_for(slot), slot.count, _tag_for(slot), _is_usable(slot))


func _tag_for(slot: Inventory.Slot) -> String:
	return ItemInfo.of(slot.scene_path).hands_tag() if slot.count > 0 else ""


func _is_usable(slot: Inventory.Slot) -> bool:
	if slot.count == 0 or Profile.character_class == null or not ItemInfo.of(slot.scene_path).is_equipment():
		return true
	return Profile.character_class.allows_scene(slot.scene_path)


func _icon_for(slot: Inventory.Slot) -> Texture2D:
	return icon_renderer.icon_for(slot.scene_path) if slot.count > 0 else null


func _on_dropped_on(from: InventorySlot, to_index: int) -> void:
	slot_dropped.emit(from.inventory, from.index, inventory, to_index)
