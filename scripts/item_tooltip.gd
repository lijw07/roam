class_name ItemTooltip
extends PanelContainer

const GAP := 12.0
const CARD_WIDTH := 240.0
const SCREEN_MARGIN := 12.0
const DETAIL_FONT_SIZE := 13
const WARNING_COLOR := Color(1, 0.4, 0.4)
const DETAIL_COLOR := Color(1, 1, 1, 0.75)
const STATS: Array[String] = ["health", "mana", "stamina"]

@export var icon_renderer: ItemIconRenderer

var _anchor: Control
var _icon: TextureRect
var _title: Label
var _kind: Label
var _details: Label
var _warning: Label
var _stack: HBoxContainer
var _count: Label
var _divider: ColorRect


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	custom_minimum_size.x = CARD_WIDTH
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.085, 0.095, 0.105, 1)
	panel.border_color = Color(0.43, 0.46, 0.49, 1)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	panel.content_margin_left = 14
	panel.content_margin_top = 14
	panel.content_margin_right = 14
	panel.content_margin_bottom = 14
	panel.shadow_color = Color(0, 0, 0, 0.3)
	panel.shadow_size = 5
	panel.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", panel)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 10)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_icon)
	var heading := VBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kind = _small_label(Color(0.61, 0.65, 0.69))
	heading.add_child(_title)
	heading.add_child(_kind)
	header.add_child(heading)
	rows.add_child(header)
	_divider = ColorRect.new()
	_divider.custom_minimum_size.y = 1
	_divider.color = Color(0.27, 0.3, 0.33)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(_divider)
	_details = _small_label(DETAIL_COLOR)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_constant_override("line_spacing", 4)
	_warning = _small_label(WARNING_COLOR)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_details)
	_stack = HBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack_label := _small_label(DETAIL_COLOR)
	stack_label.text = "Stack"
	stack_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count = _small_label(Color(0.94, 0.94, 0.94))
	_stack.add_child(stack_label)
	_stack.add_child(_count)
	rows.add_child(_stack)
	rows.add_child(_warning)
	add_child(rows)


func _process(_delta: float) -> void:
	if visible:
		reset_size()
		_place_beside_anchor()


func show_for(slot: Inventory.Slot, anchor: Control) -> void:
	var info := ItemInfo.of(slot.scene_path)
	_anchor = anchor
	_icon.texture = icon_renderer.icon_for(slot.scene_path) if icon_renderer != null else null
	_icon.visible = _icon.texture != null
	_title.text = slot.item_name
	_kind.text = info.kind_text()
	_details.text = "\n".join(_detail_lines(info))
	_details.visible = not _details.text.is_empty()
	_stack.visible = slot.max_stack > 1
	_count.text = "%d / %d" % [slot.count, slot.max_stack]
	_warning.text = _warning_text(info, slot.scene_path)
	_warning.visible = not _warning.text.is_empty()
	_divider.visible = _details.visible or _stack.visible or _warning.visible
	show()
	reset_size()
	_place_beside_anchor()


func _detail_lines(info: ItemInfo) -> PackedStringArray:
	var lines := PackedStringArray()
	if info.is_weapon:
		lines.append("Damage: %d" % roundi(info.damage))
	if info.potion != null:
		lines.append_array(_potion_effects(info.potion))
	return lines


func _warning_text(info: ItemInfo, scene_path: String) -> String:
	var character := Profile.character_class
	if not info.is_equipment() or character == null or character.allows_scene(scene_path):
		return ""
	return "%s can't use this" % character.display_name


func _potion_effects(potion: Potion) -> PackedStringArray:
	var effects := PackedStringArray()
	for stat in STATS:
		var amount: float = potion.get(stat)
		if amount > 0.0:
			effects.append(_effect_text(amount, stat, potion.duration))
	return effects


func _effect_text(amount: float, stat: String, duration: float) -> String:
	var effect := "Restores %d %s" % [roundi(amount), stat]
	if duration > 0.0:
		effect += " over %d seconds" % roundi(duration)
	return effect


func _place_beside_anchor() -> void:
	if not is_instance_valid(_anchor) or not _anchor.is_visible_in_tree():
		hide()
		return
	var anchor_rect := _anchor.get_global_rect()
	var screen := get_viewport_rect().size
	var spot := Vector2(anchor_rect.end.x + GAP, anchor_rect.position.y)
	if spot.x + size.x > screen.x - SCREEN_MARGIN:
		spot.x = anchor_rect.position.x - GAP - size.x
	var edge := Vector2.ONE * SCREEN_MARGIN
	global_position = spot.clamp(edge, (screen - size - edge).max(edge))


func _small_label(color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", DETAIL_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label
