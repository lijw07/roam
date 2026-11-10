extends Node

const SAVE_PATH := "user://profile.json"
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

var _started_classes: PackedStringArray = []
var _test_materials_given := false
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
	if OS.is_debug_build():
		_add_test_items()


func choose_class(chosen: CharacterClass) -> void:
	character_class = chosen
	_stash_unusable(weapon)
	_stash_unusable(off_hand)
	if not _started_classes.has(chosen.resource_path):
		_started_classes.append(chosen.resource_path)
		_give(chosen.starting_weapon, weapon)
		_give(chosen.starting_off_hand, off_hand)
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
		"started_classes": Array(_started_classes),
		"test_materials_given": _test_materials_given,
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
	_started_classes = PackedStringArray(data.get("started_classes", []))
	_test_materials_given = data.get("test_materials_given", false)
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


func _stash_unusable(slot: Inventory) -> void:
	var held := slot.slots[0]
	if held.count > 0 and not character_class.allows_scene(held.scene_path):
		slot.deposit_into(stash)


func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	save.call_deferred()
