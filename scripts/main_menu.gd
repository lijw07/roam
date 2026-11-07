extends Control

@export_file("*.tscn") var play_scene := "res://scenes/ui/character_select.tscn"
@export_file("*.tscn") var settings_scene := "res://scenes/ui/settings.tscn"

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	quit_button.visible = not OS.has_feature("web")
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(play_scene)


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(settings_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()
