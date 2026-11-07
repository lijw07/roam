extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func settle() -> void:
	for frame in 8:
		await process_frame

func capture(filename: String) -> void:
	if "--capture-ui" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/" + filename + ".png")

func run() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var settings = root.get_node("Settings")
	var original = [settings.mouse_sensitivity_x, settings.mouse_sensitivity_y, settings.music_volume]
	var was_queued: bool = settings._save_queued
	# Exercise live callbacks without writing the user's preferences.
	settings._save_queued = true
	var screen = load("res://scenes/ui/settings.tscn").instantiate()
	root.add_child(screen)
	await settle()
	check(screen.scroll.scroll_vertical == 0, "Settings initially opens at the top")
	check(screen.sensitivity_x_slider.has_focus(), "First slider has keyboard focus")
	var heading = screen.get_node("Margin/Content/Scroll/Rows/MouseHeading")
	check(heading.global_position.y >= screen.scroll.global_position.y, "Mouse heading is fully visible")
	await capture("roam-settings-controls")
	for stem in ["SensitivityX", "SensitivityY", "Music"]:
		var slider = screen.get_node("%" + stem + "Slider")
		var decrease = screen.get_node("%" + stem + "Decrease")
		var increase = screen.get_node("%" + stem + "Increase")
		slider.value = 0.5
		increase.pressed.emit()
		check(is_equal_approx(slider.value, 0.5 + slider.step), stem + " increases one step")
		decrease.pressed.emit()
		check(is_equal_approx(slider.value, 0.5), stem + " decreases one step")
		slider.value = slider.min_value
		decrease.pressed.emit()
		check(is_equal_approx(slider.value, slider.min_value), stem + " respects minimum")
		slider.value = slider.max_value
		increase.pressed.emit()
		check(is_equal_approx(slider.value, slider.max_value), stem + " respects maximum")
		var property_name = {"SensitivityX": "mouse_sensitivity_x", "SensitivityY": "mouse_sensitivity_y", "Music": "music_volume"}[stem]
		check(is_equal_approx(settings.get(property_name), slider.value), stem + " updates the live setting")
		var expected = screen._percent_text(slider.value) if stem == "Music" else screen._multiplier_text(slider.value)
		check(screen.get_node("%" + stem + "Value").text == expected, stem + " updates its displayed value")
	screen.sensitivity_x_slider.value = original[0]
	screen.sensitivity_y_slider.value = original[1]
	screen.music_slider.value = original[2]
	screen._binding_buttons[&"inventory"][1].grab_focus()
	await settle()
	check(screen.scroll.scroll_vertical > 0, "Keyboard focus still reveals lower bindings")
	screen.hide()
	screen.show()
	await settle()
	check(screen.scroll.scroll_vertical == 0, "Reopening resets a previously scrolled page")
	root.size = Vector2i(960, 640)
	root.content_scale_size = Vector2i(960, 640)
	await settle()
	await capture("roam-settings-controls-small")
	check(screen.get_node("%MusicValue").get_global_rect().end.x <= 960, "Adjustment rows fit a narrower window")
	screen.queue_free()
	await process_frame
	var pause = load("res://scenes/ui/pause_menu.tscn").instantiate()
	root.add_child(pause)
	pause.open()
	pause._open_settings()
	await settle()
	check(pause.settings_menu.scroll.scroll_vertical == 0, "Pause settings opens at the top")
	pause.settings_menu.scroll.scroll_vertical = 150
	pause._close_settings()
	pause._open_settings()
	await settle()
	check(pause.settings_menu.scroll.scroll_vertical == 0, "Pause settings reopens at the top")
	pause.close()
	pause.queue_free()
	settings.mouse_sensitivity_x = original[0]
	settings.mouse_sensitivity_y = original[1]
	settings.music_volume = original[2]
	settings._apply_music_volume()
	settings._save_queued = was_queued
	await process_frame
	print("Settings UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
