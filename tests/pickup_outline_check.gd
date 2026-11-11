extends Node

const GAMEPLAY := preload("res://scenes/playground/gameplay_test.tscn")
const ITEM := preload("res://scenes/resources/gold_nugget_small.tscn")
const BEHIND_PLAYER := 0.9
const BESIDE_PLAYER := 1.6

var _game: Node


func _ready() -> void:
	_game = GAMEPLAY.instantiate()
	add_child(_game)
	await get_tree().create_timer(1.0).timeout
	_game.call(&"_kill_all_enemies")
	await get_tree().create_timer(2.0).timeout
	var player := _game.get_node(^"Player") as Node3D
	var camera := get_viewport().get_camera_3d()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	_drop_at(player.global_position + forward * BEHIND_PLAYER)
	_drop_at(player.global_position + forward.cross(Vector3.UP) * BESIDE_PLAYER + forward)


func _drop_at(point: Vector3) -> void:
	var pickup := ITEM.instantiate() as ItemPickup
	pickup.auto_pick_up = false
	_game.add_child(pickup)
	pickup.global_position = point
