extends VBoxContainer

const Glyph := preload("res://scripts/control_glyph.gd")
const PLAY_HINTS := [["WASD", "Move"], ["Shift", "Run"], ["Space", "Jump"], ["left", "Attack"], ["right", "Block / aim"], ["F", "Interact"], ["Tab", "Inventory"], ["R", "New dungeon"], ["Esc", "Pause"]]
const INVENTORY_HINTS := [["left", "Drag item"], ["Shift", "Split stack"], ["right", "Drink potion"], ["Tab", "Close"]]

@onready var context: Label = $Context
@onready var hints: HFlowContainer = $Hints
var _inventory_open := false
var _dead := false

func _ready() -> void:
	minimum_size_changed.connect(_fit_height)
	_build(PLAY_HINTS)
	_fit_height()

func _fit_height() -> void:
	offset_top = -24.0 - get_combined_minimum_size().y
	offset_bottom = -24.0

func show_status(text: String, dead: bool) -> void:
	context.text = text
	context.visible = not _inventory_open and not text.is_empty()
	if dead != _dead:
		_dead = dead
		_refresh()

func set_inventory_open(open: bool) -> void:
	_inventory_open = open
	context.visible = not open and not context.text.is_empty()
	_refresh()

func _refresh() -> void:
	if _dead:
		_build([["R", "Return to camp"], ["Esc", "Pause"]])
	else:
		_build(INVENTORY_HINTS if _inventory_open else PLAY_HINTS)

func _build(entries: Array) -> void:
	for child in hints.get_children():
		hints.remove_child(child)
		child.queue_free()
	for entry in entries:
		var item := HBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", 6)
		var glyph := Glyph.new()
		if entry[0] == "left" or entry[0] == "right":
			glyph.mouse_button = MOUSE_BUTTON_LEFT if entry[0] == "left" else MOUSE_BUTTON_RIGHT
		else:
			glyph.key = entry[0]
		item.add_child(glyph)
		var label := Label.new()
		label.text = entry[1]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)
		hints.add_child(item)
	call_deferred("_fit_height")
