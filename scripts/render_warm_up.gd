class_name RenderWarmUp
extends Node3D

signal finished

const GROUP := &"render_warm_ups"
const SETTLE_FRAMES := 2
const RENDER_FRAMES := 8
const DISTANCE := 3.0
const COLUMNS := 24
const SPACING := 0.08
const STAND_IN_SCALE := 0.03
const LIGHT_ENERGY := 0.001
const LIGHT_RANGE := 30.0

var is_warming := true


func _ready() -> void:
	add_to_group(GROUP)
	_warm_up()


func _warm_up() -> void:
	for _frame in SETTLE_FRAMES:
		await get_tree().process_frame
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var stand_ins := _stand_ins()
		_line_up(stand_ins, camera)
		_light_up(camera)
		for _frame in RENDER_FRAMES:
			await get_tree().process_frame
		for child in get_children():
			child.queue_free()
	is_warming = false
	finished.emit()


func _stand_ins() -> Array[GeometryInstance3D]:
	var looks := {}
	for source in _geometry_in(owner):
		_add_stand_in(source, looks)
	for scene in _spawnable_scenes():
		var instance := scene.instantiate()
		for source in _geometry_in(instance):
			_add_stand_in(source, looks)
		instance.free()
	var stand_ins: Array[GeometryInstance3D] = []
	stand_ins.assign(looks.values())
	return stand_ins


func _geometry_in(root: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	if root is GeometryInstance3D:
		found.append(root as GeometryInstance3D)
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if node != self and not is_ancestor_of(node):
			found.append(node as GeometryInstance3D)
	return found


func _add_stand_in(source: GeometryInstance3D, looks: Dictionary) -> void:
	if source is MeshInstance3D:
		_add_mesh_stand_in(source as MeshInstance3D, looks)
	else:
		_add_effect_stand_in(source, looks)


func _add_mesh_stand_in(source: MeshInstance3D, looks: Dictionary) -> void:
	if source.mesh == null:
		return
	var look := _mesh_look_of(source)
	if looks.has(look):
		return
	var stand_in := MeshInstance3D.new()
	stand_in.mesh = source.mesh
	for surface in source.mesh.get_surface_count():
		stand_in.set_surface_override_material(surface, source.get_active_material(surface))
	stand_in.material_overlay = source.material_overlay
	looks[look] = stand_in


func _mesh_look_of(source: MeshInstance3D) -> Array:
	var look: Array = [source.mesh, source.material_overlay]
	for surface in source.mesh.get_surface_count():
		look.append(source.get_active_material(surface))
	return look


func _add_effect_stand_in(source: GeometryInstance3D, looks: Dictionary) -> void:
	var look := _effect_look_of(source)
	if looks.has(look):
		return
	var stand_in := source.duplicate(0) as GeometryInstance3D
	for child in stand_in.get_children():
		child.free()
	if stand_in is GPUParticles3D:
		(stand_in as GPUParticles3D).one_shot = false
		(stand_in as GPUParticles3D).emitting = true
	looks[look] = stand_in


func _effect_look_of(source: GeometryInstance3D) -> Array:
	var look: Array = [source.get_class(), source.material_override, source.material_overlay]
	if source is GPUParticles3D:
		var particles := source as GPUParticles3D
		look.append_array([particles.process_material, particles.draw_pass_1])
	return look


func _spawnable_scenes() -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	for dropper in owner.find_children("*", "Node", true, false):
		if dropper is ItemDropper:
			_add_loot_of(dropper as ItemDropper, scenes)
	var index := 0
	while index < scenes.size():
		_add_stack_of(scenes[index], scenes)
		index += 1
	return scenes


func _add_loot_of(dropper: ItemDropper, scenes: Array[PackedScene]) -> void:
	for table in dropper.loot_tables:
		for tier in table.tiers:
			for item in tier.items:
				if item != null and not scenes.has(item):
					scenes.append(item)


func _add_stack_of(scene: PackedScene, scenes: Array[PackedScene]) -> void:
	var item := scene.instantiate()
	var stack_path: String = item.get("full_stack_scene") if item is ItemPickup else ""
	item.free()
	if stack_path.is_empty():
		return
	var stack := load(stack_path) as PackedScene
	if stack != null and not scenes.has(stack):
		scenes.append(stack)


func _line_up(stand_ins: Array[GeometryInstance3D], camera: Camera3D) -> void:
	var rows := ceili(stand_ins.size() / float(COLUMNS))
	var origin := camera.global_position - camera.global_basis.z * DISTANCE
	var right := camera.global_basis.x * SPACING
	var down := -camera.global_basis.y * SPACING
	var corner := origin - right * (COLUMNS - 1) * 0.5 - down * (rows - 1) * 0.5
	for index in stand_ins.size():
		var stand_in := stand_ins[index]
		add_child(stand_in)
		stand_in.global_transform = Transform3D(
			camera.global_basis.scaled(Vector3.ONE * STAND_IN_SCALE),
			corner + right * (index % COLUMNS) + down * floorf(float(index) / COLUMNS)
		)


func _light_up(camera: Camera3D) -> void:
	var light := OmniLight3D.new()
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	add_child(light)
	light.global_position = camera.global_position - camera.global_basis.z * DISTANCE
