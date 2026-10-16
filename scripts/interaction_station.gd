extends Area3D

@export var label := ""
@export var prompt := "use"

@export_group("Action")
@export var enter_animation: StringName = &""
@export var idle_animation: StringName = &""
@export var exit_animation: StringName = &""

@export_group("Loadout")
@export var main_hand: PackedScene
@export var main_hand_rotation := Vector3.ZERO
@export var main_hand_offset := Vector3.ZERO
@export var off_hand: PackedScene
@export var off_hand_rotation := Vector3.ZERO
@export var off_hand_offset := Vector3.ZERO
@export var stance_idle: StringName = &""
@export var stance_walk: StringName = &""
@export var stance_run: StringName = &""
@export var attacks: Array[StringName] = []
@export var secondary: StringName = &""

@export_group("Attack effect")
@export var effect: PackedScene
@export var effect_attacks: Array[StringName] = []
@export var effect_bone: StringName = &"handslot.r"
@export var effect_delay := 0.35
@export var effect_offset := Vector3.ZERO
@export var effect_on_hit := false
@export var effect_reach := 1.4

@onready var anchor: Node3D = get_node_or_null(^"Anchor")
@onready var exit_point: Node3D = get_node_or_null(^"Exit")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_loadout() -> bool:
	return main_hand != null or not attacks.is_empty() or stance_idle != &""


func is_action() -> bool:
	return enter_animation != &"" or idle_animation != &""


func loadout() -> Dictionary:
	var result := {"label": label, "attacks": attacks}
	if main_hand:
		result["main_hand"] = main_hand
		result["main_hand_rotation"] = main_hand_rotation
		result["main_hand_offset"] = main_hand_offset
	if off_hand:
		result["off_hand"] = off_hand
		result["off_hand_rotation"] = off_hand_rotation
		result["off_hand_offset"] = off_hand_offset
	if stance_idle != &"":
		result["idle"] = stance_idle
	if stance_walk != &"":
		result["walk"] = stance_walk
	if stance_run != &"":
		result["run"] = stance_run
	if secondary != &"":
		result["secondary"] = secondary
	if effect:
		result["effect"] = effect
		result["effect_attacks"] = effect_attacks
		result["effect_bone"] = effect_bone
		result["effect_delay"] = effect_delay
		result["effect_offset"] = effect_offset
		result["effect_on_hit"] = effect_on_hit
		result["effect_reach"] = effect_reach
	return result


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("station_entered"):
		body.station_entered(self)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("station_exited"):
		body.station_exited(self)
