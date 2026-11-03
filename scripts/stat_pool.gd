class_name StatPool
extends Node

signal changed(value: float, max_value: float)
signal depleted

@export var max_value := 100.0:
	set(new_max):
		max_value = maxf(new_max, 0.0)
		_set_value(minf(value, max_value))
@export var regen_rate := 0.0
@export var regen_delay := 0.0

var value := 0.0

var _regen_cooldown := 0.0
var _restores: Array[TimedRestore] = []


class TimedRestore:
	var rate: float
	var remaining: float

	func _init(amount: float, duration: float) -> void:
		rate = amount / duration
		remaining = duration

	func take(delta: float) -> float:
		var step := minf(delta, remaining)
		remaining -= step
		return rate * step

	func is_finished() -> bool:
		return remaining <= 0.0


func _ready() -> void:
	_set_value(max_value)


func _physics_process(delta: float) -> void:
	_apply_timed_restores(delta)
	_regenerate(delta)


func ratio() -> float:
	return value / max_value if max_value > 0.0 else 0.0


func is_empty() -> bool:
	return value <= 0.0


func is_full() -> bool:
	return value >= max_value


func can_spend(amount: float) -> bool:
	return value >= amount


func spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	drain(amount)
	return true


func drain(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	_regen_cooldown = regen_delay
	var drained := _add(-amount)
	if is_empty():
		depleted.emit()
	return -drained


func restore(amount: float) -> float:
	if amount <= 0.0 or not _accepts_restore():
		return 0.0
	return _add(amount)


func restore_over_time(amount: float, duration: float) -> void:
	if duration <= 0.0:
		restore(amount)
		return
	if amount > 0.0 and _accepts_restore():
		_restores.append(TimedRestore.new(amount, duration))


func pause_regen() -> void:
	_regen_cooldown = maxf(_regen_cooldown, regen_delay)


func fill() -> void:
	_set_value(max_value)


func cancel_timed_restores() -> void:
	_restores.clear()


func _accepts_restore() -> bool:
	return true


func _apply_timed_restores(delta: float) -> void:
	if _restores.is_empty() or not _accepts_restore():
		return
	for timed_restore in _restores:
		_add(timed_restore.take(delta))
	_restores = _restores.filter(func(timed_restore: TimedRestore) -> bool: return not timed_restore.is_finished())


func _regenerate(delta: float) -> void:
	if _regen_cooldown > 0.0:
		_regen_cooldown = maxf(_regen_cooldown - delta, 0.0)
		return
	if regen_rate > 0.0 and not is_full() and _accepts_restore():
		_add(regen_rate * delta)


func _add(amount: float) -> float:
	var before := value
	_set_value(clampf(value + amount, 0.0, max_value))
	return value - before


func _set_value(new_value: float) -> void:
	if is_equal_approx(new_value, value):
		value = new_value
		return
	value = new_value
	changed.emit(value, max_value)
