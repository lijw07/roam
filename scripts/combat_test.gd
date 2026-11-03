extends Node3D

const RIG_HEIGHT := 1.4
const MOUSE_SENSITIVITY := 0.003
const MIN_PITCH := -1.2
const MAX_PITCH := 0.3
const PICK_UP_REACH := 1.6
const TEST_DAMAGE := 15.0
const TEST_MANA_COST := 20.0
const TEST_STAMINA_COST := 25.0
const TEST_HIT_DISTANCE := 2.0
const POTIONS := {
	KEY_1: preload("res://resources/potions/health_potion.tres"),
	KEY_2: preload("res://resources/potions/mana_potion.tres"),
	KEY_3: preload("res://resources/potions/stamina_potion.tres"),
	KEY_4: preload("res://resources/potions/regeneration_potion.tres"),
}
const CONTROLS := "WASD move   Shift run   Space jump   Alt dodge   LMB attack   RMB block / aim / cast   F pick up   R reset arena   Esc free mouse\n1 health potion   2 mana potion   3 stamina potion   4 regeneration potion   5 take %d damage   6 spend %d mana   7 spend %d stamina"

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_pitch: Node3D = $CameraRig/Pitch
@onready var info: Label = $HUD/Info
@onready var weapons: Node3D = $Weapons

var _resting_places: Dictionary[Node3D, Transform3D] = {}
var _key_actions: Dictionary[Key, Callable] = {}


func _ready() -> void:
	for weapon: Node3D in weapons.get_children():
		_resting_places[weapon] = weapon.transform
	for key: Key in POTIONS:
		_key_actions[key] = player.drink.bind(POTIONS[key])
	_key_actions[KEY_5] = _take_test_hit
	_key_actions[KEY_6] = player.get_node("Mana").spend.bind(TEST_MANA_COST)
	_key_actions[KEY_7] = player.get_node("Stamina").spend.bind(TEST_STAMINA_COST)
	_key_actions[KEY_R] = get_tree().reload_current_scene
	player.item_released.connect(_on_item_released)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	camera_rig.global_position = player.global_position + Vector3.UP * RIG_HEIGHT
	player.camera_yaw = camera_rig.rotation.y
	info.text = "%s\n%s" % [CONTROLS % [TEST_DAMAGE, TEST_MANA_COST, TEST_STAMINA_COST], _weapon_text()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_pick_up_nearest_weapon()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and _key_actions.has(event.physical_keycode):
		_key_actions[event.physical_keycode].call()


func _look(mouse_motion: Vector2) -> void:
	camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - mouse_motion.y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	camera_rig.rotation.y -= mouse_motion.x * MOUSE_SENSITIVITY


func _take_test_hit() -> void:
	var behind: Vector3 = player.global_position - player.model.global_basis.z * TEST_HIT_DISTANCE
	player.hurtbox.receive(Hit.new(TEST_DAMAGE, null, behind))


func _pick_up_nearest_weapon() -> void:
	var weapon := _nearest_weapon()
	if weapon != null:
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


func _weapon_text() -> String:
	var held: Array[String] = []
	for item: Node3D in [player.held_item, player.off_hand_weapon, player.shield]:
		if item != null:
			held.append(item.name.capitalize())
	var holding := "holding %s" % " + ".join(held) if not held.is_empty() else "empty-handed"
	var nearby := _nearest_weapon()
	if nearby == null:
		return holding
	return "%s   F  pick up %s" % [holding, nearby.name.capitalize()]
