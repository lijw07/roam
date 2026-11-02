class_name ItemIconRenderer
extends Node

const ICON_SIZE := Vector2i(128, 128)
const MODEL_PATH := ^"Model"
const VIEW_DIRECTION := Vector3(0.8, 1.0, 1.3)
const LIGHT_ROTATION_DEGREES := Vector3(-45, 35, 0)
const AMBIENT_COLOR := Color(0.65, 0.65, 0.7)
const AMBIENT_ENERGY := 0.8

var _icons: Dictionary[String, Texture2D] = {}


func icon_for(scene_path: String) -> Texture2D:
	if not _icons.has(scene_path):
		_icons[scene_path] = _render(load(scene_path))
	return _icons[scene_path]


func _render(scene: PackedScene) -> Texture2D:
	var viewport := _create_viewport()
	var model := _extract_model(scene)
	viewport.add_child(model)
	viewport.add_child(_create_camera(_bounds_of(model)))
	add_child(viewport)
	return viewport.get_texture()


func _extract_model(scene: PackedScene) -> Node3D:
	var item := scene.instantiate()
	var model: Node3D = item.get_node(MODEL_PATH)
	item.remove_child(model)
	item.free()
	return model


func _create_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = ICON_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.add_child(_create_light())
	viewport.add_child(_create_environment())
	return viewport


func _create_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = LIGHT_ROTATION_DEGREES
	return light


func _create_environment() -> WorldEnvironment:
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_COLOR
	environment.ambient_light_energy = AMBIENT_ENERGY
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	return world_environment


func _create_camera(bounds: AABB) -> Camera3D:
	var radius := bounds.size.length() / 2.0
	var direction := VIEW_DIRECTION.normalized()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = radius * 2.0
	camera.far = radius * 4.0
	camera.transform = Transform3D(Basis.looking_at(-direction), bounds.get_center() + direction * radius * 2.0)
	return camera


func _bounds_of(model: Node3D) -> AABB:
	var parts: Array[AABB] = []
	_collect_mesh_bounds(model, Transform3D.IDENTITY, parts)
	var bounds := parts[0]
	for part in parts:
		bounds = bounds.merge(part)
	return bounds


func _collect_mesh_bounds(node: Node, parent_transform: Transform3D, parts: Array[AABB]) -> void:
	var node_transform := parent_transform
	if node is Node3D:
		node_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		parts.append(node_transform * (node as MeshInstance3D).get_aabb())
	for child in node.get_children():
		_collect_mesh_bounds(child, node_transform, parts)
