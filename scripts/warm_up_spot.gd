class_name WarmUpSpot
extends RefCounted

const DEPTH_BELOW_FLOOR := 3.0
const MIN_DOWNWARD_SLOPE := 0.1


static func under_floor(viewer: Node, feet: Vector3) -> Vector3:
	var camera := viewer.get_viewport().get_camera_3d()
	var sight := (feet - camera.global_position).normalized()
	return feet + sight * DEPTH_BELOW_FLOOR / maxf(-sight.y, MIN_DOWNWARD_SLOPE)
