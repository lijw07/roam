extends Node3D

const RIG_HEIGHT := 1.4
const MOUSE_SENSITIVITY := 0.003
const MIN_PITCH := -1.2
const MAX_PITCH := 0.3
const DOOR_REACH := 3.0
const CONTROLS := "WASD move   Shift run   Space jump   Alt dodge   LMB attack   RMB block   F door / pick up   Tab inventory   R new dungeon   Esc free mouse"
const DEATH_TEXT := "You died   R to try a new dungeon"

@onready var player: CharacterBody3D = $Player
@onready var item_collector: ItemCollector = $Player/ItemCollector
@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D
@onready var generator: DungeonGenerator = $NavigationRegion3D/DungeonGenerator
@onready var starting_gear: Node3D = $StartingGear
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_pitch: Node3D = $CameraRig/Pitch
@onready var info: Label = $HUD/Info
@onready var inventory_ui: Control = $HUD/Inventory

var _doors: Array[Door] = []
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


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _nearest_door() != null:
		_toggle_nearest_door()
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
	_doors.append(door)
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
	camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - mouse_motion.y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	camera_rig.rotation.y -= mouse_motion.x * MOUSE_SENSITIVITY


func _toggle_nearest_door() -> void:
	_nearest_door().toggle()
	player.interact()


func _nearest_door() -> Door:
	var nearest: Door = null
	var best := DOOR_REACH
	for door in _doors:
		var distance := door.global_position.distance_to(player.global_position)
		if distance < best:
			best = distance
			nearest = door
	return nearest


func _status_text() -> String:
	if player.dead:
		return DEATH_TEXT
	var door := _nearest_door()
	if door != null:
		return "F  %s door" % ("close" if door.is_open else "open")
	return _pick_up_prompt()


func _pick_up_prompt() -> String:
	var pickup := item_collector.nearest_pickup()
	if pickup == null or pickup.auto_pick_up:
		return ""
	if pickup.count > 1:
		return "F  pick up %s x%d" % [pickup.item_name, pickup.count]
	return "F  pick up %s" % pickup.item_name
