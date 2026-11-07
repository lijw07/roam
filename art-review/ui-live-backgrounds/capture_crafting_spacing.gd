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
	var profile = root.get_node("Profile")
	if profile.character_class == null:
		profile.character_class = load("res://resources/characters/barbarian.tres")
	var hub = load("res://scenes/ui/hub.tscn").instantiate()
	root.add_child(hub)
	for frame in 10:
		await process_frame
	var tabs = hub.get_node("Margin/Content/Body/Shop/Tabs")
	var scroll = tabs.get_node("Crafting")
	var list = scroll.get_node("Inset/List")
	list.get_child(0).grab_focus()
	list.get_child(0).pressed.emit()
	await snapshot("crafting-aligned-details")
	assert(list._entries[0].details.visible)
	assert(scroll.get_v_scroll_bar().global_position.x - list.get_global_rect().end.x >= 10)
	scroll.scroll_vertical = 160
	await snapshot("crafting-scroll-spacing")
	assert(scroll.scroll_vertical > 0)
	tabs.current_tab = 1
	await snapshot("shop-scroll-spacing")
	print("CRAFTING LAYOUT: recipe expansion, inset and scrolling verified")
	hub.queue_free()
	await process_frame
	quit()
