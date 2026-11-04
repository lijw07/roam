class_name HitLog
extends HurtboxWatcher

const PREFIX := "[HitLog]"
const RECEIVE_FUNCTION := "receive"
const BLOCK_ACTION := &"secondary"

@export var player: Node3D


func _ready() -> void:
	super()
	print("%s watching hits on %s" % [PREFIX, player.name])


func _on_hit_taken(hit: Hit, damage: float, hurtbox: Hurtbox) -> void:
	if hurtbox.get_parent() == player:
		_record("-%d" % roundi(damage), hit)
		_explain_failed_block()


func _on_blocked(hit: Hit, hurtbox: Hurtbox) -> void:
	if hurtbox.get_parent() == player:
		_record("blocked", hit)


func _record(outcome: String, hit: Hit) -> void:
	print("%s %7.2fs  %-8s %-12s %-30s %s" % [PREFIX, Time.get_ticks_msec() / 1000.0, outcome, _attacker_name(hit), _delivery(), _attacker_state(hit)])


func _explain_failed_block() -> void:
	var shield := player.get("shield") as Shield
	if shield == null or not Input.is_action_pressed(BLOCK_ACTION):
		return
	var reasons: Array[String] = []
	if not (player as CharacterBody3D).is_on_floor():
		reasons.append("in the air")
	if reasons.is_empty():
		reasons.append("mid-action (attacking, drinking, dodging) or not enough stamina")
	var stamina := player.get_node_or_null(^"Stamina") as StatPool
	var stamina_left := "%d" % roundi(stamina.value) if stamina != null else "-"
	print("%s          block held but failed: %s   stamina now %s" % [PREFIX, ", ".join(reasons), stamina_left])


func _attacker_name(hit: Hit) -> String:
	return String(hit.attacker.name) if is_instance_valid(hit.attacker) else "none"


func _delivery() -> String:
	var stack := get_stack()
	for index in stack.size() - 1:
		if stack[index].function == RECEIVE_FUNCTION:
			var caller: Dictionary = stack[index + 1]
			return "%s:%s() line %d" % [String(caller.source).get_file(), caller.function, caller.line]
	return "unknown (run from the editor)"


func _attacker_state(hit: Hit) -> String:
	if not (hit.attacker is Enemy):
		return ""
	var enemy := hit.attacker as Enemy
	var brain := enemy.get_node_or_null(^"Brain") as EnemyBrain
	var state := brain.state_name() if brain != null else "-"
	var distance := enemy.global_position.distance_to(player.global_position)
	return "%s  %s @%.2f  %.1fm away" % [state, enemy.animation_player.current_animation, enemy.animation_player.current_animation_position, distance]
