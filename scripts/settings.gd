extends Node

const SAVE_PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const DEFAULT_SENSITIVITY := 1.0
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0
const ACTION_NAMES: Dictionary[StringName, String] = {
	&"move_forward": "Move forward",
	&"move_back": "Move back",
	&"move_left": "Move left",
	&"move_right": "Move right",
	&"sprint": "Sprint",
	&"jump": "Jump",
	&"attack": "Attack",
	&"secondary": "Block / secondary",
	&"interact": "Interact",
	&"inventory": "Inventory",
}
const MOUSE_BUTTON_NAMES: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "Left Mouse",
	MOUSE_BUTTON_RIGHT: "Right Mouse",
	MOUSE_BUTTON_MIDDLE: "Middle Mouse",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

var mouse_sensitivity_x := DEFAULT_SENSITIVITY
var mouse_sensitivity_y := DEFAULT_SENSITIVITY
var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME

var _default_events: Dictionary[StringName, Array] = {}
var _save_queued := false


func _ready() -> void:
	for action in ACTION_NAMES:
		_default_events[action] = InputMap.action_get_events(action)
	_load()
	_apply_music_volume()
	_apply_sfx_volume()


func set_mouse_sensitivity_x(value: float) -> void:
	mouse_sensitivity_x = value
	_queue_save()


func set_mouse_sensitivity_y(value: float) -> void:
	mouse_sensitivity_y = value
	_queue_save()


func set_music_volume(value: float) -> void:
	music_volume = value
	_apply_music_volume()
	_queue_save()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_sfx_volume()
	_queue_save()


func events_of(action: StringName) -> Array[InputEvent]:
	return InputMap.action_get_events(action)


func bind(action: StringName, slot: int, event: InputEvent) -> void:
	for other in ACTION_NAMES:
		if other != action and InputMap.action_has_event(other, event):
			InputMap.action_erase_event(other, event)
	var events := events_of(action)
	if slot < events.size():
		events[slot] = event
	else:
		events.append(event)
	_set_events(action, events)
	_queue_save()


func reset_bindings() -> void:
	for action in ACTION_NAMES:
		_set_events(action, _default_events[action])
	_queue_save()


func capture(event: InputEvent) -> InputEvent:
	return _event_from(_event_data(event))


func describe(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var button_index: int = event.button_index
		return MOUSE_BUTTON_NAMES.get(button_index, "Mouse %d" % button_index)
	return (event as InputEventKey).as_text_physical_keycode()


func save() -> void:
	_save_queued = false
	var config := ConfigFile.new()
	config.set_value("mouse", "sensitivity_x", mouse_sensitivity_x)
	config.set_value("mouse", "sensitivity_y", mouse_sensitivity_y)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	for action in ACTION_NAMES:
		config.set_value("bindings", action, events_of(action).map(_event_data))
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	mouse_sensitivity_x = config.get_value("mouse", "sensitivity_x", DEFAULT_SENSITIVITY)
	mouse_sensitivity_y = config.get_value("mouse", "sensitivity_y", DEFAULT_SENSITIVITY)
	music_volume = config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
	sfx_volume = config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	for action in ACTION_NAMES:
		if config.has_section_key("bindings", action):
			_set_events(action, config.get_value("bindings", action).map(_event_from))


func _set_events(action: StringName, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


func _event_data(event: InputEvent) -> Dictionary:
	if event is InputEventMouseButton:
		return {"mouse_button": event.button_index}
	return {"physical_keycode": (event as InputEventKey).physical_keycode}


func _event_from(data: Dictionary) -> InputEvent:
	if data.has("mouse_button"):
		var click := InputEventMouseButton.new()
		click.button_index = data["mouse_button"]
		return click
	var key := InputEventKey.new()
	key.physical_keycode = data.get("physical_keycode", KEY_NONE)
	return key


func _apply_music_volume() -> void:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(music_volume))


func _apply_sfx_volume() -> void:
	var bus := AudioServer.get_bus_index(SFX_BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(sfx_volume))


func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	save.call_deferred()
