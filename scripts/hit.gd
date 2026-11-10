class_name Hit
extends RefCounted

var amount: float
var attacker: Node3D
var origin: Vector3
var is_punch := false


func _init(hit_amount: float, hit_attacker: Node3D, hit_origin: Vector3, punch := false) -> void:
	amount = hit_amount
	attacker = hit_attacker
	origin = hit_origin
	is_punch = punch
