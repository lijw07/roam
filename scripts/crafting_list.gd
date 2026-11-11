class_name CraftingList
extends VBoxContainer

const ROW_HEIGHT := 48.0
const DETAILS_PADDING := 16
const COST_FONT_SIZE := 13
const MATERIAL_ICON_SIZE := Vector2(24, 24)
const CRAFT_BUTTON_SIZE := Vector2(110, 36)
const CRAFT_TEXT := "Craft"

@export var book: RecipeBook
@export var materials: RecipeBook
@export var icon_renderer: ItemIconRenderer

var _entries: Array[Entry] = []
var _expanded: Entry = null
var _material_scenes: Dictionary[String, String] = {}


class Entry:
	var recipe: Recipe
	var info: ItemInfo
	var details: Control
	var material_counts: Dictionary[String, Label] = {}
	var craft_button: Button


func _ready() -> void:
	for offer in materials.recipes:
		var info := ItemInfo.of(offer.item.resource_path)
		_material_scenes[info.item_name] = info.scene_path
	for recipe in book.recipes:
		if _is_craftable_by_character(recipe):
			_entries.append(_add_entry(recipe))
	Profile.stash.changed.connect(_refresh)
	_refresh()


func _is_craftable_by_character(recipe: Recipe) -> bool:
	return Profile.character_class != null and Profile.character_class.allows_scene(recipe.item.resource_path)


func _add_entry(recipe: Recipe) -> Entry:
	var entry := Entry.new()
	entry.recipe = recipe
	entry.info = ItemInfo.of(recipe.item.resource_path)
	entry.craft_button = Button.new()
	entry.craft_button.text = CRAFT_TEXT
	entry.craft_button.custom_minimum_size = CRAFT_BUTTON_SIZE
	entry.craft_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	entry.craft_button.pressed.connect(_craft.bind(entry))
	entry.details = _details(entry)
	add_child(_header(entry))
	add_child(entry.details)
	return entry


func _header(entry: Entry) -> Button:
	var button := Button.new()
	button.text = entry.info.item_name
	button.icon = icon_renderer.icon_for(entry.info.scene_path)
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	button.pressed.connect(_toggle.bind(entry))
	return button


func _details(entry: Entry) -> MarginContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	for material_name: String in entry.recipe.cost:
		rows.add_child(_material_row(entry, material_name))
	rows.add_child(entry.craft_button)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", DETAILS_PADDING)
	padding.add_theme_constant_override("margin_right", DETAILS_PADDING)
	padding.add_theme_constant_override("margin_bottom", 8)
	padding.add_child(rows)
	padding.visible = false
	return padding


func _material_row(entry: Entry, material_name: String) -> HBoxContainer:
	var icon := TextureRect.new()
	icon.custom_minimum_size = MATERIAL_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = icon_renderer.icon_for(_material_scenes[material_name]) if _material_scenes.has(material_name) else null
	var name_label := _cost_label(material_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	entry.material_counts[material_name] = _cost_label("")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(icon)
	row.add_child(name_label)
	row.add_child(entry.material_counts[material_name])
	return row


func _cost_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", COST_FONT_SIZE)
	return label


func _toggle(entry: Entry) -> void:
	var opening := _expanded != entry
	if _expanded != null:
		_expanded.details.visible = false
	_expanded = entry if opening else null
	entry.details.visible = opening


func _refresh() -> void:
	for entry in _entries:
		for material_name: String in entry.material_counts:
			entry.material_counts[material_name].text = "%d / %d" % [Profile.stash.count_of(material_name), entry.recipe.cost[material_name]]
		entry.craft_button.disabled = not _can_craft(entry)


func _can_craft(entry: Entry) -> bool:
	return Profile.has_room_for(entry.info, entry.recipe.count) and Profile.can_afford(entry.recipe.cost, 1)


func _craft(entry: Entry) -> void:
	if not _can_craft(entry):
		AudioManager.play_ui("ui_error")
		return
	Profile.spend(entry.recipe.cost, 1)
	entry.info.add_to(Profile.stash, entry.recipe.count)
	AudioManager.play_ui("purchase")
