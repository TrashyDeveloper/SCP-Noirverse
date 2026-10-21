class_name LocalPlayerInput
extends InputSource
## Reads the keyboard and mouse of the person sitting at this computer.

## Mouse look speed (radians per pixel of mouse movement).
@export var mouse_sensitivity := 0.0025
## How far up/down you can look, in degrees.
@export var max_pitch_degrees := 89.0

var _yaw := 0.0
var _pitch := 0.0
# One-shot presses are remembered until the next physics tick picks them up,
# so a quick tap between two ticks is never lost.
var _jump_queued := false
var _interact_queued := false
var _flashlight_queued := false


func set_view_angles(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, -deg_to_rad(max_pitch_degrees), deg_to_rad(max_pitch_degrees))
		_yaw = wrapf(_yaw, -PI, PI)
	elif event.is_action_pressed("jump"):
		_jump_queued = true
	elif event.is_action_pressed("interact"):
		_interact_queued = true
	elif event.is_action_pressed("toggle_flashlight"):
		_flashlight_queued = true


func sample() -> CharacterInput:
	var input := CharacterInput.new()
	input.yaw = _yaw
	input.pitch = _pitch
	if enabled:
		input.move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		input.sprint = Input.is_action_pressed("sprint")
		input.jump = _jump_queued
		input.interact = _interact_queued
		input.toggle_flashlight = _flashlight_queued
	_jump_queued = false
	_interact_queued = false
	_flashlight_queued = false
	return input


func get_view_angles() -> Vector2:
	return Vector2(_yaw, _pitch)
