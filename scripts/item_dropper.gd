class_name ItemDropper
extends Node

const HEALTH_PATH := ^"Health"

@export var loot_tables: Array[LootTable] = []
@export var scatter_radius := 1.2
@export var release_height := 1.0

@onready var body: Node3D = get_parent()


func _ready() -> void:
	var health := body.get_node(HEALTH_PATH) as Health
	health.died.connect(_drop_loot, CONNECT_DEFERRED)


func _drop_loot() -> void:
	for loot_table in loot_tables:
		_drop_item(loot_table.roll())


func _drop_item(scene: PackedScene) -> void:
	var pickup := scene.instantiate() as ItemPickup
	body.get_parent().add_child(pickup)
	pickup.launch(body.global_position + Vector3.UP * release_height, _scattered_landing())


func _scattered_landing() -> Vector3:
	var angle := randf() * TAU
	var distance := sqrt(randf()) * scatter_radius
	return body.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
