extends SceneTree
## Isolated visual review. Run with the Roam project as --path and this as --script.
## No gameplay scenes, inventory or profile data are changed by the preview.

const OUT := "res://art-review/ui-v2/"
const INK := Color("171d22")
const SURFACE := Color("242e34")
const EDGE := Color("47545b")
const PAPER := Color("eee9da")
const MUTED := Color("a7b0ad")
const GOLD := Color("c9a565")
const CLASS_IDS := ["knight", "barbarian", "mage", "ranger", "rogue", "rogue_hooded"]
const CLASS_NAMES := ["Knight", "Barbarian", "Mage", "Ranger", "Rogue", "Rogue Hooded"]
const WEAPONS := ["Swords, polearms and shields", "Axes, hammers and shields", "Staves and wands", "Bows and crossbows", "Daggers, fist weapons and one-handed crossbows", "Daggers, fist weapons and one-handed crossbows"]

var ui: Control
var world: Node3D
var regular: SystemFont
var heavy: SystemFont
var chosen := 0
var portraits: Array[Texture2D] = []
var portrait_views: Array[SubViewport] = []
var capture_mode := true
var active_screen := ""

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	root.title = "Roam — UI art review"
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	regular = SystemFont.new()
	regular.font_names = PackedStringArray(["Avenir Next", "Arial"])
	heavy = SystemFont.new()
	heavy.font_names = regular.font_names
	heavy.font_weight = 700
	build_world()
	for id in CLASS_IDS:
		var view := character_view(id, Vector2i(128, 128), true)
		root.add_child(view)
		portrait_views.append(view)
		portraits.append(view.get_texture())
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui)
	capture_mode = not OS.get_cmdline_user_args().has("--interactive")
	show_select()
	if not capture_mode:
		return
	await capture("character-select.png")
	chosen = 2
	show_select()
	await capture("character-select-mage.png")
	chosen = 0
	show_main()
	await capture("main-menu.png")
	show_hub()
	await capture("hub.png")
	quit()

func asset(path: String, parent: Node, pos := Vector3.ZERO) -> Node3D:
	var model: Node3D = load(path).instantiate()
	parent.add_child(model)
	model.position = pos
	return model

func environment(parent: Node, energy: float) -> void:
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color("333a3c")
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color("d6dddf")
	we.environment.ambient_light_energy = energy
	parent.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -30, 0)
	key.light_color = Color("f3efe7")
	key.light_energy = 0.8
	key.shadow_enabled = true
	parent.add_child(key)

func build_world() -> void:
	world = Node3D.new()
	root.add_child(world)
	environment(world, 0.55)
	for x in range(-3, 4):
		for z in range(-2, 4):
			asset("res://assets/dungeon/floors/floor_tile_large.gltf", world, Vector3(x * 4, 0, z * 4))
	for x in [-8, -4, 4, 8]:
		asset("res://assets/dungeon/walls/wall.gltf", world, Vector3(x, 0, -4))
	asset("res://assets/dungeon/walls/wall_doorway.gltf", world, Vector3(0, 0, -4))
	for x in [-2.5, 2.5]:
		asset("res://assets/dungeon/structure/pillar.gltf", world, Vector3(x, 0, -3.5))
		asset("res://assets/dungeon/banners/banner_red.gltf", world, Vector3(x * 1.9, 1.3, -3.7))
	asset("res://assets/dungeon/containers/crates_stacked.gltf", world, Vector3(-4.7, 0, 0))
	asset("res://assets/dungeon/containers/chest.gltf", world, Vector3(4.5, 0, -0.6)).rotation.y = -0.3
	asset("res://assets/dungeon/containers/barrel_large.gltf", world, Vector3(5.9, 0, -1.6))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.8
	world.add_child(camera)
	camera.position = Vector3(5, 4.8, 16)
	camera.look_at(Vector3(0, 1, -1))
	root.msaa_3d = Viewport.MSAA_4X

func character_view(id: String, dimensions: Vector2i, portrait: bool) -> SubViewport:
	var view := SubViewport.new()
	view.size = dimensions
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	environment(view, 0.65)
	var model := asset("res://scenes/characters/adventurers/" + id + ".tscn", view)
	model.rotation.y = -0.13 if not portrait else 0.0
	var anim: AnimationPlayer = model.get_node("AnimationPlayer")
	anim.play("general/Idle_A")
	anim.advance(0.2)
	anim.pause()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.65 if portrait else 3.8
	if not portrait:
		asset("res://assets/dungeon/floors/floor_tile_small.gltf", view, Vector3(0, -0.07, 0)).scale = Vector3(0.75, 1, 0.75)
	var target := Vector3(0, 1.85 if portrait else 1.2, 0)
	cam.transform = Transform3D(Basis.looking_at(Vector3(-0.15, -0.1, -1)), target + Vector3(0.15, 0.1, 1) * 6)
	view.add_child(cam)
	return view

func clear_ui(screen: String, dim: float) -> void:
	active_screen = screen
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.065, 0.08, dim)
	shade.size = Vector2(1440, 900)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

func style(fill: Color, border: Color, thickness := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(thickness)
	box.border_width_bottom = thickness + 2
	box.set_corner_radius_all(4)
	box.shadow_color = Color(0, 0, 0, 0.22)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = 20
	box.content_margin_right = 20
	return box

func panel(rect: Rect2, fill := SURFACE, border := EDGE) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", style(fill, border))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(node)
	return node

func line(pos: Vector2, width: float, color := EDGE) -> void:
	var node := ColorRect.new()
	node.position = pos
	node.size = Vector2(width, 1)
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(node)

func label(text: String, rect: Rect2, font_size := 20, color := PAPER, bold := false, center := false) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", heavy if bold else regular)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(node)
	return node

func button(text: String, rect: Rect2, action: Callable, primary := false, selected := false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", heavy)
	node.add_theme_font_size_override("font_size", 20)
	var fill := Color("bb965a") if primary else (Color("3b423e") if selected else SURFACE)
	node.add_theme_stylebox_override("normal", style(fill, GOLD if selected or primary else EDGE, 2 if selected else 1))
	node.add_theme_stylebox_override("hover", style(fill.lightened(0.12), GOLD, 2))
	node.add_theme_stylebox_override("pressed", style(fill.darkened(0.16), GOLD, 2))
	var focus := style(Color(0, 0, 0, 0), PAPER, 2)
	focus.shadow_size = 0
	node.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, INK if primary else PAPER)
	node.pressed.connect(action)
	ui.add_child(node)
	return node

func texture(image: Texture2D, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = image
	node.position = rect.position
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = rect.size
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(node)
	node.set_deferred("size", rect.size)
	return node

func header(section: String, title: String) -> void:
	label("ROAM", Rect2(48, 26, 170, 40), 26, PAPER, true)
	label(section, Rect2(240, 26, 1100, 40), 15, MUTED)
	line(Vector2(48, 82), 1344)
	label(title, Rect2(48, 108, 1100, 70), 42, PAPER, true)

func show_main() -> void:
	clear_ui("main", 0.28)
	panel(Rect2(480, 140, 480, 620), Color(0.075, 0.1, 0.115, 0.96))
	label("ROAM", Rect2(510, 195, 420, 120), 88, PAPER, true, true)
	line(Vector2(660, 338), 120, GOLD)
	button("Play", Rect2(550, 400, 340, 62), show_select, true)
	button("Settings", Rect2(550, 478, 340, 62), func(): label("Settings preview", Rect2(550, 670, 340, 32), 16, MUTED, false, true))
	button("Quit", Rect2(550, 556, 340, 62), func(): quit())
	label("A new dungeon. Another adventure.", Rect2(510, 675, 420, 32), 17, MUTED, false, true)
	label("UI ART REVIEW 02", Rect2(48, 834, 400, 28), 13, MUTED)

func show_select() -> void:
	clear_ui("select", 0.76)
	header("CHARACTER SELECTION", "Choose your character")
	label("Choose an adventurer and their weapon style.", Rect2(50, 179, 900, 36), 19, MUTED)
	for i in CLASS_IDS.size():
		var row := Rect2(48, 254 + i * 76, 310, 64)
		var b := button("", row, select_class.bind(i), false, i == chosen)
		label(CLASS_NAMES[i], Rect2(130, row.position.y, 185, 64), 20, PAPER, true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		texture(portraits[i], Rect2(57, row.position.y + 3, 58, 58))
		if i == chosen:
			label("•", Rect2(325, row.position.y, 25, 64), 24, GOLD, true)
	panel(Rect2(396, 246, 580, 484), Color("293438"), Color("424e50"))
	var character := character_view(CLASS_IDS[chosen], Vector2i(580, 484), false)
	ui.add_child(character)
	texture(character.get_texture(), Rect2(396, 246, 580, 484))
	label(CLASS_NAMES[chosen], Rect2(396, 718, 580, 52), 23, PAPER, true, true)
	label("WEAPON STYLE", Rect2(1022, 273, 360, 30), 14, GOLD, true)
	label(CLASS_NAMES[chosen], Rect2(1022, 315, 370, 52), 34, PAPER, true)
	var description := label(WEAPONS[chosen], Rect2(1022, 384, 340, 100), 22)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line(Vector2(1022, 514), 340)
	label("STARTING EQUIPMENT", Rect2(1022, 536, 350, 30), 14, MUTED, true)
	var data: Resource = load("res://resources/characters/" + CLASS_IDS[chosen] + ".tres")
	if data.starting_weapon != null:
		item_slot(data.starting_weapon.resource_path, Rect2(1022, 590, 92, 92))
	if data.starting_off_hand != null:
		item_slot(data.starting_off_hand.resource_path, Rect2(1128, 590, 92, 92))
	line(Vector2(48, 796), 1344)
	button("Back", Rect2(48, 824, 170, 52), show_main)
	button("Continue  →", Rect2(1152, 824, 240, 52), show_hub, true)

func select_class(index: int) -> void:
	chosen = index
	show_select()

func item_slot(path: String, rect: Rect2, count := "") -> void:
	panel(rect, Color("1e272c"), Color("4e5859"))
	if not path.is_empty():
		var renderer := Node.new()
		renderer.set_script(load("res://scripts/item_icon_renderer.gd"))
		ui.add_child(renderer)
		var icon: Texture2D = renderer.icon_for(path)
		texture(icon, Rect2(rect.position + Vector2(6, 6), rect.size - Vector2(12, 12)))
	if not count.is_empty():
		var quantity := label(count, Rect2(rect.position + Vector2(0, rect.size.y - 25), Vector2(rect.size.x - 8, 20)), 14, PAPER, true)
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func show_hub() -> void:
	clear_ui("hub", 0.86)
	header("PREPARE FOR YOUR NEXT RUN", "Your loadout")
	button("Change character", Rect2(962, 117, 230, 48), show_select)
	button("Main menu", Rect2(1206, 117, 186, 48), show_main)
	panel(Rect2(48, 235, 302, 530))
	texture(portraits[chosen], Rect2(68, 255, 75, 75))
	label(CLASS_NAMES[chosen], Rect2(157, 265, 180, 54), 24, PAPER, true)
	line(Vector2(72, 354), 254)
	label("Weapon", Rect2(72, 370, 110, 30), 15, MUTED)
	label("Off-hand", Rect2(196, 370, 125, 30), 15, MUTED)
	var data: Resource = load("res://resources/characters/" + CLASS_IDS[chosen] + ".tres")
	item_slot(data.starting_weapon.resource_path if data.starting_weapon != null else "", Rect2(72, 408, 100, 100))
	item_slot(data.starting_off_hand.resource_path if data.starting_off_hand != null else "", Rect2(196, 408, 100, 100))
	label("Backpack", Rect2(72, 531, 230, 35), 19, PAPER, true)
	for i in 9:
		item_slot("", Rect2(72 + (i % 3) * 70, 560 + (i / 3) * 64, 58, 58))
	label("Stash", Rect2(382, 237, 500, 40), 26, PAPER, true)
	label("Items kept between runs", Rect2(382, 281, 520, 30), 16, MUTED)
	for i in 48:
		item_slot("", Rect2(382 + (i % 8) * 68, 338 + (i / 8) * 68, 60, 60))
	label("Shop", Rect2(968, 237, 420, 40), 26, PAPER, true)
	button("Crafting", Rect2(968, 291, 198, 42), func(): pass, false, true)
	button("Materials", Rect2(1176, 291, 216, 42), func(): pass)
	var book: Resource = load("res://resources/crafting/weapon_recipes.tres")
	var row := 0
	for recipe in book.recipes:
		if row == 3:
			break
		if not data.allows_scene(recipe.item.resource_path):
			continue
		var y := 355 + row * 126
		panel(Rect2(968, y, 424, 112))
		item_slot(recipe.item.resource_path, Rect2(980, y + 13, 82, 82))
		var item_name: String = recipe.item.resource_path.get_file().get_basename().capitalize()
		label(item_name, Rect2(1078, y + 6, 300, 34), 19, PAPER, true)
		var cost: Array[String] = []
		for ingredient in recipe.cost:
			cost.append("%d %s" % [recipe.cost[ingredient], ingredient.replace("Nugget Medium", "").replace("Plank A", "").strip_edges()])
		label(" · ".join(cost), Rect2(1078, y + 40, 300, 24), 14, MUTED)
		button("Craft", Rect2(1278, y + 72, 98, 30), func(): pass)
		row += 1
	line(Vector2(48, 796), 1344)
	label("Empty slots shown for the art review.", Rect2(48, 828, 700, 40), 17, MUTED)
	button("Enter Dungeon  →", Rect2(1110, 824, 282, 52), func(): pass, true)

func capture(filename: String) -> void:
	for frame in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + filename)
	print("UI review: ", filename, " result=", result)
