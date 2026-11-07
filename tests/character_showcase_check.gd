extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	var stage := Node3D.new()
	stage.set_script(load("res://scripts/character_showcase.gd"))
	root.add_child(stage)
	for id in ["knight", "barbarian", "mage", "ranger", "rogue_hooded"]:
		var character_class: CharacterClass = load("res://resources/characters/" + id + ".tres")
		stage.show_character(character_class)
		check(stage._character.get_node("Model") != null, id + " original model is present")
		check(stage._character.get_node_or_null("Hurtbox") == null, id + " showcase has no gameplay hurtbox")
		var weapons := {}
		var actions := {}
		for step in 24:
			weapons[stage.current_weapon_path] = true
			actions[String(stage.current_action)] = true
			check(stage._animation.has_animation(stage.current_action), id + " action exists in original library")
			stage._remaining = 0
			stage._process(0.01)
			await process_frame
		check(weapons.size() >= 2, id + " swaps between original weapons")
		for path in weapons:
			check(character_class.allows_scene(path), id + " only shows class-compatible equipment")
		if id in ["knight", "barbarian"]:
			check(actions.has("combat_melee/Melee_Blocking"), id + " demonstrates shield blocking")
		elif id == "ranger":
			check(actions.keys().any(func(clip: String) -> bool: return "Ranged_" in clip), "Ranger demonstrates ranged animation")
		elif id == "mage":
			check(actions.keys().any(func(clip: String) -> bool: return "Magic" in clip), "Mage demonstrates casting animation")
	stage.show_character(null)
	check(not stage.is_processing() and stage._character == null, "Clearing selection stops and removes the showcase")
	stage.queue_free()
	await process_frame
	print("Character showcase: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
