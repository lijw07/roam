extends Node3D

const LIBRARIES: Array[StringName] = [&"movement_basic", &"movement_advanced", &"general"]
const STANCE_NAMES: Array[String] = ["Standing", "Crouching", "Crawling"]
const RIG_HEIGHT := 1.4
const ORBIT_SPEED := 2.0
const ZOOM_STEP := 0.5
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 12.0
const CONTROLS := """WASD move   Shift run   Space jump   Alt dodge   Right mouse (hold) strafe
C crouch   Z crawl
1 interact   2 pick up   3 throw   4 use item   5 hit   6 die   7 spawn   8 spawn from the air
Left / Right animation   Up / Down library   Q / E orbit   Wheel zoom"""

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Pitch/Camera3D
@onready var info: Label = $HUD/Info

var _library_index := 0
var _animation_index := -1
var _replaying: StringName = &""
var _key_actions: Dictionary[Key, Callable] = {}


func _ready() -> void:
	_key_actions = {
		KEY_1: player.interact,
		KEY_2: player.pick_up,
		KEY_3: player.throw,
		KEY_4: player.use_item,
		KEY_5: player.take_hit,
		KEY_6: player.die,
		KEY_7: player.spawn,
		KEY_8: player.spawn.bind(true),
	}
	player.animation_changed.connect(_on_player_animation_changed)
	player.animation_player.animation_finished.connect(_on_animation_finished)


func _process(delta: float) -> void:
	camera_rig.rotation.y += Input.get_axis("camera_right", "camera_left") * ORBIT_SPEED * delta
	camera_rig.global_position = player.global_position + Vector3.UP * RIG_HEIGHT
	player.camera_yaw = camera_rig.rotation.y
	info.text = _hud_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("anim_next"):
		_browse(0, 1)
	elif event.is_action_pressed("anim_prev"):
		_browse(0, -1)
	elif event.is_action_pressed("anim_library_next"):
		_browse(1, 0)
	elif event.is_action_pressed("anim_library_prev"):
		_browse(-1, 0)
	elif event is InputEventMouseButton and event.pressed:
		_zoom(event.button_index)
	elif event is InputEventKey and event.pressed and not event.echo and _key_actions.has(event.physical_keycode):
		_key_actions[event.physical_keycode].call()


func _browse(library_step: int, animation_step: int) -> void:
	_library_index = wrapi(_library_index + library_step, 0, LIBRARIES.size())
	var names := _library_animations()
	_animation_index = 0 if library_step != 0 else wrapi(_animation_index + animation_step, 0, names.size())
	var animation := _selected_animation()
	player.preview(animation)
	_replaying = animation


func _library_animations() -> PackedStringArray:
	return player.animation_player.get_animation_library(LIBRARIES[_library_index]).get_animation_list()


func _selected_animation() -> StringName:
	if _animation_index < 0:
		return &""
	return StringName("%s/%s" % [LIBRARIES[_library_index], _library_animations()[_animation_index]])


func _zoom(button: MouseButton) -> void:
	var step := 0.0
	if button == MOUSE_BUTTON_WHEEL_UP:
		step = -ZOOM_STEP
	elif button == MOUSE_BUTTON_WHEEL_DOWN:
		step = ZOOM_STEP
	camera.position.z = clampf(camera.position.z + step, MIN_DISTANCE, MAX_DISTANCE)


func _on_player_animation_changed(animation: StringName) -> void:
	if animation != _replaying:
		_replaying = &""


func _on_animation_finished(animation: StringName) -> void:
	if animation != _replaying or player.animation_player.get_animation(animation).length <= 0.0:
		return
	player.preview(animation)


func _hud_text() -> String:
	var stance: String = "Dead" if player.dead else STANCE_NAMES[player.stance]
	var selection := "press Left / Right to start"
	if _animation_index >= 0:
		var names := _library_animations()
		selection = "%d / %d  %s" % [_animation_index + 1, names.size(), names[_animation_index]]
	return "Animation   %s\nStance      %s\nBrowser     %s  %s\n\n%s" % [
		player.current_animation(), stance, LIBRARIES[_library_index], selection, CONTROLS,
	]
