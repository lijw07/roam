extends Control

signal closed

const WAITING_TEXT := "Press a key..."
const UNBOUND_TEXT := "-"
const BINDING_SLOTS := 2
const BINDING_BUTTON_SIZE := Vector2(170, 36)
const UNBINDABLE_MOUSE_BUTTONS: Array[MouseButton] = [
	MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
]
const NO_ACTION := &""

@export_file("*.tscn") var main_menu_scene := "res://scenes/ui/main_menu.tscn"

var _binding_buttons: Dictionary[StringName, Array] = {}
var _rebinding_action := NO_ACTION
var _rebinding_slot := 0
var _opening_generation := 0
var _adjustment_rows: Array[Array] = []

@onready var scroll: ScrollContainer = %Scroll
@onready var sensitivity_x_slider: HSlider = %SensitivityXSlider
@onready var sensitivity_x_value: Label = %SensitivityXValue
@onready var sensitivity_y_slider: HSlider = %SensitivityYSlider
@onready var sensitivity_y_value: Label = %SensitivityYValue
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var bindings: GridContainer = %Bindings
@onready var reset_bindings_button: Button = %ResetBindingsButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_bind_slider(sensitivity_x_slider, sensitivity_x_value, Settings.mouse_sensitivity_x, Settings.set_mouse_sensitivity_x, _multiplier_text)
	_bind_slider(sensitivity_y_slider, sensitivity_y_value, Settings.mouse_sensitivity_y, Settings.set_mouse_sensitivity_y, _multiplier_text)
	_bind_slider(music_slider, music_value, Settings.music_volume, Settings.set_music_volume, _percent_text)
	_bind_steps(sensitivity_x_slider, %SensitivityXDecrease, %SensitivityXIncrease)
	_bind_steps(sensitivity_y_slider, %SensitivityYDecrease, %SensitivityYIncrease)
	_bind_steps(music_slider, %MusicDecrease, %MusicIncrease)
	for action in Settings.ACTION_NAMES:
		_add_binding_row(action)
	reset_bindings_button.pressed.connect(_on_reset_bindings_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_refresh_bindings()
	_link_focus_rows()
	visibility_changed.connect(_focus_first_setting)
	_focus_first_setting()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _input(event: InputEvent) -> void:
	if _rebinding_action == NO_ACTION:
		return
	if _is_cancel(event):
		_stop_rebinding()
	elif _is_bindable(event):
		Settings.bind(_rebinding_action, _rebinding_slot, Settings.capture(event))
		_stop_rebinding()
	else:
		return
	get_viewport().set_input_as_handled()


func _bind_slider(slider: HSlider, value_label: Label, value: float, apply: Callable, format: Callable) -> void:
	slider.value = value
	value_label.text = format.call(value)
	slider.value_changed.connect(
		func(new_value: float) -> void:
			apply.call(new_value)
			value_label.text = format.call(new_value)
	)


func _add_binding_row(action: StringName) -> void:
	var name_label := Label.new()
	name_label.text = Settings.ACTION_NAMES[action]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bindings.add_child(name_label)
	var buttons: Array[Button] = []
	for slot in BINDING_SLOTS:
		var button := Button.new()
		button.custom_minimum_size = BINDING_BUTTON_SIZE
		button.pressed.connect(_start_rebinding.bind(action, slot))
		bindings.add_child(button)
		buttons.append(button)
	_binding_buttons[action] = buttons


func _bind_steps(slider: HSlider, decrease: Button, increase: Button) -> void:
	decrease.pressed.connect(func() -> void: slider.value -= slider.step)
	increase.pressed.connect(func() -> void: slider.value += slider.step)
	_adjustment_rows.append([decrease, slider, increase])
	decrease.focus_neighbor_right = decrease.get_path_to(slider)
	slider.focus_neighbor_left = slider.get_path_to(decrease)
	slider.focus_neighbor_right = slider.get_path_to(increase)
	increase.focus_neighbor_left = increase.get_path_to(slider)


func _link_focus_rows() -> void:
	var rows: Array[Array] = _adjustment_rows.duplicate()
	for action in _binding_buttons:
		rows.append(_binding_buttons[action])
	rows.append([reset_bindings_button])
	rows.append([back_button])
	for row_index in rows.size():
		for column in rows[row_index].size():
			var control: Control = rows[row_index][column]
			if row_index > 0:
				control.focus_neighbor_top = control.get_path_to(_control_at(rows[row_index - 1], column))
			if row_index < rows.size() - 1:
				control.focus_neighbor_bottom = control.get_path_to(_control_at(rows[row_index + 1], column))


func _control_at(row: Array, column: int) -> Control:
	return row[mini(column, row.size() - 1)]


func _start_rebinding(action: StringName, slot: int) -> void:
	_rebinding_action = action
	_rebinding_slot = slot
	_refresh_bindings()


func _stop_rebinding() -> void:
	_rebinding_action = NO_ACTION
	_refresh_bindings()


func _refresh_bindings() -> void:
	for action in _binding_buttons:
		var events := Settings.events_of(action)
		for slot in BINDING_SLOTS:
			var button: Button = _binding_buttons[action][slot]
			button.text = _binding_text(action, slot, events)


func _binding_text(action: StringName, slot: int, events: Array[InputEvent]) -> String:
	if action == _rebinding_action and slot == _rebinding_slot:
		return WAITING_TEXT
	return Settings.describe(events[slot]) if slot < events.size() else UNBOUND_TEXT


func _is_cancel(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel")


func _is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed and not UNBINDABLE_MOUSE_BUTTONS.has(event.button_index)
	return false


func _multiplier_text(value: float) -> String:
	return "%.2fx" % value


func _percent_text(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


func _on_reset_bindings_pressed() -> void:
	Settings.reset_bindings()
	_refresh_bindings()


func _focus_first_setting() -> void:
	_opening_generation += 1
	var generation := _opening_generation
	if not is_visible_in_tree():
		return
	# Initial focus must not scroll the first section's heading out of view.
	scroll.follow_focus = false
	sensitivity_x_slider.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _opening_generation or not is_visible_in_tree():
		return
	scroll.scroll_vertical = 0
	scroll.follow_focus = true


func _on_back_pressed() -> void:
	Settings.save()
	if main_menu_scene.is_empty():
		closed.emit()
	else:
		get_tree().change_scene_to_file(main_menu_scene)
