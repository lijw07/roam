extends Node3D
class_name DungeonPiece

## A room, corridor or boss room that DungeonGenerator can place.
##
## The piece is centered on its origin and covers `size` meters of floor (walls straddle the edges).
## Its connection points are Marker3D children of an "Exits" node, sitting on the boundary with
## +Z pointing outward. Room exits carry a "doorway" meta: the path to the doorway they open through,
## so the generator can wall it up when nothing connects there. A boss room connects only through
## its "Entrance"; its "LevelExit" is left as the way onward.

enum Kind { ROOM, CONNECTOR, CORRIDOR, BOSS }

## DungeonGenerator overrides this from the folder the scene is in.
@export var kind := Kind.ROOM
## Floor footprint along X and Z in meters, centered on the origin.
@export var size := Vector2(16, 16)
## Real doors in this room's doorways, for boss rooms and rooms the player has to clear.
## Without it, DungeonGenerator gives the room open archways.
@export var has_doors := false


func get_exits() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	var exits := get_node_or_null("Exits")
	if exits:
		for child in exits.get_children():
			if child is Marker3D:
				out.append(child)
	return out


func is_room() -> bool:
	return kind != Kind.CORRIDOR
