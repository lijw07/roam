extends Node3D

const LIBRARIES: Array[StringName] = [&"movement_basic", &"movement_advanced", &"general"]
const STANCE_NAMES: Array[String] = ["Standing", "Crouching", "Crawling"]
const RIG_HEIGHT := 1.4
const ORBIT_SPEED := 2.0
const ZOOM_STEP := 0.5
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 12.0
const PICK_UP_REACH := 1.6
const CONTROLS := """WASD move   Shift run   Space jump   Alt dodge   Right mouse (hold) strafe
Left mouse / J attack with the held sword, axe or dagger (keep pressing to combo, Shift + move to lunge)
C crouch   Z crawl
1 interact   2 pick up the weapon in front of you   3 throw   4 use item   5 hit   6 die   7 spawn   8 spawn from the air
Left / Right animation   Up / Down library   Q / E orbit   Wheel zoom"""

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Pitch/Camera3D
@onready var info: Label = $HUD/Info
@onready var weapons: Node3D = $Weapons

var _library_index := 0
var _animation_index := -1
var _replaying: StringName = &""
var _key_actions: Dictionary[Key, Callable] = {}
var _resting_places: Dictionary[Node3D, Transform3D] = {}


func _ready() -> void:
	_key_actions = {
		KEY_1: player.interact,
		KEY_2: _pick_up_nearest_weapon,
		KEY_3: player.throw,
		KEY_4: player.use_item,
		KEY_5: player.take_hit,
		KEY_6: player.die,
		KEY_7: player.spawn,
		KEY_8: player.spawn.bind(true),
	}
	for weapon: Node3D in weapons.get_children():
		_resting_places[weapon] = weapon.transform
	player.item_released.connect(_on_item_released)
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


func _pick_up_nearest_weapon() -> void:
	player.pick_up(_nearest_weapon())


func _nearest_weapon() -> Node3D:
	var nearest: Node3D = null
	var best := PICK_UP_REACH
	for weapon: Node3D in weapons.get_children():
		var offset := weapon.global_position - player.global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance < best:
			best = distance
			nearest = weapon
	return nearest


func _on_item_released(item: Node3D) -> void:
	item.reparent(weapons, false)
	item.transform = _resting_places[item]


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
	return "Animation   %s\nStance      %s\nWeapon      %s\nBrowser     %s  %s\n\n%s" % [
		player.current_animation(), stance, _weapon_text(), LIBRARIES[_library_index], selection, CONTROLS,
	]


func _weapon_text() -> String:
	var held := "holding %s" % player.held_item.name.capitalize() if player.held_item else "empty-handed"
	var nearby := _nearest_weapon()
	if nearby:
		return "%s   press 2 to pick up %s" % [held, nearby.name.capitalize()]
	return held
