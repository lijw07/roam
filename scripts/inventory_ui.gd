extends GridContainer

const NO_DRAG := -1

@export var inventory: Inventory
@export var icon_renderer: ItemIconRenderer

var _slots: Array[InventorySlot] = []
var _dragged_index := NO_DRAG


func _ready() -> void:
	visible = false
	columns = inventory.columns
	for index in inventory.slot_count():
		_slots.append(_create_slot(index))
	inventory.changed.connect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_finish_drag()


func _create_slot(index: int) -> InventorySlot:
	var slot := InventorySlot.new()
	slot.index = index
	slot.drag_started.connect(_on_drag_started)
	slot.swap_requested.connect(inventory.swap)
	add_child(slot)
	return slot


func _refresh() -> void:
	for index in _slots.size():
		var slot := inventory.slots[index]
		_slots[index].show_item(_icon_for(slot), slot.count)


func _icon_for(slot: Inventory.Slot) -> Texture2D:
	return icon_renderer.icon_for(slot.scene_path) if slot.count > 0 else null


func _on_drag_started(index: int) -> void:
	_dragged_index = index


func _finish_drag() -> void:
	if _dragged_index != NO_DRAG and _dropped_outside():
		inventory.throw_out(_dragged_index)
	_dragged_index = NO_DRAG


func _dropped_outside() -> bool:
	if get_viewport().gui_is_drag_successful():
		return false
	return not get_global_rect().has_point(get_global_mouse_position())
