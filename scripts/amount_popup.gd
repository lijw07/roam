class_name AmountPopup
extends PanelContainer

signal confirmed(amount: int)

const BACKGROUND := Color(0, 0, 0, 0.75)
const TEXT_COLOR := Color(1, 1, 1, 0.85)
const PADDING := 10
const SPACING := 8
const SLIDER_WIDTH := 160.0
const AMOUNT_WIDTH := 40.0
const CANCEL_TEXT := "Cancel"

var _slider: HSlider
var _amount_label: Label
var _confirm_button: Button


func _init() -> void:
	visible = false
	add_theme_stylebox_override("panel", _background())
	var rows := _box(VBoxContainer.new())
	rows.add_child(_amount_row())
	rows.add_child(_button_row())
	add_child(rows)


func ask(action_text: String, max_amount: int, at: Vector2) -> void:
	_slider.max_value = max_amount
	_slider.value = 1
	_show_amount(_slider.value)
	_confirm_button.text = action_text
	show()
	reset_size()
	position = at.clamp(Vector2.ZERO, get_viewport_rect().size - size)
	_slider.grab_focus()


func close() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _confirm() -> void:
	hide()
	confirmed.emit(int(_slider.value))


func _show_amount(amount: float) -> void:
	_amount_label.text = "%d / %d" % [int(amount), int(_slider.max_value)]


func _amount_row() -> BoxContainer:
	var row := _box(HBoxContainer.new())
	_slider = HSlider.new()
	_slider.min_value = 1
	_slider.step = 1
	_slider.custom_minimum_size.x = SLIDER_WIDTH
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.value_changed.connect(_show_amount)
	_amount_label = Label.new()
	_amount_label.custom_minimum_size.x = AMOUNT_WIDTH
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_amount_label.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(_slider)
	row.add_child(_amount_label)
	return row


func _button_row() -> BoxContainer:
	var row := _box(HBoxContainer.new())
	row.alignment = BoxContainer.ALIGNMENT_END
	_confirm_button = _button("", _confirm)
	row.add_child(_button(CANCEL_TEXT, close))
	row.add_child(_confirm_button)
	return row


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


func _box(box: BoxContainer) -> BoxContainer:
	box.add_theme_constant_override("separation", SPACING)
	return box


func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.set_content_margin_all(PADDING)
	return style
