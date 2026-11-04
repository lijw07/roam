extends HurtboxWatcher

const OUTLINE_SHADER := preload("res://shaders/hit_outline.gdshader")
const COLOR_PARAMETER := &"outline_color"
const WIDTH_PARAMETER := &"outline_width"
const WIDTH_PROPERTY := ^"shader_parameter/outline_width"
const FLASH_WIDTH := 0.04
const HOLD_TIME := 0.08
const FADE_TIME := 0.3
const WARM_UP_FRAMES := 2
const RADIAL_PARAMETER := &"radial"

@export var player: Node3D
@export var targeting: AimTargeting
@export var hit_color := Color(1.0, 0.2, 0.2)
@export var target_color := Color(1.0, 0.2, 0.2)
@export var aggro_color := Color.WHITE
@export var looked_at_color := Color.WHITE
@export var state_width := 0.03

var _flashes: Dictionary[int, Tween] = {}
var _state_outlines: Dictionary[int, ShaderMaterial] = {}


func _ready() -> void:
	super()
	_warm_up_outline.call_deferred()


func _process(_delta: float) -> void:
	var wanted := _wanted_outlines()
	for id: int in _state_outlines.keys():
		var outlined := instance_from_id(id) as Node3D
		if outlined == null or not wanted.has(outlined):
			_drop_state_outline(id)
	for outlined: Node3D in wanted:
		_show_state_outline(outlined, wanted[outlined])


func _on_hit_taken(_hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	var enemy := hurtbox.get_parent() as Enemy
	if damage > 0.0 and enemy != null:
		_flash(enemy)


func _wanted_outlines() -> Dictionary[Node3D, Color]:
	var wanted: Dictionary[Node3D, Color] = {}
	for enemy in _aggroed_enemies():
		wanted[enemy] = aggro_color
	if targeting == null or not is_instance_valid(targeting.looked_at) or targeting.looked_at == player:
		return wanted
	var looked_at: Node3D = targeting.looked_at
	wanted[looked_at] = target_color if looked_at is Enemy else looked_at_color
	return wanted


func _aggroed_enemies() -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	var director := get_tree().get_first_node_in_group(CombatDirector.GROUP) as CombatDirector
	if director == null:
		return enemies
	for brain in director.brains():
		if brain.is_engaged():
			enemies.append(brain.enemy)
	return enemies


func _show_state_outline(outlined: Node3D, color: Color) -> void:
	var id := outlined.get_instance_id()
	if _flashes.has(id):
		return
	if not _state_outlines.has(id):
		_state_outlines[id] = _outline_material(color, state_width)
		_state_outlines[id].set_shader_parameter(RADIAL_PARAMETER, not (outlined is Enemy))
		_outline_meshes(_meshes_of(outlined), _state_outlines[id])
	_state_outlines[id].set_shader_parameter(COLOR_PARAMETER, color)


func _drop_state_outline(id: int) -> void:
	_state_outlines.erase(id)
	var outlined := instance_from_id(id) as Node3D
	if outlined != null and not _flashes.has(id):
		_clear_outline(_meshes_of(outlined))


func _warm_up_outline() -> void:
	var meshes: Array[MeshInstance3D] = []
	for hurtbox: Hurtbox in _watched:
		meshes.append_array(_meshes_of(hurtbox.get_parent()))
	_outline_meshes(meshes, _outline_material(aggro_color, 0.0))
	for _frame in WARM_UP_FRAMES:
		await get_tree().process_frame
	_clear_outline(meshes)


func _flash(target: Node3D) -> void:
	var id := target.get_instance_id()
	if _flashes.has(id):
		_flashes[id].kill()
	_state_outlines.erase(id)
	var meshes := _meshes_of(target)
	var outline := _outline_material(hit_color, FLASH_WIDTH)
	_outline_meshes(meshes, outline)
	var tween := create_tween()
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(outline, WIDTH_PROPERTY, 0.0, FADE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_flash.bind(id, meshes))
	_flashes[id] = tween


func _finish_flash(id: int, meshes: Array[MeshInstance3D]) -> void:
	_clear_outline(meshes)
	_flashes.erase(id)


func _outline_material(color: Color, width: float) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter(COLOR_PARAMETER, color)
	outline.set_shader_parameter(WIDTH_PARAMETER, width)
	return outline


func _outline_meshes(meshes: Array[MeshInstance3D], outline: ShaderMaterial) -> void:
	for mesh in meshes:
		mesh.material_overlay = outline


func _clear_outline(meshes: Array[MeshInstance3D]) -> void:
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null


func _meshes_of(target: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and not (mesh is EnemyHealthBar):
			meshes.append(mesh)
	return meshes
