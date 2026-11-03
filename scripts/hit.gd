class_name Hit
extends RefCounted

var amount: float
var attacker: Node3D
var origin: Vector3


func _init(hit_amount: float, hit_attacker: Node3D, hit_origin: Vector3) -> void:
	amount = hit_amount
	attacker = hit_attacker
	origin = hit_origin
