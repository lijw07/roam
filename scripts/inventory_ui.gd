extends GridContainer

const NO_DRAG := -1
const MOVE_TEXT := "Move"
const DROP_TEXT := "Drop"

@export var inventory: Inventory
@export var icon_renderer: ItemIconRenderer
@export var amount_popup: AmountPopup

var _slots: Array[InventorySlot] = []
var _dragged_index := NO_DRAG
var _apply_amount := Callable()


func _ready() -> void:
	visible = false
	columns = inventory.columns
	for index in inventory.slot_count():
		_slots.append(_create_slot(index))
	inventory.changed.connect(_refresh)
	amount_popup.confirmed.connect(_on_amount_confirmed)
	visibility_changed.connect(_on_visibility_changed)


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
	slot.dropped_on.connect(_on_dropped_on_slot)
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


func _on_dropped_on_slot(from_index: int, to_index: int) -> void:
	var movable := inventory.movable_amount(from_index, to_index)
	if _choosing_amount() and movable > 0:
		_with_amount(MOVE_TEXT, movable, func(amount: int) -> void: inventory.move(from_index, to_index, amount))
	else:
		inventory.swap(from_index, to_index)


func _finish_drag() -> void:
	if _dragged_index != NO_DRAG and _dropped_outside():
		_throw(_dragged_index)
	_dragged_index = NO_DRAG


func _throw(index: int) -> void:
	var count := inventory.count_at(index)
	if _choosing_amount():
		_with_amount(DROP_TEXT, count, func(amount: int) -> void: inventory.throw_out(index, amount))
	else:
		inventory.throw_out(index, count)


func _with_amount(action_text: String, max_amount: int, apply: Callable) -> void:
	if max_amount == 1:
		apply.call(1)
		return
	_apply_amount = apply
	amount_popup.ask(action_text, max_amount, get_global_mouse_position())


func _on_amount_confirmed(amount: int) -> void:
	_apply_amount.call(amount)
	_apply_amount = Callable()


func _on_visibility_changed() -> void:
	if not visible:
		amount_popup.close()


func _choosing_amount() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


func _dropped_outside() -> bool:
	if get_viewport().gui_is_drag_successful():
		return false
	return not get_global_rect().has_point(get_global_mouse_position())
