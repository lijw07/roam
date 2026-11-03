extends Node3D

const UNLIT_FRAMES := 4
const WARM_UP_FRAMES := 10
const WARM_UP_LIGHT_ENERGY := 0.001
const ARENA_LIGHT_RANGE := 60.0

@export var player: Node3D


func _ready() -> void:
	_warm_up()


func _warm_up() -> void:
	for _frame in UNLIT_FRAMES:
		await get_tree().process_frame
	var hidden_spot := WarmUpSpot.under_floor(self, player.global_position)
	var stand_ins: Array[Node3D] = []
	for scene in _projectile_scenes():
		stand_ins.append(_still_projectile(scene, hidden_spot))
	stand_ins.append(_arena_light(hidden_spot))
	for _frame in WARM_UP_FRAMES:
		await get_tree().process_frame
	for stand_in in stand_ins:
		stand_in.queue_free()


func _projectile_scenes() -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	for node in owner.find_children("*", "Area3D", true, false):
		if node is Weapon:
			for scene: PackedScene in [node.projectile, node.secondary_projectile]:
				if scene != null and not scenes.has(scene):
					scenes.append(scene)
	return scenes


func _still_projectile(scene: PackedScene, at: Vector3) -> Node3D:
	var projectile: Projectile = scene.instantiate()
	projectile.set_physics_process(false)
	for light: Light3D in projectile.find_children("*", "Light3D", true, false):
		light.light_energy = WARM_UP_LIGHT_ENERGY
	add_child(projectile)
	projectile.global_position = at
	return projectile


func _arena_light(at: Vector3) -> Node3D:
	var light := OmniLight3D.new()
	light.omni_range = ARENA_LIGHT_RANGE
	light.light_energy = WARM_UP_LIGHT_ENERGY
	add_child(light)
	light.global_position = at
	return light
