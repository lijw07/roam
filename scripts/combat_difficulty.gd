class_name CombatDifficulty
extends Resource

@export var display_name := "Normal"
@export_range(1, 6) var max_melee_attackers := 2
@export_range(0, 4) var max_ranged_attackers := 1
@export_range(0.0, 5.0, 0.05) var attack_interval := 1.0
@export_range(0.0, 1.0, 0.05) var block_chance := 0.45
@export_range(0.0, 1.0, 0.01) var reaction_time := 0.3
@export_range(0.0, 1.0, 0.05) var combo_chance := 0.25
@export_range(-1.0, 1.0, 0.05) var flank_bias := 0.2
@export_range(0.0, 3.0, 0.05) var recover_time := 0.8
@export_range(0.0, 1.0, 0.05) var ranged_caution := 0.5
