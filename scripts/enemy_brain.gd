class_name EnemyBrain
extends Node3D

enum State { IDLE, ENGAGE, APPROACH, ATTACK, RECOVER, GUARD, RETURN }

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
const WALK_DISTANCE := 2.5
const CIRCLE_ENTER_DISTANCE := 1.2
const CIRCLE_EXIT_DISTANCE := 2.0
const MOVE_GAP := 0.1
const TRYING_THROTTLE := 0.5
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
const ROAM_POINT_TIMEOUT := 8.0
const ATTACK_FACING_TOLERANCE := deg_to_rad(20.0)
const REACHABLE_TOLERANCE := 0.75
const REACHABLE_HEIGHT := 0.6
const REPATH_INTERVAL := 0.5
const MAX_SNAP_DISTANCE := 2.0
const PATH_LOOK_AHEAD := 0.8
const FREE_LOOK_AHEAD := 1.4
const STUCK_CHECK_INTERVAL := 0.5
const STUCK_PROGRESS := 0.2
const DETOUR_TIME := 0.6
const REACH_SETTLE_TIME := 0.4
const REACHABILITY_CHECK_INTERVAL := 0.3
const QUEUE_DISTANCE := 1.8
const QUEUE_ARC := deg_to_rad(40.0)
const QUEUE_RECHECK_TIME := 0.4

@export var sight_range := 9.0
@export_range(0.0, 360.0) var sight_arc_degrees := 140.0
@export var awareness_radius := 3.0
@export var give_up_distance := 18.0
@export var give_up_time := 4.0
@export var roam_radius := 4.0
@export var roam_pause_min := 2.0
@export var roam_pause_max := 5.0
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
var _running_to_slot := false
var _home := Vector3.ZERO
var _home_facing := Vector3.ZERO
var _roam_point := Vector3.ZERO
var _has_roam_point := false
var _roam_pause := 0.0
var _unseen_time := 0.0
var _pursuit_timer := 0.0
var _circling := false
var _last_move_time := -INF
var _reachable_time := 0.0
var _reachability_checked_at := -INF
var _target_was_reachable := true
var _queued_until := -INF
var _sight_ray := PhysicsRayQueryParameters3D.new()
var _shot_ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	set_physics_process(false)
	_director = get_tree().get_first_node_in_group(CombatDirector.GROUP) as CombatDirector
	if _director == null:
		return
	if not enemy.is_node_ready():
		await enemy.ready
	_home = enemy.global_position
	_home_facing = _flat(enemy.global_basis.z).normalized()
	enemy.rest_facing = _home_facing
	_prepare_navigation()
	_prepare_rays()
	_sidestep_sign = 1.0 if get_instance_id() % 2 == 0 else -1.0
	_sight_timer = randf() * SIGHT_CHECK_INTERVAL
	_roam_pause = randf_range(0.0, roam_pause_max)
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
	if state in [State.ENGAGE, State.APPROACH, State.RECOVER]:
		_keep_track_of_target(delta)
		_track_reachability(delta)
	match state:
		State.IDLE:
			_roam(delta)
		State.RETURN:
			_return_home(delta)
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
	if state in [State.IDLE, State.RETURN] and not enemy.dead:
		_unseen_time = 0.0
		_reachable_time = REACH_SETTLE_TIME
		_enter(State.ENGAGE)


func is_engaged() -> bool:
	return state not in [State.IDLE, State.RETURN] and not enemy.dead


func is_ranged() -> bool:
	return enemy.is_ranged()


func wants_token() -> bool:
	return state == State.ENGAGE and _cooldown <= 0.0 and _guard_delay < 0.0 and enemy.can_act() and _distance_to_target() <= circle_distance + attack_range and (is_ranged() or _can_get_at_target())


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
	enemy.rest_facing = _home_facing if next == State.IDLE else Vector3.ZERO
	state = next
	_state_time = 0.0


func _target() -> Node3D:
	return _director.target


func _stand_down() -> void:
	enemy.focus = null
	if state not in [State.IDLE, State.RETURN]:
		_enter(State.RETURN)
	if state == State.RETURN:
		_walk_home()
	else:
		enemy.move_direction = Vector3.ZERO


func _keep_track_of_target(delta: float) -> void:
	if _distance_to_target() > give_up_distance:
		_enter(State.RETURN)
		return
	_pursuit_timer -= delta
	if _pursuit_timer > 0.0:
		return
	_pursuit_timer = SIGHT_CHECK_INTERVAL
	var tracked := _distance_to_target() <= awareness_radius or can_see(_target_chest())
	_unseen_time = 0.0 if tracked else _unseen_time + SIGHT_CHECK_INTERVAL
	if _unseen_time >= give_up_time:
		_enter(State.RETURN)


func _return_home(delta: float) -> void:
	_walk_home()
	_watch_for_target(delta)


func _walk_home() -> void:
	enemy.focus = null
	var distance := _flat(_home - enemy.global_position).length()
	if distance <= ARRIVE_DISTANCE:
		_enter(State.IDLE)
		_rest_between_roams()
		return
	_move_to(_home, distance > RUN_DISTANCE)


func _roam(delta: float) -> void:
	enemy.focus = null
	_watch_for_target(delta)
	if state != State.IDLE:
		return
	if roam_radius <= 0.0 or _roam_pause > 0.0:
		_roam_pause -= delta
		enemy.move_direction = Vector3.ZERO
		return
	if not _has_roam_point:
		_roam_point = _pick_roam_point()
		_has_roam_point = true
		_state_time = 0.0
	if _flat(_roam_point - enemy.global_position).length() <= ARRIVE_DISTANCE or _state_time > ROAM_POINT_TIMEOUT:
		_rest_between_roams()
		return
	_move_to(_roam_point, false)


func _pick_roam_point() -> Vector3:
	var angle := randf() * TAU
	var distance := sqrt(randf()) * roam_radius
	return _reachable(_home + Vector3(sin(angle), 0.0, cos(angle)) * distance)


func _rest_between_roams() -> void:
	_has_roam_point = false
	_roam_pause = randf_range(roam_pause_min, roam_pause_max)
	enemy.move_direction = Vector3.ZERO


func _watch_for_target(delta: float) -> void:
	_sight_timer -= delta
	if _sight_timer > 0.0:
		return
	_sight_timer = SIGHT_CHECK_INTERVAL
	if _notices_target():
		_director.alert(self)


func _track_reachability(delta: float) -> void:
	_reachable_time = _reachable_time + delta if _can_get_at_target() else 0.0


func _waits_for_opening() -> bool:
	return not is_ranged() and _reachable_time < REACH_SETTLE_TIME


func _watch_from_here() -> void:
	enemy.focus = _target()
	enemy.running = false
	enemy.move_direction = Vector3.ZERO


func _hold_position_in_ring() -> void:
	if _waits_for_opening():
		_watch_from_here()
		return
	var slot := _director.slot_for(self)
	_update_ring_pace(_flat(slot - enemy.global_position).length())
	enemy.focus = _target() if _circling and _distance_to_target() <= FOCUS_DISTANCE else null
	_move_to(slot, _running_to_slot)
	if _director.holds_token(self):
		_enter(State.APPROACH)


func _update_ring_pace(distance: float) -> void:
	if distance > RUN_DISTANCE:
		_running_to_slot = true
	elif distance < WALK_DISTANCE:
		_running_to_slot = false
	if distance < CIRCLE_ENTER_DISTANCE:
		_circling = true
	elif distance > CIRCLE_EXIT_DISTANCE:
		_circling = false


func _close_in() -> void:
	enemy.focus = _target()
	if _state_time > APPROACH_TIMEOUT:
		_enter(State.ENGAGE)
		return
	if is_ranged():
		_find_a_shot()
	elif _distance_to_target() <= attack_range or enemy.reaches(_target_hurtbox()):
		_start_attack()
	elif not _target_reachable():
		_enter(State.ENGAGE)
	else:
		_move_to(_target().global_position, true, false)


func _can_get_at_target() -> bool:
	return _target_reachable() or enemy.reaches(_target_hurtbox())


func _target_reachable() -> bool:
	if _clock - _reachability_checked_at >= REACHABILITY_CHECK_INTERVAL:
		_reachability_checked_at = _clock
		_target_was_reachable = _has_path_to(_target().global_position)
	return _target_was_reachable


func _has_path_to(target: Vector3) -> bool:
	var map := _agent.get_navigation_map()
	var closest := NavigationServer3D.map_get_closest_point(map, target)
	var gap := _flat(closest - target).length()
	if gap > MAX_SNAP_DISTANCE:
		return true
	if gap > REACHABLE_TOLERANCE or absf(closest.y - target.y) > REACHABLE_HEIGHT:
		return false
	var path := NavigationServer3D.map_get_path(map, enemy.global_position, closest, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(closest) <= REACHABLE_TOLERANCE


func _target_hurtbox() -> Hurtbox:
	return _target().get("hurtbox") as Hurtbox


func _find_a_shot() -> void:
	if _distance_to_target() <= attack_range and _has_clear_shot():
		_start_attack()
	elif _distance_to_target() > attack_range:
		_move_to(_target().global_position, true, false)
	else:
		_move_to(_sidestep_point(), false)


func _start_attack() -> void:
	enemy.move_direction = Vector3.ZERO
	enemy.running = false
	if not _faces_target():
		return
	if enemy.attack(_attack_sequence()):
		_enter(State.ATTACK)


func _attack_sequence() -> Array[AttackStep]:
	var first := randi() % enemy.attacks.size()
	var sequence: Array[AttackStep] = [enemy.attacks[first]]
	while not is_ranged() and sequence.size() <= MAX_COMBO and randf() < _director.difficulty.combo_chance:
		sequence.append(enemy.attacks[(first + sequence.size()) % enemy.attacks.size()])
	return sequence


func _faces_target() -> bool:
	var to_target := _flat(_target().global_position - enemy.global_position)
	var facing := _flat(enemy.global_basis.z)
	return to_target.is_zero_approx() or facing.angle_to(to_target) <= ATTACK_FACING_TOLERANCE


func _follow_through() -> void:
	enemy.move_direction = Vector3.ZERO
	if enemy.is_attacking():
		return
	_cooldown = attack_cooldown
	_enter(State.RECOVER)


func _back_off() -> void:
	enemy.focus = _target()
	if _waits_for_opening():
		_watch_from_here()
	else:
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
	if state in [State.IDLE, State.RETURN]:
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


func _move_to(goal: Vector3, run: bool, arrive := true) -> void:
	var reachable := _reachable(goal)
	var distance := _flat(reachable - enemy.global_position).length()
	var neighbours := _director.allies_near(self, NEIGHBOUR_RADIUS)
	enemy.running = run
	if distance <= ARRIVE_DISTANCE:
		enemy.move_direction = _steering.separate(enemy, neighbours)
		return
	var waypoint := _next_waypoint(reachable)
	var desired := _flat(waypoint - enemy.global_position).normalized()
	if _waits_in_queue(desired):
		_watch_from_here()
		return
	enemy.heading = desired
	if arrive:
		desired *= clampf(distance / SLOW_DISTANCE, MIN_THROTTLE, 1.0)
	_steering.look_ahead = FREE_LOOK_AHEAD if waypoint.is_equal_approx(reachable) else PATH_LOOK_AHEAD
	enemy.move_direction = _steering.steer(enemy, _detoured(desired), neighbours, _steering_exclusions())


func _reachable(goal: Vector3) -> Vector3:
	var closest := NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), goal)
	if _flat(closest - goal).length() > MAX_SNAP_DISTANCE:
		return goal
	return Vector3(closest.x, goal.y, closest.z)


func _detoured(desired: Vector3) -> Vector3:
	_track_progress(desired)
	if _detour_time <= 0.0:
		return desired
	return desired.rotated(Vector3.UP, _detour_sign * PI * 0.5)


func _track_progress(desired: Vector3) -> void:
	var resumed := _clock - _last_move_time > MOVE_GAP
	_last_move_time = _clock
	if resumed or desired.length() < TRYING_THROTTLE:
		_restart_progress_check()
		return
	if _clock - _stuck_check_time < STUCK_CHECK_INTERVAL:
		return
	if _flat(enemy.global_position - _stuck_check_position).length() < STUCK_PROGRESS and _detour_time <= 0.0:
		_get_unstuck(desired)
	_restart_progress_check()


func _get_unstuck(desired: Vector3) -> void:
	if _ally_blocks_way(desired):
		_queued_until = _clock + QUEUE_RECHECK_TIME
		return
	_detour_time = DETOUR_TIME
	_detour_sign = -_detour_sign
	_last_repath_time = -INF


func _waits_in_queue(desired: Vector3) -> bool:
	if _clock >= _queued_until:
		return false
	if not _ally_blocks_way(desired):
		_queued_until = -INF
		return false
	_queued_until = maxf(_queued_until, _clock + QUEUE_RECHECK_TIME)
	return true


func _ally_blocks_way(desired: Vector3) -> bool:
	for ally in _director.allies_near(self, QUEUE_DISTANCE):
		var offset := _flat(ally.global_position - enemy.global_position)
		if not offset.is_zero_approx() and offset.angle_to(desired) <= QUEUE_ARC:
			return true
	return false


func _restart_progress_check() -> void:
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


func eye_position() -> Vector3:
	return enemy.global_position + Vector3.UP * EYE_HEIGHT


func can_see(point: Vector3) -> bool:
	var exclude := _steering_exclusions()
	_sight_ray.from = eye_position()
	_sight_ray.to = point
	for _pass in SIGHT_RAY_PASSES:
		_sight_ray.exclude = exclude
		var hit := get_world_3d().direct_space_state.intersect_ray(_sight_ray)
		if hit.is_empty():
			return true
		if not (hit.collider is CharacterBody3D):
			return false
		exclude.append(hit.rid)
	return true


func _notices_target() -> bool:
	var distance := _distance_to_target()
	if distance > sight_range:
		return false
	if distance > awareness_radius and not _in_view(_target().global_position):
		return false
	return can_see(_target_chest())


func _in_view(point: Vector3) -> bool:
	var offset := _flat(point - enemy.global_position)
	var facing := _flat(enemy.global_basis.z).normalized()
	return offset.is_zero_approx() or facing.angle_to(offset) <= deg_to_rad(sight_arc_degrees) * 0.5


func _target_chest() -> Vector3:
	return _target().global_position + Vector3.UP * CHEST_HEIGHT


func _has_clear_shot() -> bool:
	if not can_see(_target_chest()):
		return false
	_shot_ray.from = eye_position()
	_shot_ray.to = _target_chest()
	var hit := get_world_3d().direct_space_state.intersect_ray(_shot_ray)
	return hit.is_empty() or (hit.collider as Node).get_parent() == _target()


func _distance_to_target() -> float:
	return _flat(_target().global_position - enemy.global_position).length()


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
