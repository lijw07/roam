class_name Health
extends StatPool

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died
signal revived

@export var invulnerable := false

var _dead := false


func is_dead() -> bool:
	return _dead


func take_damage(amount: float, source: Node = null) -> float:
	if _dead or invulnerable or amount <= 0.0:
		return 0.0
	var dealt := drain(amount)
	damaged.emit(dealt, source)
	if is_empty():
		_die()
	return dealt


func heal(amount: float) -> float:
	return restore(amount)


func heal_over_time(amount: float, duration: float) -> void:
	restore_over_time(amount, duration)


func restore(amount: float) -> float:
	var restored := super(amount)
	if restored > 0.0:
		healed.emit(restored)
	return restored


func kill(source: Node = null) -> void:
	if _dead:
		return
	damaged.emit(drain(value), source)
	_die()


func revive(fraction := 1.0) -> void:
	if not _dead:
		return
	_dead = false
	_add(max_value * clampf(fraction, 0.0, 1.0))
	revived.emit()


func _accepts_restore() -> bool:
	return not _dead


func _die() -> void:
	_dead = true
	cancel_timed_restores()
	died.emit()
