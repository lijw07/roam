extends Node3D

## Explore generated dungeons. Tab cycles the views:
##   Overview  top-down map; WASD or right/middle-drag to pan, wheel to zoom
##   Fly       free camera through walls; mouse looks, WASD moves, Q/E down/up, Shift fast, wheel sets speed
##   Walk      play as a knight; mouse orbits the camera, WASD moves, Shift runs, Space jumps,
##             F opens or closes the nearest door, wheel sets camera distance
## R builds a new dungeon. Esc frees the mouse; click to capture it again.

enum Mode { OVERVIEW, FLY, WALK }

const EXPLORER := preload("res://scenes/characters/adventurers/knight.tscn")
const EXPLORER_SCRIPT := preload("res://scripts/dungeon_explorer.gd")
const MODE_NAMES := ["Overview", "Fly", "Walk"]
const CONTROLS := [
	"WASD / right-drag: pan   Wheel: zoom",
	"Mouse: look   WASD: move   Q/E: down/up   Shift: fast   Wheel: speed",
	"Mouse: camera   WASD: move   Shift: run   Space: jump   F: door   Wheel: distance",
]

@export var mouse_sensitivity := 0.003
@export var fly_speed := 12.0
## How close the knight has to be to a door to open it.
@export var door_reach := 3.0

@onready var generator: DungeonGenerator = $DungeonGenerator
@onready var overview_camera: Camera3D = $Camera3D
@onready var info: Label = $UI/Info

var mode := Mode.OVERVIEW

var _fly_camera := Camera3D.new()
var _explorer: CharacterBody3D
# Walk camera: the rig follows the knight and turns (yaw), the pitch node tilts,
# and the spring arm pulls the camera in when a wall gets between it and the knight.
var _rig := Node3D.new()
var _pitch := Node3D.new()
var _arm := SpringArm3D.new()
var _walk_camera := Camera3D.new()
var _doors: Array[Door] = []
var _dragging := false


func _ready() -> void:
	_fly_camera.name = "FlyCamera"
	_fly_camera.fov = 70.0
	_fly_camera.far = 400.0
	add_child(_fly_camera)

	_explorer = EXPLORER.instantiate()
	_explorer.set_script(EXPLORER_SCRIPT)
	_explorer.name = "Explorer"
	add_child(_explorer)

	_rig.name = "CameraRig"
	add_child(_rig)
	_rig.add_child(_pitch)
	_pitch.rotation.x = -0.35
	_pitch.add_child(_arm)
	# Wide enough that the camera also stays clear of banners hanging off the walls.
	var probe := SphereShape3D.new()
	probe.radius = 0.4
	_arm.shape = probe
	_arm.spring_length = 4.5
	_arm.add_excluded_object(_explorer.get_rid())
	_arm.add_child(_walk_camera)
	_walk_camera.fov = 70.0

	# Outline keeps the help text readable over bright and dark parts of the scene.
	info.add_theme_constant_override("outline_size", 6)
	info.add_theme_color_override("font_outline_color", Color.BLACK)

	generator.generated.connect(_on_generated)
	# The generator builds in its own _ready, before this one connects.
	if generator.start_room:
		_on_generated(generator.last_seed)
	_set_mode(Mode.OVERVIEW)


func _process(delta: float) -> void:
	match mode:
		Mode.OVERVIEW:
			var pan := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			overview_camera.position += Vector3(pan.x, 0.0, pan.y) * overview_camera.size * 0.8 * delta
		Mode.FLY:
			var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			var rise := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
			var speed := fly_speed * (3.0 if Input.is_action_pressed("sprint") else 1.0)
			var heading := _fly_camera.global_basis * Vector3(move.x, 0.0, move.y) + Vector3.UP * rise
			_fly_camera.global_position += heading * speed * delta
		Mode.WALK:
			_rig.global_position = _explorer.global_position + Vector3.UP * 1.6
			_explorer.camera_yaw = _rig.rotation.y
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				_set_mode(((mode + 1) % Mode.size()) as Mode)
			KEY_R:
				generator.generate(0)
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F:
				var door := _nearest_door()
				if mode == Mode.WALK and door:
					door.toggle()
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if mode == Mode.OVERVIEW and event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_dragging = event.pressed
	if not event.pressed:
		return
	if mode != Mode.OVERVIEW and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var zoom := 0.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom = -1.0
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom = 1.0
	if zoom == 0.0:
		return
	match mode:
		Mode.OVERVIEW:
			overview_camera.size = maxf(overview_camera.size * pow(1.1, zoom), 10.0)
		Mode.FLY:
			fly_speed = clampf(fly_speed * pow(1.2, -zoom), 2.0, 100.0)
		Mode.WALK:
			_arm.spring_length = clampf(_arm.spring_length + zoom * 0.5, 1.5, 10.0)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if mode == Mode.OVERVIEW:
		if _dragging:
			var meters_per_pixel := overview_camera.size / get_viewport().get_visible_rect().size.y
			overview_camera.position -= Vector3(event.relative.x, 0.0, event.relative.y) * meters_per_pixel
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var look := event.relative * mouse_sensitivity
	if mode == Mode.FLY:
		_fly_camera.rotation.y -= look.x
		_fly_camera.rotation.x = clampf(_fly_camera.rotation.x - look.y, -1.5, 1.5)
	else:
		_rig.rotation.y -= look.x
		_pitch.rotation.x = clampf(_pitch.rotation.x - look.y, -1.2, 0.4)


func _set_mode(new_mode: Mode) -> void:
	if new_mode == Mode.FLY:
		# Start flying from whatever the previous view was looking at.
		if mode == Mode.WALK:
			_fly_camera.global_transform = _walk_camera.global_transform
		else:
			var center := overview_camera.global_position
			_fly_camera.global_position = Vector3(center.x, 30.0, center.z + 20.0)
			_fly_camera.rotation = Vector3(-0.9, 0.0, 0.0)
		_fly_camera.rotation.z = 0.0
	mode = new_mode
	overview_camera.current = mode == Mode.OVERVIEW
	_fly_camera.current = mode == Mode.FLY
	_walk_camera.current = mode == Mode.WALK
	# Only walk mode drives the knight, so WASD doesn't move it while panning or flying.
	_explorer.set_physics_process(mode == Mode.WALK)
	_dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mode == Mode.OVERVIEW else Input.MOUSE_MODE_CAPTURED


func _on_generated(_used_seed: int) -> void:
	var bounds := generator.get_bounds()
	var center := bounds.get_center()
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / viewport_size.y
	overview_camera.position = Vector3(center.x, 80.0, center.y)
	overview_camera.size = maxf(bounds.size.y, bounds.size.x / aspect) * 1.1
	_explorer.global_position = generator.get_spawn_position()
	_explorer.velocity = Vector3.ZERO
	_doors.clear()
	for node in generator.find_children("*", "", true, false):
		if node is Door:
			_doors.append(node)


func _nearest_door() -> Door:
	var nearest: Door = null
	var best := door_reach
	for door in _doors:
		if not is_instance_valid(door):
			continue
		var distance := door.global_position.distance_to(_explorer.global_position)
		if distance < best:
			best = distance
			nearest = door
	return nearest


func _update_info() -> void:
	var room_count := generator.get_pieces().filter(func(p): return p.is_room()).size()
	var lines := [
		"Seed %d   %d rooms (boss: %s)   %d enemies" % [generator.last_seed, room_count,
			generator.boss_room.name if generator.boss_room else "-", generator.get_enemies().size()],
		"%s view   %s" % [MODE_NAMES[mode], CONTROLS[mode]],
		"Tab: switch view   R: new dungeon   Esc: free mouse",
	]
	if mode == Mode.WALK:
		var door := _nearest_door()
		if door:
			lines.append("[F] %s door" % ("Close" if door.is_open else "Open"))
	info.text = "\n".join(lines)
