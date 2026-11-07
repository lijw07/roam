extends SceneTree

## Captures the real screens. Sample loot is added only to the temporary dungeon run.
func _initialize() -> void:
	call_deferred("run")

func snapshot(name: String) -> void:
	for frame in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://art-review/ui-live-backgrounds/" + name + ".png")
	print("CAPTURE ", name, " ", result)

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.get_node("Profile").character_class = load("res://resources/characters/knight.tres")
	for name in ["main_menu", "character_select", "hub"]:
		var scene = load("res://scenes/ui/" + name + ".tscn").instantiate()
		root.add_child(scene)
		await snapshot(name)
		if name == "character_select":
			var turntable = scene.get_node("%PreviewSpace")
			var grab := InputEventMouseButton.new()
			grab.button_index = MOUSE_BUTTON_LEFT
			grab.pressed = true
			turntable._gui_input(grab)
			var drag := InputEventMouseMotion.new()
			drag.relative = Vector2(150, 0)
			turntable._input(drag)
			await snapshot("character-rotated")
			turntable.cancel_drag()
			var showcase = scene.get_node("Background").showcase
			showcase._character.rotation.y = -0.22
			for step in showcase._sequence.size():
				if String(showcase._sequence[step].animation).ends_with("Melee_Blocking"):
					showcase._step = step
					showcase._play_step()
					await snapshot("character-blocking")
					break
			showcase._weapon_index = 1
			showcase._equip_and_sequence()
			await snapshot("character-weapon-swapped")
		if name == "main_menu":
			var backdrop = scene.get_node("Background")
			var initial: Vector3 = backdrop.camera.position
			backdrop._process(12.0)
			assert(initial.distance_to(backdrop.camera.position) > 0.05)
			await snapshot("main_menu-motion")
		scene.queue_free()
		await process_frame
	var dungeon = load("res://scenes/playground/gameplay_test.tscn").instantiate()
	dungeon.get_node("NavigationRegion3D/DungeonGenerator").map_seed = 41203
	root.add_child(dungeon)
	for frame in 240:
		await process_frame
	# Freeze this capture fixture after warmup; live gameplay is not paused by the UI.
	dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	var inventory: Inventory = dungeon.get_node("Player/Inventory")
	for spec in [["res://scenes/potions/health_potion.tscn", 4], ["res://scenes/potions/mana_potion.tscn", 2], ["res://scenes/resources/coin.tscn", 12], ["res://scenes/resources/iron_nugget_medium.tscn", 3], ["res://scenes/resources/wood_log_a.tscn", 2]]:
		ItemInfo.of(spec[0]).add_to(inventory, spec[1])
	var ui = dungeon.get_node("HUD/Inventory")
	ui.show()
	ui._on_slot_selected(0)
	await snapshot("dungeon-inventory")
	ui.hide()
	await snapshot("dungeon-inventory-closed")
	dungeon.queue_free()
	await process_frame
	quit()
