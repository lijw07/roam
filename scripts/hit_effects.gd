extends HurtboxWatcher

const EFFECTS: Array[PackedScene] = [
	preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_01.tscn"),
	preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_02.tscn"),
]

@export var player: Node3D
@export var heavy_damage := 30.0
@export var heavy_scale := 1.4


func _ready() -> void:
	super()
	_warm_up_effects()


func _on_hit_taken(hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	if damage > 0.0 and hurtbox.get_parent() is Enemy:
		var size := heavy_scale if damage >= heavy_damage else 1.0
		_spawn(EFFECTS.pick_random(), _contact_point(hit, hurtbox), size)


func _warm_up_effects() -> void:
	await get_tree().process_frame
	if player == null:
		return
	for effect in EFFECTS:
		_spawn(effect, WarmUpSpot.under_floor(self, player.global_position), 1.0)


func _spawn(effect: PackedScene, at: Vector3, size: float) -> void:
	var instance: VFXImpactBB = effect.instantiate()
	instance.one_shot = true
	instance.light.hide()
	add_child(instance)
	instance.global_position = at
	instance.scale = Vector3.ONE * size
	instance.finished.connect(instance.queue_free)
	instance.play()


func _contact_point(hit: Hit, hurtbox: Hurtbox) -> Vector3:
	var box := hurtbox.bounds()
	var center := box.get_center()
	var toward := Vector3(hit.origin.x - center.x, 0.0, hit.origin.z - center.z)
	if toward.is_zero_approx() and hit.attacker != null:
		toward = Vector3(hit.attacker.global_position.x - center.x, 0.0, hit.attacker.global_position.z - center.z)
	var height := clampf(hit.origin.y, box.position.y, box.end.y)
	var surface := Vector3(center.x, height, center.z)
	if toward.is_zero_approx():
		return surface
	return surface + toward.normalized() * maxf(box.size.x, box.size.z) * 0.5
