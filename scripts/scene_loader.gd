extends CanvasLayer

const COVER_LAYER := 128
const COVER_IN_TIME := 0.25
const COVER_OUT_TIME := 0.35
const PRESENTED_FRAMES := 2

var _cover := ColorRect.new()
var _fade: Tween
var _changing_scene := false
var _holds := 0
var _change_started_msec := -1


func _ready() -> void:
	layer = COVER_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover.color = Color.BLACK
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_cover_alpha(0.0)


func go_to(scene_path: String) -> void:
	if _changing_scene:
		return
	_changing_scene = true
	_change_started_msec = Time.get_ticks_msec()
	await _fade_cover_to(1.0, COVER_IN_TIME)
	await _wait_until_presented()
	var scene := await _load(scene_path)
	_log_time("%s loaded" % scene_path)
	if scene != null:
		get_tree().paused = false
		if get_tree().change_scene_to_packed(scene) == OK:
			await get_tree().scene_changed
	_changing_scene = false
	_reveal_if_released()


func cover_until(done: Signal) -> void:
	_holds += 1
	if not _changing_scene:
		_kill_fade()
		_set_cover_alpha(1.0)
	await done
	_holds -= 1
	_reveal_if_released()


func _reveal_if_released() -> void:
	if _holds > 0 or _changing_scene:
		return
	if _change_started_msec >= 0:
		_log_time("scene shown")
		_change_started_msec = -1
	_fade_cover_to(0.0, COVER_OUT_TIME)


func _load(scene_path: String) -> PackedScene:
	if ResourceLoader.load_threaded_request(scene_path) != OK:
		push_error("SceneLoader: could not start loading %s" % scene_path)
		return null
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("SceneLoader: failed to load %s" % scene_path)
		return null
	return ResourceLoader.load_threaded_get(scene_path) as PackedScene


func _wait_until_presented() -> void:
	for _frame in PRESENTED_FRAMES:
		await RenderingServer.frame_post_draw


func _fade_cover_to(alpha: float, duration: float) -> void:
	_kill_fade()
	_cover.show()
	_fade = create_tween()
	_fade.tween_property(_cover, "modulate:a", alpha, duration)
	await _fade.finished
	_set_cover_alpha(alpha)


func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()


func _set_cover_alpha(alpha: float) -> void:
	_cover.modulate.a = alpha
	_cover.visible = alpha > 0.0


func _log_time(event: String) -> void:
	if OS.is_debug_build():
		print("SceneLoader: %s after %d ms" % [event, Time.get_ticks_msec() - _change_started_msec])
