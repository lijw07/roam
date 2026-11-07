extends Node


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton or node is InventorySlot:
		node.mouse_entered.connect(_focus.bind(node))


func _focus(control: Control) -> void:
	if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
		control.grab_focus()
