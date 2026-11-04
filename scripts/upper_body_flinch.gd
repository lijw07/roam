class_name UpperBodyFlinch
extends SkeletonModifier3D

const BONES: Array[StringName] = [
	&"spine", &"chest", &"head",
	&"upperarm.l", &"lowerarm.l", &"wrist.l", &"hand.l",
	&"upperarm.r", &"lowerarm.r", &"wrist.r", &"hand.r",
]
const FADE_IN := 0.08
const FADE_OUT := 0.2

var _animation: Animation = null
var _time := 0.0
var _tracks: Dictionary[int, int] = {}


func play(animation: Animation, from := 0.0) -> void:
	_animation = animation
	_time = from
	_tracks = _bone_tracks(animation)


func stop() -> void:
	_animation = null


func _process(delta: float) -> void:
	if _animation == null:
		return
	_time += delta
	if _time >= _animation.length:
		stop()


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _animation == null:
		return
	var weight := _weight()
	for bone: int in _tracks:
		var offset := _offset_at(_tracks[bone], _time)
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion.IDENTITY.slerp(offset, weight))


func _offset_at(track: int, time: float) -> Quaternion:
	return _animation.rotation_track_interpolate(track, 0.0).inverse() * _animation.rotation_track_interpolate(track, time)


func _weight() -> float:
	return clampf(minf(_time / FADE_IN, (_animation.length - _time) / FADE_OUT), 0.0, 1.0)


func _bone_tracks(animation: Animation) -> Dictionary[int, int]:
	var tracks: Dictionary[int, int] = {}
	var skeleton := get_skeleton()
	for track in animation.get_track_count():
		var bone_name := StringName(animation.track_get_path(track).get_concatenated_subnames())
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D and bone_name in BONES:
			tracks[skeleton.find_bone(bone_name)] = track
	return tracks
