class_name ItemInfo
extends RefCounted

const EQUIPMENT_STACK := 1
const TWO_HANDED_ANIMATION_MARKERS: Array[String] = ["2H", "Bow"]

static var _known: Dictionary[String, ItemInfo] = {}

var scene_path := ""
var item_name := ""
var max_stack := EQUIPMENT_STACK
var potion: Potion = null
var is_weapon := false
var is_shield := false
var allows_shield := false
var dual_wieldable := false
var two_handed := false
var damage := 0.0


static func of(path: String) -> ItemInfo:
	if not _known.has(path):
		_known[path] = _read(path)
	return _known[path]


static func _read(path: String) -> ItemInfo:
	var info := ItemInfo.new()
	var item := (load(path) as PackedScene).instantiate()
	if item is ItemPickup:
		info._read_pickup(item)
	else:
		info._read_equipment(item, path)
	item.free()
	return info


func is_equipment() -> bool:
	return is_weapon or is_shield


func hands_tag() -> String:
	if is_shield:
		return "SH"
	if is_weapon:
		return "2H" if two_handed else "1H"
	return ""


func kind_text() -> String:
	if is_shield:
		return "Shield"
	if is_weapon:
		return "Two-handed weapon" if two_handed else "One-handed weapon"
	return "Potion" if potion != null else "Material"


func add_to(inventory: Inventory, count: int) -> int:
	return inventory.add_item(item_name, scene_path, max_stack, count, potion)


func _read_pickup(pickup: ItemPickup) -> void:
	scene_path = pickup.item_scene_path()
	item_name = pickup.item_name
	max_stack = pickup.max_stack
	potion = pickup.potion


func _read_equipment(item: Node, path: String) -> void:
	scene_path = path
	item_name = path.get_file().get_basename().capitalize()
	is_weapon = item is Weapon
	is_shield = item is Shield
	if is_weapon:
		allows_shield = item.allows_shield
		dual_wieldable = item.dual_wieldable
		damage = item.damage
		two_handed = _holds_with_both_hands(item)


static func _holds_with_both_hands(weapon: Weapon) -> bool:
	if weapon.worn_on_both_hands:
		return true
	var animations: Array[StringName] = [weapon.idle_animation, weapon.upper_body_animation, weapon.aim_animation]
	animations.append_array(weapon.shot_animations)
	return animations.any(func(animation: StringName) -> bool:
		return TWO_HANDED_ANIMATION_MARKERS.any(func(marker: String) -> bool: return String(animation).contains(marker))
	)
