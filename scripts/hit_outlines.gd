extends HurtboxWatcher

const OUTLINE_SHADER := preload("res://shaders/hit_outline.gdshader")
const PROP_OUTLINE_SHADER := preload("res://shaders/prop_outline.gdshader")
const PROP_OUTLINE_THROUGH_PLAYER_SHADER := preload("res://shaders/prop_outline_through_player.gdshader")
const OUTLINE_MASK_SHADER := preload("res://shaders/outline_mask.gdshader")
const COLOR_PARAMETER := &"outline_color"
const WIDTH_PARAMETER := &"outline_width"
const WIDTH_PROPERTY := ^"shader_parameter/outline_width"
const FLASH_WIDTH := 0.04
const HOLD_TIME := 0.08
const FADE_TIME := 0.3
const WARM_UP_FRAMES := 2
const RADIAL_CENTER_PARAMETER := &"radial_center"
const PROP_OUTLINE_PRIORITY := 1
const PICKUP_OUTLINE_RADIUS := 6.0

@export var player: Node3D
@export var targeting: AimTargeting
@export var hit_color := Color(1.0, 0.2, 0.2)
@export var target_color := Color(1.0, 0.2, 0.2)
@export var aggro_color := Color.WHITE
@export var looked_at_color := Color.WHITE
@export var state_width := 0.03

var _flashes: Dictionary[int, Tween] = {}
var _state_outlines: Dictionary[int, ShaderMaterial] = {}
var _pickup_outlines: Dictionary[int, ShaderMaterial] = {}


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
	_update_pickup_outlines()


func _update_pickup_outlines() -> void:
	for id: int in _pickup_outlines.keys():
		var tracked := instance_from_id(id) as ItemPickup
		if tracked == null or not _tracks_pickup(tracked):
			_drop_pickup_outline(id, tracked)
	for pickup: ItemPickup in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		if _tracks_pickup(pickup):
			_show_pickup_outline(pickup)


func _tracks_pickup(pickup: ItemPickup) -> bool:
	if pickup.is_queued_for_deletion() or not is_instance_valid(player):
		return false
	return _is_looked_at(pickup) or pickup.global_position.distance_to(player.global_position) <= PICKUP_OUTLINE_RADIUS


func _is_looked_at(pickup: ItemPickup) -> bool:
	return targeting != null and targeting.looked_at == pickup


func _show_pickup_outline(pickup: ItemPickup) -> void:
	var id := pickup.get_instance_id()
	if not _pickup_outlines.has(id):
		_pickup_outlines[id] = _pickup_outline_material(pickup)
		_outline_meshes(_meshes_of(pickup), _overlay_for(_pickup_outlines[id], pickup))
	var outline := _pickup_outlines[id]
	outline.set_shader_parameter(COLOR_PARAMETER, Color(looked_at_color, 1.0 if _is_looked_at(pickup) else 0.0))
	(outline.next_pass as ShaderMaterial).set_shader_parameter(COLOR_PARAMETER, Color(looked_at_color, 1.0 if _covered_by_player(pickup) else 0.0))


func _drop_pickup_outline(id: int, pickup: ItemPickup) -> void:
	_pickup_outlines.erase(id)
	if pickup != null:
		_clear_outline(_meshes_of(pickup))


func _pickup_outline_material(pickup: ItemPickup) -> ShaderMaterial:
	var outline := _outline_material(Color.TRANSPARENT, state_width, pickup)
	var through := ShaderMaterial.new()
	through.shader = PROP_OUTLINE_THROUGH_PLAYER_SHADER
	through.render_priority = PROP_OUTLINE_PRIORITY
	through.set_shader_parameter(COLOR_PARAMETER, Color.TRANSPARENT)
	through.set_shader_parameter(WIDTH_PARAMETER, state_width)
	through.set_shader_parameter(RADIAL_CENTER_PARAMETER, _local_center(pickup))
	outline.next_pass = through
	return outline


func _covered_by_player(pickup: ItemPickup) -> bool:
	var camera := get_viewport().get_camera_3d()
	var body := player as CollisionObject3D
	if camera == null or body == null:
		return false
	var center := pickup.global_transform * _local_center(pickup)
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, center, body.collision_layer)
	return get_world_3d().direct_space_state.intersect_ray(query).get("collider") == body


func _on_hit_taken(_hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	var enemy := hurtbox.get_parent() as Enemy
	if damage > 0.0 and enemy != null:
		_flash(enemy)


func _wanted_outlines() -> Dictionary[Node3D, Color]:
	var wanted: Dictionary[Node3D, Color] = {}
	for enemy in _aggroed_enemies():
		wanted[enemy] = aggro_color
	if targeting == null:
		return wanted
	if is_instance_valid(targeting.looked_at):
		var looked_at := targeting.looked_at
		if looked_at != player and not (looked_at is Enemy or looked_at is ItemPickup):
			wanted[looked_at] = looked_at_color
	if is_instance_valid(targeting.attack_target):
		wanted[targeting.attack_target] = target_color
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
		_state_outlines[id] = _outline_material(color, state_width, outlined)
		_outline_meshes(_meshes_of(outlined), _overlay_for(_state_outlines[id], outlined))
	_state_outlines[id].set_shader_parameter(COLOR_PARAMETER, color)


func _drop_state_outline(id: int) -> void:
	_state_outlines.erase(id)
	var outlined := instance_from_id(id) as Node3D
	if outlined != null and not _flashes.has(id):
		_clear_outline(_meshes_of(outlined))


func _warm_up_outline() -> void:
	var meshes: Array[MeshInstance3D] = []
	for hurtbox: Hurtbox in _watched:
		var owner_node := hurtbox.get_parent() as Node3D
		var owned := _meshes_of(owner_node)
		_outline_meshes(owned, _overlay_for(_outline_material(aggro_color, 0.0, owner_node), owner_node))
		meshes.append_array(owned)
	for _frame in WARM_UP_FRAMES:
		await get_tree().process_frame
	_clear_outline(meshes)


func _flash(target: Node3D) -> void:
	var id := target.get_instance_id()
	if _flashes.has(id):
		_flashes[id].kill()
	_state_outlines.erase(id)
	var meshes := _meshes_of(target)
	var outline := _outline_material(hit_color, FLASH_WIDTH, target)
	_outline_meshes(meshes, _overlay_for(outline, target))
	var tween := create_tween()
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(outline, WIDTH_PROPERTY, 0.0, FADE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_flash.bind(id, meshes))
	_flashes[id] = tween


func _finish_flash(id: int, meshes: Array[MeshInstance3D]) -> void:
	_clear_outline(meshes)
	_flashes.erase(id)


func _outline_material(color: Color, width: float, target: Node3D) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER if target is Enemy else PROP_OUTLINE_SHADER
	outline.set_shader_parameter(COLOR_PARAMETER, color)
	outline.set_shader_parameter(WIDTH_PARAMETER, width)
	if not (target is Enemy):
		outline.render_priority = PROP_OUTLINE_PRIORITY
		outline.set_shader_parameter(RADIAL_CENTER_PARAMETER, _local_center(target))
	return outline


func _overlay_for(outline: ShaderMaterial, target: Node3D) -> Material:
	if target is Enemy:
		return outline
	var mask := ShaderMaterial.new()
	mask.shader = OUTLINE_MASK_SHADER
	mask.next_pass = outline
	return mask


func _outline_meshes(meshes: Array[MeshInstance3D], overlay: Material) -> void:
	for mesh in meshes:
		mesh.material_overlay = overlay


func _clear_outline(meshes: Array[MeshInstance3D]) -> void:
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null


func _local_center(target: Node3D) -> Vector3:
	var meshes := _meshes_of(target)
	return Vector3.ZERO if meshes.is_empty() else meshes[0].get_aabb().get_center()


func _meshes_of(target: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if target is MeshInstance3D:
		meshes.append(target as MeshInstance3D)
	for mesh: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and not (mesh is EnemyHealthBar):
			meshes.append(mesh)
	return meshes
