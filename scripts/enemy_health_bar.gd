class_name EnemyHealthBar
extends MeshInstance3D

const FILL_PARAMETER := &"fill"

@export var health: Health
@export var hurtbox: Hurtbox
@export var margin := 0.35


func _ready() -> void:
	if hurtbox != null:
		position = get_parent().to_local(hurtbox.top()) + Vector3.UP * margin
	health.changed.connect(_show_fill.unbind(2))
	health.died.connect(hide)
	health.revived.connect(show)
	_show_fill()


func _show_fill() -> void:
	(material_override as ShaderMaterial).set_shader_parameter(FILL_PARAMETER, health.ratio())
