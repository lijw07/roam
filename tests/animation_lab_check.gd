extends SceneTree

## Checks the animation lab: loadouts, stances, attacks, stations and attack effects.
## Run: godot --headless --path . --script res://tests/animation_lab_check.gd
## Exits with code 1 if anything fails.

const LAB := "res://scenes/playground/animation_lab.tscn"
const RACKS := ["SwordShieldRack", "TwoHandedRack", "DaggerRack", "BowRack", "StaffRack"]
const ACTION_STATIONS := ["Chest", "Chair", "Bed", "Barrel"]
const MOUNTS := {"Chair": &"simulation/Sit_Chair_Idle", "Bed": &"simulation/Lie_Idle"}
# Animations that must never be a plain walk or run: they read as sneaking or crouching.
const NOT_LOCOMOTION := [&"movement_advanced/Sneaking", &"movement_advanced/Crouching", &"movement_advanced/Crawling"]
# Measured from chair.tscn: the seat is 0.75 square, its top 0.5 above the floor.
const SEAT_HALF := 0.45
const SEAT_HEIGHT := Vector2(0.35, 0.65)
# Measured from bed_decorated.tscn: the mattress alone (the side table sits beyond x 0.8).
const MATTRESS_HALF_WIDTH := 0.9
const MATTRESS_TOP := 0.72

var scene: Node3D
var character: CharacterBody3D
var failures := 0


func _initialize() -> void:
	scene = load(LAB).instantiate()
	root.add_child(scene)
	character = scene.get_node("TestCharacter")
	await _frames(20)
	await _check_characters()
	await _check_stances()
	await _check_attacks()
	await _check_stations()
	await _check_effects()
	await _check_browser()
	if failures == 0:
		print("\nanimation lab: all checks passed")
	else:
		printerr("\nanimation lab: %d checks failed" % failures)
	quit(1 if failures > 0 else 0)


func _check_characters() -> void:
	print("\n[characters]")
	character.equip(scene.get_node("Stations/" + RACKS[0]).loadout())
	for i in character.characters.size():
		character.set_character(i)
		await _frames(12)
		_ok("%-16s holds %d items" % [character.character_name(), _hands().size()], _hands().size() == 2)
	character.set_character(1)
	character.unequip()
	await _frames(12)


func _check_stances() -> void:
	print("\n[stances]")
	for rack in RACKS:
		var station: Area3D = scene.get_node("Stations/" + rack)
		character.global_position = Vector3(0.0, 0.1, 0.0)
		character.equip(station.loadout())
		await _frames(15)
		var idle: StringName = character.current_animation()
		Input.action_press("move_forward")
		await _frames(12)
		var walk: StringName = character.current_animation()
		Input.action_press("sprint")
		await _frames(12)
		var run: StringName = character.current_animation()
		Input.action_release("sprint")
		Input.action_release("move_forward")
		await _frames(12)
		print("  %-16s idle=%s walk=%s run=%s" % [rack, idle, walk, run])
		_ok("%s walks, not sneaks" % rack, not NOT_LOCOMOTION.has(walk))
		_ok("%s runs, not sneaks" % rack, not NOT_LOCOMOTION.has(run))
		_ok("%s idle matches its stance" % rack, station.stance_idle == &"" or idle == station.stance_idle)
		# a block or aim stance is planted: holding it must not slide the character along
		Input.action_press("secondary")
		Input.action_press("move_forward")
		await _frames(10)
		var before: Vector3 = character.global_position
		var held: StringName = character.current_animation()
		await _frames(30)
		var drift: float = character.global_position.distance_to(before)
		Input.action_release("secondary")
		Input.action_release("move_forward")
		await _frames(12)
		if station.secondary != &"":
			_ok("%s stays planted while blocking or aiming (%.2fm)" % [rack, drift], drift < 0.05)
			_ok("%s holds %s, not a crouch" % [rack, held], not NOT_LOCOMOTION.has(held))


func _check_attacks() -> void:
	print("\n[attacks]")
	for rack in RACKS:
		var station: Area3D = scene.get_node("Stations/" + rack)
		character.equip(station.loadout())
		await _settle()
		var played: Array[StringName] = []
		for i in station.attacks.size():
			character.attack()
			await _frames(10)
			played.append(character.current_animation())
			if i == 0:
				# spamming during a swing must not switch or restart the animation
				var during: StringName = character.current_animation()
				for j in 6:
					character.attack()
					await _frames(2)
				_ok("%s ignores attack spam" % rack, character.current_animation() == during)
			await _settle()
		var unique := {}
		for animation in played:
			unique[animation] = true
		_ok("%s plays all %d attacks in turn" % [rack, station.attacks.size()], unique.size() == station.attacks.size())
	character.unequip()
	await _frames(12)


func _check_stations() -> void:
	print("\n[stations]")
	_ok("tool-less stations removed", scene.get_node("Stations").get_child_count() == RACKS.size() + ACTION_STATIONS.size())
	for name in ACTION_STATIONS:
		var station: Area3D = scene.get_node("Stations/" + name)
		var approach: Vector3 = station.global_position
		character.global_position = approach - approach.normalized() * 2.0
		character.global_position.y = 0.1
		await _frames(25)
		var before: Vector3 = character.global_position
		var detected: Node = character.nearest_station()
		character._interact()
		await _settle_station(name)
		var moved: float = character.global_position.distance_to(before)
		_ok("%s detected" % name, detected == station)
		_ok("%s plays an animation" % name, character.current_animation() != &"")
		if MOUNTS.has(name):
			await _check_mount_pose(name, station)
		else:
			_ok("%s does not teleport the character (%.2fm)" % [name, moved], moved < 0.05)
		character._interact()
		await _settle()
		_ok("%s releases to idle on the floor" % name,
			character.current_animation() == &"general/Idle_A" and character.is_on_floor())
		character.station_exited(station)


func _check_mount_pose(name: String, station: Area3D) -> void:
	var skeleton: Skeleton3D = character._instance.get_node("Model/Rig_Medium/Skeleton3D")
	var to_station: Transform3D = station.global_transform.affine_inverse()
	var hips: Vector3 = to_station * _bone(skeleton, "hips")
	var head: Vector3 = to_station * _bone(skeleton, "head")
	print("    %s hips=%s head=%s" % [name, str(hips.snappedf(0.01)), str(head.snappedf(0.01))])
	if name == "Chair":
		_ok("sits on the seat, not beside it", absf(hips.x) < SEAT_HALF and absf(hips.z) < SEAT_HALF)
		_ok("sits at seat height", hips.y > SEAT_HEIGHT.x and hips.y < SEAT_HEIGHT.y)
		_ok("sits upright with the backrest behind", head.y > hips.y + 0.5)
	else:
		_ok("lies on the mattress, not the side table", absf(hips.x) < MATTRESS_HALF_WIDTH)
		_ok("lies on top of the mattress", hips.y > MATTRESS_TOP - 0.15 and hips.y < MATTRESS_TOP + 0.4)
		_ok("lies flat", absf(head.y - hips.y) < 0.25)
		_ok("head is at the pillow end", head.z < hips.z)


func _check_effects() -> void:
	print("\n[attack effects]")
	# melee: sparks only when the swing connects
	character.global_position = Vector3(0.0, 0.1, 0.0)
	character.equip(scene.get_node("Stations/SwordShieldRack").loadout())
	await _settle()
	character.attack()
	await _after_effect()
	_ok("no sparks when swinging at air", _effects("MeleeSparks") == 0)
	await _settle()
	var dummy: Node3D = scene.get_node("Targets/TrainingDummy")
	var towards: Vector3 = dummy.global_position - Vector3.ZERO
	character.global_position = dummy.global_position - towards.normalized() * 1.1
	character.global_position.y = 0.1
	character.get_node("Model").rotation.y = atan2(towards.x, towards.z)
	await _frames(25)
	character.attack()
	await _after_effect()
	_ok("sparks when the swing hits the training dummy", _effects("MeleeSparks") > 0)
	await _settle()
	# ranged: a projectile spawns and travels
	for entry in [["BowRack", 0, "Arrow"], ["StaffRack", -1, "MagicBolt"]]:
		character.equip(scene.get_node("Stations/" + entry[0]).loadout())
		await _settle()
		character._attack_index = entry[1]
		character.attack()
		await _after_effect()
		var start := _effect_position(entry[2])
		await _frames(30)
		var travelled: float = start.distance_to(_effect_position(entry[2])) if start != Vector3.INF else 0.0
		_ok("%s fires a %s that travels (%.1fm)" % [entry[0], entry[2], travelled], travelled > 1.0)
		await _settle()
	character.unequip()
	await _frames(12)


func _check_browser() -> void:
	print("\n[animation browser]")
	character.global_position = Vector3.ZERO
	await _frames(10)
	var played := 0
	for i in scene._libraries.size():
		scene._step_library(1)
		await _frames(6)
		if character.current_animation() != &"":
			played += 1
	_ok("every library plays (%d/%d)" % [played, scene._libraries.size()], played == scene._libraries.size())
	Input.action_press("move_forward")
	await _frames(12)
	Input.action_release("move_forward")
	_ok("moving cancels the browsed animation", character.current_animation() == &"movement_basic/Walking_A")


func _bone(skeleton: Skeleton3D, name: String) -> Vector3:
	var index := skeleton.find_bone(name)
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin


func _hands() -> Array:
	var items := []
	for attachment in character._attachments:
		items.append(attachment.get_child(0).name)
	return items


func _effects(prefix: String) -> int:
	var count := 0
	for child in scene.get_children():
		if String(child.name).begins_with(prefix):
			count += 1
	return count


func _effect_position(prefix: String) -> Vector3:
	for child in scene.get_children():
		if String(child.name).begins_with(prefix):
			return (child as Node3D).global_position
	return Vector3.INF


func _after_effect() -> void:
	var guard := 0
	while not character._effect_timer.is_stopped() and guard < 300:
		await physics_frame
		guard += 1
	await _frames(10)


func _settle() -> void:
	var guard := 0
	while (character._attacking or character._locked) and guard < 900:
		await physics_frame
		guard += 1
	await _frames(10)


func _settle_station(name: String) -> void:
	var settled: StringName = MOUNTS.get(name, &"")
	var guard := 0
	while guard < 900:
		await physics_frame
		guard += 1
		if settled == &"" and guard > 70:
			return
		if settled != &"" and character.current_animation() == settled:
			await _frames(10)
			return


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _ok(message: String, passed: bool) -> void:
	if not passed:
		failures += 1
	print("  %s %s" % ["ok  " if passed else "FAIL", message])
