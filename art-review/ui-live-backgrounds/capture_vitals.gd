extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var dungeon = load("res://scenes/playground/gameplay_test.tscn").instantiate()
	dungeon.get_node("NavigationRegion3D/DungeonGenerator").map_seed = 41203
	root.add_child(dungeon)
	for frame in 240:
		await process_frame
	dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = dungeon.get_node("HUD/VitalsHUD")
	var pools = [hud.health, hud.mana, hud.stamina]
	var bars = [hud.health_bar, hud.mana_bar, hud.stamina_bar]
	for i in 3:
		pools[i].fill()
		assert(is_equal_approx(bars[i].value, pools[i].value))
	await snapshot("dungeon-vitals-full")
	for i in 3:
		pools[i].drain(pools[i].max_value * [0.28, 0.55, 0.37][i])
		assert(is_equal_approx(bars[i].value, pools[i].value))
		assert(bars[i].get_node("../Header/Value").text == "%d / %d" % [ceili(pools[i].value), roundi(pools[i].max_value)])
	await snapshot("dungeon-vitals-minimal")
	pools[1].drain(pools[1].max_value)
	assert(hud.mana_bar.value == 0.0)
	pools[1].restore(10.0)
	assert(hud.mana_bar.value == 10.0)
	var unbound = load("res://scenes/ui/vitals_hud.tscn").instantiate()
	root.add_child(unbound)
	assert(not unbound.get_node("Health").visible)
	assert(not unbound.get_node("Mana").visible)
	assert(not unbound.get_node("Stamina").visible)
	unbound.queue_free()
	print("VITALS CHECK: full, drained, empty, restored and unbound states passed")
	dungeon.queue_free()
	await process_frame
	quit()

func snapshot(filename: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png("res://art-review/ui-live-backgrounds/" + filename + ".png")
	assert(result == OK)
