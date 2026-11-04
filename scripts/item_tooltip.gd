class_name ItemTooltip
extends PanelContainer

const BACKGROUND := Color(0, 0, 0, 0.75)
const TITLE_COLOR := Color(1, 1, 1, 0.95)
const DETAIL_COLOR := Color(1, 1, 1, 0.7)
const TITLE_FONT_SIZE := 15
const DETAIL_FONT_SIZE := 12
const PADDING := 8
const SPACING := 2
const MOUSE_OFFSET := Vector2(16, 16)
const USE_HINT := "Right click to use"
const STATS: Array[String] = ["health", "mana", "stamina"]

var _title: Label
var _details: Label


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _background())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", SPACING)
	_title = _label(TITLE_COLOR, TITLE_FONT_SIZE)
	_details = _label(DETAIL_COLOR, DETAIL_FONT_SIZE)
	rows.add_child(_title)
	rows.add_child(_details)
	add_child(rows)


func _process(_delta: float) -> void:
	if visible:
		_follow_mouse()


func show_slot(slot: Inventory.Slot) -> void:
	_title.text = slot.item_name
	_details.text = "\n".join(_detail_lines(slot))
	show()
	reset_size()
	_follow_mouse()


func _detail_lines(slot: Inventory.Slot) -> PackedStringArray:
	var lines := PackedStringArray(["Count: %d" % slot.count])
	if slot.potion != null:
		lines.append(USE_HINT)
		lines.append_array(_potion_effects(slot.potion))
	return lines


func _potion_effects(potion: Potion) -> PackedStringArray:
	var effects := PackedStringArray()
	for stat: String in STATS:
		var amount: float = potion.get(stat)
		if amount > 0.0:
			effects.append(_effect_text(amount, stat, potion.duration))
	return effects


func _effect_text(amount: float, stat_name: String, duration: float) -> String:
	var effect := "Restores %d %s" % [roundi(amount), stat_name]
	if duration > 0.0:
		effect += " over %d seconds" % roundi(duration)
	return effect


func _follow_mouse() -> void:
	var limit := get_viewport_rect().size - size
	position = (get_global_mouse_position() + MOUSE_OFFSET).clamp(Vector2.ZERO, limit)


func _label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.set_content_margin_all(PADDING)
	return style
