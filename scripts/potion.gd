class_name Potion
extends Resource

const HEALTH_PATH := ^"Health"
const MANA_PATH := ^"Mana"
const STAMINA_PATH := ^"Stamina"

@export var potion_name := ""
@export var health := 0.0
@export var mana := 0.0
@export var stamina := 0.0
@export var duration := 0.0


func apply_to(drinker: Node) -> void:
	_pour_into(drinker.get_node_or_null(HEALTH_PATH), health)
	_pour_into(drinker.get_node_or_null(MANA_PATH), mana)
	_pour_into(drinker.get_node_or_null(STAMINA_PATH), stamina)


func _pour_into(pool: StatPool, amount: float) -> void:
	if pool != null and amount > 0.0:
		pool.restore_over_time(amount, duration)
