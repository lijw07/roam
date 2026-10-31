extends Node3D

const RIG_HEIGHT := 1.4
const MOUSE_SENSITIVITY := 0.003
const MIN_PITCH := -1.2
const MAX_PITCH := 0.3
const CONTROLS := "WASD move   Tab inventory   F pick up   drag out of the inventory to throw   Esc free mouse"

@onready var player: CharacterBody3D = $Player
@onready var item_collector: ItemCollector = $Player/ItemCollector
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_pitch: Node3D = $CameraRig/Pitch
@onready var info: Label = $HUD/Info
@onready var inventory_ui: Control = $HUD/Inventory


func _ready() -> void:
	inventory_ui.visibility_changed.connect(_on_inventory_toggled)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	camera_rig.global_position = player.global_position + Vector3.UP * RIG_HEIGHT
	player.camera_yaw = camera_rig.rotation.y
	info.text = "%s\n%s" % [CONTROLS, _pick_up_prompt()]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not inventory_ui.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_inventory_toggled() -> void:
	player.combat_input_enabled = not inventory_ui.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED


func _look(mouse_motion: Vector2) -> void:
	camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - mouse_motion.y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	camera_rig.rotation.y -= mouse_motion.x * MOUSE_SENSITIVITY


func _pick_up_prompt() -> String:
	var pickup := item_collector.nearest_pickup()
	if pickup == null:
		return ""
	if pickup.count > 1:
		return "F  pick up %s x%d" % [pickup.item_name, pickup.count]
	return "F  pick up %s" % pickup.item_name
