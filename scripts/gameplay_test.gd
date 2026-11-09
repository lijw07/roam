extends Node3D

const RIG_HEIGHT := 1.4
const MOUSE_SENSITIVITY := 0.003
const MIN_PITCH := -1.2
const MAX_PITCH := 0.3
const DOOR_REACH := 3.0
const HOVERED_DOOR_REACH := 3.5
const REACH_HEIGHT := 1.0
const DEATH_TEXT := "You died   R to return to camp"
const LEAVE_TEXT := "Leave dungeon"
const LOCKED_EXIT_TEXT := "Defeat the boss to leave"
const MODEL_PATH := ^"Model"
const BODY_SHAPE_PATH := ^"CollisionShape3D"

@export var default_class: CharacterClass
@export_file("*.tscn") var hub_scene := "res://scenes/ui/hub.tscn"

@onready var player: CharacterBody3D = $Player
@onready var item_collector: ItemCollector = $Player/ItemCollector
@onready var run_inventory: Inventory = $Player/Inventory
@onready var kill_all_button: Button = $HUD/KillAllEnemies
@onready var pause_menu: Control = $HUD/PauseMenu
@onready var victory_screen: Control = $HUD/VictoryScreen
@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D
@onready var generator: DungeonGenerator = $NavigationRegion3D/DungeonGenerator
@onready var starting_gear: Node3D = $StartingGear
@onready var camera_rig: ShoulderCamera = $CameraRig
@onready var camera_pitch: Node3D = $CameraRig/Pitch
@onready var control_hints: VBoxContainer = $HUD/ControlHints
@onready var inventory_ui: Control = $HUD/Inventory
@onready var aim_targeting: AimTargeting = $AimTargeting

var _doors: Array[Door] = []
var _navigation_stale := false
var _boss_defeated := false


func _enter_tree() -> void:
	_become(Profile.character_class if Profile.character_class != null else default_class)


func _ready() -> void:
	_stock_starting_gear()
	run_inventory.load_data(Profile.backpack.to_data())
	_enter_dungeon()
	kill_all_button.visible = OS.is_debug_build()
	kill_all_button.pressed.connect(_kill_all_enemies)
	navigation_region.bake_finished.connect(_on_navigation_baked)
	_rebake_navigation()
	inventory_ui.visibility_changed.connect(_on_inventory_toggled)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_equip_starting_gear_after_spawn()


func _process(_delta: float) -> void:
	camera_rig.global_position = player.global_position + Vector3.UP * RIG_HEIGHT
	player.camera_yaw = camera_rig.rotation.y
	control_hints.show_status(_status_text(), player.dead)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _door_to_use() != null:
		get_viewport().set_input_as_handled()
		_use_door()
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key_pressed(event.physical_keycode)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not inventory_ui.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_key_pressed(key: Key) -> void:
	if key == KEY_R:
		_restart()


func _restart() -> void:
	if player.dead:
		Profile.lose_run()
		set_process_unhandled_key_input(false)
		get_tree().change_scene_to_file.call_deferred(hub_scene)
	else:
		get_tree().reload_current_scene.call_deferred()


func _become(chosen: CharacterClass) -> void:
	var body := $Player
	var character: Node3D = chosen.character_scene.instantiate()
	_swap_child(body, character, MODEL_PATH)
	var shape: CollisionShape3D = character.get_node(BODY_SHAPE_PATH)
	var own_shape: CollisionShape3D = body.get_node(BODY_SHAPE_PATH)
	own_shape.shape = shape.shape
	own_shape.transform = shape.transform
	body.character_class = chosen
	character.free()


func _swap_child(parent: Node, source: Node, path: NodePath) -> void:
	var old := parent.get_node(path)
	var replacement := source.get_node(path)
	var index := old.get_index()
	parent.remove_child(old)
	old.free()
	source.remove_child(replacement)
	replacement.owner = null
	parent.add_child(replacement)
	parent.move_child(replacement, index)


func _stock_starting_gear() -> void:
	for scene_path in _starting_gear_paths():
		starting_gear.add_child((load(scene_path) as PackedScene).instantiate())


func _starting_gear_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	if Profile.character_class == null:
		for scene: PackedScene in [default_class.starting_weapon, default_class.starting_off_hand]:
			if scene != null:
				paths.append(scene.resource_path)
		return paths
	for hand: Inventory in [Profile.weapon, Profile.off_hand]:
		if hand.count_at(0) > 0:
			paths.append(hand.slots[0].scene_path)
	return paths


func _equip_starting_gear_after_spawn() -> void:
	await player.animation_player.animation_finished
	for item: Node3D in starting_gear.get_children():
		player.equip(item)


func _enter_dungeon() -> void:
	player.global_position = generator.get_spawn_position()
	player.spawn()
	_watch_boss()
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
	control_hints.set_inventory_open(inventory_ui.visible)
	player.combat_input_enabled = not inventory_ui.visible
	player.movement_input_enabled = not inventory_ui.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED


func _look(mouse_motion: Vector2) -> void:
	var sensitivity := MOUSE_SENSITIVITY * camera_rig.look_scale()
	camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - mouse_motion.y * sensitivity * Settings.mouse_sensitivity_y, MIN_PITCH, MAX_PITCH)
	camera_rig.rotation.y -= mouse_motion.x * sensitivity * Settings.mouse_sensitivity_x


func _kill_all_enemies() -> void:
	for enemy in generator.get_enemies():
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.die()


func _watch_boss() -> void:
	_boss_defeated = generator.boss == null
	if not _boss_defeated:
		generator.boss.health.died.connect(func() -> void: _boss_defeated = true)


func _use_door() -> void:
	var door := _door_to_use()
	if door == generator.level_exit:
		_leave_dungeon()
		return
	door.toggle()
	player.interact()


func _leave_dungeon() -> void:
	if not _boss_defeated:
		return
	Profile.finish_run(run_inventory)
	set_process_unhandled_key_input(false)
	pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = true
	victory_screen.finished.connect(_return_to_camp)
	victory_screen.play()


func _return_to_camp() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(hub_scene)


func _door_to_use() -> Door:
	var hovered := _hovered_door()
	return hovered if hovered != null else _nearest_door()


func _hovered_door() -> Door:
	var reach_from := player.global_position + Vector3.UP * REACH_HEIGHT
	if aim_targeting.hovered_door_point.distance_to(reach_from) > HOVERED_DOOR_REACH:
		return null
	return aim_targeting.hovered_door


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
	var door := _door_to_use()
	if door != null:
		return "F  %s" % _door_action(door)
	return _pick_up_prompt()


func _pick_up_prompt() -> String:
	var pickup := item_collector.nearest_pickup()
	if pickup == null or pickup.auto_pick_up:
		return ""
	if pickup.count > 1:
		return "F  pick up %s x%d" % [pickup.item_name, pickup.count]
	return "F  pick up %s" % pickup.item_name


func _door_action(door: Door) -> String:
	if door == generator.level_exit:
		return LEAVE_TEXT if _boss_defeated else LOCKED_EXIT_TEXT
	return "Close door" if door.is_open else "Open door"
