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

func run() -> void:
	var scene = load("res://scenes/ui/character_select.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var control = scene.get_node("%PreviewSpace")
	var backdrop = scene.get_node("Background")
	var actor = backdrop.showcase
	var original: Vector3 = actor._character.rotation
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	control._gui_input(click)
	check(control._dragging and actor._turning, "Press begins character grab")
	check(not actor._animation.is_playing(), "Showcase animation pauses while grabbed")
	var time_left: float = actor._remaining
	var camera_position: Vector3 = backdrop.camera.position
	actor._process(5.0)
	backdrop._process(5.0)
	check(actor._remaining == time_left, "Action timer pauses with animation")
	check(backdrop.camera.position == camera_position, "Camera drift pauses during grab")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 30)
	control._input(motion)
	check(is_equal_approx(actor._character.rotation.y, wrapf(original.y + 1.2, -PI, PI)), "Horizontal drag rotates the real background actor")
	check(actor._character.rotation.x == original.x and actor._character.rotation.z == original.z, "Vertical motion keeps character upright")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(-100, -100)
	release.pressed = false
	control._input(release)
	check(not control._dragging and not actor._turning, "Release outside the region ends the grab")
	check(actor._animation.is_playing(), "Showcase resumes on release")
	control._gui_input(click)
	control._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not control._dragging and not actor._turning, "Window focus loss safely releases grab")
	control._gui_input(click)
	scene._show(scene.classes[1])
	check(not control._dragging and not actor._turning, "Changing character safely releases grab")
	check(is_equal_approx(actor._character.rotation.y, -0.22), "New character starts facing forward")
	control._gui_input(click)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	control._input(cancel)
	check(not control._dragging, "Escape releases the grab")
	control._gui_input(click)
	scene.queue_free()
	await process_frame
	check(Input.get_current_cursor_shape() != Input.CURSOR_DRAG, "Leaving the screen restores the cursor")
	print("Character turntable: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
