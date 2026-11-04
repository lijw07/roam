class_name InteractPrompt
extends PanelContainer

const BACKGROUND := Color(0, 0, 0, 0.6)
const KEY_BORDER := Color(1, 1, 1, 0.85)
const TEXT_COLOR := Color(1, 1, 1, 0.9)
const FONT_SIZE := 14
const PADDING := 6
const KEY_PADDING := 6
const KEY_VERTICAL_PADDING := 0
const SPACING := 8
const KEY_TEXT := "F"
const CROSSHAIR_OFFSET := 18.0

var _action: Label


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _box(BACKGROUND, PADDING))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING)
	row.add_child(_key_chip())
	_action = _label("")
	row.add_child(_action)
	add_child(row)


func show_action(action: String) -> void:
	_action.text = action
	show()
	reset_size()
	var crosshair := get_viewport_rect().size / 2.0
	position = crosshair + Vector2(CROSSHAIR_OFFSET, -size.y / 2.0)


func _key_chip() -> PanelContainer:
	var chip := PanelContainer.new()
	var style := _box(Color.TRANSPARENT, KEY_PADDING)
	style.border_color = KEY_BORDER
	style.set_border_width_all(1)
	style.content_margin_top = KEY_VERTICAL_PADDING
	style.content_margin_bottom = KEY_VERTICAL_PADDING
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(_label(KEY_TEXT))
	return chip


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	return label


func _box(color: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(padding)
	return style
