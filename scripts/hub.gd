extends Control

const FADE_IN_TIME := 0.6

@export_file("*.tscn") var dungeon_scene := "res://scenes/playground/gameplay_test.tscn"
@export_file("*.tscn") var character_select_scene := "res://scenes/ui/character_select.tscn"
@export_file("*.tscn") var main_menu_scene := "res://scenes/ui/main_menu.tscn"

@onready var character_name: Label = %CharacterName
@onready var weapon_grid: ItemGrid = %WeaponGrid
@onready var off_hand_grid: ItemGrid = %OffHandGrid
@onready var backpack_grid: ItemGrid = %BackpackGrid
@onready var stash_grid: ItemGrid = %StashGrid
@onready var enter_dungeon_button: Button = %EnterDungeonButton
@onready var change_character_button: Button = %ChangeCharacterButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var item_tooltip: ItemTooltip = %ItemTooltip
@onready var fade_in: ColorRect = %FadeIn

var _detail_inventory: Inventory
var _detail_index := 0
var _detail_anchor: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Profile.character_class == null:
		get_tree().change_scene_to_file.call_deferred(character_select_scene)
		return
	character_name.text = Profile.character_class.display_name
	_bind(weapon_grid, Profile.weapon)
	_bind(off_hand_grid, Profile.off_hand)
	_bind(backpack_grid, Profile.backpack)
	_bind(stash_grid, Profile.stash)
	enter_dungeon_button.pressed.connect(_go_to.bind(dungeon_scene))
	change_character_button.pressed.connect(_go_to.bind(character_select_scene))
	main_menu_button.pressed.connect(_go_to.bind(main_menu_scene))
	enter_dungeon_button.grab_focus()
	if Profile.take_run_return():
		_fade_in_from_black()


func _fade_in_from_black() -> void:
	fade_in.modulate.a = 1.0
	fade_in.show()
	var fade := create_tween()
	fade.tween_property(fade_in, "modulate:a", 0.0, FADE_IN_TIME)
	fade.tween_callback(fade_in.hide)


func _bind(grid: ItemGrid, inventory: Inventory) -> void:
	grid.bind(inventory)
	grid.slot_dropped.connect(_on_slot_dropped)
	grid.slot_activated.connect(_on_slot_activated)
	grid.slot_focused.connect(_show_details)
	grid.slot_unfocused.connect(_hide_details)
	inventory.changed.connect(_refresh_details)


func _show_details(inventory: Inventory, index: int, anchor: Control) -> void:
	_detail_inventory = inventory
	_detail_index = index
	_detail_anchor = anchor
	_refresh_details()


func _hide_details() -> void:
	_detail_inventory = null
	item_tooltip.hide()


func _refresh_details() -> void:
	if _detail_inventory == null or _detail_inventory.count_at(_detail_index) == 0:
		item_tooltip.hide()
		return
	item_tooltip.show_for(_detail_inventory.slots[_detail_index], _detail_anchor)


func _go_to(scene_path: String) -> void:
	Profile.save()
	get_tree().change_scene_to_file(scene_path)


func _on_slot_dropped(source: Inventory, from_index: int, target: Inventory, to_index: int) -> void:
	var moving := source.slots[from_index]
	if not _fits(target, moving):
		return
	var changed := false
	if target.movable_amount_from(source, from_index, to_index) > 0:
		target.move_from(source, from_index, to_index, moving.count)
		changed = true
	elif _fits(source, target.slots[to_index]):
		target.swap_from(source, from_index, to_index)
		changed = true
	if changed and target in [Profile.weapon, Profile.off_hand]:
		AudioManager.play_ui("equipment_equip")
	_stash_unpaired_off_hand()


func _on_slot_activated(source: Inventory, index: int) -> void:
	if source != Profile.stash:
		_transfer(source, index, Profile.stash)
	elif ItemInfo.of(source.slots[index].scene_path).is_equipment():
		_equip_from_stash(index)
	else:
		_transfer(source, index, Profile.backpack)
	_stash_unpaired_off_hand()


func _transfer(source: Inventory, index: int, target: Inventory) -> void:
	var slot := source.slots[index]
	source.take(index, target.add_item(slot.item_name, slot.scene_path, slot.max_stack, slot.count, slot.potion))


func _equip_from_stash(index: int) -> void:
	var slot := Profile.stash.slots[index]
	var hand := Profile.weapon if ItemInfo.of(slot.scene_path).is_weapon else Profile.off_hand
	if _fits(hand, slot):
		hand.swap_from(Profile.stash, index, 0)
		AudioManager.play_ui("equipment_equip")


func _fits(inventory: Inventory, slot: Inventory.Slot) -> bool:
	if slot.count == 0 or inventory == Profile.stash:
		return true
	var info := ItemInfo.of(slot.scene_path)
	if inventory == Profile.backpack:
		return not info.is_equipment()
	if not Profile.character_class.allows_scene(slot.scene_path):
		return false
	if inventory == Profile.weapon:
		return info.is_weapon
	return (info.is_shield or info.dual_wieldable) and _pairs_with_weapon(info)


func _pairs_with_weapon(off_hand: ItemInfo) -> bool:
	var held := Profile.weapon.slots[0]
	if held.count == 0:
		return off_hand.is_shield
	var weapon := ItemInfo.of(held.scene_path)
	return weapon.allows_shield if off_hand.is_shield else weapon.dual_wieldable


func _stash_unpaired_off_hand() -> void:
	var held := Profile.off_hand.slots[0]
	if held.count > 0 and not _pairs_with_weapon(ItemInfo.of(held.scene_path)):
		Profile.off_hand.deposit_into(Profile.stash)
