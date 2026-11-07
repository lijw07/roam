extends Control

## A visual-only room shared by the menu screens. It never spawns gameplay actors.
@export_enum("Main menu", "Character selection", "Inventory") var view := 0
@export var motion_enabled := true

@onready var camera: Camera3D = $ViewportContainer/Viewport/Room/Camera
@onready var shade: ColorRect = $Shade
@onready var showcase: Node3D = $ViewportContainer/Viewport/Room/Showcase

var _time := 0.0
var _turning := false
var _origin := Vector3.ZERO
var _target := Vector3.ZERO


func _ready() -> void:
	# Open the model's door directly: decorative geometry has no gameplay Door script.
	for piece in $ViewportContainer/Viewport/Room/Set.get_children():
		var door := piece.get_node_or_null("wall_doorway/wall_doorway_door") as Node3D
		if door != null:
			door.rotation.y = -PI * 0.5
	showcase.visible = view == 1
	match view:
		1:
			_origin = Vector3(-1.2, 3.1, 7.8)
			_target = Vector3(0.2, 0, -1.5)
			shade.color.a = 0.24
			_add_selection_shade()
		2:
			_origin = Vector3(1.8, 2.7, 7.6)
			_target = Vector3(-0.8, 1.7, -5.0)
			shade.color.a = 0.77
		_:
			_origin = Vector3(0, 2.4, 7.8)
			_target = Vector3(0, 1.7, -5.0)
			shade.color.a = 0.38
	_place_camera()


func _process(delta: float) -> void:
	if motion_enabled and not _turning:
		_time = fmod(_time + delta, 48.0)
		_place_camera()


func _place_camera() -> void:
	var phase := _time * TAU / 48.0
	camera.position = _origin + Vector3(sin(phase) * 0.12, sin(phase * 2.0) * 0.025, 0)
	camera.look_at(_target)


func show_character(character_class: CharacterClass) -> void:
	end_character_turn()
	showcase.show_character(character_class)


func _add_selection_shade() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.26, 0.44, 0.64, 0.78, 1.0])
	gradient.colors = PackedColorArray([Color(0.02, 0.025, 0.03, 0.75), Color(0.02, 0.025, 0.03, 0.6), Color(0.02, 0.025, 0.03, 0.05), Color(0.02, 0.025, 0.03, 0.05), Color(0.02, 0.025, 0.03, 0.6), Color(0.02, 0.025, 0.03, 0.75)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(1, 0)
	var overlay := TextureRect.new()
	overlay.texture = texture
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func begin_character_turn() -> bool:
	_turning = showcase.begin_turn()
	return _turning


func rotate_character(radians: float) -> void:
	showcase.turn(radians)


func end_character_turn() -> void:
	_turning = false
	showcase.end_turn()
