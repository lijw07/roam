class_name CameraBoom
extends SpringArm3D

const PROBE_RADIUS := 0.25


func _ready() -> void:
	if shape == null:
		var probe := SphereShape3D.new()
		probe.radius = PROBE_RADIUS
		shape = probe


func _physics_process(_delta: float) -> void:
	clear_excluded_objects()
	for hurtbox: Hurtbox in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var character := hurtbox.get_parent() as CharacterBody3D
		if character != null:
			add_excluded_object(character.get_rid())
