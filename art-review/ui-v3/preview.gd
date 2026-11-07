extends SceneTree
## Isolated visual review. Run with the Roam project as --path and this as --script.
## No gameplay scenes, inventory or profile data are changed by the preview.

const OUT := "res://art-review/ui-v3/"
const INK := Color("202124")
const SURFACE := Color("292a2d")
const EDGE := Color("45464a")
const PAPER := Color("f0f0f0")
const MUTED := Color("a7a8ac")
const GOLD := Color("f0f0f0")
const CLASS_IDS := ["knight", "barbarian", "mage", "ranger", "rogue", "rogue_hooded"]
const CLASS_NAMES := ["Knight", "Barbarian", "Mage", "Ranger", "Rogue", "Rogue Hooded"]
const WEAPONS := ["Swords, polearms and shields", "Axes, hammers and shields", "Staves and wands", "Bows and crossbows", "Daggers, fist weapons and one-handed crossbows", "Daggers, fist weapons and one-handed crossbows"]

var ui: Control
var world: Node3D
var regular: Font
var heavy: Font
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
	regular = ThemeDB.fallback_font
	heavy = regular
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
	var target := Vector3(0, 1.85 if portrait else 1.2, 0)
	cam.transform = Transform3D(Basis.looking_at(Vector3(-0.15, -0.1, -1)), target + Vector3(0.15, 0.1, 1) * 6)
	view.add_child(cam)
	return view

func clear_ui(screen: String, _dim: float) -> void:
	active_screen = screen
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = INK
	shade.size = Vector2(1440, 900)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

func style(fill: Color, border: Color, thickness := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(thickness)
	box.set_corner_radius_all(2)
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
	var fill := PAPER if primary else (Color("35363a") if selected else Color(0, 0, 0, 0))
	node.add_theme_stylebox_override("normal", style(fill, Color(0, 0, 0, 0), 0))
	node.add_theme_stylebox_override("hover", style(Color("d5d5d5") if primary else Color("35363a"), Color(0, 0, 0, 0), 0))
	node.add_theme_stylebox_override("pressed", style(Color("b9b9b9") if primary else Color("444549"), Color(0, 0, 0, 0), 0))
	node.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), PAPER, 1))
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

func header(_section: String, title: String) -> void:
	label(title, Rect2(48, 90, 900, 60), 30)

func show_main() -> void:
	clear_ui("main", 1)
	label("Roam", Rect2(540, 270, 360, 70), 52, PAPER, false, true)
	button("Play", Rect2(610, 410, 220, 50), show_select, true)
	button("Settings", Rect2(610, 478, 220, 50), func(): pass)
	button("Quit", Rect2(610, 546, 220, 50), func(): quit())

func show_select() -> void:
	clear_ui("select", 1)
	label("Choose your character", Rect2(360, 152, 720, 54), 30, PAPER, false, true)
	for i in CLASS_IDS.size():
		var row := Rect2(380, 286 + i * 60, 250, 48)
		var b := button(CLASS_NAMES[i], row, select_class.bind(i), false, i == chosen)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var character := character_view(CLASS_IDS[chosen], Vector2i(340, 350), false)
	ui.add_child(character)
	texture(character.get_texture(), Rect2(730, 254, 340, 350))
	label(CLASS_NAMES[chosen], Rect2(710, 600, 380, 40), 22, PAPER, false, true)
	var description := label(WEAPONS[chosen], Rect2(700, 644, 400, 60), 17, MUTED, false, true)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button("Back", Rect2(380, 738, 130, 48), show_main)
	button("Continue", Rect2(920, 738, 170, 48), show_hub, true)

func select_class(index: int) -> void:
	chosen = index
	show_select()

func item_slot(path: String, rect: Rect2, count := "") -> void:
	panel(rect, Color("242528"), Color("45464a"))
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
	label(CLASS_NAMES[chosen], Rect2(72, 265, 240, 54), 22)
	label("Weapon", Rect2(72, 370, 110, 30), 15, MUTED)
	label("Off-hand", Rect2(196, 370, 125, 30), 15, MUTED)
	var data: Resource = load("res://resources/characters/" + CLASS_IDS[chosen] + ".tres")
	item_slot(data.starting_weapon.resource_path if data.starting_weapon != null else "", Rect2(72, 408, 100, 100))
	item_slot(data.starting_off_hand.resource_path if data.starting_off_hand != null else "", Rect2(196, 408, 100, 100))
	label("Backpack", Rect2(72, 531, 230, 35), 19, PAPER, true)
	for i in 9:
		item_slot("", Rect2(72 + (i % 3) * 70, 560 + (i / 3) * 64, 58, 58))
	label("Stash", Rect2(382, 237, 500, 40), 26, PAPER, true)
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
		item_slot(recipe.item.resource_path, Rect2(980, y + 13, 82, 82))
		var item_name: String = recipe.item.resource_path.get_file().get_basename().capitalize()
		label(item_name, Rect2(1078, y + 6, 300, 34), 19, PAPER, true)
		var cost: Array[String] = []
		for ingredient in recipe.cost:
			cost.append("%d %s" % [recipe.cost[ingredient], ingredient.replace("Nugget Medium", "").replace("Plank A", "").strip_edges()])
		label(" · ".join(cost), Rect2(1078, y + 40, 300, 24), 14, MUTED)
		button("Craft", Rect2(1278, y + 72, 98, 30), func(): pass)
		row += 1
	button("Enter Dungeon", Rect2(1110, 824, 282, 52), func(): pass, true)

func capture(filename: String) -> void:
	for frame in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + filename)
	print("UI review: ", filename, " result=", result)
