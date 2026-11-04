extends HurtboxWatcher

const HIT_EFFECTS: Array[PackedScene] = [
	preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_01.tscn"),
	preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_02.tscn"),
]
const VIEW_SPHERE_PARAMETER := &"vfx_player_view_sphere"
const PLAYER_CENTER_HEIGHT := 1.0
const PLAYER_VIEW_RADIUS := 0.8

@export var player: Node3D
@export var heavy_damage := 30.0
@export var effect_scale := 1.0
@export var heavy_scale := 1.3
@export var effect_emission := 1.6
@export var effect_speed := 1.25

var _materials: Dictionary[ShaderMaterial, bool] = {}


func _ready() -> void:
	super()
	_warm_up_effects()


func _process(_delta: float) -> void:
	_share_player_view_sphere(_player_view_sphere())


func _exit_tree() -> void:
	_share_player_view_sphere(Vector4.ZERO)


func _share_player_view_sphere(sphere: Vector4) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(VIEW_SPHERE_PARAMETER, sphere)


func _on_hit_taken(hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	if damage > 0.0:
		_play_impact(hit, hurtbox, heavy_scale if damage >= heavy_damage else effect_scale)


func _on_blocked(hit: Hit, hurtbox: Hurtbox) -> void:
	if hurtbox.get_parent() is Enemy:
		_play_impact(hit, hurtbox, effect_scale)


func _play_impact(hit: Hit, hurtbox: Hurtbox, size: float) -> void:
	var target := hurtbox.get_parent()
	if target is Enemy:
		_spawn(HIT_EFFECTS.pick_random(), _contact_point(hit, hurtbox, _viewer_position(hit)), size)
	elif target == player:
		_spawn(HIT_EFFECTS.pick_random(), _contact_point(hit, hurtbox, hit.origin), size)


func _player_view_sphere() -> Vector4:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(player):
		return Vector4.ZERO
	var chest := player.global_position + Vector3.UP * PLAYER_CENTER_HEIGHT
	var center := camera.global_transform.affine_inverse() * chest
	return Vector4(center.x, center.y, center.z, PLAYER_VIEW_RADIUS)


func _warm_up_effects() -> void:
	await get_tree().process_frame
	if player == null:
		return
	for effect in HIT_EFFECTS:
		_spawn(effect, WarmUpSpot.under_floor(self, player.global_position), 1.0)


func _spawn(effect: PackedScene, at: Vector3, size: float) -> void:
	var instance: VFXImpactBB = effect.instantiate()
	instance.one_shot = true
	instance.top_level = true
	instance.position = at
	instance.scale = Vector3.ONE * size
	add_child(instance)
	instance.emission = effect_emission
	instance.speed_scale = effect_speed
	instance.light.hide()
	for material in instance.materials:
		_materials[material] = true
	instance.finished.connect(instance.queue_free)
	instance.play()


func _contact_point(hit: Hit, hurtbox: Hurtbox, facing: Vector3) -> Vector3:
	var box := hurtbox.bounds()
	var center := box.get_center()
	var toward := Vector3(facing.x - center.x, 0.0, facing.z - center.z)
	var surface := Vector3(center.x, clampf(hit.origin.y, box.position.y, box.end.y), center.z)
	if toward.is_zero_approx():
		return surface
	return surface + toward.normalized() * maxf(box.size.x, box.size.z) * 0.5


func _viewer_position(hit: Hit) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return camera.global_position if camera != null else hit.origin
