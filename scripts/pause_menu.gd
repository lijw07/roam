extends Control

@export_file("*.tscn") var hub_scene := "res://scenes/ui/hub.tscn"

@onready var menu: Control = %Menu
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var camp_button: Button = %CampButton
@onready var quit_button: Button = %QuitButton
@onready var settings_menu: Control = %SettingsMenu
@onready var leave_confirmation: Control = %LeaveConfirmation
@onready var cancel_leave_button: Button = %CancelLeaveButton
@onready var confirm_leave_button: Button = %ConfirmLeaveButton


func _ready() -> void:
	hide()
	quit_button.visible = not OS.has_feature("web")
	resume_button.pressed.connect(close)
	settings_button.pressed.connect(_open_settings)
	camp_button.pressed.connect(_open_leave_confirmation)
	quit_button.pressed.connect(get_tree().quit)
	settings_menu.closed.connect(_close_settings)
	cancel_leave_button.pressed.connect(_cancel_leave)
	confirm_leave_button.pressed.connect(_leave)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if leave_confirmation.visible:
		_cancel_leave()
	elif settings_menu.visible:
		_close_settings()
	elif visible:
		close()
	else:
		open()


func open() -> void:
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()


func close() -> void:
	_close_settings()
	leave_confirmation.hide()
	menu.show()
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
	menu.hide()
	settings_menu.show()


func _close_settings() -> void:
	if not settings_menu.visible:
		return
	settings_menu.hide()
	menu.show()
	settings_button.grab_focus()


func _open_leave_confirmation() -> void:
	menu.hide()
	leave_confirmation.show()
	cancel_leave_button.grab_focus()


func _cancel_leave() -> void:
	leave_confirmation.hide()
	menu.show()
	camp_button.grab_focus()


func _leave() -> void:
	if not leave_confirmation.visible:
		return
	leave_confirmation.hide()
	Profile.lose_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(hub_scene)
