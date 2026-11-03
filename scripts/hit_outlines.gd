extends HurtboxWatcher

const GROW := 0.04
const HOLD_TIME := 0.08
const FADE_TIME := 0.3

@export var player: Node3D
@export var enemy_color := Color(1.0, 0.2, 0.2)
@export var item_color := Color.WHITE

var _flashes: Dictionary[int, Tween] = {}


func _on_hit_taken(_hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	var target := hurtbox.get_parent() as Node3D
	if damage > 0.0 and target != player:
		_flash(target, enemy_color if target is Enemy else item_color)


func _flash(target: Node3D, color: Color) -> void:
	var key := target.get_instance_id()
	if _flashes.has(key):
		_flashes[key].kill()
	var outline := _outline_material(color)
	var meshes := _meshes_of(target)
	for mesh in meshes:
		mesh.material_overlay = outline
	var tween := create_tween()
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(outline, "grow_amount", 0.0, FADE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(_clear.bind(key, meshes))
	_flashes[key] = tween


func _clear(key: int, meshes: Array[MeshInstance3D]) -> void:
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
	_flashes.erase(key)


func _meshes_of(target: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
		if not (mesh is EnemyHealthBar):
			meshes.append(mesh)
	return meshes


func _outline_material(color: Color) -> StandardMaterial3D:
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = GROW
	outline.albedo_color = color
	return outline
