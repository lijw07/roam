class_name CameraBoom
extends SpringArm3D

const PROBE_RADIUS := 0.25
const IGNORED_GROUP := &"camera_ignored"


func _ready() -> void:
	if shape == null:
		var probe := SphereShape3D.new()
		probe.radius = PROBE_RADIUS
		shape = probe


func _physics_process(_delta: float) -> void:
	clear_excluded_objects()
	for hurtbox: Hurtbox in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		if is_instance_valid(hurtbox.body):
			add_excluded_object(hurtbox.body.get_rid())
	for ignored: CollisionObject3D in get_tree().get_nodes_in_group(IGNORED_GROUP):
		add_excluded_object(ignored.get_rid())
