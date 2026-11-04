class_name LootTable
extends Resource

@export var tiers: Array[LootTier] = []
@export_range(0.0, 1.0) var chance := 1.0

var _rng := RandomNumberGenerator.new()


func drops() -> bool:
	return _rng.randf() < chance


func roll() -> PackedScene:
	var tier := tiers[_rng.rand_weighted(_tier_weights())]
	return tier.items.pick_random()


func _tier_weights() -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	for tier in tiers:
		weights.append(tier.weight)
	return weights
