class_name InventorySlot
extends ColorRect

signal drag_started(index: int)
signal swap_requested(from_index: int, to_index: int)

const SIZE := Vector2(64, 64)
const BACKGROUND := Color(0, 0, 0, 0.45)
const COUNT_COLOR := Color(1, 1, 1, 0.85)
const COUNT_FONT_SIZE := 13
const COUNT_OUTLINE_SIZE := 4
const COUNT_MARGIN := 4
const ICON_MARGIN := 8
const PREVIEW_ALPHA := 0.8

var index := 0

var _icon: Texture2D = null
var _count := 0
var _icon_rect: TextureRect
var _count_label: Label


func _init() -> void:
	custom_minimum_size = SIZE
	color = BACKGROUND
	_icon_rect = _add_icon(self)
	_count_label = _add_count_label(self)


func show_item(icon: Texture2D, count: int) -> void:
	_count = count
	_icon = icon
	_icon_rect.texture = _icon
	_count_label.text = _count_text()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _count == 0:
		return null
	set_drag_preview(_preview())
	drag_started.emit(index)
	return self


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is InventorySlot


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	swap_requested.emit((data as InventorySlot).index, index)


func _count_text() -> String:
	return str(_count) if _count > 0 else ""


func _preview() -> Control:
	var holder := Control.new()
	var square := ColorRect.new()
	square.size = SIZE
	square.position = -SIZE / 2.0
	square.color = BACKGROUND
	square.modulate.a = PREVIEW_ALPHA
	_add_icon(square).texture = _icon
	_add_count_label(square).text = _count_text()
	holder.add_child(square)
	return holder


func _add_icon(parent: Control) -> TextureRect:
	var icon_rect := TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon_rect)
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, ICON_MARGIN)
	return icon_rect


func _add_count_label(parent: Control) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_color_override("font_color", COUNT_COLOR)
	label.add_theme_font_size_override("font_size", COUNT_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", COUNT_OUTLINE_SIZE)
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, COUNT_MARGIN)
	return label
