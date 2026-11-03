extends HurtboxWatcher

@export var effect: PackedScene


func _on_hit_taken(hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	if damage > 0.0 and hurtbox.get_parent() is Enemy:
		_spawn_at(hurtbox.closest_point(hit.origin), hurtbox.outward_toward(hit.origin))


func _spawn_at(point: Vector3, outward: Vector3) -> void:
	var impact: Node3D = effect.instantiate()
	add_child(impact)
	impact.global_transform = Transform3D(Basis.looking_at(-outward), point)
