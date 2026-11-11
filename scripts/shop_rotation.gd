class_name ShopRotation
extends VBoxContainer

const ROTATION_SECONDS := 900
const OFFER_COUNT := 5
const MIN_STOCK := 3
const MAX_STOCK := 12
const ICON_SIZE := Vector2(48, 48)
const QUANTITY_BUTTON_SIZE := Vector2(36, 36)
const QUANTITY_LABEL_WIDTH := 32.0
const BUY_BUTTON_SIZE := Vector2(90, 36)
const DETAIL_FONT_SIZE := 13
const ROW_SEPARATION := 8
const LIST_SEPARATION := 10

@export var pool: RecipeBook
@export var icon_renderer: ItemIconRenderer

var _rotation := -1
var _offers: Array[Offer] = []
var _countdown: Label
var _offer_list: VBoxContainer


class Offer:
	var recipe: Recipe
	var info: ItemInfo
	var stock := 0
	var quantity := 1
	var details: Label
	var quantity_label: Label
	var fewer_button: Button
	var more_button: Button
	var buy_button: Button


func _ready() -> void:
	_countdown = Label.new()
	add_child(_countdown)
	_offer_list = VBoxContainer.new()
	_offer_list.add_theme_constant_override("separation", LIST_SEPARATION)
	add_child(_offer_list)
	Profile.stash.changed.connect(_refresh)
	_update_rotation()


func _process(_delta: float) -> void:
	_update_rotation()


func _update_rotation() -> void:
	var now := int(Time.get_unix_time_from_system())
	var current_rotation := floori(float(now) / ROTATION_SECONDS)
	if current_rotation != _rotation:
		_rotation = current_rotation
		_stock_offers()
	var seconds_left := ROTATION_SECONDS - now % ROTATION_SECONDS
	_countdown.text = "New stock in %d:%02d" % [floori(seconds_left / 60.0), seconds_left % 60]


func _stock_offers() -> void:
	for row in _offer_list.get_children():
		row.queue_free()
	_offers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_rotation)
	var choices := pool.recipes.duplicate()
	for _pick in mini(OFFER_COUNT, choices.size()):
		var recipe: Recipe = choices.pop_at(rng.randi_range(0, choices.size() - 1))
		_offers.append(_add_offer(recipe, rng.randi_range(MIN_STOCK, MAX_STOCK)))
	_refresh()


func _add_offer(recipe: Recipe, stock: int) -> Offer:
	var offer := Offer.new()
	offer.recipe = recipe
	offer.info = ItemInfo.of(recipe.item.resource_path)
	offer.stock = stock
	offer.details = Label.new()
	offer.details.add_theme_font_size_override("font_size", DETAIL_FONT_SIZE)
	offer.quantity_label = Label.new()
	offer.quantity_label.custom_minimum_size = Vector2(QUANTITY_LABEL_WIDTH, 0)
	offer.quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offer.fewer_button = _button("-", QUANTITY_BUTTON_SIZE, _change_quantity.bind(offer, -1))
	offer.more_button = _button("+", QUANTITY_BUTTON_SIZE, _change_quantity.bind(offer, 1))
	offer.buy_button = _button("Buy", BUY_BUTTON_SIZE, _buy.bind(offer))
	_offer_list.add_child(_row(offer))
	return offer


func _row(offer: Offer) -> PanelContainer:
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = offer.info.item_name
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	offer.details.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	text.add_child(offer.details)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	row.add_child(_icon(offer.info))
	row.add_child(text)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", ROW_SEPARATION)
	for control: Control in [offer.fewer_button, offer.quantity_label, offer.more_button, offer.buy_button]:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		actions.add_child(control)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", ROW_SEPARATION)
	content.add_child(row)
	content.add_child(actions)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ShopOffer"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(content)
	return panel


func _refresh() -> void:
	for offer in _offers:
		var most := _most_buyable(offer)
		offer.quantity = clampi(offer.quantity, 1, maxi(most, 1))
		offer.details.text = "%s each  -  %d left" % [_price_text(offer.recipe), _stock_left(offer)]
		offer.quantity_label.text = str(offer.quantity)
		offer.fewer_button.disabled = offer.quantity <= 1
		offer.more_button.disabled = offer.quantity >= most
		offer.buy_button.disabled = most == 0


func _change_quantity(offer: Offer, step: int) -> void:
	offer.quantity += step
	_refresh()


func _buy(offer: Offer) -> void:
	var amount := offer.quantity
	if amount > _most_buyable(offer):
		AudioManager.play_ui("ui_error")
		return
	Profile.spend(offer.recipe.cost, amount)
	offer.info.add_to(Profile.stash, amount * offer.recipe.count)
	Profile.record_purchase(_rotation, offer.recipe.item.resource_path, amount)
	AudioManager.play_ui("purchase")
	offer.quantity = 1
	_refresh()


func _most_buyable(offer: Offer) -> int:
	for amount in range(_stock_left(offer), 0, -1):
		if Profile.can_afford(offer.recipe.cost, amount) and Profile.has_room_for(offer.info, amount * offer.recipe.count):
			return amount
	return 0


func _stock_left(offer: Offer) -> int:
	return offer.stock - Profile.purchased_in_rotation(_rotation, offer.recipe.item.resource_path)


func _price_text(recipe: Recipe) -> String:
	var parts := PackedStringArray()
	for material_name: String in recipe.cost:
		parts.append("%d %s" % [recipe.cost[material_name], material_name])
	return ", ".join(parts)


func _icon(info: ItemInfo) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = icon_renderer.icon_for(info.scene_path)
	return icon


func _button(text: String, minimum_size: Vector2, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.pressed.connect(on_pressed)
	return button
