class_name NoirOverlay
extends CanvasLayer
## The full-screen black & white film filter (see shaders/noir_post.gdshader).
## `color_burst()` briefly lets the real colours back in, e.g. when a grenade
## explodes.

@export var flash_in_time := 0.06
@export var hold_time := 0.35
@export var fade_out_time := 1.0

var _base_saturation := 0.06
var _tween: Tween

@onready var filter: ColorRect = $Filter


func _ready() -> void:
	_base_saturation = _material().get_shader_parameter("saturation")


## `strength` 0..1: how much colour comes back (1 = full colour).
func color_burst(strength: float) -> void:
	var peak := lerpf(_base_saturation, 1.0, clampf(strength, 0.0, 1.0))
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_saturation, _get_saturation(), peak, flash_in_time)
	_tween.tween_interval(hold_time)
	_tween.tween_method(_set_saturation, peak, _base_saturation, fade_out_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Changes how much colour is always visible (e.g. raised during an alarm so
## red emergency lights show).
func set_base_saturation(value: float) -> void:
	_base_saturation = value
	if _tween == null or not _tween.is_running():
		_set_saturation(value)


func _material() -> ShaderMaterial:
	return filter.material as ShaderMaterial


func _get_saturation() -> float:
	return _material().get_shader_parameter("saturation")


func _set_saturation(value: float) -> void:
	_material().set_shader_parameter("saturation", value)
