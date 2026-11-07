extends SubViewportContainer

## Shows the original character scene in its own display world.
var _viewport: SubViewport
var _character: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.84, 0.87, 0.88)
	environment.environment.ambient_light_energy = 0.65
	_viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 0.8
	_viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.8
	camera.position = Vector3(0.9, 1.8, 6)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0, 1.2, 0))


func show_character(character_class: CharacterClass) -> void:
	if is_instance_valid(_character):
		_viewport.remove_child(_character)
		_character.queue_free()
		_character = null
	if character_class == null:
		return
	_character = character_class.character_scene.instantiate()
	_viewport.add_child(_character)
	var animation := _character.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation != null and animation.has_animation("general/Idle_A"):
		animation.play("general/Idle_A")
