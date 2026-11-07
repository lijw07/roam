extends Control

const VIEW := preload("res://scenes/ui/dungeon_inventory.tscn")
const SLOT_SIZE := Vector2(64, 64)

const NO_DRAG := -1
const NO_SELECTION := -1
const MOVE_TEXT := "Move"
const DROP_TEXT := "Drop"

@export var inventory: Inventory
@export var icon_renderer: ItemIconRenderer
@export var amount_popup: AmountPopup
@export var drinker: Node3D

var _view: Control
var _grid: GridContainer
var _panel: PanelContainer
var _selected_index := NO_SELECTION
var _slots: Array[InventorySlot] = []
var _dragged_index := NO_DRAG
var _apply_amount := Callable()


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_view = VIEW.instantiate()
	add_child(_view)
	_grid = _view.get_node("%SlotGrid")
	_panel = _view.get_node("%Panel")
	_view.get_node("%Close").pressed.connect(hide)
	amount_popup.theme = _view.theme
	_grid.columns = inventory.columns
	for index in inventory.slot_count():
		_slots.append(_create_slot(index))
	inventory.changed.connect(_refresh)
	amount_popup.confirmed.connect(_on_amount_confirmed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	# Handle Tab before focused buttons consume it as focus navigation.
	if event.is_action_pressed("inventory"):
		visible = not visible
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel") and not amount_popup.visible:
		hide()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_finish_drag()


func _create_slot(index: int) -> InventorySlot:
	var slot := InventorySlot.new()
	slot.index = index
	slot.inventory = inventory
	slot.custom_minimum_size = SLOT_SIZE
	slot.selected.connect(_on_slot_selected)
	slot.drag_started.connect(_on_drag_started)
	slot.dropped_on.connect(_on_dropped_on_slot)
	slot.used.connect(_on_slot_used)
	slot.activated.connect(_on_slot_used)
	_grid.add_child(slot)
	return slot


func _refresh() -> void:
	for index in _slots.size():
		var slot := inventory.slots[index]
		_slots[index].show_item(_icon_for(slot), slot.count)
	_refresh_selection()


func _icon_for(slot: Inventory.Slot) -> Texture2D:
	return icon_renderer.icon_for(slot.scene_path) if slot.count > 0 else null


func _on_drag_started(index: int) -> void:
	_dragged_index = index
	_selected_index = index
	_refresh_selection()


func _on_slot_selected(index: int) -> void:
	_selected_index = index
	_refresh_selection()


func _refresh_selection() -> void:
	for slot in _slots:
		slot.set_selected(slot.index == _selected_index)


func _on_dropped_on_slot(from: InventorySlot, to_index: int) -> void:
	var from_index := from.index
	var movable := inventory.movable_amount(from_index, to_index)
	if _choosing_amount() and movable > 0:
		_with_amount(MOVE_TEXT, movable, func(amount: int) -> void: inventory.move(from_index, to_index, amount))
	else:
		inventory.swap(from_index, to_index)


func _on_slot_used(index: int) -> void:
	var potion := inventory.potion_at(index)
	if potion != null and is_instance_valid(drinker) and drinker.drink(potion):
		inventory.use_one(index)


func _finish_drag() -> void:
	if visible and _dragged_index != NO_DRAG and _dropped_outside():
		_throw(_dragged_index)
	_dragged_index = NO_DRAG
	_refresh_selection()


func _throw(index: int) -> void:
	var count := inventory.count_at(index)
	if count == 0:
		return
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
	if _apply_amount.is_valid():
		_apply_amount.call(amount)
	_apply_amount = Callable()


func _on_visibility_changed() -> void:
	if not visible:
		amount_popup.close()
		_dragged_index = NO_DRAG
		_apply_amount = Callable()
	else:
		_slots[maxi(_selected_index, 0)].grab_focus()
	_refresh_selection()


func _choosing_amount() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


func _dropped_outside() -> bool:
	if get_viewport().gui_is_drag_successful():
		return false
	return not _panel.get_global_rect().has_point(get_global_mouse_position())
