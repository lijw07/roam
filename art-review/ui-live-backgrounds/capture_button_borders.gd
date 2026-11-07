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
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await snapshot("main-menu-bordered-buttons")
	menu.queue_free()
	await process_frame
	var settings = load("res://scenes/ui/settings.tscn").instantiate()
	root.add_child(settings)
	await snapshot("settings-bordered-buttons")
	settings._binding_buttons[&"move_right"][0].grab_focus()
	await snapshot("settings-bordered-focus")
	settings.queue_free()
	await process_frame
	var profile = root.get_node("Profile")
	if profile.character_class == null:
		profile.character_class = load("res://resources/characters/knight.tres")
	var hub = load("res://scenes/ui/hub.tscn").instantiate()
	root.add_child(hub)
	await snapshot("hub-bordered-buttons")
	hub.get_node("Margin/Content/Body/Shop/Tabs").current_tab = 1
	await snapshot("shop-bordered-offers")
	hub.queue_free()
	await process_frame
	quit()
