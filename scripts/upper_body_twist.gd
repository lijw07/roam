extends SkeletonModifier3D
class_name UpperBodyTwist

const BONE_SHARES := {&"spine": 0.35, &"chest": 0.35, &"head": 0.3}

var twist := 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or is_zero_approx(twist):
		return
	for bone_name: StringName in BONE_SHARES:
		_rotate_bone(skeleton, skeleton.find_bone(bone_name), twist * BONE_SHARES[bone_name])


func _rotate_bone(skeleton: Skeleton3D, bone: int, angle: float) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_rotation := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var spin := Quaternion(Vector3.UP, angle)
	var local := parent_rotation.inverse() * spin * parent_rotation * skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, local)
