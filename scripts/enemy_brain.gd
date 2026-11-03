class_name EnemyBrain
extends Node3D

enum State { IDLE, ENGAGE, APPROACH, ATTACK, RECOVER, GUARD }

const EYE_HEIGHT := 1.5
const CHEST_HEIGHT := 1.1
const WORLD_MASK := 1
const SIGHT_CHECK_INTERVAL := 0.2
const SIGHT_RAY_PASSES := 4
const REPATH_DISTANCE := 0.5
const STUCK_WAYPOINT_DISTANCE := 0.05
const ARRIVE_DISTANCE := 0.35
const SLOW_DISTANCE := 1.2
const MIN_THROTTLE := 0.35
const RUN_DISTANCE := 4.0
const FOCUS_DISTANCE := 9.0
const NEIGHBOUR_RADIUS := 2.0
const APPROACH_TIMEOUT := 3.0
const MAX_COMBO := 2
const MELEE_THREAT_RANGE := 3.6
const MELEE_THREAT_ARC := deg_to_rad(70.0)
const RANGED_THREAT_ARC := deg_to_rad(12.0)
const REACTION_JITTER := 0.2
const GUARD_LINGER := 0.35
const MAX_GUARD_TIME := 2.5
const GUARD_BREAK_COOLDOWN := 3.0
const PRESSURE_WINDOW := 1.5
const PRESSURE_GUARD_BONUS := 0.25
const PRESSURE_RETREAT_HITS := 2
const SIDESTEP_DISTANCE := 2.0
const REPATH_INTERVAL := 0.5
const MAX_SNAP_DISTANCE := 2.0
const PATH_LOOK_AHEAD := 0.8
const FREE_LOOK_AHEAD := 1.4
const STUCK_CHECK_INTERVAL := 0.5
const STUCK_PROGRESS := 0.2
const DETOUR_TIME := 0.6

@export var sight_range := 14.0
@export var attack_range := 1.9
@export var circle_distance := 3.2
@export var attack_cooldown := 1.5
@export_range(0.0, 2.0) var block_skill := 1.0

@onready var enemy: Enemy = get_parent()

var state := State.IDLE

var _director: CombatDirector
var _agent: NavigationAgent3D
var _steering := ContextSteering.new()
var _clock := 0.0
var _state_time := 0.0
var _cooldown := 0.0
var _guard_cooldown := 0.0
var _guard_delay := -1.0
var _sight_timer := 0.0
var _combo_count := 0
var _last_threat_time := -INF
var _threat_animation: StringName = &""
var _recent_hits: Array[float] = []
var _last_goal := Vector3.INF
var _last_repath_time := -INF
var _stuck_check_time := -INF
var _stuck_check_position := Vector3.ZERO
var _detour_time := 0.0
var _detour_sign := 1.0
var _sidestep_sign := 1.0
var _sight_ray := PhysicsRayQueryParameters3D.new()
var _shot_ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	set_physics_process(false)
	_director = get_tree().get_first_node_in_group(CombatDirector.GROUP) as CombatDirector
	if _director == null:
		return
	if not enemy.is_node_ready():
		await enemy.ready
	_prepare_navigation()
	_prepare_rays()
	_sidestep_sign = 1.0 if get_instance_id() % 2 == 0 else -1.0
	_sight_timer = randf() * SIGHT_CHECK_INTERVAL
	_connect_enemy()
	_director.register(self)
	set_physics_process(true)


func _exit_tree() -> void:
	if is_instance_valid(_director):
		_director.unregister(self)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if not _director.has_living_target():
		_stand_down()
		return
	_watch_target_attacks(delta)
	match state:
		State.IDLE:
			_look_for_target(delta)
		State.ENGAGE:
			_hold_position_in_ring()
		State.APPROACH:
			_close_in()
		State.ATTACK:
			_follow_through()
		State.RECOVER:
			_back_off()
		State.GUARD:
			_keep_guard()


func engage() -> void:
	if state == State.IDLE and not enemy.dead:
		_enter(State.ENGAGE)


func is_engaged() -> bool:
	return state != State.IDLE and not enemy.dead


func is_ranged() -> bool:
	return enemy.is_ranged()


func wants_token() -> bool:
	return state == State.ENGAGE and _cooldown <= 0.0 and _guard_delay < 0.0 and enemy.can_act() and _distance_to_target() <= circle_distance + attack_range


func waiting_time() -> float:
	return _state_time if state == State.ENGAGE else 0.0


func was_hit_recently() -> bool:
	return not _recent_hits.is_empty()


func state_name() -> String:
	return State.keys()[state].capitalize()


func _prepare_navigation() -> void:
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = ARRIVE_DISTANCE
	_agent.radius = 0.45
	add_child(_agent)


func _prepare_rays() -> void:
	_sight_ray.collision_mask = WORLD_MASK
	_shot_ray.collision_mask = 1 << (Hurtbox.LAYER - 1)
	_shot_ray.collide_with_areas = true
	_shot_ray.collide_with_bodies = false


func _connect_enemy() -> void:
	if enemy.health != null:
		enemy.health.died.connect(_on_died)
	if enemy.hurtbox != null:
		enemy.hurtbox.hit_taken.connect(_on_hit_taken)
		_shot_ray.exclude = [enemy.hurtbox.get_rid()]
	enemy.guard_broken.connect(_on_guard_broken)


func _tick_timers(delta: float) -> void:
	_clock += delta
	_state_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_guard_cooldown = maxf(_guard_cooldown - delta, 0.0)
	_detour_time = maxf(_detour_time - delta, 0.0)
	while not _recent_hits.is_empty() and _clock - _recent_hits[0] > PRESSURE_WINDOW:
		_recent_hits.pop_front()


func _enter(next: State) -> void:
	if state == State.GUARD and next != State.GUARD:
		enemy.lower_guard()
	if next != State.APPROACH and next != State.ATTACK:
		_director.release_token(self)
	state = next
	_state_time = 0.0


func _target() -> Node3D:
	return _director.target


func _stand_down() -> void:
	enemy.move_direction = Vector3.ZERO
	enemy.focus = null
	if state != State.IDLE:
		_enter(State.ENGAGE)


func _look_for_target(delta: float) -> void:
	enemy.move_direction = Vector3.ZERO
	enemy.focus = null
	_sight_timer -= delta
	if _sight_timer > 0.0:
		return
	_sight_timer = SIGHT_CHECK_INTERVAL
	if _can_see_target():
		_director.alert(self)


func _hold_position_in_ring() -> void:
	var distance := _distance_to_target()
	enemy.focus = _target() if distance <= FOCUS_DISTANCE else null
	var slot := _director.slot_for(self)
	_move_to(slot, _flat(slot - enemy.global_position).length() > RUN_DISTANCE)
	if _director.holds_token(self):
		_combo_count = 0
		_enter(State.APPROACH)


func _close_in() -> void:
	enemy.focus = _target()
	if _state_time > APPROACH_TIMEOUT:
		_enter(State.ENGAGE)
		return
	if is_ranged():
		_find_a_shot()
	elif _distance_to_target() <= attack_range:
		_start_attack()
	else:
		_move_to(_target().global_position, true)


func _find_a_shot() -> void:
	if _distance_to_target() <= attack_range and _has_clear_shot():
		_start_attack()
	elif _distance_to_target() > attack_range:
		_move_to(_target().global_position, true)
	else:
		_move_to(_sidestep_point(), false)


func _start_attack() -> void:
	enemy.move_direction = Vector3.ZERO
	if enemy.attack(enemy.attacks.pick_random(), _director.difficulty.windup_speed):
		_enter(State.ATTACK)


func _follow_through() -> void:
	enemy.move_direction = Vector3.ZERO
	if enemy.is_attacking():
		return
	if _wants_combo() and enemy.attack(enemy.attacks.pick_random(), _director.difficulty.windup_speed):
		_combo_count += 1
		return
	_cooldown = attack_cooldown
	_enter(State.RECOVER)


func _wants_combo() -> bool:
	return not is_ranged() and enemy.can_act() and _combo_count < MAX_COMBO and _distance_to_target() <= attack_range and randf() < _director.difficulty.combo_chance


func _back_off() -> void:
	enemy.focus = _target()
	var away := _flat(enemy.global_position - _target().global_position).normalized()
	_move_to(_target().global_position + away * circle_distance, false)
	if _state_time >= _director.difficulty.recover_time:
		_enter(State.ENGAGE)


func _keep_guard() -> void:
	enemy.move_direction = Vector3.ZERO
	enemy.focus = _target()
	if not enemy.is_guarding():
		_enter(State.RECOVER)
		return
	var threat_passed := _clock - _last_threat_time > GUARD_LINGER
	if threat_passed or _state_time > MAX_GUARD_TIME:
		_enter(State.ENGAGE)


func _watch_target_attacks(delta: float) -> void:
	var attack := _target_attack()
	var threatened := attack != &"" and _threatened()
	if threatened:
		_last_threat_time = _clock
	if threatened and attack != _threat_animation:
		_consider_guard()
	_threat_animation = attack
	if _guard_delay >= 0.0:
		_guard_delay -= delta
		if _guard_delay < 0.0:
			_raise_guard()


func _target_attack() -> StringName:
	if not _target().has_method(&"is_attacking") or not _target().is_attacking():
		return &""
	if _target().has_method(&"current_animation"):
		return _target().current_animation()
	return &"attack"


func _threatened() -> bool:
	var offset := _flat(enemy.global_position - _target().global_position)
	var angle := _director.target_facing().angle_to(offset)
	if offset.length() <= MELEE_THREAT_RANGE:
		return angle <= MELEE_THREAT_ARC
	return offset.length() <= sight_range and angle <= RANGED_THREAT_ARC


func _consider_guard() -> void:
	if not _can_guard():
		return
	var chance := _director.difficulty.block_chance * block_skill + PRESSURE_GUARD_BONUS * _recent_hits.size()
	if randf() < chance:
		_guard_delay = _director.difficulty.reaction_time * randf_range(1.0 - REACTION_JITTER, 1.0 + REACTION_JITTER)


func _can_guard() -> bool:
	return state in [State.ENGAGE, State.APPROACH, State.RECOVER] and _guard_cooldown <= 0.0


func _raise_guard() -> void:
	if _clock - _last_threat_time > GUARD_LINGER:
		return
	if _can_guard() and enemy.raise_guard():
		_enter(State.GUARD)


func _on_hit_taken(_hit: Hit, damage: float) -> void:
	if damage <= 0.0 or enemy.dead:
		return
	_recent_hits.append(_clock)
	_guard_delay = -1.0
	if state == State.IDLE:
		_director.alert(self)
		return
	if state in [State.APPROACH, State.ATTACK, State.GUARD] or _recent_hits.size() >= PRESSURE_RETREAT_HITS:
		_enter(State.RECOVER)


func _on_guard_broken() -> void:
	_guard_cooldown = GUARD_BREAK_COOLDOWN
	_enter(State.RECOVER)


func _on_died() -> void:
	_enter(State.IDLE)
	_director.unregister(self)
	enemy.move_direction = Vector3.ZERO
	enemy.focus = null
	set_physics_process(false)


func _move_to(goal: Vector3, run: bool) -> void:
	var reachable := _reachable(goal)
	var distance := _flat(reachable - enemy.global_position).length()
	var neighbours := _director.allies_near(self, NEIGHBOUR_RADIUS)
	enemy.running = run
	if distance <= ARRIVE_DISTANCE:
		enemy.move_direction = _steering.separate(enemy, neighbours)
		return
	var waypoint := _next_waypoint(reachable)
	var desired := _flat(waypoint - enemy.global_position).normalized()
	desired *= clampf(distance / SLOW_DISTANCE, MIN_THROTTLE, 1.0)
	_steering.look_ahead = FREE_LOOK_AHEAD if waypoint.is_equal_approx(reachable) else PATH_LOOK_AHEAD
	enemy.move_direction = _steering.steer(enemy, _detoured(desired), neighbours, _steering_exclusions())


func _reachable(goal: Vector3) -> Vector3:
	var snapped := NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), goal)
	if _flat(snapped - goal).length() > MAX_SNAP_DISTANCE:
		return goal
	return Vector3(snapped.x, goal.y, snapped.z)


func _detoured(desired: Vector3) -> Vector3:
	_check_progress()
	if _detour_time <= 0.0:
		return desired
	return desired.rotated(Vector3.UP, _detour_sign * PI * 0.5)


func _check_progress() -> void:
	var elapsed := _clock - _stuck_check_time
	if elapsed < STUCK_CHECK_INTERVAL:
		return
	var stuck := elapsed < STUCK_CHECK_INTERVAL * 2.0 and _flat(enemy.global_position - _stuck_check_position).length() < STUCK_PROGRESS
	if stuck and _detour_time <= 0.0:
		_detour_time = DETOUR_TIME
		_detour_sign = -_detour_sign
		_last_repath_time = -INF
	_stuck_check_time = _clock
	_stuck_check_position = enemy.global_position


func _next_waypoint(goal: Vector3) -> Vector3:
	if goal.distance_to(_last_goal) > REPATH_DISTANCE or _clock - _last_repath_time >= REPATH_INTERVAL:
		_agent.target_position = goal
		_last_goal = goal
		_last_repath_time = _clock
	if _agent.is_navigation_finished():
		return goal
	var waypoint := _agent.get_next_path_position()
	if _flat(waypoint - enemy.global_position).length() <= STUCK_WAYPOINT_DISTANCE:
		return goal
	return waypoint


func _steering_exclusions() -> Array[RID]:
	var rids: Array[RID] = [enemy.get_rid()]
	if _target() is CollisionObject3D:
		rids.append((_target() as CollisionObject3D).get_rid())
	return rids


func _sidestep_point() -> Vector3:
	var to_target := _flat(_target().global_position - enemy.global_position).normalized()
	return enemy.global_position + to_target.cross(Vector3.UP) * SIDESTEP_DISTANCE * _sidestep_sign


func _can_see_target() -> bool:
	if _distance_to_target() > sight_range:
		return false
	var exclude := _steering_exclusions()
	_sight_ray.from = enemy.global_position + Vector3.UP * EYE_HEIGHT
	_sight_ray.to = _target().global_position + Vector3.UP * CHEST_HEIGHT
	for _pass in SIGHT_RAY_PASSES:
		_sight_ray.exclude = exclude
		var hit := get_world_3d().direct_space_state.intersect_ray(_sight_ray)
		if hit.is_empty():
			return true
		if not (hit.collider is CharacterBody3D):
			return false
		exclude.append(hit.rid)
	return true


func _has_clear_shot() -> bool:
	if not _can_see_target():
		return false
	_shot_ray.from = enemy.global_position + Vector3.UP * EYE_HEIGHT
	_shot_ray.to = _target().global_position + Vector3.UP * CHEST_HEIGHT
	var hit := get_world_3d().direct_space_state.intersect_ray(_shot_ray)
	return hit.is_empty() or (hit.collider as Node).get_parent() == _target()


func _distance_to_target() -> float:
	return _flat(_target().global_position - enemy.global_position).length()


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
