class_name FlickerLight
extends Light3D
## Makes a light flicker like an old, failing fluorescent tube.
## Attach this script to any OmniLight3D or SpotLight3D.

## Average time between flicker bursts, in seconds.
@export var calm_time := 4.0
## 0 = never flickers, 1 = flickers a lot.
@export_range(0.0, 1.0) var intensity := 0.5
## Light energy while flickered "off" (as a fraction of normal).
@export_range(0.0, 1.0) var dim_fraction := 0.05

var _base_energy := 1.0
var _timer := 0.0
var _burst_left := 0


func _ready() -> void:
	_base_energy = light_energy
	_timer = randf_range(0.5, calm_time)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if _burst_left <= 0:
		if randf() < intensity:
			_burst_left = randi_range(2, 8)
		_timer = randf_range(calm_time * 0.5, calm_time * 1.5)
		light_energy = _base_energy
		return
	# Inside a burst: rapidly toggle between dim and bright.
	_burst_left -= 1
	var dim := _burst_left % 2 == 1
	light_energy = _base_energy * (dim_fraction if dim else randf_range(0.7, 1.1))
	_timer = randf_range(0.03, 0.12)
