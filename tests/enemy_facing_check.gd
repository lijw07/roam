extends Node3D

const ARENA := preload("res://scenes/playground/enemy_ai_test.tscn")
const REPORT_PATH := "res://tests/enemy_facing_report.txt"
const SETTLE_TIME := 1.5
const RUN_TIME := 40.0
const PLAYER_SPEED := 4.0
const LOOP_RADIUS := 7.0
const TURN_EVERY := 3.0
const MOVING_SPEED := 1.0
const BACKWARD_ANGLE := 112.0
const MAX_EXAMPLES := 12
const LASTING_FRAMES := 6

var _arena: Node3D
var _player: CharacterBody3D
var _enemies: Array[Enemy] = []
var _clock := 0.0
var _heading := Vector3.FORWARD
var _center := Vector3.ZERO
var _moving_frames := {}
var _backward_frames := {}
var _examples := {}
var _streaks := {}
var _engaged := false


func _ready() -> void:
	_arena = ARENA.instantiate()
	add_child(_arena)
	_player = _arena.get_node("Player")
	(_player.get_node("Health") as Health).invulnerable = true
	for enemy: Enemy in _arena.find_children("*", "Enemy", true, false):
		_enemies.append(enemy)
		_center += enemy.global_position / 6.0
		_moving_frames[enemy.name] = 0
		_backward_frames[enemy.name] = 0
		_examples[enemy.name] = []
		_streaks[enemy.name] = 0


func _physics_process(delta: float) -> void:
	_clock += delta
	if _clock < SETTLE_TIME:
		return
	if not _engaged:
		_engage_everyone()
	_steer_player(delta)
	for enemy in _enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			_sample(enemy)
	if _clock >= SETTLE_TIME + RUN_TIME:
		_write_report()
		get_tree().quit()


func _engage_everyone() -> void:
	_engaged = true
	_player.global_position = _center
	for enemy in _enemies:
		(enemy.get_node("Brain") as EnemyBrain).engage()


func _steer_player(delta: float) -> void:
	if fmod(_clock, TURN_EVERY) < delta:
		var away := _center - _player.global_position
		_heading = away.normalized() if away.length() > LOOP_RADIUS else _heading.rotated(Vector3.UP, randf_range(-2.5, 2.5))
	_player.global_position += _heading * PLAYER_SPEED * delta


func _sample(enemy: Enemy) -> void:
	var velocity := enemy.get_real_velocity()
	velocity.y = 0.0
	if velocity.length() < MOVING_SPEED:
		return
	_moving_frames[enemy.name] += 1
	var forward := Vector3(enemy.global_basis.z.x, 0.0, enemy.global_basis.z.z).normalized()
	var angle := rad_to_deg(forward.angle_to(velocity.normalized()))
	var clip := String(enemy.animation_player.current_animation)
	if angle < BACKWARD_ANGLE or clip.contains("Backwards"):
		_streaks[enemy.name] = 0
		return
	_streaks[enemy.name] += 1
	if _streaks[enemy.name] < LASTING_FRAMES:
		return
	_backward_frames[enemy.name] += 1
	var examples: Array = _examples[enemy.name]
	if examples.size() < MAX_EXAMPLES:
		var brain := enemy.get_node("Brain") as EnemyBrain
		examples.append("t=%.2f angle=%.0f speed=%.1f clip=%s running=%s focus=%s state=%s move_dir=%s" % [
			_clock, angle, velocity.length(), clip, enemy.running, enemy.focus != null, brain.state_name(), enemy.move_direction
		])


func _write_report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	for enemy_name: String in _moving_frames:
		file.store_line("%s moving=%d backward=%d" % [enemy_name, _moving_frames[enemy_name], _backward_frames[enemy_name]])
		for example: String in _examples[enemy_name]:
			file.store_line("    " + example)
	file.close()
