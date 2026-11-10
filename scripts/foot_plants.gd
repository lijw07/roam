class_name FootPlants
extends RefCounted

enum Foot { SETTLING, PLANTED, LIFTED }

const FOOT_BONES: Array[StringName] = [&"foot.l", &"foot.r"]
const LIFT_HEIGHT := 0.2
const PLANT_HEIGHT := 0.17
const COOLDOWN_MSEC := 120

var _skeleton: Skeleton3D
var _bones: Array[int] = []
var _feet: Array[Foot] = []
var _last_frame := -2
var _last_step_msec := -COOLDOWN_MSEC


func _init(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	for bone_name in FOOT_BONES:
		_bones.append(skeleton.find_bone(bone_name))
		_feet.append(Foot.SETTLING)


func planted_this_frame(floor_height: float) -> Array[Vector3]:
	_settle_after_gap()
	var plants: Array[Vector3] = []
	for index in _bones.size():
		var foot := _skeleton.global_transform * _skeleton.get_bone_global_pose(_bones[index]).origin
		if _advance(index, (foot.y - floor_height) / _skeleton.global_basis.get_scale().y):
			plants.append(foot)
	return _outside_cooldown(plants)


func _settle_after_gap() -> void:
	var frame := Engine.get_physics_frames()
	if frame != _last_frame + 1:
		_feet.fill(Foot.SETTLING)
	_last_frame = frame


func _advance(index: int, height: float) -> bool:
	match _feet[index]:
		Foot.SETTLING:
			if height < PLANT_HEIGHT:
				_feet[index] = Foot.PLANTED
		Foot.PLANTED:
			if height > LIFT_HEIGHT:
				_feet[index] = Foot.LIFTED
		Foot.LIFTED:
			if height < PLANT_HEIGHT:
				_feet[index] = Foot.PLANTED
				return true
	return false


func _outside_cooldown(plants: Array[Vector3]) -> Array[Vector3]:
	var now := Time.get_ticks_msec()
	if plants.is_empty() or now - _last_step_msec < COOLDOWN_MSEC:
		return []
	_last_step_msec = now
	var first: Array[Vector3] = [plants[0]]
	return first
