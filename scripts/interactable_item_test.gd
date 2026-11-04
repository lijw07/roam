extends Node3D

const RIG_HEIGHT := 1.4
const MOUSE_SENSITIVITY := 0.003
const MIN_PITCH := -1.2
const MAX_PITCH := 0.3
const START_HEALTH := 50.0
const TEST_MANA_COST := 50.0
const TEST_STAMINA_COST := 50.0
const CONTROLS := "WASD move   Shift run   Tab inventory   right-click a potion to drink   drag out of the inventory to throw   F pick up\n1 spend %d mana   2 spend %d stamina   R reset   Esc free mouse"

@onready var player: CharacterBody3D = $Player
@onready var health: Health = $Player/Health
@onready var mana: StatPool = $Player/Mana
@onready var stamina: StatPool = $Player/Stamina
@onready var item_collector: ItemCollector = $Player/ItemCollector
@onready var camera_rig: ShoulderCamera = $CameraRig
@onready var camera_pitch: Node3D = $CameraRig/Pitch
@onready var info: Label = $HUD/Info
@onready var inventory_ui: Control = $HUD/Inventory
@onready var interact_prompt: InteractPrompt = $HUD/InteractPrompt


func _ready() -> void:
	health.drain(health.value - START_HEALTH)
	inventory_ui.visibility_changed.connect(_on_inventory_toggled)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	camera_rig.global_position = player.global_position + Vector3.UP * RIG_HEIGHT
	player.camera_yaw = camera_rig.rotation.y
	info.text = CONTROLS % [TEST_MANA_COST, TEST_STAMINA_COST]
	_update_interact_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not inventory_ui.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key_pressed(event.physical_keycode)


func _on_key_pressed(key: Key) -> void:
	match key:
		KEY_1:
			mana.drain(TEST_MANA_COST)
		KEY_2:
			stamina.drain(TEST_STAMINA_COST)
		KEY_R:
			get_tree().reload_current_scene()
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_inventory_toggled() -> void:
	player.combat_input_enabled = not inventory_ui.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED


func _look(mouse_motion: Vector2) -> void:
	var sensitivity := MOUSE_SENSITIVITY * camera_rig.look_scale()
	camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - mouse_motion.y * sensitivity, MIN_PITCH, MAX_PITCH)
	camera_rig.rotation.y -= mouse_motion.x * sensitivity


func _update_interact_prompt() -> void:
	var pickup := item_collector.manual_pickup()
	if pickup == null or inventory_ui.visible:
		interact_prompt.hide()
	else:
		interact_prompt.show_action(pickup.pick_up_text())
