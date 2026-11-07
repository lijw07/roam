class_name ItemDropper
extends Node

const HEALTH_PATH := ^"Health"

@export var loot_tables: Array[LootTable] = []
@export var scatter_radius := 1.2
@export var release_height := 1.0

@onready var body: Node3D = get_parent()


func _ready() -> void:
	var health := body.get_node(HEALTH_PATH) as Health
	health.died.connect(_on_died)


func _on_died() -> void:
	_drop_loot.call_deferred(body.global_position, body.get_parent())


func _drop_loot(origin: Vector3, container: Node) -> void:
	var dropped := 0
	for loot_table in loot_tables:
		if loot_table.drops():
			_drop_item(loot_table.roll(), origin, container)
			dropped += 1
	if dropped > 0:
		AudioManager.play("loot_drop", origin, Vector2(0.94, 1.06), -8.0)


func _drop_item(scene: PackedScene, origin: Vector3, container: Node) -> void:
	var pickup := scene.instantiate() as ItemPickup
	container.add_child(pickup)
	pickup.launch(origin + Vector3.UP * release_height, _scattered_landing(origin))


func _scattered_landing(origin: Vector3) -> Vector3:
	var angle := randf() * TAU
	var distance := sqrt(randf()) * scatter_radius
	return origin + Vector3(cos(angle), 0.0, sin(angle)) * distance
