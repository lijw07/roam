extends Control

@export var backdrop: Control
@export_range(0.002, 0.03) var radians_per_pixel := 0.012

var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if backdrop.begin_character_turn():
			_dragging = true
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	# Follow the drag outside this region; release anywhere must end the grab.
	if event is InputEventMouseMotion:
		backdrop.rotate_character(event.relative.x * radians_per_pixel)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		cancel_drag()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_drag()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		cancel_drag()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		cancel_drag()


func cancel_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if is_instance_valid(backdrop):
		backdrop.end_character_turn()
