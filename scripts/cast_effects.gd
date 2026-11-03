extends Node3D

const AREA := preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn")
const CAST_ANIMATION_PREFIX := "combat_ranged/Ranged_Magic_"
const WARM_UP_TIME := 0.2
const WARM_UP_FRAMES := 16

@export var player: Node3D
@export var radius := 0.8
@export var emission := 1.2

var _area: VFXElementalAreaBB
var _open := false


func _ready() -> void:
	_area = AREA.instantiate()
	_area.visible = false
	add_child(_area)
	_area.area_radius = radius
	_area.emission = emission
	player.animation_changed.connect(_on_player_animation_changed)
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
	var casting := String(animation).begins_with(CAST_ANIMATION_PREFIX)
	if casting and not _open:
		_open_circle(_cast_color())
	elif not casting and _open:
		_close_circle()


func _on_player_projectile_launched(_projectile: Projectile) -> void:
	if _open:
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
	_open = false
	_area.close()


func _cast_color() -> Color:
	var weapon := player.held_item as Weapon
	return weapon.cast_color if weapon != null else Color.WHITE
