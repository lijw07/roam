extends "res://scripts/combat_test.gd"

const DIFFICULTIES := {
	KEY_8: preload("res://resources/difficulty/easy.tres"),
	KEY_9: preload("res://resources/difficulty/normal.tres"),
	KEY_0: preload("res://resources/difficulty/hard.tres"),
}
const AI_CONTROLS := "8 easy   9 normal   0 hard"

@onready var director: CombatDirector = $CombatDirector
@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	super()
	for key: Key in DIFFICULTIES:
		_key_actions[key] = _set_difficulty.bind(DIFFICULTIES[key])
	navigation_region.bake_navigation_mesh()


func _info_text() -> String:
	return "%s\n%s\n%s" % [super(), AI_CONTROLS, _ai_text()]


func _set_difficulty(difficulty: CombatDifficulty) -> void:
	director.difficulty = difficulty


func _ai_text() -> String:
	var tokens := "melee attackers %d/%d   ranged attackers %d/%d" % [
		director.attacker_count(false), director.attacker_limit(false),
		director.attacker_count(true), director.attacker_limit(true),
	]
	return "Difficulty %s   %s   %s" % [director.difficulty.display_name, tokens, _state_counts()]


func _state_counts() -> String:
	var counts: Dictionary[String, int] = {}
	for brain in director.brains():
		var state := brain.state_name()
		counts[state] = counts.get(state, 0) + 1
	var parts: Array[String] = []
	for state in counts:
		parts.append("%s %d" % [state, counts[state]])
	return "   ".join(parts)
