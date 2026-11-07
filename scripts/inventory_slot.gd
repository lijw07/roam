class_name InventorySlot
extends ColorRect

signal selected(index: int)
signal activated(index: int)
signal drag_started(index: int)
signal dropped_on(from: InventorySlot, to_index: int)
signal used(index: int)
signal hovered(index: int)
signal unhovered(index: int)

const SIZE := Vector2(64, 64)
const BACKGROUND := Color(0.13, 0.14, 0.15, 0.94)
const COUNT_COLOR := Color(1, 1, 1, 0.85)
const COUNT_FONT_SIZE := 13
const COUNT_OUTLINE_SIZE := 4
const COUNT_MARGIN := 4
const ICON_MARGIN := 8
const PREVIEW_ALPHA := 0.8
const TAG_FONT_SIZE := 11
const UNUSABLE_ICON_TINT := Color(1, 0.35, 0.35)
const UNUSABLE_TAG_COLOR := Color(1, 0.4, 0.4)

var index := 0
var inventory: Inventory

var _selected := false
var _hovered := false

var _icon: Texture2D = null
var _count := 0
var _icon_rect: TextureRect
var _count_label: Label
var _tag_label: Label


func _init() -> void:
	custom_minimum_size = SIZE
	color = BACKGROUND
	focus_mode = Control.FOCUS_ALL
	_icon_rect = _add_icon(self)
	_count_label = _add_count_label(self)
	_tag_label = _add_tag_label(self)
	mouse_entered.connect(func() -> void:
		_hovered = true
		queue_redraw()
		hovered.emit(index)
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw()
		unhovered.emit(index)
	)
	focus_entered.connect(func() -> void:
		queue_redraw()
		selected.emit(index)
	)
	focus_exited.connect(queue_redraw)


func set_selected(value: bool) -> void:
	if _selected != value:
		_selected = value
		queue_redraw()


func _draw() -> void:
	var highlighted := _selected or _hovered or has_focus()
	var border := Color(0.83, 0.85, 0.87) if highlighted else Color(0.32, 0.34, 0.36)
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), border, false, 1.0)


func show_item(icon: Texture2D, count: int, tag := "", usable := true) -> void:
	_count = count
	_icon = icon
	_icon_rect.texture = _icon
	_icon_rect.modulate = Color.WHITE if usable else UNUSABLE_ICON_TINT
	_count_label.text = _count_text()
	_tag_label.text = tag
	_tag_label.add_theme_color_override("font_color", COUNT_COLOR if usable else UNUSABLE_TAG_COLOR)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
		selected.emit(index)
		accept_event()
	if event.is_action_pressed("ui_accept") and _count > 0:
		activated.emit(index)
	if _is_right_click(event) and _count > 0:
		used.emit(index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _count == 0:
		return null
	set_drag_preview(_preview())
	drag_started.emit(index)
	return self


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is InventorySlot


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped_on.emit(data as InventorySlot, index)


func _is_right_click(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT


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


func _add_tag_label(parent: Control) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", TAG_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", COUNT_OUTLINE_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, COUNT_MARGIN)
	return label


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
