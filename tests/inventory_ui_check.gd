extends SceneTree

## UI behavior checks; uses a separate inventory and never writes the player's save.
const UI_SCRIPT := preload("res://scripts/inventory_ui.gd")
const POTION_SCENE := "res://scenes/potions/health_potion.tscn"
var failures := 0
var checks := 0

class Drinker extends Node3D:
	var drinks := 0
	var accepts_potion := true
	func drink(_potion: Potion) -> bool:
		if accepts_potion:
			drinks += 1
		return accepts_potion

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var inventory := Inventory.new()
	holder.add_child(inventory)
	var renderer := ItemIconRenderer.new()
	holder.add_child(renderer)
	var popup := AmountPopup.new()
	var drinker := Drinker.new()
	var ui := Control.new()
	ui.set_script(UI_SCRIPT)
	ui.inventory = inventory
	ui.icon_renderer = renderer
	ui.amount_popup = popup
	ui.drinker = drinker
	holder.add_child(drinker)
	# Popups come after the overlay in the actual HUD, so they draw and receive input above it.
	holder.add_child(ui)
	holder.add_child(popup)
	await process_frame
	check(not ui.visible, "Inventory must start closed")
	var potion: Potion = load("res://resources/potions/health_potion.tres")
	inventory.add_item("Health Potion", POTION_SCENE, 16, 5, potion)
	var tab := InputEventAction.new()
	tab.action = "inventory"
	tab.pressed = true
	ui._input(tab)
	await process_frame
	check(ui.visible, "Inventory opens with Tab action")
	check(ui._slots[0]._count == 5 and ui._slots[0]._icon != null, "Grid shows the original item icon and stack count")
	check(ui._panel.get_global_rect().end.x <= 1280 and ui._panel.get_global_rect().end.y <= 720, "Panel fits 1280x720")
	ui._on_slot_selected(0)
	check(ui._panel.size.x <= 320 and ui._panel.size.y <= 360, "Inventory remains a compact grid")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	ui._slots[0]._gui_input(right_click)
	check(drinker.drinks == 1 and inventory.count_at(0) == 4, "Right-click consumes exactly one potion")
	drinker.accepts_potion = false
	ui._on_slot_used(0)
	check(inventory.count_at(0) == 4, "A rejected potion use does not consume the item")
	drinker.accepts_potion = true
	ui._on_dropped_on_slot(ui._slots[0], 2)
	check(inventory.count_at(0) == 0 and inventory.count_at(2) == 4, "Drag between slots preserves the stack")
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	shift.shift_pressed = true
	Input.parse_input_event(shift)
	Input.flush_buffered_events()
	await process_frame
	ui._on_dropped_on_slot(ui._slots[2], 4)
	check(popup.visible, "Shift-drag opens the amount selector")
	popup._slider.value = 2
	popup._confirm()
	check(inventory.count_at(2) == 2 and inventory.count_at(4) == 2, "Confirmed split transfers only the chosen amount")
	var release := shift.duplicate() as InputEventKey
	release.pressed = false
	release.shift_pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame
	ui._on_drag_started(4)
	ui.hide()
	ui._finish_drag()
	check(inventory.count_at(4) == 2, "Closing during a drag does not discard an item")
	ui.show()
	ui._with_amount("Move", 2, func(amount: int) -> void: inventory.move(2, 5, amount))
	ui.hide()
	check(not popup.visible and not ui._apply_amount.is_valid(), "Closing cancels the pending amount action")
	ui.show()
	var escaped := InputEventAction.new()
	escaped.action = "ui_cancel"
	escaped.pressed = true
	ui._input(escaped)
	check(not ui.visible, "Escape closes the inventory")
	ui.show()
	ui._view.get_node("%Close").pressed.emit()
	check(not ui.visible, "Close button closes the inventory")
	ui.show()
	ui._input(tab)
	check(not ui.visible, "Tab closes the inventory even with focusable controls")
	var dropped := [0]
	inventory.thrown.connect(func(_path: String, amount: int) -> void: dropped[0] += amount)
	ui.show()
	ui._throw(4)
	check(inventory.count_at(4) == 0 and dropped[0] == 2, "Drop emits the original item stack for the world spawner")
	ui._on_slot_selected(4)
	check(ui._slots[4]._icon == null and ui._slots[4]._count == 0, "Empty slot clears the old icon and count")
	holder.queue_free()
	await process_frame
	print("Inventory UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
