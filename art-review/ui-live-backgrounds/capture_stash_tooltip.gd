extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func snapshot(filename: String) -> void:
	for frame in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://art-review/ui-live-backgrounds/" + filename + ".png") == OK)

func run() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var profile = root.get_node("Profile")
	if profile.character_class == null:
		profile.character_class = load("res://resources/characters/knight.tres")
	var hub = load("res://scenes/ui/hub.tscn").instantiate()
	root.add_child(hub)
	for frame in 20:
		await process_frame
	var captured := {}
	for i in profile.stash.slot_count():
		var slot = profile.stash.slots[i]
		if slot.count == 0:
			continue
		var info = ItemInfo.of(slot.scene_path)
		var kind = "potion" if info.potion != null else ("weapon" if info.is_equipment() else "material")
		if captured.has(kind):
			continue
		hub.stash_grid._slots[i].grab_focus()
		await snapshot("stash-tooltip-" + kind)
		assert(hub.item_tooltip.visible)
		assert(hub.item_tooltip._title.text == slot.item_name)
		assert(hub.item_tooltip._icon.texture != null)
		assert(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(hub.item_tooltip.get_global_rect()))
		captured[kind] = true
	var edge_anchor := Control.new()
	edge_anchor.position = Vector2(1200, 660)
	edge_anchor.size = Vector2(64, 48)
	hub.add_child(edge_anchor)
	hub.item_tooltip.show_for(profile.stash.slots[0], edge_anchor)
	await snapshot("stash-tooltip-edge")
	assert(hub.item_tooltip.global_position.x < edge_anchor.global_position.x)
	assert(hub.item_tooltip.get_global_rect().end.y <= 708)
	assert(hub.item_tooltip.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	hub.enter_dungeon_button.grab_focus()
	await process_frame
	assert(not hub.item_tooltip.visible)
	print("TOOLTIP: item details/icons, screen-edge placement and focus dismissal verified; captured ", captured.keys())
	hub.queue_free()
	await process_frame
	quit()
