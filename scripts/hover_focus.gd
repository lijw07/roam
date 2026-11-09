extends Node

var _last_mouse_position := Vector2.INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var mouse_position := get_viewport().get_mouse_position()
	if mouse_position == _last_mouse_position:
		return
	_last_mouse_position = mouse_position
	_focus_hovered_control()


func _focus_hovered_control() -> void:
	var target := _focusable_ancestor(get_viewport().gui_get_hovered_control())
	if target != null and not target.has_focus():
		target.grab_focus()


func _focusable_ancestor(control: Control) -> Control:
	var current: Node = control
	while current is Control:
		if _takes_hover_focus(current):
			return current
		current = current.get_parent()
	return null


func _takes_hover_focus(control: Control) -> bool:
	return (control is BaseButton or control is InventorySlot) \
		and control.focus_mode != Control.FOCUS_NONE \
		and control.is_visible_in_tree()
