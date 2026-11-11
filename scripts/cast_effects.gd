extends Node3D

const AREA := preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn")
const CAST_ANIMATION_MARKER := "Ranged_Magic_"
const WARM_UP_TIME := 0.2
const WARM_UP_FRAMES := 16
const CONJURE_SOUND := preload("res://assets/audio/samples/magic/fireball_launch.wav")
const CONJURE_VOLUME_DB := -7.0
const SILENT_DB := -40.0
const CONJURE_FADE_OUT := 0.25
const SOUND_UNIT_SIZE := 5.0
const SOUND_MAX_DISTANCE := 24.0

@export var player: Node3D
@export var radius := 0.8
@export var emission := 1.2

var _area: VFXElementalAreaBB
var _open := false
var _casting := false
var _conjure_sound: AudioStreamPlayer3D
var _conjure_fade: Tween


func _ready() -> void:
	_area = AREA.instantiate()
	_area.visible = false
	add_child(_area)
	_area.area_radius = radius
	_area.emission = emission
	_conjure_sound = _create_conjure_sound()
	add_child(_conjure_sound)
	player.animation_changed.connect(_on_player_animation_changed)
	player.attack_step_started.connect(_on_player_attack_step_started)
	player.projectile_launched.connect(_on_player_projectile_launched)
	_warm_up()


func _process(_delta: float) -> void:
	global_position = player.global_position


func _warm_up() -> void:
	await get_tree().process_frame
	if not _open:
		_area.global_position = WarmUpSpot.under_floor(self, player.global_position)
	_area.visible = true
	var sparks_started := get_tree().create_timer(WARM_UP_TIME)
	for _frame in WARM_UP_FRAMES:
		await get_tree().process_frame
	if sparks_started.time_left > 0.0:
		await sparks_started.timeout
	if not _open:
		_area.visible = false
		_area.close()


func _on_player_animation_changed(animation: StringName) -> void:
	if _casting and not _is_cast_clip(animation):
		_casting = false
		_close_circle()
		_stop_conjure_sound()


func _on_player_attack_step_started(step: AttackStep) -> void:
	if _is_cast_clip(step.animation) and not _open:
		_casting = true
		_open_circle(_cast_color())
		_start_conjure_sound()


func _is_cast_clip(animation: StringName) -> bool:
	return String(animation).contains(CAST_ANIMATION_MARKER)


func _on_player_projectile_launched(_projectile: Projectile) -> void:
	_close_circle()


func _open_circle(color: Color) -> void:
	_open = true
	_area.primary_color = color.lightened(0.5)
	_area.secondary_color = color
	_area.tertiary_color = color.darkened(0.5)
	_area.position = Vector3.ZERO
	_area.visible = true
	_area.open()


func _close_circle() -> void:
	if not _open:
		return
	_open = false
	_area.close()


func _create_conjure_sound() -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = CONJURE_SOUND
	sound.bus = AudioManager.SFX_BUS
	sound.unit_size = SOUND_UNIT_SIZE
	sound.max_distance = SOUND_MAX_DISTANCE
	return sound


func _start_conjure_sound() -> void:
	_kill_conjure_fade()
	_conjure_sound.volume_db = CONJURE_VOLUME_DB
	_conjure_sound.play()


func _stop_conjure_sound() -> void:
	if not _conjure_sound.playing:
		return
	_kill_conjure_fade()
	_conjure_fade = create_tween()
	_conjure_fade.tween_property(_conjure_sound, "volume_db", SILENT_DB, CONJURE_FADE_OUT)
	_conjure_fade.tween_callback(_conjure_sound.stop)


func _kill_conjure_fade() -> void:
	if _conjure_fade != null and _conjure_fade.is_valid():
		_conjure_fade.kill()


func _cast_color() -> Color:
	var weapon := player.held_item as Weapon
	return weapon.cast_color if weapon != null else Color.WHITE
