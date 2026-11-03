class_name HurtboxWatcher
extends Node3D

var _watched: Dictionary[Hurtbox, bool] = {}


func _ready() -> void:
	for hurtbox: Hurtbox in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		_watch(hurtbox)
	get_tree().node_added.connect(_on_node_added)


func _on_hit_taken(_hit: Hit, _damage: float, _hurtbox: Hurtbox) -> void:
	pass


func _on_blocked(_hit: Hit, _hurtbox: Hurtbox) -> void:
	pass


func _on_node_added(node: Node) -> void:
	if node is Hurtbox:
		_watch(node)


func _watch(hurtbox: Hurtbox) -> void:
	if _watched.has(hurtbox):
		return
	_watched[hurtbox] = true
	hurtbox.tree_exiting.connect(func() -> void: _watched.erase(hurtbox))
	hurtbox.hit_taken.connect(_on_hit_taken.bind(hurtbox))
	hurtbox.blocked.connect(_on_blocked.bind(hurtbox))
