extends Node3D

const LIBRARIES: Array[StringName] = [&"movement_basic", &"movement_advanced", &"general"]
const RIG_HEIGHT := 1.4
const MOUSE_SENSITIVITY := 0.003
const MIN_PITCH := -1.2
const MAX_PITCH := 0.3
const ZOOM_STEP := 0.5
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 12.0
const PICK_UP_REACH := 1.6
const CONTROL_GROUPS := [
	["Move", [["W A S D", "move"], ["Shift", "run"], ["Space", "jump"], ["Alt", "dodge"], ["Mouse", "look / turn"]]],
	["Combat", [["LMB / J", "attack (combo)"], ["Shift + move + LMB", "lunge"], ["RMB", "block / aim / cast"], ["LMB while blocking", "bash"], ["LMB while aiming", "shoot"]]],
	["Actions", [["1", "interact"], ["2", "pick up"], ["3", "throw"], ["4", "use item"], ["5", "hit"], ["6", "die"], ["7", "spawn"], ["8", "spawn from air"]]],
	["Test", [["Left / Right", "animation"], ["Up / Down", "library"], ["Wheel", "zoom"], ["C", "freeze facing"], ["Click", "capture mouse"], ["Esc", "free mouse"]]],
]
const KEY_CHIP_COLOR := Color(1, 1, 1, 0.14)
const KEY_CHIP_BORDER := Color(1, 1, 1, 0.35)
const GROUP_TITLE_COLOR := Color(1.0, 0.82, 0.45)
const ACTION_COLOR := Color(0.85, 0.87, 0.9)
const GROUP_TITLE_WIDTH := 64.0

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_pitch: Node3D = $CameraRig/Pitch
@onready var camera: Camera3D = $CameraRig/Pitch/Camera3D
@onready var info: Label = $HUD/Info
@onready var control_rows: VBoxContainer = $HUD/Controls/Margin/Rows
@onready var weapons: Node3D = $Weapons

var _library_index := 0
var _animation_index := -1
var _replaying: StringName = &""
var _key_actions: Dictionary[Key, Callable] = {}
var _resting_places: Dictionary[Node3D, Transform3D] = {}
var _facing_frozen := false


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
		KEY_C: _toggle_facing_freeze,
	}
	for weapon: Node3D in weapons.get_children():
		_resting_places[weapon] = weapon.transform
	player.item_released.connect(_on_item_released)
	player.animation_changed.connect(_on_player_animation_changed)
	player.animation_player.animation_finished.connect(_on_animation_finished)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_controls()


func _process(_delta: float) -> void:
	camera_rig.global_position = player.global_position + Vector3.UP * RIG_HEIGHT
	if not _facing_frozen:
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
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		_on_mouse_button(event.button_index)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and _key_actions.has(event.physical_keycode):
		_key_actions[event.physical_keycode].call()


func _look(mouse_motion: Vector2) -> void:
	camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - mouse_motion.y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	camera_rig.rotation.y -= mouse_motion.x * MOUSE_SENSITIVITY


func _on_mouse_button(button: MouseButton) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and button == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	_zoom(button)


func _pick_up_nearest_weapon() -> void:
	var weapon := _nearest_weapon()
	if weapon:
		player.pick_up(weapon)


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


func _toggle_facing_freeze() -> void:
	_facing_frozen = not _facing_frozen
	if _facing_frozen:
		player.camera_yaw = player.model.rotation.y - PI


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
	var selection := "press Left / Right to start"
	if _animation_index >= 0:
		var names := _library_animations()
		selection = "%d / %d  %s" % [_animation_index + 1, names.size(), names[_animation_index]]
	return "Animation   %s\nWeapon      %s\nBrowser     %s  %s\nCamera      %s" % [
		player.current_animation(), _weapon_text(), LIBRARIES[_library_index], selection, _camera_text(),
	]


func _camera_text() -> String:
	return "orbiting freely, character keeps its direction (C to release)" if _facing_frozen else "character faces where the camera looks"


func _build_controls() -> void:
	var chip_style := _key_chip_style()
	for group: Array in CONTROL_GROUPS:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 18)
		row.add_theme_constant_override("v_separation", 6)
		var title := _label(group[0], GROUP_TITLE_COLOR)
		title.custom_minimum_size.x = GROUP_TITLE_WIDTH
		row.add_child(title)
		for binding: Array in group[1]:
			row.add_child(_control_hint(binding[0], binding[1], chip_style))
		control_rows.add_child(row)


func _control_hint(keys: String, action: String, chip_style: StyleBoxFlat) -> HBoxContainer:
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 6)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.add_child(_label(keys, Color.WHITE))
	hint.add_child(chip)
	hint.add_child(_label(action, ACTION_COLOR))
	return hint


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	return label


func _key_chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = KEY_CHIP_COLOR
	style.border_color = KEY_CHIP_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style


func _held_text() -> String:
	var items: Array[String] = []
	for item: Node3D in [player.held_item, player.off_hand_weapon, player.shield]:
		if item:
			items.append(item.name.capitalize())
	return "holding %s" % " + ".join(items) if not items.is_empty() else "empty-handed"


func _weapon_text() -> String:
	var held := _held_text()
	var nearby := _nearest_weapon()
	if nearby:
		return "%s   press 2 to pick up %s" % [held, nearby.name.capitalize()]
	return held
