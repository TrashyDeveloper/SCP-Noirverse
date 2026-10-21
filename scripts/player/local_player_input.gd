class_name LocalPlayerInput
extends InputSource
## Reads the keyboard and mouse of the person sitting at this computer.

## Mouse look speed (radians per pixel of mouse movement).
@export var mouse_sensitivity := 0.0025
## How far up/down you can look, in degrees.
@export var max_pitch_degrees := 89.0

## False while a menu like the inventory is open: you can still walk, but
## mouse look and item use are paused.
var look_enabled := true

var _yaw := 0.0
var _pitch := 0.0
# One-shot presses are collected here until the next physics tick picks them
# up, so a quick tap between two ticks is never lost.
var _pending := CharacterInput.new()


func set_view_angles(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch


## Called by the inventory screen.
func request_select_slot(slot: int) -> void:
	_pending.select_slot = slot


## Called by the inventory screen.
func request_drop_slot(slot: int) -> void:
	_pending.drop_slot = slot


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion:
		if look_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw = wrapf(_yaw - event.relative.x * mouse_sensitivity, -PI, PI)
			_pitch -= event.relative.y * mouse_sensitivity
			_pitch = clampf(_pitch, -deg_to_rad(max_pitch_degrees), deg_to_rad(max_pitch_degrees))
		return
	if event.is_action_pressed("jump"):
		_pending.jump = true
	elif event.is_action_pressed("toggle_flashlight"):
		_pending.toggle_flashlight = true
	elif not look_enabled:
		return
	elif event.is_action_pressed("interact"):
		_pending.interact = true
	elif event.is_action_pressed("use_item") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pending.use_item = true
	elif event.is_action_pressed("reload"):
		_pending.reload = true
	elif event.is_action_pressed("drop_item"):
		_pending.drop_item = true


func sample() -> CharacterInput:
	var input := _pending
	_pending = CharacterInput.new()
	if not enabled:
		input = CharacterInput.new()
	input.yaw = _yaw
	input.pitch = _pitch
	if enabled:
		input.move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		input.sprint = Input.is_action_pressed("sprint")
	return input


func get_view_angles() -> Vector2:
	return Vector2(_yaw, _pitch)
