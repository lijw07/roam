extends Node3D

## A flame: rising particles plus a warm light that flickers.
## Each instance starts at a random point in the flicker so neighboring flames don't pulse together.

@export var light_energy := 1.6
## How far the brightness wanders, as a fraction of light_energy.
@export_range(0.0, 1.0) var flicker := 0.25
@export var flicker_speed := 7.0

@onready var _light: OmniLight3D = $Light

var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_time = randf() * 100.0


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	_light.light_energy = light_energy * (1.0 + flicker * _noise.get_noise_1d(_time))
