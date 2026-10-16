extends Node3D
class_name DungeonGenerator

## Builds a random dungeon out of DungeonPiece scenes.
##
## Layout: a start room, then branches of 1..max_corridor_chain corridors that each end in a room,
## until room_count rooms exist. Exactly one boss room is then attached to the open exit farthest
## from the start. Rooms never join rooms directly: an open-ended corridor always sits between them.
## Each new piece may only touch the piece it connects to and must keep MIN_GAP from every other
## piece, so walls of neighboring pieces can never overlap. Unused doorways are walled up and unused
## corridor openings capped. Props are thinned out and banners recolored per room.
##
## Pieces come from folders under pieces_dir, scanned on every generate(), so a new scene saved
## into one of them joins the pool with no other setup than its DungeonPiece script, size and exits:
##   rooms/small                  start rooms and fillers; may repeat
##   rooms/medium, rooms/large    unique rooms; each appears at most once per dungeon
##   corridors/small|medium|large open-ended corridor pieces
##   boss                         one is picked per dungeon

signal generated(used_seed: int)

const WALL := preload("res://scenes/dungeon/walls/wall.tscn")
const DOORWAY := preload("res://scenes/dungeon/walls/wall_doorway.tscn")
const ARCHWAY := preload("res://scenes/dungeon/walls/wall_doorway_open.tscn")
const BANNER_COLORS := ["blue", "brown", "green", "red", "white", "yellow"]
## Clearance between pieces that aren't connected; covers wall thickness and pilasters on both sides.
const MIN_GAP := 1.6
## Times an exit may fail to grow a branch before it's given up and sealed.
const MAX_EXIT_FAILURES := 4
## Floor tiles rising higher than this (rocks, raised grates, bones) get no enemies standing on them.
const MAX_SPAWN_FLOOR_BUMP := 0.12

## Seed for the layout; 0 picks a new random seed on every generate().
@export var map_seed := 0
@export var generate_on_ready := true
## Rooms before the boss room, the start room included.
@export_range(2, 30) var room_count := 8
## Most corridors in a row between two rooms.
@export_range(1, 4) var max_corridor_chain := 2
@export_range(1, 100) var max_attempts := 25

@export_group("Pieces")
## Folder holding the rooms/, corridors/ and boss/ piece folders.
@export_dir var pieces_dir := "res://scenes/Rooms"
## Relative odds of each corridor size; shared evenly by the designs in that folder,
## so adding designs to one folder doesn't change how often that size shows up.
@export var corridor_size_weights: Dictionary[String, float] = {"small": 2.0, "medium": 3.0, "large": 1.5}
## Chance each new room is a unique (medium or large) room rather than a small one, while unique rooms remain.
@export_range(0.0, 1.0) var unique_room_chance := 0.75

@export_group("Props")
## Chance to drop each container, loot or small prop (chests and boss rooms are left alone).
@export_range(0.0, 1.0) var prop_removal_chance := 0.3
@export var randomize_banners := true

@export_group("Enemies")
@export var spawn_enemies := true
## Folder of Enemy scenes; bosses go in its boss/ subfolder. Scanned like the piece folders.
@export_dir var enemies_dir := "res://scenes/enemies"
## Enemy threat per 64 m² of floor in a room next to the start.
@export_range(0.0, 4.0) var enemy_density := 1.0
## Extra enemies in the deepest room, as a fraction (1.0 doubles them).
@export_range(0.0, 4.0) var depth_scaling := 1.0
## Chance a small room holds a couple of enemies.
@export_range(0.0, 1.0) var small_room_enemy_chance := 0.5
@export_range(1, 20) var max_enemies_per_room := 6
## Threat of the guards placed alongside the boss.
@export_range(0, 20) var boss_guard_threat := 4
## Enemies keep this far from doorways, so nothing stands in the way in.
@export var doorway_clearance := 3.0
## Closest two enemies may stand to each other.
@export var enemy_spacing := 2.0

## Seed of the current layout.
var last_seed := 0
var start_room: DungeonPiece
var boss_room: DungeonPiece
## The boss room's onward doorway.
var level_exit: Node3D

var _rng := RandomNumberGenerator.new()
var _pieces: Array[DungeonPiece] = []
var _rects := {}  # DungeonPiece -> Rect2 footprint on the XZ plane, in generator space
var _depth := {}  # DungeonPiece -> pieces between it and the start room
var _links := {}  # Marker3D -> the Marker3D it's joined to (stored both ways)
var _open: Array[Marker3D] = []
var _failures := {}  # Marker3D -> failed branch attempts
var _straight := {}  # PackedScene -> whether it's a two-ended straight corridor

# Piece library, rebuilt from pieces_dir on every generate().
var _kinds := {}  # PackedScene -> DungeonPiece.Kind from its folder
var _start_rooms: Array[PackedScene] = []
var _small_rooms: Array[PackedScene] = []
var _unique_rooms: Array[PackedScene] = []
var _boss_rooms: Array[PackedScene] = []
var _corridors: Array[PackedScene] = []
var _corridor_weights: Array[float] = []
var _enemies: Array[PackedScene] = []
var _bosses: Array[PackedScene] = []
var _threat := {}  # PackedScene -> Enemy.threat


func _ready() -> void:
	if generate_on_ready:
		generate()


## Builds a new dungeon, replacing the current one. Returns false if no layout was found.
func generate(new_seed := map_seed) -> bool:
	clear()
	if not _load_library():
		return false
	var base := new_seed if new_seed != 0 else randi()
	for attempt in max_attempts:
		_rng.seed = base + attempt * 7919
		if _build():
			_finish()
			last_seed = base
			generated.emit(base)
			return true
		clear()
	push_error("DungeonGenerator: no layout found for seed %d" % base)
	return false


func clear() -> void:
	for piece in _pieces:
		if is_instance_valid(piece):
			piece.free()
	_pieces.clear()
	_rects.clear()
	_depth.clear()
	_links.clear()
	_open.clear()
	_failures.clear()
	start_room = null
	boss_room = null
	level_exit = null


func get_pieces() -> Array[DungeonPiece]:
	return _pieces


## The piece on the other side of an exit, or null if nothing connects there.
func get_linked_piece(exit: Marker3D) -> DungeonPiece:
	return _owner(_links[exit]) if _links.has(exit) else null


## Where the player should start: the middle of the start room.
func get_spawn_position() -> Vector3:
	return start_room.global_position + Vector3.UP * 0.5 if start_room else global_position


## Footprint of the whole dungeon on the XZ plane, in generator space.
func get_bounds() -> Rect2:
	var bounds := Rect2()
	for i in _pieces.size():
		bounds = _rects[_pieces[i]] if i == 0 else bounds.merge(_rects[_pieces[i]])
	return bounds


# --- Piece library ---

func _load_library() -> bool:
	_kinds.clear()
	_small_rooms = _scan("rooms/small", DungeonPiece.Kind.CONNECTOR)
	_unique_rooms = _scan("rooms/medium", DungeonPiece.Kind.ROOM) + _scan("rooms/large", DungeonPiece.Kind.ROOM)
	_boss_rooms = _scan("boss", DungeonPiece.Kind.BOSS)
	_corridors.clear()
	_corridor_weights.clear()
	for size_name in corridor_size_weights:
		var found := _scan("corridors/" + size_name, DungeonPiece.Kind.CORRIDOR)
		for scene in found:
			_corridors.append(scene)
			_corridor_weights.append(corridor_size_weights[size_name] / found.size())
	# A start room needs at least two ways out.
	_start_rooms = _small_rooms.filter(func(scene): return _exit_count(scene) >= 2)
	var missing: Array[String] = []
	if _start_rooms.is_empty():
		missing.append("rooms/small (with 2+ exits)")
	if _boss_rooms.is_empty():
		missing.append("boss")
	if not _corridors.any(_is_straight):
		missing.append("a straight corridor")
	if not missing.is_empty():
		push_error("DungeonGenerator: no pieces in %s under %s" % [", ".join(missing), pieces_dir])
		return false
	_threat.clear()
	_enemies = _scan_enemies(enemies_dir)
	_bosses = _scan_enemies(enemies_dir.path_join("boss"))
	return true


## Loads every Enemy scene directly in a folder (an empty or missing folder just spawns nothing).
func _scan_enemies(dir: String) -> Array[PackedScene]:
	var found: Array[PackedScene] = []
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for file in ResourceLoader.list_directory(dir):
		if file.get_extension() != "tscn" and file.get_extension() != "scn":
			continue
		var path := dir.path_join(file)
		var scene := load(path) as PackedScene
		var enemy: Node = scene.instantiate() if scene else null
		if enemy is Enemy:
			_threat[scene] = maxi(enemy.threat, 1)
			found.append(scene)
		else:
			push_warning("DungeonGenerator: skipping %s: root has no Enemy script" % path)
		if enemy:
			enemy.free()
	return found


## Loads every valid piece scene in a folder under pieces_dir, tagging it with `kind`.
func _scan(folder: String, kind: DungeonPiece.Kind) -> Array[PackedScene]:
	var dir := pieces_dir.path_join(folder)
	var found: Array[PackedScene] = []
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for file in ResourceLoader.list_directory(dir):
		if file.get_extension() != "tscn" and file.get_extension() != "scn":
			continue
		var path := dir.path_join(file)
		var scene := load(path) as PackedScene
		var problem := _check_piece(scene)
		if problem != "":
			push_warning("DungeonGenerator: skipping %s: %s" % [path, problem])
			continue
		_kinds[scene] = kind
		found.append(scene)
	return found


func _check_piece(scene: PackedScene) -> String:
	if scene == null:
		return "not a scene"
	var node := scene.instantiate()
	var problem := ""
	if not node is DungeonPiece:
		problem = "root has no DungeonPiece script"
	elif node.size.x <= 0.0 or node.size.y <= 0.0:
		problem = "size is not set"
	elif node.get_exits().is_empty():
		problem = "no Marker3D exits under an Exits node"
	node.free()
	return problem


func _exit_count(scene: PackedScene) -> int:
	var piece := _spawn(scene)
	var count := piece.get_exits().size()
	piece.free()
	return count


# --- Layout ---

func _build() -> bool:
	var unused_rooms := _shuffled(_unique_rooms)
	start_room = _spawn(_pick(_start_rooms))
	start_room.transform = Transform3D(_yaw_basis(_rng.randi_range(0, 3)), Vector3.ZERO)
	_place(start_room, null)
	_open.append_array(_free_exits(start_room))

	var placed := 1
	while placed < room_count:
		if _open.is_empty():
			return false
		var socket: Marker3D = _open[_rng.randi() % _open.size()]
		var use_unique := not unused_rooms.is_empty() and _rng.randf() < unique_room_chance
		var scene: PackedScene = unused_rooms.back() if use_unique else _pick(_small_rooms)
		if _branch(socket, scene):
			placed += 1
			if use_unique:
				unused_rooms.pop_back()
		else:
			_fail(socket)

	# The boss goes as deep into the dungeon as it will fit.
	var sockets := _open.duplicate()
	sockets.sort_custom(func(a, b): return _depth[_owner(a)] > _depth[_owner(b)])
	var boss_scene := _pick(_boss_rooms)
	for socket in sockets:
		boss_room = _branch(socket, boss_scene)
		if boss_room:
			return true
	return false


## Grows corridors from `socket` and ends them in a room built from `room_scene`.
## Everything placed is rolled back if the room doesn't fit.
func _branch(socket: Marker3D, room_scene: PackedScene) -> DungeonPiece:
	var added: Array[DungeonPiece] = []
	var current := socket
	for _i in _rng.randi_range(1, max_corridor_chain):
		# Leaving a room, a corridor has to run straight out, or it would hug the room's wall.
		var straight_only := _owner(current).is_room()
		var corridor := _attach(current, _corridor_order(straight_only), added)
		if corridor == null:
			break
		var onward := _free_exits(corridor)
		if onward.is_empty():
			break
		current = onward[_rng.randi() % onward.size()]
	if _owner(current).is_room():
		_rollback(added)
		return null
	var room := _attach(current, [room_scene], added)
	if room == null:
		_rollback(added)
		return null
	_open.erase(socket)
	for piece in added:
		_open.append_array(_free_exits(piece))
	return room


## Joins the first of `scenes` that fits onto `socket`, trying each of its exits.
func _attach(socket: Marker3D, scenes: Array, added: Array[DungeonPiece]) -> DungeonPiece:
	var neighbor := _owner(socket)
	for scene in scenes:
		var piece := _spawn(scene)
		for exit in _shuffled(piece.get_exits().filter(_connectable)):
			piece.transform = _mate(socket, exit)
			if _fits(_footprint(piece), neighbor):
				_place(piece, neighbor)
				_links[socket] = exit
				_links[exit] = socket
				added.append(piece)
				return piece
		piece.free()
	return null


func _rollback(added: Array[DungeonPiece]) -> void:
	for piece in added:
		for exit in piece.get_exits():
			if _links.has(exit):
				_links.erase(_links[exit])
				_links.erase(exit)
		_pieces.erase(piece)
		_rects.erase(piece)
		_depth.erase(piece)
		piece.free()


func _place(piece: DungeonPiece, neighbor: DungeonPiece) -> void:
	_pieces.append(piece)
	_rects[piece] = _footprint(piece)
	_depth[piece] = _depth[neighbor] + 1 if neighbor else 0


func _fail(socket: Marker3D) -> void:
	_failures[socket] = _failures.get(socket, 0) + 1
	if _failures[socket] >= MAX_EXIT_FAILURES:
		_open.erase(socket)


## Transform that puts `exit` of a new piece on `socket`, facing it.
func _mate(socket: Marker3D, exit: Marker3D) -> Transform3D:
	var target := _owner(socket).transform * socket.transform
	var out := target.basis.z
	var local_out := exit.transform.basis.z
	var yaw := atan2(-out.x, -out.z) - atan2(local_out.x, local_out.z)
	var turn := _yaw_basis(roundi(yaw / (PI / 2.0)))
	var origin := target.origin - turn * exit.position
	return Transform3D(turn, origin.snapped(Vector3(0.5, 0.0, 0.5)))


## A new piece may only touch the piece it joins, and must keep MIN_GAP from everything else.
func _fits(rect: Rect2, neighbor: DungeonPiece) -> bool:
	for piece in _pieces:
		var other: Rect2 = _rects[piece]
		if piece == neighbor:
			if rect.grow(-0.1).intersects(other):
				return false
		elif rect.grow(MIN_GAP).intersects(other):
			return false
	return true


func _footprint(piece: DungeonPiece) -> Rect2:
	var half := piece.size / 2.0
	var a := piece.transform * Vector3(-half.x, 0, -half.y)
	var b := piece.transform * Vector3(half.x, 0, half.y)
	return Rect2(minf(a.x, b.x), minf(a.z, b.z), absf(a.x - b.x), absf(a.z - b.z))


## Corridors in weighted random order; only two-ended straight ones if `straight_only`.
func _corridor_order(straight_only: bool) -> Array[PackedScene]:
	var pool: Array[PackedScene] = []
	var weights: Array[float] = []
	for i in _corridors.size():
		if straight_only and not _is_straight(_corridors[i]):
			continue
		pool.append(_corridors[i])
		weights.append(_corridor_weights[i])
	var order: Array[PackedScene] = []
	while not pool.is_empty():
		var i := _rng.rand_weighted(PackedFloat32Array(weights))
		order.append(pool[i])
		pool.remove_at(i)
		weights.remove_at(i)
	return order


func _is_straight(scene: PackedScene) -> bool:
	if not _straight.has(scene):
		var piece := _spawn(scene)
		var exits := piece.get_exits()
		_straight[scene] = exits.size() == 2 and exits[0].basis.z.dot(exits[1].basis.z) < -0.9
		piece.free()
	return _straight[scene]


# --- Finishing ---

func _finish() -> void:
	var deepest := 1
	for piece in _pieces:
		deepest = maxi(deepest, _depth[piece])
	for piece in _pieces:
		for exit in piece.get_exits():
			if _links.has(exit):
				if exit.has_meta("doorway"):
					_fit_doorway(piece, exit, DOORWAY if piece.has_doors else ARCHWAY)
				continue
			if exit.name == "LevelExit":
				level_exit = piece.get_node(exit.get_meta("doorway"))
			else:
				_seal(piece, exit)
		if piece.is_room():
			_vary_props(piece, piece.kind != DungeonPiece.Kind.BOSS)
			if spawn_enemies and piece != start_room:
				_populate(piece, float(_depth[piece]) / deepest)
		add_child(piece, true)


# --- Enemies ---

## All enemies in the dungeon.
func get_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for piece in _pieces:
		var group := piece.get_node_or_null("Enemies")
		if group:
			for enemy in group.get_children():
				out.append(enemy)
	return out


## Fills a room with enemies; `depth` runs from 0 next to the start to 1 at the deepest room.
func _populate(piece: DungeonPiece, depth: float) -> void:
	var budget := 0
	match piece.kind:
		DungeonPiece.Kind.CONNECTOR:
			if _rng.randf() < small_room_enemy_chance:
				budget = _rng.randi_range(1, 2)
		DungeonPiece.Kind.ROOM:
			var area := piece.size.x * piece.size.y
			budget = roundi(area / 64.0 * enemy_density * (1.0 + depth_scaling * depth) * _rng.randf_range(0.75, 1.25))
		DungeonPiece.Kind.BOSS:
			budget = boss_guard_threat
	var spots := _spawn_spots(piece)
	var facing := _arrival_point(piece)
	var placed: Array[Vector3] = []
	if piece.kind == DungeonPiece.Kind.BOSS and not _bosses.is_empty():
		# The boss takes the open spot nearest the middle of the room, with extra room around it.
		var roomy := _spawn_spots(piece, 1.6)
		if not roomy.is_empty():
			roomy.sort_custom(func(a, b): return a.length() < b.length())
			_place_enemy(piece, _pick(_bosses), roomy[0], facing)
			placed.append(roomy[0])
	var count := 0
	while budget > 0 and count < max_enemies_per_room:
		var affordable := _enemies.filter(func(e): return _threat[e] <= budget)
		if affordable.is_empty():
			break
		var spot := _free_spot(spots, placed)
		if spot == Vector3.INF:
			break
		var scene: PackedScene = affordable[_rng.randi() % affordable.size()]
		_place_enemy(piece, scene, spot, facing)
		placed.append(spot)
		budget -= _threat[scene]
		count += 1


func _place_enemy(piece: DungeonPiece, scene: PackedScene, spot: Vector3, facing: Vector3) -> void:
	var group := piece.get_node_or_null("Enemies")
	if group == null:
		group = Node3D.new()
		group.name = "Enemies"
		piece.add_child(group)
	var enemy: Node3D = scene.instantiate()
	var look := facing - spot
	enemy.position = spot
	enemy.rotation.y = atan2(look.x, look.z) + _rng.randf_range(-0.4, 0.4)
	group.add_child(enemy, true)


## A random spot at least enemy_spacing from those already taken (spots are used up), or INF.
func _free_spot(spots: Array[Vector3], taken: Array[Vector3]) -> Vector3:
	while not spots.is_empty():
		var spot: Vector3 = spots.pop_at(_rng.randi() % spots.size())
		if taken.all(func(t): return t.distance_to(spot) >= enemy_spacing):
			return spot
	return Vector3.INF


## Where the player comes in: the doorway joined to the piece nearer the start.
func _arrival_point(piece: DungeonPiece) -> Vector3:
	for exit in piece.get_exits():
		if _links.has(exit) and _depth[_owner(_links[exit])] < _depth[piece]:
			return exit.position
	return Vector3.ZERO


## Open floor spots in a room (piece space, 1m apart) that an enemy can stand on: clear of walls,
## props and pillars by `clearance`, back from every doorway, and reachable from where the
## player comes in, so nothing spawns shut in a cell or behind a wall of crates.
func _spawn_spots(piece: DungeonPiece, clearance := 0.9) -> Array[Vector3]:
	var obstacles: Array[Rect2] = []
	for group in piece.get_children():
		if group.name in ["Floors", "Exits", "Enemies"]:
			continue
		for node in group.get_children():
			# Props sit one level deeper, in Props/<kind>/.
			for part in (node.get_children() if group.name == "Props" else [node]):
				if part is Node3D:
					obstacles.append(_bounds_in(part, piece))
	# Rocks, raised grates, bones and spikes: walkable, but feet would sink into them.
	var uneven: Array[Rect2] = []
	for tile in piece.get_node("Floors").get_children():
		if _top_height(tile) > MAX_SPAWN_FLOOR_BUMP:
			uneven.append(_bounds_in(tile, piece))
	var half := piece.size / 2.0
	var walk := {}
	for x in range(-int(half.x) + 1, int(half.x)):
		for z in range(-int(half.y) + 1, int(half.y)):
			var p := Vector2(x, z)
			if absf(p.x) <= half.x - 1.0 and absf(p.y) <= half.y - 1.0 and not obstacles.any(func(r): return r.grow(0.4).has_point(p)):
				walk[Vector2i(x, z)] = true
	# Flood from just inside each joined doorway.
	var reached := {}
	var stack: Array[Vector2i] = []
	for exit in piece.get_exits():
		if _links.has(exit) or exit.name == "LevelExit":
			var inside := exit.position - exit.basis.z * 1.5
			var c := Vector2i(roundi(inside.x), roundi(inside.z))
			if walk.has(c) and not reached.has(c):
				reached[c] = true
				stack.append(c)
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if walk.has(n) and not reached.has(n):
				reached[n] = true
				stack.append(n)
	var spots: Array[Vector3] = []
	for c in reached:
		var p := Vector2(c.x, c.y)
		if absf(p.x) > half.x - 0.5 - clearance or absf(p.y) > half.y - 0.5 - clearance:
			continue
		if obstacles.any(func(r): return r.grow(clearance).has_point(p)):
			continue
		if uneven.any(func(r): return r.grow(0.5).has_point(p)):
			continue
		if piece.get_exits().any(func(e): return Vector2(e.position.x, e.position.z).distance_to(p) < doorway_clearance):
			continue
		spots.append(Vector3(p.x, 0.0, p.y))
	return spots


## Swaps the doorway an exit opens through for `scene` (door or open archway), if it isn't one already.
## The replacement keeps the doorway's name, so the exit's "doorway" path still finds it.
func _fit_doorway(piece: DungeonPiece, exit: Marker3D, scene: PackedScene) -> void:
	var doorway: Node3D = piece.get_node(exit.get_meta("doorway"))
	if doorway.scene_file_path == scene.resource_path:
		return
	_replace(doorway, scene.instantiate(), doorway.name)


## Walls up an unused doorway, or caps an unused corridor opening.
func _seal(piece: DungeonPiece, exit: Marker3D) -> void:
	var wall: Node3D = WALL.instantiate()
	if exit.has_meta("doorway"):
		var doorway: Node3D = piece.get_node(exit.get_meta("doorway"))
		_replace(doorway, wall, "Sealed" + doorway.name)
	else:
		# The opening's marker faces out; turn the wall so its front faces into the corridor.
		wall.transform = Transform3D(exit.basis.rotated(Vector3.UP, PI), exit.position)
		wall.name = "Cap" + exit.name
		piece.get_node("Walls").add_child(wall)


func _vary_props(piece: DungeonPiece, allow_removal: bool) -> void:
	var props := piece.get_node_or_null("Props")
	if props == null:
		return
	var color: String = BANNER_COLORS[_rng.randi() % BANNER_COLORS.size()]
	var all_props: Array[Node3D] = []
	for group in props.get_children():
		for prop in group.get_children():
			all_props.append(prop)
	var supporting := _supporting_props(all_props)
	for prop in all_props:
		var path: String = prop.scene_file_path
		if randomize_banners and path.contains("/banners/"):
			_recolor_banner(prop, color)
		elif allow_removal and _removable(path) and not supporting.has(prop) and _rng.randf() < prop_removal_chance:
			prop.free()


## Props with another prop resting on top of them; removing one would leave the other floating.
func _supporting_props(props: Array[Node3D]) -> Dictionary:
	var supporting := {}
	for top in props:
		if top.position.y < 0.3:
			continue
		var spot := Vector2(top.position.x, top.position.z)
		for base in props:
			if base != top and base.position.y < top.position.y - 0.3 and _xz_bounds(base).grow(0.05).has_point(spot):
				supporting[base] = true
	return supporting


## A prop's mesh bounds on the XZ plane, in its parent's space.
func _xz_bounds(prop: Node3D) -> Rect2:
	return _bounds_in(prop, prop.get_parent())


## A node's mesh bounds on the XZ plane, in the space of its ancestor `space`.
## Works on pieces that aren't in the scene tree yet.
func _bounds_in(node: Node3D, space: Node) -> Rect2:
	var origin := _transform_in(node, space).origin
	var bounds := Rect2(origin.x, origin.z, 0, 0)
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = _transform_in(mesh, space) * mesh.get_aabb()
		bounds = bounds.merge(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
	return bounds


## Highest point of a node's meshes, relative to the node.
func _top_height(node: Node3D) -> float:
	var top := 0.0
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = _transform_in(mesh, node) * mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top


func _transform_in(node: Node3D, space: Node) -> Transform3D:
	var xform := Transform3D()
	var current: Node = node
	while current != space:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


func _removable(path: String) -> bool:
	if path.contains("chest"):
		return false
	return path.contains("/containers/") or path.contains("/loot/") or path.contains("/props/")


func _recolor_banner(banner: Node3D, color: String) -> void:
	var base := banner.scene_file_path.get_basename()
	var path := "%s_%s.tscn" % [base.substr(0, base.rfind("_")), color]
	if path == banner.scene_file_path or not ResourceLoader.exists(path):
		return
	_replace(banner, load(path).instantiate(), banner.name)


## Puts `replacement` where `node` was (same parent, transform and order) and frees `node`.
func _replace(node: Node3D, replacement: Node3D, new_name: String) -> void:
	var parent := node.get_parent()
	var index := node.get_index()
	replacement.transform = node.transform
	node.free()
	replacement.name = new_name
	parent.add_child(replacement)
	parent.move_child(replacement, index)


# --- Helpers ---

## Instances a piece; its kind comes from the folder it was found in.
func _spawn(scene: PackedScene) -> DungeonPiece:
	var piece := scene.instantiate() as DungeonPiece
	if _kinds.has(scene):
		piece.kind = _kinds[scene]
	return piece


func _owner(exit: Marker3D) -> DungeonPiece:
	return exit.get_parent().get_parent() as DungeonPiece


func _connectable(exit: Marker3D) -> bool:
	return exit.name != "LevelExit"


func _free_exits(piece: DungeonPiece) -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for exit in piece.get_exits():
		if not _links.has(exit) and _connectable(exit):
			out.append(exit)
	return out


## Basis for a yaw of quarter_turns * 90 degrees, built exactly so positions stay on the grid.
func _yaw_basis(quarter_turns: int) -> Basis:
	var c: float = [1, 0, -1, 0][posmod(quarter_turns, 4)]
	var s: float = [0, 1, 0, -1][posmod(quarter_turns, 4)]
	return Basis(Vector3(c, 0, -s), Vector3.UP, Vector3(s, 0, c))


func _pick(scenes: Array[PackedScene]) -> PackedScene:
	return scenes[_rng.randi() % scenes.size()]


func _shuffled(items: Array) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out
