extends Control

@export var classes: Array[CharacterClass] = []
@export_file("*.tscn") var hub_scene := "res://scenes/ui/hub.tscn"
@export_file("*.tscn") var main_menu_scene := "res://scenes/ui/main_menu.tscn"

var _chosen: CharacterClass
var _choices := ButtonGroup.new()

@onready var backdrop: Control = $Background
@onready var turntable: Control = %PreviewSpace

@onready var character_list: VBoxContainer = %CharacterList
@onready var description_label: Label = %CharacterDescription
@onready var lore_label: Label = %CharacterLore
@onready var continue_button: Button = %ContinueButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	var initial := Profile.character_class if classes.has(Profile.character_class) else (classes[0] if not classes.is_empty() else null)
	for character_class in classes:
		character_list.add_child(_choice_button(character_class))
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_show(initial)
	_focus_chosen_or_first()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _focus_chosen_or_first() -> void:
	var index := maxi(classes.find(_chosen), 0)
	var button := character_list.get_child(index) as Button
	button.set_pressed_no_signal(true)
	button.grab_focus()


func _choice_button(character_class: CharacterClass) -> Button:
	var button := Button.new()
	button.text = character_class.display_name
	button.custom_minimum_size = Vector2(240, 44)
	button.toggle_mode = true
	button.button_group = _choices
	button.pressed.connect(_show.bind(character_class))
	return button


func _show(character_class: CharacterClass) -> void:
	turntable.cancel_drag()
	_chosen = character_class
	backdrop.show_character(character_class)
	continue_button.disabled = character_class == null
	description_label.text = character_class.description if character_class != null else ""
	lore_label.text = character_class.lore if character_class != null else ""


func _on_continue_pressed() -> void:
	Profile.choose_class(_chosen)
	get_tree().change_scene_to_file(hub_scene)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_scene)
