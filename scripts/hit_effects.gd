extends HurtboxWatcher

const HIT_EFFECT := preload(
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_01.tscn"
)
const BLOCK_EFFECT := preload(
	"res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_02.tscn"
)
const EFFECT_SPACING_MS := 300
const GLOW_PATH := ^"Glow"
const SURFACE_DEPTH := 0.25

@export var player: Node3D
@export var heavy_damage := 30.0
@export var effect_scale := 1.0
@export var heavy_scale := 1.3
@export var effect_emission := 1.6
@export var effect_speed := 1.25

var _last_effect_ms: Dictionary[int, int] = {}


func _ready() -> void:
	super()
	_warm_up_effects()


func _on_hit_taken(hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	if damage > 0.0:
		_play_impact(HIT_EFFECT, hit, hurtbox, heavy_scale if damage >= heavy_damage else effect_scale)


func _on_blocked(hit: Hit, hurtbox: Hurtbox) -> void:
	_play_impact(BLOCK_EFFECT, hit, hurtbox, effect_scale)


func _play_impact(effect: PackedScene, hit: Hit, hurtbox: Hurtbox, size: float) -> void:
	if _played_recently_on(hurtbox):
		return
	_last_effect_ms[hurtbox.get_instance_id()] = Time.get_ticks_msec()
	var facing := hit.origin if hurtbox.get_parent() == player else _viewer_position(hit)
	_spawn(effect, _contact_point(hit, hurtbox, facing), size)


func _played_recently_on(hurtbox: Hurtbox) -> bool:
	var last: int = _last_effect_ms.get(hurtbox.get_instance_id(), -EFFECT_SPACING_MS)
	return Time.get_ticks_msec() - last < EFFECT_SPACING_MS


func _warm_up_effects() -> void:
	await get_tree().process_frame
	if player == null:
		return
	for effect: PackedScene in [HIT_EFFECT, BLOCK_EFFECT]:
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
	instance.get_node(GLOW_PATH).hide()
	for particles in instance.particles:
		particles.interpolate = false
	instance.finished.connect(instance.queue_free)
	_play_once_placed(instance)


func _play_once_placed(instance: VFXImpactBB) -> void:
	await get_tree().process_frame
	if is_instance_valid(instance):
		instance.play()


func _contact_point(hit: Hit, hurtbox: Hurtbox, facing: Vector3) -> Vector3:
	var box := hurtbox.bounds()
	var center := box.get_center()
	var toward := Vector3(facing.x - center.x, 0.0, facing.z - center.z)
	var surface := Vector3(center.x, clampf(hit.origin.y, box.position.y, box.end.y), center.z)
	if toward.is_zero_approx():
		return surface
	return surface + toward.normalized() * maxf(box.size.x, box.size.z) * SURFACE_DEPTH


func _viewer_position(hit: Hit) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return camera.global_position if camera != null else hit.origin
