extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func snapshot(filename: String) -> void:
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://art-review/ui-live-backgrounds/" + filename + ".png") == OK)

func run() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var select = load("res://scenes/ui/character_select.tscn").instantiate()
	root.add_child(select)
	for character in select.classes:
		select.character_list.get_child(select.classes.find(character)).grab_focus()
		select._show(character)
		assert(select.get_node("%CharacterDescription").text == character.description)
		assert(not select.get_node("%CharacterLore").text.is_empty())
		await snapshot("character-lore-" + character.display_name.to_lower())
	select.queue_free()
	await process_frame
	var dungeon = load("res://scenes/playground/gameplay_test.tscn").instantiate()
	dungeon.get_node("NavigationRegion3D/DungeonGenerator").map_seed = 41203
	root.add_child(dungeon)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in 240:
		await process_frame
	dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	var hints = dungeon.get_node("HUD/ControlHints")
	assert(hints.get_node("Hints").get_child_count() == 9)
	await snapshot("dungeon-control-icons")
	var vitals: Control = dungeon.get_node("HUD/VitalsHUD")
	assert(not hints.get_global_rect().intersects(vitals.get_global_rect()))
	hints.show_status("F  Open door", false)
	await snapshot("dungeon-control-context")
	dungeon.get_node("HUD/Inventory").show()
	assert(hints.get_node("Hints").get_child_count() == 4)
	await snapshot("dungeon-inventory-controls")
	dungeon.get_node("HUD/Inventory").hide()
	hints.show_status("You died", true)
	assert(hints.get_node("Hints").get_child_count() == 2)
	hints.show_status("", false)
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await snapshot("dungeon-control-icons-small")
	assert(not hints.get_global_rect().intersects(vitals.get_global_rect()))
	for item in hints.get_node("Hints").get_children():
		assert(item.get_global_rect().end.x <= 960)
		assert(item.get_global_rect().end.y <= 540)
	print("CONTROLS AND LORE: all five descriptions, inventory/death hints and two viewport sizes passed")
	dungeon.queue_free()
	await process_frame
	quit()
