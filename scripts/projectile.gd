extends Node3D

@export var speed := 0.0
@export var lifetime := 2.0

var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	if speed > 0.0:
		global_position += global_transform.basis.z * speed * delta
	if _age >= lifetime:
		queue_free()
