extends SceneTree

## Checks dungeon pieces and generated dungeons for layout, geometry and gameplay bugs.
## Run: godot --headless --path . --script res://tests/dungeon_check.gd [-- --maps=N]
## Exits with code 1 if anything fails.

const PIECES_DIR := "res://scenes/Rooms"
const PIECE_FOLDERS := ["start", "rooms/small", "rooms/medium", "rooms/large", "corridors/small", "corridors/medium", "corridors/large", "boss"]
const GENERATOR := preload("res://scripts/dungeon_generator.gd")
const DOOR := preload("res://scripts/door.gd")

# The widest (ranger, rogues) and tallest (knight) character capsules in scenes/characters;
# a spot is walkable only if both fit. Their bottoms float a little above the floor so
# floor bumps a character steps over don't count as blocking.
const CAPSULES := [Vector2(0.51, 2.27), Vector2(0.44, 2.54)]
const CAPSULE_LIFT := 0.12
const GRID := 0.5
# Below this the floor counts as missing.
const HOLE_DEPTH := -0.3
# Wall meshes from different pieces overlapping by more than this many m3 are doubled walls.
const WALL_OVERLAP_LIMIT := 2.5
# Wall-mounted props, identified by scene path.
const MOUNTED := ["/banners/", "torch_mounted", "sword_shield", "keyring_hanging", "shelf", "shelves"]
# How far a prop may sink into something solid before it counts as clipping.
const CLIP_TOLERANCE := 0.08

var _failures: Array[String] = []
var _space: PhysicsDirectSpaceState3D
var _holder: Node3D
var _single := false
var _capsule_queries: Array[PhysicsShapeQueryParameters3D] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var maps := 25
	var only_seed := 0
	var only_rooms := 8
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--maps="):
			maps = arg.trim_prefix("--maps=").to_int()
		elif arg.begins_with("--seed="):
			only_seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--rooms="):
			only_rooms = arg.trim_prefix("--rooms=").to_int()
	_holder = Node3D.new()
	root.add_child(_holder)
	_space = _holder.get_world_3d().direct_space_state

	# --seed=N [--rooms=M] checks just that one dungeon.
	_single = only_seed != 0
	if only_seed != 0:
		await _check_dungeon(only_seed, only_rooms)
		_report()
		return

	print("== Pieces")
	for scene in _all_piece_scenes():
		await _check_piece(scene)
	print("== Enemies")
	await _check_enemy_scenes()
	print("== Generator")
	await _check_generator()
	print("== Generated dungeons (%d)" % maps)
	for i in maps:
		await _check_dungeon(1000 + i * 37, [5, 8, 12][i % 3])
	_report()


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d PROBLEMS" % _failures.size())
		for f in _failures:
			print("  - ", f)
	quit(0 if _failures.is_empty() else 1)


func _fail(msg: String) -> void:
	_failures.append(msg)


# --- Single pieces ---

func _all_piece_scenes() -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for folder in PIECE_FOLDERS:
		var dir := PIECES_DIR.path_join(folder)
		for file in ResourceLoader.list_directory(dir):
			if file.get_extension() == "tscn":
				out.append(load(dir.path_join(file)))
	return out


func _check_piece(scene: PackedScene) -> void:
	var path := scene.resource_path
	var piece := scene.instantiate()
	if not piece is DungeonPiece:
		_fail("%s: no DungeonPiece script" % path)
		piece.free()
		return
	_holder.add_child(piece)
	var tag := path.trim_prefix(PIECES_DIR + "/")
	var rect := Rect2(-piece.size / 2.0, piece.size)

	# Exits sit on the footprint edge, face straight out, and room exits point at a doorway there.
	var doorways_used := {}
	for exit in piece.get_exits():
		var p := Vector2(exit.position.x, exit.position.z)
		var out := Vector2(exit.basis.z.x, exit.basis.z.z)
		var on_edge := is_equal_approx(absf(p.x), rect.end.x) or is_equal_approx(absf(p.y), rect.end.y)
		if not on_edge or not rect.grow(0.01).has_point(p):
			_fail("%s: exit %s at %s is not on the footprint edge" % [tag, exit.name, p])
		if not rect.has_point(p - out * 0.5) or rect.has_point(p + out * 0.5):
			_fail("%s: exit %s does not face outward" % [tag, exit.name])
		if piece.kind != DungeonPiece.Kind.CORRIDOR or exit.has_meta("doorway"):
			if not exit.has_meta("doorway") or not piece.has_node(exit.get_meta("doorway")):
				_fail("%s: exit %s has no valid doorway meta" % [tag, exit.name])
				continue
			var door: Node3D = piece.get_node(exit.get_meta("doorway"))
			doorways_used[door] = true
			if door.position.distance_to(exit.position) > 0.01:
				_fail("%s: exit %s is not at its doorway" % [tag, exit.name])
	for door in piece.find_children("*", "", true, false):
		if door.scene_file_path.contains("wall_doorway") and not doorways_used.has(door):
			_fail("%s: doorway %s has no exit marker" % [tag, door.name])

	_open_doors(piece)
	for _i in 3:
		await physics_frame
	await _check_door_swings(piece, tag)
	_check_props(piece, tag)
	# Every exit is reachable from every other on foot.
	var walk := _walkable_cells([rect])
	var targets := {}
	for exit in piece.get_exits():
		targets[exit.name] = _cell(exit.position - exit.basis.z * 1.25)
	if not targets.is_empty():
		var start: Vector2i = targets.values()[0]
		var reached := _flood(walk.walkable, start)
		for name in targets:
			if not reached.has(targets[name]):
				_fail("%s: exit %s can't be reached on foot from %s" % [tag, name, targets.keys()[0]])
	for c in walk.holes:
		_fail("%s: hole in the floor at %s" % [tag, _world(c)])
		break
	piece.free()
	await physics_frame


func _open_doors(node: Node) -> void:
	for door in node.find_children("*", "", true, false):
		if door is DOOR:
			var leaf: Node3D = door.get_node(door.leaf_path)
			leaf.rotation.y = -deg_to_rad(door.open_angle)


## Swings each door through its arc and reports anything the leaf would hit.
func _check_door_swings(piece: Node3D, tag: String) -> void:
	for door in piece.find_children("*", "", true, false):
		if not door is DOOR:
			continue
		var leaf: Node3D = door.get_node(door.leaf_path)
		var body: CollisionObject3D = leaf.find_children("*", "CollisionObject3D", true, false)[0]
		var shape_node: CollisionShape3D = body.find_children("*", "CollisionShape3D", true, false)[0]
		var exclude: Array[RID] = []
		for b in door.find_children("*", "CollisionObject3D", true, false):
			exclude.append(b.get_rid())
		var leaf_visual := _visual_aabb(leaf)
		for angle in [30.0, 60.0, door.open_angle]:
			leaf.rotation.y = -deg_to_rad(angle)
			# The leaf's bottom 12cm may brush low floor bumps; rocky tiles stand far taller.
			var q := PhysicsShapeQueryParameters3D.new()
			var box := BoxShape3D.new()
			box.size = (shape_node.shape as BoxShape3D).size - Vector3(0.1, 0.24, 0.1)
			q.shape = box
			q.transform = shape_node.global_transform.translated(Vector3(0, 0.12, 0))
			q.exclude = exclude
			for hit in _space.intersect_shape(q, 8):
				_fail("%s: %s hits %s when %d deg open" % [tag, door.name, _describe(hit.collider), angle])
			# Props without collision in the swing.
			var swing := _visual_aabb(leaf).grow(-0.1)
			for prop in _props(piece):
				if not _has_collision(prop) and not _is_mounted(prop) and swing.intersects(_visual_aabb(prop)):
					_fail("%s: %s swings through %s" % [tag, door.name, prop.name])
		leaf.rotation.y = -deg_to_rad(door.open_angle)
		if leaf_visual.size == Vector3.ZERO:
			_fail("%s: %s leaf has no mesh" % [tag, door.name])


## Props must not sink into walls or other solid things, must rest on something and,
## if wall-mounted, must have a wall behind them.
func _check_props(piece: Node3D, tag: String) -> void:
	var props := _props(piece)
	var floor_bodies := _bodies_under(piece.get_node_or_null("Floors"))
	for prop in props:
		var box := _visual_aabb(prop)
		if box.size == Vector3.ZERO:
			continue
		if _is_mounted(prop):
			var forward: Vector3 = prop.global_basis.z
			var from := box.get_center() + forward * 0.8
			var hit := _ray(from, box.get_center() - forward * 1.2)
			if hit.is_empty():
				_fail("%s: %s is mounted on nothing" % [tag, prop.name])
			continue
		var elevated := box.position.y > 0.2
		if elevated:
			var bottom := Vector3(box.get_center().x, box.position.y + 0.05, box.get_center().z)
			if _ray(bottom, bottom - Vector3(0, 0.3, 0)).is_empty():
				_fail("%s: %s floats at y=%.2f" % [tag, prop.name, box.position.y])
		var exclude: Array[RID] = floor_bodies.duplicate()
		exclude.append_array(_bodies_under(prop))
		var clip := _deepest_clip(prop, box.get_center(), exclude)
		if clip.depth > CLIP_TOLERANCE:
			_fail("%s: %s sinks %.2fm into %s" % [tag, prop.name, clip.depth, clip.into])
	# Props without collision overlapping each other.
	for i in props.size():
		var a: Node3D = props[i]
		if _has_collision(a) or _is_mounted(a):
			continue
		var ab := _visual_aabb(a)
		for j in range(i + 1, props.size()):
			var b: Node3D = props[j]
			if _has_collision(b) or _is_mounted(b):
				continue
			var bb := _visual_aabb(b)
			var overlap := ab.intersection(bb)
			var smaller := minf(ab.get_volume(), bb.get_volume())
			if smaller > 0.0 and overlap.get_volume() > smaller * 0.4:
				_fail("%s: %s overlaps %s" % [tag, a.name, b.name])


# --- Enemy scenes ---

## Each enemy scene has the Enemy script and a real idle animation, holds every weapon it
## attaches (visible), and leaves no collision switched on besides its own capsule.
func _check_enemy_scenes() -> void:
	var dirs := ["res://scenes/enemies", "res://scenes/enemies/boss"]
	for dir in dirs:
		for file in ResourceLoader.list_directory(dir):
			if file.get_extension() != "tscn":
				continue
			var path: String = dir.path_join(file)
			var enemy: Node = load(path).instantiate()
			if not enemy is Enemy:
				_fail("%s: no Enemy script" % path)
				enemy.free()
				continue
			_holder.add_child(enemy)
			await process_frame
			for animation in [enemy.idle_animation, enemy.walk_animation, enemy.run_animation, enemy.fall_animation]:
				if not enemy.animation_player.has_animation(animation):
					_fail("%s: animation %s doesn't exist" % [path, animation])
			for slot in enemy.find_children("Handslot*", "BoneAttachment3D", true, false):
				var meshes: Array = slot.find_children("*", "MeshInstance3D", true, false)
				if meshes.is_empty() or not meshes.all(func(m): return m.is_visible_in_tree()):
					_fail("%s: %s holds no visible weapon" % [path, slot.name])
			for body in enemy.find_children("*", "CollisionObject3D", true, false):
				if body.collision_layer != 0 or body.collision_mask != 0:
					_fail("%s: %s still collides" % [path, body.name])
			print("  %s: threat %d" % [path.get_file(), enemy.threat])
			enemy.free()


# --- Generator behavior ---

func _check_generator() -> void:
	# Same seed, same dungeon.
	var a := _new_generator(8)
	a.generate(777)
	var sig_a := _signature(a)
	a.generate(778)
	a.generate(777)
	if _signature(a) != sig_a:
		_fail("generator: seed 777 gave a different dungeon the second time")
	a.free()

	# Regenerating doesn't leak nodes.
	var gen := _new_generator(8)
	gen.generate(1)
	await process_frame
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for s in range(2, 40):
		gen.generate(s)
	gen.generate(1)
	await process_frame
	var after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans_after := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	if after != before or orphans_after != orphans_before:
		_fail("generator: node count %d -> %d, orphans %d -> %d after regenerating" % [before, after, orphans_before, orphans_after])
	gen.free()

	# Extreme settings finish quickly and either work or fail cleanly.
	for setting in [{"room_count": 2}, {"room_count": 30}, {"max_corridor_chain": 4, "room_count": 12}]:
		var g := _new_generator(8)
		for key in setting:
			g.set(key, setting[key])
		var t := Time.get_ticks_msec()
		var ok: bool = g.generate(5)
		var ms := Time.get_ticks_msec() - t
		print("  %s -> %s in %d ms (%d pieces)" % [setting, "ok" if ok else "no layout", ms, g.get_pieces().size()])
		if ms > 10000:
			_fail("generator: %s took %d ms" % [setting, ms])
		if ok and g.get_pieces().filter(func(p): return p.kind == DungeonPiece.Kind.BOSS).size() != 1:
			_fail("generator: %s did not place exactly one boss room" % [setting])
		g.free()

	# A broken scene in a piece folder is skipped, not fatal.
	var bad_path := PIECES_DIR.path_join("rooms/small/_test_broken_piece.tscn")
	var bad := PackedScene.new()
	var bad_root := Node3D.new()
	bad.pack(bad_root)
	bad_root.free()
	ResourceSaver.save(bad, bad_path)
	var g2 := _new_generator(6)
	if not g2.generate(9):
		_fail("generator: a broken scene in rooms/small stopped generation")
	g2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))

	# A missing folder fails cleanly.
	var g3 := _new_generator(6)
	g3.pieces_dir = "res://does_not_exist"
	if g3.generate(3):
		_fail("generator: generated with no pieces")
	g3.free()


func _new_generator(room_count: int) -> Node3D:
	var gen: Node3D = GENERATOR.new()
	gen.generate_on_ready = false
	gen.room_count = room_count
	_holder.add_child(gen)
	return gen


func _signature(gen: Node3D) -> String:
	var parts: PackedStringArray = []
	for p in gen.get_pieces():
		parts.append("%s@%s" % [p.scene_file_path, p.transform])
		for prop in _props(p):
			parts.append(prop.scene_file_path)
		var enemies: Node = p.get_node_or_null("Enemies")
		if enemies:
			for e in enemies.get_children():
				parts.append("%s@%s" % [e.scene_file_path, e.transform])
	return "|".join(parts)


# --- Whole dungeons ---

func _check_dungeon(seed_value: int, room_count: int) -> void:
	var gen := _new_generator(room_count)
	if not gen.generate(seed_value):
		_fail("dungeon %d: generation failed" % seed_value)
		gen.free()
		return
	var tag := "dungeon %d (%d rooms)" % [seed_value, room_count]
	var pieces: Array = gen.get_pieces()

	# Doors only in rooms flagged has_doors; their connected doorways all get one.
	for p in pieces:
		var doors: Array = p.find_children("*", "", true, false).filter(func(n): return n is DOOR)
		if not p.has_doors and not doors.is_empty():
			_fail("%s: %s has %d doors but isn't flagged has_doors" % [tag, p.name, doors.size()])
		if p.has_doors:
			for exit in p.get_exits():
				if exit.has_meta("doorway") and (gen._links.has(exit) or exit.name == "LevelExit"):
					if not p.get_node(exit.get_meta("doorway")) is DOOR:
						_fail("%s: %s.%s has no door" % [tag, p.name, exit.name])
	_open_doors(gen)
	for _i in 3:
		await physics_frame

	# Wall and floor meshes of different pieces must not overlap.
	var meshes := []
	for p in pieces:
		for group in ["Walls", "Floors"]:
			var g: Node = p.get_node_or_null(group)
			if g == null:
				continue
			for part in g.get_children():
				meshes.append([p, group, part, _visual_aabb(part)])
	for i in meshes.size():
		for j in range(i + 1, meshes.size()):
			var a: Array = meshes[i]
			var b: Array = meshes[j]
			if a[0] == b[0] or a[1] != b[1]:
				continue
			var overlap: AABB = a[3].intersection(b[3])
			if a[1] == "Walls" and overlap.get_volume() > WALL_OVERLAP_LIMIT:
				_fail("%s: walls overlap: %s/%s and %s/%s" % [tag, a[0].name, a[2].name, b[0].name, b[2].name])
			elif a[1] == "Floors" and overlap.size.x > 0.05 and overlap.size.z > 0.05:
				_fail("%s: floors overlap: %s/%s and %s/%s" % [tag, a[0].name, a[2].name, b[0].name, b[2].name])

	# Props after random removal still rest on something.
	for p in pieces:
		_check_props(p, "%s %s" % [tag, p.name])

	# The Compatibility renderer drops lights past a per-mesh limit, which shows as popping.
	var limit: int = ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object", 8)
	var lights: Array = gen.find_children("*", "OmniLight3D", true, false)
	var worst := 0
	for m in meshes:
		var box: AABB = m[3]
		var count := 0
		for l in lights:
			var reach: float = l.omni_range
			var closest: Vector3 = l.global_position.clamp(box.position, box.end)
			if closest.distance_to(l.global_position) < reach:
				count += 1
		worst = maxi(worst, count)
		if count > limit:
			_fail("%s: %s/%s is lit by %d lights (limit %d)" % [tag, m[0].name, m[2].name, count, limit])
	print("  %s: %d lights, at most %d on one mesh" % [tag, lights.size(), worst])

	# Walk the whole dungeon from the spawn point.
	var rects: Array[Rect2] = []
	for p in pieces:
		rects.append(gen._rects[p])
	var walk := _walkable_cells(rects)
	var spawn: Vector3 = gen.get_spawn_position()
	var start := _nearest_walkable(walk.walkable, _cell(spawn))
	var reached := _flood(walk.walkable, start)
	for p in pieces:
		for exit in p.get_exits():
			var t: Transform3D = p.transform * exit.transform
			var inside := _cell(t.origin - t.basis.z * 1.25)
			var linked: bool = gen._links.has(exit)
			if (linked or exit.name == "LevelExit") and not reached.has(inside):
				_fail("%s: can't walk to %s.%s from the start" % [tag, p.name, exit.name])
				_print_area(walk.walkable, reached, inside, 40 if _single else 14)
	_check_enemies(gen, tag, walk.walkable, reached)
	var leaks := 0
	for c in reached:
		var pt := Vector2(c.x, c.y) * GRID
		if not rects.any(func(r: Rect2): return r.grow(0.3).has_point(pt)):
			leaks += 1
	if leaks > 0:
		_fail("%s: %d walkable spots outside the dungeon (hole in a wall)" % [tag, leaks])
	for c in walk.holes:
		_fail("%s: hole in the floor at %s" % [tag, _world(c)])
		break
	print("  %s: %d pieces, %d/%d floor cells reachable" % [tag, pieces.size(), reached.size(), walk.walkable.size()])
	gen.free()
	await physics_frame


## Enemies: none in the start room or corridors, one boss per boss room, each standing on open
## floor without overlapping anything, clear of doorways, apart from each other, and reachable
## on foot. (They stay solid during the walk check, so one blocking a route fails that check.)
func _check_enemies(gen: Node3D, tag: String, walkable: Dictionary, reached: Dictionary) -> void:
	var total := 0
	for p in gen.get_pieces():
		var group: Node = p.get_node_or_null("Enemies")
		var enemies: Array = group.get_children() if group else []
		total += enemies.size()
		if not enemies.is_empty() and (p == gen.start_room or p.kind == DungeonPiece.Kind.CORRIDOR):
			_fail("%s: %d enemies in %s" % [tag, enemies.size(), p.name])
		var bosses := enemies.filter(func(e): return e.scene_file_path.contains("/boss/"))
		var expected := 1 if p.kind == DungeonPiece.Kind.BOSS and not gen._bosses.is_empty() else 0
		if bosses.size() != expected:
			_fail("%s: %s has %d bosses" % [tag, p.name, bosses.size()])
		if enemies.size() - bosses.size() > gen.max_enemies_per_room:
			_fail("%s: %s has %d enemies (max %d)" % [tag, p.name, enemies.size(), gen.max_enemies_per_room])
		for i in enemies.size():
			var e: Node3D = enemies[i]
			var name := "%s/%s" % [p.name, e.name]
			for j in range(i + 1, enemies.size()):
				if e.global_position.distance_to(enemies[j].global_position) < gen.enemy_spacing - 0.01:
					_fail("%s: %s stands too close to %s" % [tag, name, enemies[j].name])
			for exit in p.get_exits():
				if exit.global_position.distance_to(e.global_position) < gen.doorway_clearance - 0.01:
					_fail("%s: %s stands in a doorway" % [tag, name])
			var floor_y := _floor_height(e.global_position)
			if absf(floor_y - e.global_position.y) > 0.3:
				_fail("%s: %s is %.2fm off the floor" % [tag, name, e.global_position.y - floor_y])
			var shape_node: CollisionShape3D = e.get_node("CollisionShape3D")
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape_node.shape
			q.transform = shape_node.global_transform.translated(Vector3(0, 0.15, 0))
			q.exclude = [e.get_rid()]
			for hit in _space.intersect_shape(q, 4):
				_fail("%s: %s overlaps %s" % [tag, name, _describe(hit.collider)])
			# Reachable: some walkable cell next to it was reached from the start.
			var c := _cell(e.global_position)
			var near := false
			for dx in range(-4, 5):
				for dz in range(-4, 5):
					if reached.has(c + Vector2i(dx, dz)):
						near = true
			if not near:
				_fail("%s: %s can't be reached on foot" % [tag, name])
	print("  %s: %d enemies" % [tag, total])


# --- Walkability ---

## Cells inside the rects where a character capsule fits, plus cells with no floor under them.
func _walkable_cells(rects: Array[Rect2]) -> Dictionary:
	var walkable := {}
	var holes: Array[Vector2i] = []
	var seen := {}
	for r in rects:
		var lo := _cell(Vector3(r.position.x, 0, r.position.y))
		var hi := _cell(Vector3(r.end.x, 0, r.end.y))
		for x in range(lo.x, hi.x + 1):
			for z in range(lo.y, hi.y + 1):
				var c := Vector2i(x, z)
				var w := _world(c)
				# Cells on the line where two pieces meet belong to both.
				if seen.has(c) or not r.grow(0.01).has_point(Vector2(w.x, w.z)):
					continue
				seen[c] = true
				var floor_y := _floor_height(w)
				var free := _characters_fit(Vector3(w.x, floor_y, w.z))
				if free and floor_y < HOLE_DEPTH:
					if not _inside_solid(w):
						holes.append(c)
				elif free:
					walkable[c] = floor_y
	return {"walkable": walkable, "holes": holes}


## Whether every character capsule fits standing at a floor point.
func _characters_fit(at: Vector3) -> bool:
	if _capsule_queries.is_empty():
		for size in CAPSULES:
			var capsule := CapsuleShape3D.new()
			capsule.radius = size.x
			capsule.height = size.y
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = capsule
			_capsule_queries.append(q)
	for q in _capsule_queries:
		var height: float = (q.shape as CapsuleShape3D).height
		q.transform = Transform3D(Basis(), at + Vector3(0, CAPSULE_LIFT + height / 2.0, 0))
		if not _space.intersect_shape(q, 1).is_empty():
			return false
	return true


## Height of the floor under a point; a sphere is cast after the ray so grates count as floor.
func _floor_height(w: Vector3) -> float:
	var hit := _ray(Vector3(w.x, 0.6, w.z), Vector3(w.x, -2.5, w.z))
	if not hit.is_empty() and hit.position.y > HOLE_DEPTH:
		return hit.position.y
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), Vector3(w.x, 0.6, w.z))
	q.motion = Vector3(0, -3.1, 0)
	var frac := _space.cast_motion(q)
	return 0.6 - 3.1 * frac[1] - 0.3


func _flood(walkable: Dictionary, start: Vector2i) -> Dictionary:
	var reached := {}
	if not walkable.has(start):
		return reached
	var stack: Array[Vector2i] = [start]
	reached[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if not walkable.has(n) or reached.has(n):
				continue
			# A diagonal step only counts if the characters also fit halfway, so it can't cut
			# a corner; it lets the check follow gaps narrower than the grid spacing.
			if d.x != 0 and d.y != 0:
				var mid := (_world(c) + _world(n)) / 2.0
				mid.y = (walkable[c] + walkable[n]) / 2.0
				if not _characters_fit(mid):
					continue
			reached[n] = true
			stack.append(n)
	return reached


## Text map around a cell: o reached from the start, . walkable but cut off, # blocked, X the cell.
func _print_area(walkable: Dictionary, reached: Dictionary, center: Vector2i, radius := 14) -> void:
	print("    area around %s (o reached, . cut off, # blocked, X target):" % _world(center))
	for z in range(center.y - radius, center.y + radius + 1):
		var row := "    "
		for x in range(center.x - radius, center.x + radius + 1):
			var c := Vector2i(x, z)
			row += "X" if c == center else "o" if reached.has(c) else "." if walkable.has(c) else "#"
		print(row)


func _nearest_walkable(walkable: Dictionary, c: Vector2i) -> Vector2i:
	for r in 8:
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				if walkable.has(c + Vector2i(x, z)):
					return c + Vector2i(x, z)
	return c


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / GRID), roundi(p.z / GRID))


func _world(c: Vector2i) -> Vector3:
	return Vector3(c.x * GRID, 0, c.y * GRID)


# --- Helpers ---

func _props(piece: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var props := piece.get_node_or_null("Props")
	if props:
		for group in props.get_children():
			for prop in group.get_children():
				out.append(prop)
	return out


func _is_mounted(prop: Node) -> bool:
	return MOUNTED.any(func(k): return prop.scene_file_path.contains(k))


func _has_collision(node: Node) -> bool:
	return not node.find_children("*", "CollisionObject3D", true, false).is_empty()


func _bodies_under(node: Node) -> Array[RID]:
	var out: Array[RID] = []
	if node:
		for b in node.find_children("*", "CollisionObject3D", true, false):
			out.append(b.get_rid())
	return out


## How far a prop's mesh reaches past solid surfaces: rays from its center out to its vertices
## that hit something before arriving have that vertex buried behind the surface.
func _deepest_clip(prop: Node3D, center: Vector3, exclude: Array[RID]) -> Dictionary:
	var deepest := {"depth": 0.0, "into": ""}
	for mi in _mesh_instances(prop):
		if mi.mesh == null:
			continue
		var faces: PackedVector3Array = mi.mesh.get_faces()
		var step := maxi(1, faces.size() / 400)
		for i in range(0, faces.size(), step):
			var v: Vector3 = mi.global_transform * faces[i]
			var q := PhysicsRayQueryParameters3D.create(center, v)
			q.exclude = exclude
			var hit := _space.intersect_ray(q)
			if not hit.is_empty():
				var depth: float = hit.position.distance_to(v)
				if depth > deepest.depth:
					deepest = {"depth": depth, "into": _describe(hit.collider)}
	return deepest


func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		out.append(mi)
	return out


func _visual_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	# Meshes only: lights and particles would count their whole reach.
	for vi in _mesh_instances(node):
		var b: AABB = vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _inside_solid(w: Vector3) -> bool:
	return not _ray(Vector3(w.x, 6.0, w.z), Vector3(w.x, 0.6, w.z)).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


## Name of the prop or piece part a collider belongs to.
func _describe(collider: Object) -> String:
	var n: Node = collider
	while n and n.get_parent() and not (n.get_parent().name in ["Walls", "Floors", "Structure", "Furniture", "Containers", "Lighting", "Decor", "Loot", "Debris"]):
		n = n.get_parent()
	return String(n.name) if n else "?"
