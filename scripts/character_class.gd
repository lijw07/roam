class_name CharacterClass
extends Resource

@export var display_name := ""
@export var character_scene: PackedScene
@export_multiline var weapons_text := ""
@export_multiline var description := ""
@export_multiline var lore := ""
@export var starting_weapon: PackedScene
@export var starting_off_hand: PackedScene
@export var equipment: Array[PackedScene] = []
@export var damage_taken := 1.0


func allows(item: Node3D) -> bool:
	return not (item is Weapon or item is Shield) or allows_scene(item.scene_file_path)


func allows_scene(scene_path: String) -> bool:
	return equipment.any(func(scene: PackedScene) -> bool: return scene.resource_path == scene_path)
