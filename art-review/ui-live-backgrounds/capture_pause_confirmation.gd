extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func snapshot(filename: String) -> void:
	for frame in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://art-review/ui-live-backgrounds/" + filename + ".png") == OK)

func run() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var dungeon = load("res://scenes/playground/gameplay_test.tscn").instantiate()
	dungeon.get_node("NavigationRegion3D/DungeonGenerator").map_seed = 41203
	root.add_child(dungeon)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in 240:
		await process_frame
	var pause = dungeon.get_node("HUD/PauseMenu")
	pause.open()
	await snapshot("pause-menu-minimal")
	pause.camp_button.pressed.emit()
	await snapshot("pause-leave-confirmation")
	assert(paused and pause.leave_confirmation.visible and not pause.menu.visible)
	assert(pause.cancel_leave_button.has_focus())
	pause.cancel_leave_button.pressed.emit()
	assert(paused and pause.menu.visible and not pause.leave_confirmation.visible)
	assert(pause.camp_button.has_focus())
	pause.camp_button.pressed.emit()
	var escape := InputEventAction.new()
	escape.action = &"pause"
	escape.pressed = true
	pause._unhandled_input(escape)
	assert(paused and pause.menu.visible and not pause.leave_confirmation.visible)
	pause.settings_button.pressed.emit()
	assert(pause.settings_menu.visible)
	pause._unhandled_input(escape)
	assert(paused and not pause.settings_menu.visible and pause.menu.visible)
	pause.close()
	assert(not paused and not pause.visible)
	pause.open()
	assert(pause.menu.visible and not pause.leave_confirmation.visible)
	pause.close()
	print("PAUSE UI: confirmation, Cancel, Escape, focus, settings and resume states passed; no run ended")
	dungeon.queue_free()
	await process_frame
	quit()
