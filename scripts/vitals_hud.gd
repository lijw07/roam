extends VBoxContainer

const VALUE_PATH := ^"Value"

@export var health: StatPool
@export var mana: StatPool
@export var stamina: StatPool

@onready var health_bar: ProgressBar = $Health
@onready var mana_bar: ProgressBar = $Mana
@onready var stamina_bar: ProgressBar = $Stamina


func _ready() -> void:
	_bind(health, health_bar)
	_bind(mana, mana_bar)
	_bind(stamina, stamina_bar)


func _bind(pool: StatPool, bar: ProgressBar) -> void:
	bar.visible = pool != null
	if pool == null:
		return
	pool.changed.connect(_show.bind(bar))
	_show(pool.value, pool.max_value, bar)


func _show(value: float, max_value: float, bar: ProgressBar) -> void:
	bar.max_value = max_value
	bar.value = value
	(bar.get_node(VALUE_PATH) as Label).text = "%s  %d / %d" % [bar.name, ceili(value), roundi(max_value)]
