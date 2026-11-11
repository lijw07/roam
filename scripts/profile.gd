extends Node

const SAVE_PATH := "user://profile.json"
const TEST_STASH_SETTING := "roam/testing/fill_stash"
const STASH_COLUMNS := 8
const STASH_ROWS := 7
const BACKPACK_COLUMNS := 3
const BACKPACK_ROWS := 3
const TEST_STASH_SLOTS := 24
const TEST_MATERIAL_COUNT := 12
const TEST_COIN_COUNT := 50
const TEST_COIN_PATH := "res://scenes/resources/coin.tscn"
const WEAPON_RECIPES_PATH := "res://resources/crafting/weapon_recipes.tres"
const MATERIAL_SHOP_PATH := "res://resources/crafting/material_shop.tres"
const TEST_ITEM_BOOKS: Array[String] = [WEAPON_RECIPES_PATH, MATERIAL_SHOP_PATH]
const TEST_EXTRA_ITEMS: Array[String] = [
	TEST_COIN_PATH,
	"res://scenes/potions/health_potion.tscn",
	"res://scenes/potions/mana_potion.tscn",
	"res://scenes/potions/stamina_potion.tscn",
	"res://scenes/potions/regeneration_potion.tscn",
]

var character_class: CharacterClass
var stash: Inventory
var weapon: Inventory
var off_hand: Inventory
var backpack: Inventory

var _test_materials_given := false
var _loadouts: Dictionary[String, Dictionary] = {}
var _returned_from_run := false
var _shop_rotation := -1
var _shop_purchases: Dictionary[String, int] = {}
var _save_queued := false


func _ready() -> void:
	stash = _add_inventory("Stash", STASH_COLUMNS, STASH_ROWS)
	weapon = _add_inventory("Weapon", 1, 1)
	off_hand = _add_inventory("OffHand", 1, 1)
	backpack = _add_inventory("Backpack", BACKPACK_COLUMNS, BACKPACK_ROWS)
	_load()
	if ProjectSettings.get_setting(TEST_STASH_SETTING, false):
		_add_test_items()


func choose_class(chosen: CharacterClass) -> void:
	if chosen != character_class:
		_put_away_loadout()
		character_class = chosen
		_take_out_loadout()
	_arm_if_unarmed()
	_queue_save()


func finish_run(run_inventory: Inventory) -> void:
	backpack.load_data(run_inventory.to_data())
	_returned_from_run = true
	save()


func take_run_return() -> bool:
	var returned := _returned_from_run
	_returned_from_run = false
	return returned


func lose_run() -> void:
	backpack.clear()
	weapon.clear()
	off_hand.clear()
	_arm_if_unarmed()
	_returned_from_run = true
	save()


func can_afford(cost: Dictionary[String, int], times: int) -> bool:
	for material: String in cost:
		if stash.count_of(material) < cost[material] * times:
			return false
	return true


func spend(cost: Dictionary[String, int], times: int) -> void:
	for material: String in cost:
		stash.remove_item(material, cost[material] * times)


func has_room_for(info: ItemInfo, count: int) -> bool:
	return stash.room_for(info.item_name, info.max_stack) >= count


func purchased_in_rotation(rotation: int, item_path: String) -> int:
	return _shop_purchases.get(item_path, 0) if rotation == _shop_rotation else 0


func record_purchase(rotation: int, item_path: String, count: int) -> void:
	var already_bought := purchased_in_rotation(rotation, item_path)
	if rotation != _shop_rotation:
		_shop_rotation = rotation
		_shop_purchases.clear()
	_shop_purchases[item_path] = already_bought + count
	_queue_save()


func save() -> void:
	_save_queued = false
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"character_class": character_class.resource_path if character_class != null else "",
		"test_materials_given": _test_materials_given,
		"loadouts": _loadouts,
		"stash": stash.to_data(),
		"weapon": weapon.to_data(),
		"off_hand": off_hand.to_data(),
		"backpack": backpack.to_data(),
		"shop_rotation": _shop_rotation,
		"shop_purchases": _shop_purchases,
	}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return
	var class_path: String = data.get("character_class", "")
	character_class = load(class_path) as CharacterClass if ResourceLoader.exists(class_path) else null
	_test_materials_given = data.get("test_materials_given", false)
	var loadouts: Dictionary = data.get("loadouts", {})
	for class_key: String in loadouts:
		_loadouts[class_key] = loadouts[class_key]
	stash.load_data(data.get("stash", []))
	weapon.load_data(data.get("weapon", []))
	off_hand.load_data(data.get("off_hand", []))
	backpack.load_data(data.get("backpack", []))
	_shop_rotation = int(data.get("shop_rotation", -1))
	var purchases: Dictionary = data.get("shop_purchases", {})
	for item_path: String in purchases:
		_shop_purchases[item_path] = int(purchases[item_path])


func _is_empty(inventory: Inventory) -> bool:
	return inventory.slots.all(func(slot: Inventory.Slot) -> bool: return slot.count == 0)


func _add_test_items() -> void:
	if _is_empty(stash):
		_fill_with_test_items(stash)
	if not _test_materials_given:
		_test_materials_given = true
		_give_crafting_materials()


func _give_crafting_materials() -> void:
	for material_path in _crafting_material_paths():
		ItemInfo.of(material_path).add_to(stash, TEST_MATERIAL_COUNT)
	ItemInfo.of(TEST_COIN_PATH).add_to(stash, TEST_COIN_COUNT)


func _crafting_material_paths() -> PackedStringArray:
	var needed := {}
	for recipe in (load(WEAPON_RECIPES_PATH) as RecipeBook).recipes:
		needed.merge(recipe.cost)
	var paths := PackedStringArray()
	for offer in (load(MATERIAL_SHOP_PATH) as RecipeBook).recipes:
		var path := offer.item.resource_path
		if needed.has(ItemInfo.of(path).item_name):
			paths.append(path)
	return paths


func _fill_with_test_items(inventory: Inventory) -> void:
	var groups := _test_item_groups()
	for _slot in TEST_STASH_SLOTS:
		var info := ItemInfo.of(groups.pick_random().pick_random())
		info.add_to(inventory, randi_range(1, info.max_stack))


func _test_item_groups() -> Array[Array]:
	var groups: Array[Array] = [TEST_EXTRA_ITEMS]
	for book_path in TEST_ITEM_BOOKS:
		groups.append((load(book_path) as RecipeBook).recipes.map(func(recipe: Recipe) -> String: return recipe.item.resource_path))
	return groups


func _add_inventory(inventory_name: String, columns: int, rows: int) -> Inventory:
	var inventory := Inventory.new()
	inventory.name = inventory_name
	inventory.columns = columns
	inventory.rows = rows
	add_child(inventory)
	inventory.changed.connect(_queue_save)
	return inventory


func _give(scene: PackedScene, slot: Inventory) -> void:
	if scene == null:
		return
	var target := slot if slot.count_at(0) == 0 else stash
	ItemInfo.of(scene.resource_path).add_to(target, 1)


func _arm_if_unarmed() -> void:
	if character_class == null or _owns_usable_weapon():
		return
	_give(character_class.starting_weapon, weapon)
	if off_hand.count_at(0) == 0:
		_give(character_class.starting_off_hand, off_hand)


func _owns_usable_weapon() -> bool:
	for inventory: Inventory in [weapon, off_hand, stash, backpack]:
		for slot: Inventory.Slot in inventory.slots:
			if slot.count > 0 and ItemInfo.of(slot.scene_path).is_weapon and character_class.allows_scene(slot.scene_path):
				return true
	return false


func _put_away_loadout() -> void:
	if character_class == null:
		return
	_loadouts[character_class.resource_path] = {"weapon": weapon.to_data(), "off_hand": off_hand.to_data()}


func _take_out_loadout() -> void:
	var loadout: Dictionary = _loadouts.get(character_class.resource_path, {})
	for hand: Inventory in [weapon, off_hand]:
		hand.clear()
	weapon.load_data(loadout.get("weapon", []))
	off_hand.load_data(loadout.get("off_hand", []))


func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	save.call_deferred()
