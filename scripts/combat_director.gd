class_name CombatDirector
extends Node

const GROUP := &"combat_directors"
const TOKEN_TIMEOUT := 10.0
const SLOT_PROBE_HEIGHT := 0.6
const SLOT_WALL_MARGIN := 0.7
const WORLD_MASK := 1
const WAIT_WEIGHT := 0.6
const DISTANCE_WEIGHT := 0.2
const RETALIATION_BONUS := 1.5
const MIN_SLOT_DISTANCE := 1.2

@export var target: Node3D
@export var difficulty: CombatDifficulty
@export var assist_radius := 3.5
@export var circle_lead := 0.25
@export var circle_flip_interval := 6.0

var _brains: Array[EnemyBrain] = []
var _tokens: Dictionary[EnemyBrain, float] = {}
var _slots: Dictionary[EnemyBrain, Vector3] = {}
var _since_grant: Dictionary[bool, float] = {false: INF, true: INF}
var _clock := 0.0
var _circle_direction := 1.0
var _until_circle_flip := 0.0
var _slot_ray := PhysicsRayQueryParameters3D.new()


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_slot_ray.collision_mask = WORLD_MASK
	if difficulty == null:
		difficulty = CombatDifficulty.new()


func _physics_process(delta: float) -> void:
	_clock += delta
	_flip_circle_direction_when_due(delta)
	if not has_living_target():
		_tokens.clear()
		return
	_assign_slots()
	_expire_tokens()
	for ranged: bool in _since_grant:
		_since_grant[ranged] += delta
		if _since_grant[ranged] >= difficulty.attack_interval and _grant_token(ranged):
			_since_grant[ranged] = 0.0


func register(brain: EnemyBrain) -> void:
	if not _brains.has(brain):
		_brains.append(brain)


func unregister(brain: EnemyBrain) -> void:
	_brains.erase(brain)
	_tokens.erase(brain)
	_slots.erase(brain)


func brains() -> Array[EnemyBrain]:
	return _brains


func alert(source: EnemyBrain) -> void:
	source.engage()
	for brain in _brains:
		if brain != source and _answers_alert(brain, source):
			brain.engage()


func _answers_alert(brain: EnemyBrain, source: EnemyBrain) -> bool:
	return brain.global_position.distance_to(source.global_position) <= assist_radius and brain.can_see(source.eye_position())


func has_living_target() -> bool:
	return is_instance_valid(target) and target.get("dead") != true


func holds_token(brain: EnemyBrain) -> bool:
	return _tokens.has(brain)


func release_token(brain: EnemyBrain) -> void:
	_tokens.erase(brain)


func attacker_count(ranged: bool) -> int:
	return _tokens.keys().filter(func(brain: EnemyBrain) -> bool: return brain.is_ranged() == ranged).size()


func attacker_limit(ranged: bool) -> int:
	return difficulty.max_ranged_attackers if ranged else difficulty.max_melee_attackers


func slot_for(brain: EnemyBrain) -> Vector3:
	return _slots.get(brain, brain.global_position)


func target_facing() -> Vector3:
	var model := target.get("model") as Node3D
	var facing := (model if model != null else target).global_basis.z
	return _flat(facing).normalized()


func allies_near(brain: EnemyBrain, radius: float) -> Array[Node3D]:
	var allies: Array[Node3D] = []
	for other in _brains:
		if other != brain and other.enemy.global_position.distance_to(brain.enemy.global_position) <= radius:
			allies.append(other.enemy)
	return allies


func _grant_token(ranged: bool) -> bool:
	if attacker_count(ranged) >= attacker_limit(ranged):
		return false
	var best: EnemyBrain = null
	var best_score := -INF
	for brain in _brains:
		if brain.is_ranged() != ranged or holds_token(brain) or not brain.wants_token():
			continue
		var score := _attack_score(brain)
		if score > best_score:
			best_score = score
			best = brain
	if best == null:
		return false
	_tokens[best] = _clock
	return true


func _attack_score(brain: EnemyBrain) -> float:
	var offset := _flat(brain.enemy.global_position - target.global_position)
	var behind := -_view_forward().dot(offset.normalized())
	var score := brain.waiting_time() * WAIT_WEIGHT - offset.length() * DISTANCE_WEIGHT
	score += difficulty.flank_bias * (behind + _spread_from_attackers(offset))
	if brain.was_hit_recently():
		score += RETALIATION_BONUS
	return score


func _spread_from_attackers(offset: Vector3) -> float:
	var closest := PI
	for attacker: EnemyBrain in _tokens:
		var attacker_offset := _flat(attacker.enemy.global_position - target.global_position)
		closest = minf(closest, attacker_offset.angle_to(offset))
	return closest / PI if not _tokens.is_empty() else 0.0


func _view_forward() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return target_facing()
	return _flat(-camera.global_basis.z).normalized()


func _expire_tokens() -> void:
	for brain: EnemyBrain in _tokens.keys():
		if not is_instance_valid(brain) or _clock - _tokens[brain] > TOKEN_TIMEOUT:
			_tokens.erase(brain)


func _flip_circle_direction_when_due(delta: float) -> void:
	_until_circle_flip -= delta
	if _until_circle_flip <= 0.0:
		_until_circle_flip = circle_flip_interval
		_circle_direction = -_circle_direction


func _assign_slots() -> void:
	_slots.clear()
	var exclude := _body_rids()
	for ranged: bool in [false, true]:
		var ring := _brains.filter(func(brain: EnemyBrain) -> bool: return brain.is_engaged() and brain.is_ranged() == ranged)
		_assign_ring(ring, exclude)


func _assign_ring(ring: Array, exclude: Array[RID]) -> void:
	if ring.is_empty():
		return
	ring.sort_custom(func(a: EnemyBrain, b: EnemyBrain) -> bool: return _angle_of(a) < _angle_of(b))
	var spacing := TAU / ring.size()
	var offset := _ring_offset(ring, spacing) + circle_lead * _circle_direction
	for index in ring.size():
		var brain: EnemyBrain = ring[index]
		var angle := offset + spacing * index
		_slots[brain] = _clear_slot(Vector3(sin(angle), 0.0, cos(angle)) * brain.circle_distance, exclude)


func _ring_offset(ring: Array, spacing: float) -> float:
	var sum := Vector2.ZERO
	for index in ring.size():
		var angle := _angle_of(ring[index]) - spacing * index
		sum += Vector2(cos(angle), sin(angle))
	return atan2(sum.y, sum.x)


func _angle_of(brain: EnemyBrain) -> float:
	var offset := brain.enemy.global_position - target.global_position
	return atan2(offset.x, offset.z)


func _clear_slot(offset: Vector3, exclude: Array[RID]) -> Vector3:
	var center := target.global_position + Vector3.UP * SLOT_PROBE_HEIGHT
	_slot_ray.from = center
	_slot_ray.to = center + offset
	_slot_ray.exclude = exclude
	var hit := target.get_world_3d().direct_space_state.intersect_ray(_slot_ray)
	var slot := target.global_position + offset
	if not hit.is_empty():
		var reach := maxf(center.distance_to(hit.position) - SLOT_WALL_MARGIN, MIN_SLOT_DISTANCE)
		slot = target.global_position + offset.normalized() * reach
	return slot


func _body_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if target is CollisionObject3D:
		rids.append((target as CollisionObject3D).get_rid())
	for brain in _brains:
		rids.append(brain.enemy.get_rid())
	return rids


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
