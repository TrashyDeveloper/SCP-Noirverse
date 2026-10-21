class_name CharacterController
extends CharacterBody3D
## A first-person humanoid character (Class-D, Scientist, Guard...).
##
## It only knows how to move, look and interact. *Who* controls it is decided
## by the InputSource it is given: the local player, a bot, or (later) a
## network peer. Nothing in here reads the keyboard directly.

## Emitted when the thing under the crosshair changes. Empty text = nothing.
signal interaction_prompt_changed(text: String)

@export var walk_speed := 3.5
@export var sprint_speed := 6.0
@export var jump_velocity := 4.2
## How quickly we reach full speed on the ground (higher = snappier).
@export var ground_acceleration := 12.0
@export var air_acceleration := 2.0
## Gentle camera bob while walking. Set to 0 to disable.
@export var head_bob_amount := 0.04

var input_source: InputSource

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob_time := 0.0
var _last_prompt := ""
var _head_base_height := 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var body_mesh: MeshInstance3D = $Body


func _ready() -> void:
	_head_base_height = head.position.y


## Gives this character a controller. `first_person` = true when the local
## player is looking through this character's eyes.
func possess(source: InputSource, first_person: bool) -> void:
	input_source = source
	add_child(source)
	camera.current = first_person
	# Hide our own body from our own camera so it doesn't block the view.
	# (It stays visible to everyone else.)
	camera.set_cull_mask_value(2, not first_person)


func _process(delta: float) -> void:
	if input_source == null:
		return
	# Apply the view every frame for smooth mouse look.
	var view := input_source.get_view_angles()
	rotation.y = view.x
	head.rotation.x = view.y
	_update_head_bob(delta)


func _physics_process(delta: float) -> void:
	if input_source == null:
		return
	var input := input_source.sample()
	rotation.y = input.yaw
	head.rotation.x = input.pitch
	_apply_movement(input, delta)
	_update_interaction(input)
	if input.toggle_flashlight:
		flashlight.visible = not flashlight.visible


func _apply_movement(input: CharacterInput, delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif input.jump:
		velocity.y = jump_velocity

	var speed := sprint_speed if input.sprint and input.move.y > 0.0 else walk_speed
	# Turn the 2D stick/keys direction into a 3D direction relative to where
	# the body is facing. Forward in Godot is -Z.
	var wish := (transform.basis * Vector3(input.move.x, 0.0, -input.move.y))
	wish.y = 0.0
	var target := wish.limit_length(1.0) * speed
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.lerp(target, clampf(accel * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


func _update_interaction(input: CharacterInput) -> void:
	var target := _find_interactable()
	var prompt := ""
	if target != null:
		prompt = target.get_interaction_prompt(self)
		if input.interact:
			target.interact(self)
	if prompt != _last_prompt:
		_last_prompt = prompt
		interaction_prompt_changed.emit(prompt)


## Returns the interactable object under the crosshair, or null.
## Any node with `interact(actor)` and `get_interaction_prompt(actor)` methods
## counts. The ray may hit a child collider, so we walk up the parents.
func _find_interactable() -> Node:
	if not interact_ray.is_colliding():
		return null
	var node: Node = interact_ray.get_collider()
	while node != null:
		if node.has_method("interact") and node.has_method("get_interaction_prompt"):
			return node
		node = node.get_parent()
	return null


func _update_head_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.5:
		_bob_time += delta * horizontal_speed * 2.2
	else:
		_bob_time = 0.0
	head.position.y = _head_base_height + sin(_bob_time) * head_bob_amount
