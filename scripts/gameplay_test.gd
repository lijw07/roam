extends Node3D

const RIG_HEIGHT := 1.4
const MOUSE_SENSITIVITY := 0.003
const MIN_PITCH := -1.2
const MAX_PITCH := 0.3
const HOVERED_DOOR_REACH := 3.5
const REACH_HEIGHT := 1.0
const CONTROLS := "WASD move   Shift run   Space jump   LMB attack   RMB block   F door / pick up   Tab inventory (right-click a potion to drink)   R new dungeon   Esc free mouse"
const DEATH_TEXT := "You died   R to try a new dungeon"

@onready var player: CharacterBody3D = $Player
@onready var item_collector: ItemCollector = $Player/ItemCollector
@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D
@onready var generator: DungeonGenerator = $NavigationRegion3D/DungeonGenerator
@onready var starting_gear: Node3D = $StartingGear
@onready var camera_rig: ShoulderCamera = $CameraRig
@onready var camera_pitch: Node3D = $CameraRig/Pitch
@onready var info: Label = $HUD/Info
@onready var inventory_ui: Control = $HUD/Inventory
@onready var aim_targeting: AimTargeting = $AimTargeting
@onready var interact_prompt: InteractPrompt = $HUD/InteractPrompt

var _navigation_stale := false


func _ready() -> void:
	_enter_dungeon()
	navigation_region.bake_finished.connect(_on_navigation_baked)
	_rebake_navigation()
	inventory_ui.visibility_changed.connect(_on_inventory_toggled)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_equip_starting_gear_after_spawn()


func _process(_delta: float) -> void:
	camera_rig.global_position = player.global_position + Vector3.UP * RIG_HEIGHT
	player.camera_yaw = camera_rig.rotation.y
	info.text = "%s\n%s" % [CONTROLS, _status_text()]
	_update_interact_prompt()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _door_to_use() != null:
		_toggle_door()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key_pressed(event.physical_keycode)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not inventory_ui.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_key_pressed(key: Key) -> void:
	match key:
		KEY_R:
			get_tree().reload_current_scene()
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _equip_starting_gear_after_spawn() -> void:
	await player.animation_player.animation_finished
	for item: Node3D in starting_gear.get_children():
		player.equip(item)


func _enter_dungeon() -> void:
	player.global_position = generator.get_spawn_position()
	player.spawn()
	for node in generator.find_children("*", "Node3D", true, false):
		if node is Door:
			_track_door(node)


func _track_door(door: Door) -> void:
	door.opened.connect(_rebake_navigation)
	door.closed.connect(_rebake_navigation)


func _rebake_navigation() -> void:
	if navigation_region.is_baking():
		_navigation_stale = true
		return
	navigation_region.bake_navigation_mesh()


func _on_navigation_baked() -> void:
	if _navigation_stale:
		_navigation_stale = false
		navigation_region.bake_navigation_mesh()


func _on_inventory_toggled() -> void:
	player.combat_input_enabled = not inventory_ui.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED


func _look(mouse_motion: Vector2) -> void:
	var sensitivity := MOUSE_SENSITIVITY * camera_rig.look_scale()
	camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - mouse_motion.y * sensitivity, MIN_PITCH, MAX_PITCH)
	camera_rig.rotation.y -= mouse_motion.x * sensitivity


func _toggle_door() -> void:
	_door_to_use().toggle()
	player.interact()


func _door_to_use() -> Door:
	var reach_from := player.global_position + Vector3.UP * REACH_HEIGHT
	if aim_targeting.hovered_door_point.distance_to(reach_from) > HOVERED_DOOR_REACH:
		return null
	return aim_targeting.hovered_door


func _status_text() -> String:
	return DEATH_TEXT if player.dead else ""


func _update_interact_prompt() -> void:
	if player.dead or inventory_ui.visible:
		interact_prompt.hide()
		return
	var door := _door_to_use()
	if door != null:
		interact_prompt.show_action(_door_action(door))
		return
	var pickup := item_collector.manual_pickup()
	if pickup != null:
		interact_prompt.show_action(pickup.pick_up_text())
	else:
		interact_prompt.hide()


func _door_action(door: Door) -> String:
	return "Close door" if door.is_open else "Open door"
