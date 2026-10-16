extends Node3D

const FOLLOW_SPEED := 6.0
const ORBIT_SPEED := 2.2
const WHEEL_STEP := 1.2
const MIN_DISTANCE := 2.5
const MAX_DISTANCE := 16.0

@export var camera_distance := 7.0
@export var camera_height := 0.45

@onready var character: CharacterBody3D = $TestCharacter
@onready var rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var character_label: Label = $HUD/Margin/Panel/Info/CharacterLabel
@onready var loadout_label: Label = $HUD/Margin/Panel/Info/LoadoutLabel
@onready var animation_label: Label = $HUD/Margin/Panel/Info/AnimationLabel
@onready var prompt_label: Label = $HUD/Prompt

var _libraries: Array[String] = []
var _by_library: Dictionary = {}
var _library := 0
var _index := 0
var _distance := 7.0
var _yaw := 0.0


func _ready() -> void:
	_build_catalog()
	_distance = camera_distance
	character.character_changed.connect(_on_character_changed)
	character.loadout_changed.connect(_on_loadout_changed)
	_on_character_changed(character.character_name())
	_on_loadout_changed(character.loadout_name)
	rig.global_position = character.global_position


func _process(delta: float) -> void:
	_yaw += Input.get_axis("camera_right", "camera_left") * ORBIT_SPEED * delta
	_update_camera(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("anim_next"):
		_step_animation(1)
	elif event.is_action_pressed("anim_prev"):
		_step_animation(-1)
	elif event.is_action_pressed("anim_library_next"):
		_step_library(1)
	elif event.is_action_pressed("anim_library_prev"):
		_step_library(-1)
	elif event.is_action_pressed("character_next"):
		character.step_character(1)
	elif event.is_action_pressed("character_prev"):
		character.step_character(-1)
	elif event.is_action_pressed("lab_reset"):
		character.reset()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - WHEEL_STEP, MIN_DISTANCE, MAX_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + WHEEL_STEP, MIN_DISTANCE, MAX_DISTANCE)


func _build_catalog() -> void:
	for animation in character.animation_list():
		var library := String(animation).get_base_dir()
		if library.is_empty():
			continue
		if not _by_library.has(library):
			_by_library[library] = PackedStringArray()
			_libraries.append(library)
		_by_library[library].append(animation)
	_libraries.sort()


func _current_list() -> PackedStringArray:
	return _by_library[_libraries[_library]]


func _step_animation(step: int) -> void:
	_index += step
	if _index >= _current_list().size():
		_library = wrapi(_library + 1, 0, _libraries.size())
		_index = 0
	elif _index < 0:
		_library = wrapi(_library - 1, 0, _libraries.size())
		_index = _current_list().size() - 1
	_play_selection()


func _step_library(step: int) -> void:
	_library = wrapi(_library + step, 0, _libraries.size())
	_index = 0
	_play_selection()


func _play_selection() -> void:
	character.play_override(StringName(_current_list()[_index]), true)


func _update_camera(delta: float) -> void:
	var weight := 1.0 - exp(-FOLLOW_SPEED * delta)
	rig.global_position = rig.global_position.lerp(character.global_position, weight)
	rig.rotation.y = _yaw
	camera.position = Vector3(0.0, _distance * camera_height + 1.0, _distance)
	camera.look_at(rig.global_position + Vector3.UP * 1.2)


func _update_hud() -> void:
	var animation := String(character.current_animation())
	animation_label.text = "Animation: %s" % (animation if not animation.is_empty() else "-")
	var station = character.nearest_station()
	if station and character.station == null:
		prompt_label.text = "[F] %s  ·  %s" % [station.prompt, station.label]
		prompt_label.visible = true
	elif character.station:
		prompt_label.text = "[F] stop  ·  %s" % character.station.label
		prompt_label.visible = true
	else:
		prompt_label.visible = false


func _on_character_changed(character_name: String) -> void:
	character_label.text = "Character: %s  [%d/%d]" % [
		character_name, character.character_index + 1, character.characters.size()
	]


func _on_loadout_changed(loadout_name: String) -> void:
	loadout_label.text = "Loadout: %s" % loadout_name
