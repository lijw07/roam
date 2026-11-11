extends Node

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SURFACE_STEPS := {
	"stone": [preload("res://assets/audio/sfx/surfaces/stone01.ogg")],
	"wood": [
		preload("res://assets/audio/sfx/surfaces/wood01.ogg"),
		preload("res://assets/audio/sfx/surfaces/wood02.ogg"),
		preload("res://assets/audio/sfx/surfaces/wood03.ogg"),
	],
	"leaves": [
		preload("res://assets/audio/sfx/surfaces/leaves01.ogg"),
		preload("res://assets/audio/sfx/surfaces/leaves02.ogg"),
	],
	"gravel": [preload("res://assets/audio/sfx/surfaces/gravel.ogg")],
	"mud": [preload("res://assets/audio/sfx/surfaces/mud02.ogg")],
}
const DEATH_SOUNDS := [
	preload("res://assets/audio/samples/pain/death_01.ogg"),
	preload("res://assets/audio/samples/pain/death_02.ogg"),
	preload("res://assets/audio/samples/pain/death_03.ogg"),
	preload("res://assets/audio/samples/pain/death_04.ogg"),
	preload("res://assets/audio/samples/pain/death_05.ogg"),
	preload("res://assets/audio/samples/pain/death_06.ogg"),
]
const SWORD_SWINGS := [
	preload("res://assets/audio/samples/medieval/sword_swing_01.wav"),
	preload("res://assets/audio/samples/medieval/sword_swing_02.wav"),
	preload("res://assets/audio/samples/medieval/sword_swing_03.wav"),
]
const SWING_PEAKS := {
	"sword_swing": 0.14,
	"swing_light": 0.13,
	"swing_heavy": 0.13,
	"axe_swing": 0.13,
	"blunt_swing": 0.13,
	"fist_swing": 0.01,
	"magic_cast": 1.26,
	"bow_draw": 0.63,
}
const MIN_PLAYBACK_SPEED := 0.01
const UNARMED_ANIMATION_TAG := "Unarmed"
const EFFECTS := {
	"swing_light": preload("res://assets/audio/samples/mixkit/1487.mp3"),
	"swing_heavy": preload("res://assets/audio/samples/mixkit/1485.mp3"),
	"bow_draw": preload("res://assets/audio/samples/medieval/bow_draw.wav"),
	"sword_swing": preload("res://assets/audio/samples/medieval/sword_swing_01.wav"),
	"axe_swing": preload("res://assets/audio/samples/mixkit/1485.mp3"),
	"blunt_swing": preload("res://assets/audio/samples/mixkit/1485.mp3"),
	"fist_swing": preload("res://assets/audio/sfx/fist_swing.wav"),
	"jump_takeoff": preload("res://assets/audio/sfx/jump_takeoff.wav"),
	"landing": preload("res://assets/audio/sfx/surfaces/stone01.ogg"),
	"magic_cast": preload("res://assets/audio/samples/mixkit/2345.mp3"),
	"projectile_launch": preload("res://assets/audio/samples/mixkit/1491.mp3"),
	"fireball_launch": preload("res://assets/audio/samples/magic/fireball_launch.wav"),
	"impact_flesh": preload("res://assets/audio/sfx/impact_flesh.wav"),
	"impact_heavy": preload("res://assets/audio/samples/mixkit/2765.mp3"),
	"impact_wood": preload("res://assets/audio/samples/mixkit/3141.mp3"),
	"impact_stone": preload("res://assets/audio/samples/rock_break.ogg"),
	"impact_metal": preload("res://assets/audio/samples/mixkit/833.mp3"),
	"block_metal": preload("res://assets/audio/sfx/block_metal.wav"),
	"shield_raise": preload("res://assets/audio/sfx/shield_raise.wav"),
	"projectile_impact": preload("res://assets/audio/samples/mixkit/2765.mp3"),
	"footstep_walk": preload("res://assets/audio/sfx/surfaces/stone01.ogg"),
	"footstep_run": preload("res://assets/audio/sfx/surfaces/gravel.ogg"),
	"pickup": preload("res://assets/audio/samples/stone_rock_or_wood_moved.mp3"),
	"item_drop": preload("res://assets/audio/samples/stone_rock_or_wood_moved.mp3"),
	"item_throw": preload("res://assets/audio/samples/mixkit/1487.mp3"),
	"coin_drop": preload("res://assets/audio/samples/mixkit/1993.mp3"),
	"coin_pickup": preload("res://assets/audio/samples/mixkit/1939.mp3"),
	"potion_pickup": preload("res://assets/audio/samples/stone_rock_or_wood_moved.mp3"),
	"potion_drink": preload("res://assets/audio/samples/mixkit/2828.mp3"),
	"loot_drop": preload("res://assets/audio/samples/mixkit/1989.mp3"),
	"equipment_equip": preload("res://assets/audio/samples/mixkit/833.mp3"),
	"equipment_unequip": preload("res://assets/audio/samples/mixkit/833.mp3"),
	"ui_confirm": preload("res://assets/audio/samples/mixkit/1109.mp3"),
	"ui_back": preload("res://assets/audio/samples/mixkit/1109.mp3"),
	"ui_hover": preload("res://assets/audio/sfx/ui_hover.wav"),
	"ui_error": preload("res://assets/audio/samples/stone_rock_or_wood_moved.mp3"),
	"purchase": preload("res://assets/audio/samples/mixkit/1993.mp3"),
	"breakable_crack": preload("res://assets/audio/samples/mixkit/3141.mp3"),
	"death_sting": preload("res://assets/audio/samples/pain/death_01.ogg"),
	"door_open": preload("res://assets/audio/samples/mixkit/195.mp3"),
	"door_close": preload("res://assets/audio/samples/mixkit/189.mp3"),
}
const HUB_MUSIC_START_DELAY := 1.5
const MENU_MUSIC: AudioStream = preload("res://assets/audio/music/menu_calm.wav")
const DUNGEON_AMBIENCE: AudioStream = preload("res://assets/audio/music/dungeon_ambience.ogg")
const SURFACE_SOUNDS := {
	"wood": "impact_wood",
	"stone": "impact_stone",
	"metal": "impact_metal",
}

var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _music_tween: Tween
var _music_scene := ""
var _ui_hover_time := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_stream_loop(DUNGEON_AMBIENCE, true)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.name = "BackgroundMusic"
	add_child(_music_player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = MUSIC_BUS
	_ambience_player.name = "BackgroundAmbience"
	_ambience_player.volume_db = -20.0
	add_child(_ambience_player)
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_on_scene_changed")


func play(sound: String, at: Vector3 = Vector3.ZERO, pitch_range := Vector2(0.94, 1.06), volume_db := -5.0, from := 0.0) -> AudioStreamPlayer3D:
	if not EFFECTS.has(sound):
		return null
	return play_stream(EFFECTS[sound], at, pitch_range, volume_db, from)


func play_stream(stream: AudioStream, at: Vector3 = Vector3.ZERO, pitch_range := Vector2(0.94, 1.06), volume_db := -5.0, from := 0.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	player.volume_db = volume_db
	player.max_distance = 24.0
	player.unit_size = 5.0
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play(from)
	return player


func play_swing(source: Node3D, weapon: Node3D = null, enemy_attack := false, animation: StringName = &"", from := 0.0) -> void:
	var sound := _swing_sound(source, weapon, enemy_attack, animation)
	if sound == "sword_swing":
		play_stream(SWORD_SWINGS[randi_range(0, SWORD_SWINGS.size() - 1)], source.global_position, Vector2(0.94, 1.06), -7.0, from)
	else:
		play(sound, source.global_position, Vector2(0.9, 1.1), -7.0, from)


func play_projectile_launch(at: Vector3, weapon: Node3D = null) -> void:
	if is_fireball_weapon(weapon):
		play("fireball_launch", at, Vector2(0.94, 1.06), -7.0)
	else:
		play("projectile_launch", at, Vector2(0.94, 1.06), -5.0)


func is_fireball_weapon(weapon: Node3D) -> bool:
	if weapon == null:
		return false
	var identity := (weapon.scene_file_path + "/" + str(weapon.name)).to_lower()
	return "staff" in identity or "wand" in identity


func swing_lateness(source: Node3D, weapon: Node3D, enemy_attack: bool, animation: StringName, strike_time: float, animation_player: AnimationPlayer) -> float:
	if strike_time < 0.0 or strike_time == INF:
		return 0.0
	var speed := maxf(animation_player.get_playing_speed(), MIN_PLAYBACK_SPEED)
	var until_strike := (strike_time - animation_player.current_animation_position) / speed
	return SWING_PEAKS.get(_swing_sound(source, weapon, enemy_attack, animation), 0.0) - until_strike


func _swing_sound(source: Node3D, weapon: Node3D, enemy_attack: bool, animation: StringName) -> String:
	var sound := "fist_swing"
	if UNARMED_ANIMATION_TAG in String(animation):
		return sound
	if is_fireball_weapon(weapon):
		return ""
	var identity := ""
	if weapon != null:
		identity = (weapon.scene_file_path + "/" + str(weapon.name)).to_lower()
		if weapon.has_method("is_ranged") and weapon.call("is_ranged"):
			sound = "bow_draw"
		elif "sword" in identity or "dagger" in identity:
			sound = "sword_swing"
		elif "axe" in identity or "halberd" in identity or "spear" in identity:
			sound = "axe_swing"
		elif "hammer" in identity or "mace" in identity:
			sound = "blunt_swing"
		else:
			sound = "swing_heavy" if float(weapon.get("damage")) >= 25.0 else "swing_light"
	elif enemy_attack and source.has_method("is_ranged") and source.call("is_ranged"):
		sound = "magic_cast"
	return sound


func play_surface_impact(surface: String, at: Vector3, weight := 1.0) -> void:
	var sound: String = SURFACE_SOUNDS.get(surface, "impact_stone")
	play(sound, at, Vector2(0.9, 1.08), -4.5 - (1.0 - clampf(weight, 0.0, 1.0)) * 4.0)


func surface_for(collider: Object) -> String:
	return surfaces_for(collider)[0]


func surfaces_for(collider: Object) -> Array[String]:
	var node := collider as Node
	if node == null:
		return ["stone"]
	var found: Array[String] = []
	var cursor: Node = node
	while cursor != null:
		if cursor.has_meta("audio_surface"):
			var explicit := str(cursor.get_meta("audio_surface")).to_lower()
			if SURFACE_SOUNDS.has(explicit) and explicit not in found:
				found.append(explicit)
		for surface in SURFACE_SOUNDS:
			if cursor.is_in_group("audio_surface_" + surface) and surface not in found:
				found.append(surface)
		var description := str(cursor.name)
		if cursor is Node3D:
			description += " " + (cursor as Node3D).scene_file_path
		_append_surface_from_text(description, found)
		if cursor is Node3D and not (cursor as Node3D).scene_file_path.is_empty():
			_collect_material_surfaces(cursor, found)
			break
		cursor = cursor.get_parent()
	if found.is_empty():
		found.append("stone")
	return found


func play_footstep_at(at: Vector3, running: bool, actor: Node = null) -> void:
	var surface := _footstep_surface_at(at, actor)
	if surface == "metal":
		surface = "stone"
	var variants: Array = SURFACE_STEPS.get(surface, SURFACE_STEPS["stone"])
	var stream: AudioStream = variants[randi_range(0, variants.size() - 1)]
	play_stream(stream, at, Vector2(0.94, 1.06) if not running else Vector2(0.98, 1.1), -9.5 if not running else -7.5)


func play_takeoff_at(at: Vector3, actor: Node = null) -> void:
	var surface := _footstep_surface_at(at, actor)
	if surface == "metal":
		surface = "stone"
	var variants: Array = SURFACE_STEPS.get(surface, SURFACE_STEPS["stone"])
	var stream: AudioStream = variants[randi_range(0, variants.size() - 1)]
	play_stream(stream, at, Vector2(0.88, 0.98), -14.0)


func play_landing_at(at: Vector3, actor: Node = null, volume_db := -4.5) -> void:
	var surface := _footstep_surface_at(at, actor)
	if surface == "metal":
		surface = "stone"
	var variants: Array = SURFACE_STEPS.get(surface, SURFACE_STEPS["stone"])
	var stream: AudioStream = variants[randi_range(0, variants.size() - 1)]
	play_stream(stream, at, Vector2(0.78, 0.9), volume_db)


func play_death(at: Vector3, is_player := false) -> void:
	var stream: AudioStream = DEATH_SOUNDS[randi_range(0, DEATH_SOUNDS.size() - 1)]
	var pitch := Vector2(0.9, 0.98) if is_player else Vector2(0.96, 1.04)
	play_stream(stream, at, pitch, -3.5 if is_player else -5.0)


func _footstep_surface_at(at: Vector3, actor: Node) -> String:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.35, at + Vector3.DOWN * 0.8)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if actor is CollisionObject3D:
		query.exclude.append((actor as CollisionObject3D).get_rid())
	if actor != null:
		for body: CollisionObject3D in actor.find_children("*", "CollisionObject3D", true, false):
			query.exclude.append(body.get_rid())
	var result := get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return "stone"
	var collider := result.get("collider") as Node
	if collider == null:
		return "stone"
	var cursor: Node = collider
	while cursor != null:
		if cursor.has_meta("audio_surface"):
			var explicit := str(cursor.get_meta("audio_surface")).to_lower()
			if SURFACE_STEPS.has(explicit):
				return explicit
		for surface in SURFACE_STEPS:
			if cursor.is_in_group("audio_surface_" + surface):
				return surface
		var label := str(cursor.name)
		if cursor is Node3D:
			label += " " + (cursor as Node3D).scene_file_path
		if cursor is MeshInstance3D:
			var mesh_instance := cursor as MeshInstance3D
			if mesh_instance.mesh != null:
				for surface_index in mesh_instance.mesh.get_surface_count():
					var material := mesh_instance.get_active_material(surface_index)
					if material != null:
						label += " " + material.resource_name + " " + material.resource_path
		var material_surface := _footstep_surface_from_text(label)
		if not material_surface.is_empty():
			return material_surface
		cursor = cursor.get_parent()
	var known := surfaces_for(collider)
	if known[0] == "wood":
		return "wood"
	return "stone"


func _footstep_surface_from_text(value: String) -> String:
	var label := value.to_lower()
	if "gravel" in label or "pebble" in label:
		return "gravel"
	if "mud" in label or "dirt" in label or "soil" in label:
		return "mud"
	if "leaf" in label or "grass" in label or "foliage" in label:
		return "leaves"
	if "wood" in label or "plank" in label or "timber" in label:
		return "wood"
	if "stone" in label or "rock" in label or "floor" in label or "ground" in label:
		return "stone"
	return ""


func play_item_landing(item_name: String, is_potion: bool, at: Vector3) -> void:
	var lowered_name := item_name.to_lower()
	if "coin" in lowered_name:
		play("coin_drop", at, Vector2(0.9, 1.12), -7.0)
	elif is_potion:
		play("potion_pickup", at, Vector2(0.92, 1.08), -8.0)
	else:
		var surfaces: Array[String] = []
		_append_surface_from_text(lowered_name, surfaces)
		if surfaces.is_empty():
			play("item_drop", at, Vector2(0.94, 1.06), -9.0)
		else:
			play_surface_impact(surfaces[0], at, 0.35)


func play_item_pickup(item_name: String, is_potion: bool, at: Vector3, count := 1) -> void:
	var lowered_name := item_name.to_lower()
	var pitch := Vector2(0.95, 1.05)
	if "coin" in lowered_name:
		var bonus := minf(float(count) * 0.003, 0.06)
		play("coin_pickup", at, Vector2(0.96 + bonus, 1.04 + bonus), -6.0)
	elif is_potion:
		play("potion_pickup", at, pitch, -6.5)
	else:
		play("pickup", at, pitch, -6.0)


func check_weapon_environment(attacker: Node3D, weapon: Node3D, struck: Array[CollisionObject3D]) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var exclude: Array[RID] = []
	if attacker is CollisionObject3D:
		exclude.append((attacker as CollisionObject3D).get_rid())
	if weapon is CollisionObject3D:
		exclude.append(weapon.get_rid())
	for child: CollisionObject3D in attacker.find_children("*", "CollisionObject3D", true, false):
		exclude.append(child.get_rid())
	for shape_node: CollisionShape3D in weapon.find_children("*", "CollisionShape3D", true, false):
		if shape_node.disabled or shape_node.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape_node.shape
		query.transform = shape_node.global_transform
		query.collision_mask = (1 << 0) | (1 << 2)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = exclude
		for contact in attacker.get_world_3d().direct_space_state.intersect_shape(query, 64):
			var body := contact.collider as CollisionObject3D
			if body == null or body in struck or _is_character_body(body):
				continue
			struck.append(body)
			for surface in surfaces_for(body):
				play_surface_impact(surface, shape_node.global_position, clampf(float(weapon.get("damage")) / 35.0, 0.35, 1.0))


func _is_character_body(node: Node) -> bool:
	var cursor := node
	while cursor != null:
		if cursor is CharacterBody3D or cursor.is_in_group("hurtboxes"):
			return true
		cursor = cursor.get_parent()
	return false


func play_ui(sound := "ui_confirm") -> void:
	if not EFFECTS.has(sound):
		return
	var player := AudioStreamPlayer.new()
	player.stream = EFFECTS[sound]
	player.bus = SFX_BUS
	player.pitch_scale = randf_range(0.97, 1.03)
	player.volume_db = -8.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_hover() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _ui_hover_time < 0.075:
		return
	_ui_hover_time = now
	play_ui("ui_hover")


func play_menu_music() -> void:
	if _music_scene == "menu" and _music_player.playing:
		return
	_music_scene = "menu"
	_fade_to_ambience(null)
	_fade_to_music(MENU_MUSIC)


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_register_ui_tree(scene)
	var path := scene.scene_file_path.to_lower()
	var is_gameplay := "gameplay" in path or "dungeon" in path or "combat_test" in path or "enemy_" in path
	var start_delay := HUB_MUSIC_START_DELAY if "hub.tscn" in path else 0.0
	var audio_scene := "gameplay" if is_gameplay else "menu"
	if audio_scene != _music_scene:
		_music_scene = audio_scene
		_fade_to_music(null if is_gameplay else MENU_MUSIC, start_delay)
		_fade_to_ambience(DUNGEON_AMBIENCE if is_gameplay else null)


func _on_node_added(node: Node) -> void:
	if node is Button:
		_attach_button(node as Button)
	elif node is HSlider and not (node as HSlider).value_changed.is_connected(_on_slider_changed):
		(node as HSlider).value_changed.connect(_on_slider_changed)


func _register_ui_tree(node: Node) -> void:
	if node is Button:
		_attach_button(node as Button)
	elif node is HSlider and not (node as HSlider).value_changed.is_connected(_on_slider_changed):
		(node as HSlider).value_changed.connect(_on_slider_changed)
	for child in node.get_children():
		_register_ui_tree(child)


func _attach_button(button: Button) -> void:
	if not button.pressed.is_connected(_on_button_pressed.bind(button)):
		button.pressed.connect(_on_button_pressed.bind(button))
	if not button.mouse_entered.is_connected(play_hover):
		button.mouse_entered.connect(play_hover)
	if not button.focus_entered.is_connected(play_hover):
		button.focus_entered.connect(play_hover)


func _on_button_pressed(button: Button) -> void:
	var label := button.text.to_lower()
	var is_back := "back" in label or "cancel" in label or "close" in label or "return" in label
	play_ui("ui_back" if is_back else "ui_confirm")


func _on_slider_changed(_value: float) -> void:
	play_hover()


func _fade_to_music(stream: AudioStream, start_delay := 0.0) -> void:
	if _music_tween != null and _music_tween.is_running():
		_music_tween.kill()
	if stream == null:
		if not _music_player.playing:
			return
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -35.0, 0.35)
		_music_tween.tween_callback(_music_player.stop)
		return
	if not _music_player.playing and is_zero_approx(start_delay):
		_music_player.stream = stream
		_music_player.volume_db = 6.0
		_music_player.play()
		return
	_music_tween = create_tween()
	if _music_player.playing:
		_music_tween.tween_property(_music_player, "volume_db", -35.0, 0.35)
		_music_tween.tween_callback(_music_player.stop)
	if start_delay > 0.0:
		_music_tween.tween_interval(start_delay)
	_music_tween.tween_callback(_music_player.set_stream.bind(stream))
	_music_tween.tween_callback(_music_player.set_volume_db.bind(-35.0))
	_music_tween.tween_callback(_music_player.play)
	_music_tween.tween_property(_music_player, "volume_db", 6.0, 0.45)


func _fade_to_ambience(stream: AudioStream) -> void:
	if stream == null and not _ambience_player.playing:
		return
	var tween := create_tween()
	if _ambience_player.playing:
		tween.tween_property(_ambience_player, "volume_db", -45.0, 0.6)
		tween.tween_callback(_ambience_player.stop)
	if stream == null:
		return
	tween.tween_callback(_ambience_player.set_stream.bind(stream))
	tween.tween_callback(_ambience_player.set_volume_db.bind(-45.0))
	tween.tween_callback(_ambience_player.play)
	tween.tween_property(_ambience_player, "volume_db", -20.0, 0.8)


func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = should_loop
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = should_loop


func _append_surface_from_text(value: String, found: Array[String]) -> void:
	var text := value.to_lower()
	if "metal" in text or "iron" in text or "steel" in text or "armor" in text or "sword" in text or "copper" in text or "silver" in text or "gold" in text or "cog" in text:
		if "metal" not in found:
			found.append("metal")
	if "wood" in text or "barrel" in text or "crate" in text or "plank" in text or "trunk" in text or "table" in text or "box" in text or "chair" in text or "door" in text or "chest" in text:
		if "wood" not in found:
			found.append("wood")
	if "stone" in text or "rock" in text or "brick" in text or "wall" in text or "column" in text or "floor" in text or "pillar" in text:
		if "stone" not in found:
			found.append("stone")


func _collect_material_surfaces(node: Node, found: Array[String]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface_index)
				if material != null:
					_append_surface_from_text(material.resource_name + " " + material.resource_path, found)
	for child in node.get_children():
		_collect_material_surfaces(child, found)
