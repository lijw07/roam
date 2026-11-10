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
var _fire_sound: AudioStreamPlayer3D


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_time = randf() * 100.0
	_fire_sound = get_node_or_null("FireSound") as AudioStreamPlayer3D
	if _fire_sound == null or _fire_sound.stream == null:
		return
	_fire_sound.pitch_scale = randf_range(0.94, 1.06)
	var duration := _fire_sound.stream.get_length()
	_fire_sound.play(randf_range(0.0, maxf(0.0, duration - 0.1)))


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	_light.light_energy = light_energy * (1.0 + flicker * _noise.get_noise_1d(_time))
