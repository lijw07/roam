extends HurtboxWatcher

const OUTLINE_SHADER := preload("res://shaders/hit_outline.gdshader")
const COLOR_PARAMETER := &"outline_color"
const WIDTH_PARAMETER := &"outline_width"
const WIDTH := 0.04
const HOLD_TIME := 0.08
const FADE_TIME := 0.3
const WARM_UP_FRAMES := 2

@export var player: Node3D
@export var enemy_color := Color(1.0, 0.2, 0.2)
@export var item_color := Color.WHITE

var _outline := ShaderMaterial.new()
var _flashes: Dictionary[int, Tween] = {}


func _ready() -> void:
	_outline.shader = OUTLINE_SHADER
	super()
	_warm_up_outline.call_deferred()


func _on_hit_taken(_hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	var target := hurtbox.get_parent() as Node3D
	if damage > 0.0 and target != player:
		_flash(target, enemy_color if target is Enemy else item_color)


func _warm_up_outline() -> void:
	var meshes: Array[MeshInstance3D] = []
	for hurtbox: Hurtbox in _watched:
		meshes.append_array(_meshes_of(hurtbox.get_parent()))
	_outline_meshes(meshes, item_color, 0.0)
	for _frame in WARM_UP_FRAMES:
		await get_tree().process_frame
	_clear_outline(meshes)


func _flash(target: Node3D, color: Color) -> void:
	var key := target.get_instance_id()
	if _flashes.has(key):
		_flashes[key].kill()
	var meshes := _meshes_of(target)
	_outline_meshes(meshes, color, WIDTH)
	var tween := create_tween()
	tween.tween_interval(HOLD_TIME)
	tween.tween_method(_set_width.bind(meshes), WIDTH, 0.0, FADE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_flash.bind(key, meshes))
	_flashes[key] = tween


func _finish_flash(key: int, meshes: Array[MeshInstance3D]) -> void:
	_clear_outline(meshes)
	_flashes.erase(key)


func _outline_meshes(meshes: Array[MeshInstance3D], color: Color, width: float) -> void:
	for mesh in meshes:
		mesh.material_overlay = _outline
		mesh.set_instance_shader_parameter(COLOR_PARAMETER, color)
		mesh.set_instance_shader_parameter(WIDTH_PARAMETER, width)


func _set_width(width: float, meshes: Array[MeshInstance3D]) -> void:
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.set_instance_shader_parameter(WIDTH_PARAMETER, width)


func _clear_outline(meshes: Array[MeshInstance3D]) -> void:
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null


func _meshes_of(target: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
		if not (mesh is EnemyHealthBar):
			meshes.append(mesh)
	return meshes
