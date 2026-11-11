extends Node3D

const CLIP_BLEND := 0.18
const NO_BLEND := 0.0

var _character: Node3D
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _class: CharacterClass
var _weapons: Array[PackedScene] = []
var _weapon_index := 0
var _attachments: Array[BoneAttachment3D] = []
var _sequence: Array[Dictionary] = []
var _step := 0
var _remaining := 0.0
var _turning := false
var current_weapon_path := ""
var current_action: StringName = &""


func _ready() -> void:
	set_process(false)


func show_character(character_class: CharacterClass) -> void:
	_clear_character()
	_class = character_class
	if character_class == null:
		return
	_character = character_class.character_scene.instantiate()
	for child in _character.get_children():
		if child.name not in [&"Model", &"AnimationPlayer"]:
			_character.remove_child(child)
			child.free()
	if _character is CollisionObject3D:
		_character.collision_layer = 0
		_character.collision_mask = 0
	add_child(_character)
	_character.rotation.y = -0.22
	_animation = _character.get_node("AnimationPlayer")
	_skeleton = _character.get_node("Model/Rig_Medium/Skeleton3D")
	_weapons.clear()
	if character_class.starting_weapon != null:
		_weapons.append(character_class.starting_weapon)
	for candidate in character_class.equipment:
		if _weapons.has(candidate):
			continue
		var item := candidate.instantiate()
		var is_weapon := item is Weapon
		item.free()
		if is_weapon:
			_weapons.append(candidate)
			break
	_weapon_index = 0
	_equip_and_sequence(NO_BLEND)
	_animation.advance(0.0)
	set_process(true)


func _process(delta: float) -> void:
	if _turning:
		return
	_remaining -= delta
	if _remaining > 0.0:
		return
	_step += 1
	if _step >= _sequence.size():
		_weapon_index = (_weapon_index + 1) % maxi(_weapons.size(), 1)
		_equip_and_sequence()
	else:
		_play_step()


func _clear_character() -> void:
	_turning = false
	set_process(false)
	_attachments.clear()
	_sequence.clear()
	current_weapon_path = ""
	current_action = &""
	if is_instance_valid(_character):
		_character.hide()
		_character.queue_free()
	_character = null
	_animation = null
	_skeleton = null


func _equip_and_sequence(first_blend := CLIP_BLEND) -> void:
	for attachment in _attachments:
		attachment.hide()
		attachment.queue_free()
	_attachments.clear()
	_sequence.clear()
	if _weapons.is_empty():
		_clip(&"general/Idle_A", 5.0)
	else:
		var scene := _weapons[_weapon_index]
		var weapon := scene.instantiate() as Weapon
		current_weapon_path = scene.resource_path
		_mount_model(weapon, weapon.hand, weapon.grip())
		if weapon.worn_on_both_hands:
			var pair := scene.instantiate() as Weapon
			_mount_model(pair, &"handslot.l", pair.off_hand_grip())
			pair.free()
		var idle: StringName = weapon.idle_animation if weapon.idle_animation != &"" else &"general/Idle_A"
		_clip(idle, 2.4)
		if weapon.is_ranged():
			_clip(weapon.aim_animation)
			if weapon.aim_hold_animation != &"":
				_clip(weapon.aim_hold_animation, 0.8)
			for shot in weapon.shot_animations:
				_clip(shot)
		else:
			for index in mini(weapon.combo.size(), 2):
				_clip(weapon.combo[index].animation)
		_clip(idle, 1.0)
		if weapon.allows_shield and _class.starting_off_hand != null:
			var off_hand := _class.starting_off_hand.instantiate()
			if off_hand is Shield:
				_mount_model(off_hand, &"handslot.l", off_hand.grip())
				_clip(off_hand.raise_animation)
				_clip(off_hand.hold_animation, 1.4)
				_clip(off_hand.bash_animation)
			off_hand.free()
		_clip(idle, 1.6)
		_clip(&"general/Use_Item")
		weapon.free()
	_step = 0
	_play_step(first_blend)


func _mount_model(item: Node3D, hand: StringName, grip: Transform3D) -> void:
	var model := item.get_node("Model") as Node3D
	model.owner = null
	item.remove_child(model)
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = hand
	_skeleton.add_child(attachment)
	attachment.add_child(model)
	model.transform = grip
	_attachments.append(attachment)


func _clip(animation: StringName, hold := 0.0) -> void:
	if _animation.has_animation(animation):
		_sequence.append({"animation": animation, "duration": hold if hold > 0.0 else _animation.get_animation(animation).length})


func _play_step(blend := CLIP_BLEND) -> void:
	if _sequence.is_empty():
		set_process(false)
		return
	var next := _sequence[_step]
	current_action = next.animation
	_remaining = next.duration
	_animation.play(current_action, blend)


func begin_turn() -> bool:
	if not is_instance_valid(_character):
		return false
	_turning = true
	_animation.pause()
	return true


func turn(radians: float) -> void:
	if _turning and is_instance_valid(_character):
		_character.rotation.y = wrapf(_character.rotation.y + radians, -PI, PI)


func end_turn() -> void:
	if not _turning:
		return
	_turning = false
	if is_instance_valid(_animation):
		_animation.play()
