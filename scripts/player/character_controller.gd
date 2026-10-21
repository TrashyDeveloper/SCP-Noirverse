class_name CharacterController
extends CharacterBody3D
## A first-person humanoid character (Class-D, Scientist, Guard...).
##
## It only knows how to move, look, interact and carry items. *Who* controls
## it is decided by the InputSource it is given: the local player, a bot, or
## (later) a network peer. Nothing in here reads the keyboard directly.

## Emitted when the thing under the crosshair changes. Empty text = nothing.
signal interaction_prompt_changed(text: String)
## progress 0..1 while holding E on something (e.g. disarming); -1 = done.
signal hold_progress_changed(progress: float)
signal died(source: Node)
signal disarm_changed(disarmed: bool)
## A flashbang went off in view; `duration` = seconds of blindness.
signal flashed(duration: float)
signal class_changed(new_class: CharacterClass)

## Seconds of holding E needed to disarm (or release) someone.
const DISARM_HOLD_TIME := 1.2
## A disarmed character is released when its captor gets this far away.
const MAX_DISARM_DISTANCE := 30.0

@export var walk_speed := 3.5
@export var sprint_speed := 6.0
@export var jump_velocity := 4.2
## How quickly we reach full speed on the ground (higher = snappier).
@export var ground_acceleration := 12.0
@export var air_acceleration := 2.0
## Gentle camera bob while walking. Set to 0 to disable.
@export var head_bob_amount := 0.04

var input_source: InputSource
var is_alive := true
## This character's class (Class-D, Scientist...). Set with apply_class().
var character_class: CharacterClass
## Whether characters on the same side can hurt each other (set by the match).
var friendly_fire := false
## Who disarmed (restrained) this character, or null.
var disarmed_by: CharacterController
## Seconds of flashbang blindness left (bots will use this later).
var blind_time_left := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob_time := 0.0
var _last_prompt := ""
var _head_base_height := 0.0
var _hold_target: Node
var _hold_time := 0.0
var _speed_multiplier := 1.0
var _class_speed := 1.0
var _step_distance := 0.0
## True when someone looks through these eyes (the gun in hand is drawn).
var view_model_visible := false
var _speed_boost_left := 0.0
## The visible body (dressed for the class and animated).
var model: HumanoidModel

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var status_label: Label3D = $StatusLabel
@onready var view_model: Node3D = $Head/Camera3D/ViewModel
@onready var view_model_rest: Vector3 = view_model.position
@onready var health: Health = $Health
@onready var inventory: Inventory = $Inventory
@onready var items: ItemHandler = $ItemHandler


func _ready() -> void:
	add_to_group(&"characters")
	_head_base_height = head.position.y
	health.died.connect(_on_died)
	health.damage_modifier = _modify_damage
	interact_ray.add_exception(self)
	status_label.visible = false
	model = HumanoidModel.new()
	model.name = "Model"
	add_child(model)
	items.equipped_changed.connect(func(_slot: int):
		var held := items.get_equipped()
		model.hold(held.data if held != null else null))


## Gives this character a controller. `first_person` = true when the local
## player is looking through this character's eyes.
func possess(source: InputSource, first_person: bool) -> void:
	input_source = source
	add_child(source)
	camera.current = first_person
	# The item-in-hand model is only drawn for the player looking through
	# these eyes (third-person held items come later).
	view_model_visible = first_person
	view_model.visible = first_person
	if first_person:
		# Put our own body on render layer 3 and hide that layer from our
		# camera, so it doesn't block the view. Other characters stay on
		# layer 2 and remain visible.
		model.set_layers(4)
		status_label.layers = 4
		camera.set_cull_mask_value(3, false)


func _process(delta: float) -> void:
	if is_alive and model != null:
		var local_velocity := global_basis.inverse() * velocity
		model.animate(delta, local_velocity, is_on_floor(), head.rotation.x, is_disarmed(), items.aiming)
	if input_source == null or not is_alive:
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
	_update_timers(delta)
	if not is_alive:
		# Dead bodies still fall, but ignore all commands.
		_apply_movement(CharacterInput.new(), delta)
		return
	rotation.y = input.yaw
	head.rotation.x = input.pitch
	_apply_movement(input, delta)
	_update_footsteps(delta)
	# Items first, so a hotkey-drawn keycard already counts for a door this tick.
	items.tick(input, delta)
	_update_interaction(input, delta)
	if input.toggle_flashlight:
		flashlight.visible = not flashlight.visible


# --- Class and side ---

## Becomes `new_class`: health, colour and starting equipment. With
## `keep_items` (e.g. after escaping) the current inventory is kept and the
## new equipment is added; anything that doesn't fit is dropped.
func apply_class(new_class: CharacterClass, keep_items := false) -> void:
	character_class = new_class
	set_disarmed(null)
	health.max_health = new_class.max_health
	health.reset()
	inventory.extra_limits = new_class.limit_bonuses.duplicate()
	_class_speed = new_class.speed_multiplier
	inventory.ammo_multiplier = 2.0 if new_class.perks.has(&"heavy") else 1.0
	model.dress(new_class)
	var held := items.get_equipped()
	model.hold(held.data if held != null else null)
	if not keep_items:
		items.equip(-1)
		for slot in Inventory.SLOT_COUNT:
			inventory.take_item(slot)
		inventory.ammo.clear()
	for data in new_class.starting_items:
		var item := ItemInstance.new(data)
		if not inventory.add_item(item):
			items.drop_item_instance(item)
	for ammo_type in new_class.starting_ammo:
		inventory.give_ammo(ammo_type, new_class.starting_ammo[ammo_type])
	class_changed.emit(new_class)


func has_perk(perk: StringName) -> bool:
	return character_class != null and character_class.perks.has(perk)


func get_side() -> int:
	return character_class.side if character_class != null else -1


func is_ally_of(other: CharacterController) -> bool:
	return other != null and character_class != null and other.get_side() == get_side()


## The character responsible for `source` (a character itself, or the
## thrower of a grenade), or null for hazards and the like.
static func resolve_attacker(source: Node) -> CharacterController:
	if source is CharacterController:
		return source
	if source != null and source.get("thrower") is CharacterController:
		return source.get("thrower")
	return null


func _modify_damage(amount: float, source: Node) -> float:
	var attacker := resolve_attacker(source)
	if attacker != null and attacker != self and not friendly_fire and is_ally_of(attacker):
		return 0.0
	return amount


# --- Things other objects ask the character (doors, pickups...) ---

func get_held_item() -> ItemInstance:
	return items.get_equipped()


func is_disarmed() -> bool:
	return disarmed_by != null


## Why this character can't pick up `item` right now ("" = it can).
func get_pickup_block_reason(item: ItemInstance) -> String:
	if not is_alive:
		return "Dead"
	if is_disarmed():
		return "You are disarmed"
	return inventory.get_block_reason(item)


func give_item(item: ItemInstance) -> bool:
	return get_pickup_block_reason(item) == "" and inventory.add_item(item)


func apply_speed_boost(multiplier: float, duration: float) -> void:
	_speed_multiplier = multiplier
	_speed_boost_left = duration


## A flashbang exploded at `origin`. Looking towards it blinds fully,
## looking away only briefly.
func apply_flash(origin: Vector3, duration: float) -> void:
	if not is_alive:
		return
	var to_flash := (origin - camera.global_position).normalized()
	var facing := -camera.global_basis.z
	var amount := duration if facing.dot(to_flash) > 0.2 else duration * 0.3
	blind_time_left = maxf(blind_time_left, amount)
	flashed.emit(amount)


# --- Disarming: other characters hold E on us ---

## Can this character disarm `target` right now?
func can_disarm(target: CharacterController) -> bool:
	var held := get_held_item()
	if not is_alive or is_disarmed() or held == null or held.data.kind != ItemData.Kind.FIREARM:
		return false
	if not target.is_alive or target.is_disarmed():
		return false
	var target_held := target.get_held_item()
	return target_held == null or not target_held.data.blocks_disarm()


func get_interaction_prompt(actor: Node) -> String:
	if not actor is CharacterController or not is_alive:
		return ""
	if is_disarmed():
		return "Hold [E] to release" if _can_release(actor) else ""
	if actor.can_disarm(self):
		return "Hold [E] to disarm"
	var held := get_held_item()
	var actor_held: ItemInstance = actor.get_held_item()
	if actor_held != null and actor_held.data.kind == ItemData.Kind.FIREARM and held != null and held.data.blocks_disarm():
		return "Can't disarm: they are holding %s" % held.data.display_name
	return ""


## Characters are only "held" interactions, never single presses.
func interact(_actor: Node) -> void:
	pass


func get_hold_duration(actor: Node) -> float:
	if not actor is CharacterController:
		return 0.0
	if is_disarmed():
		return DISARM_HOLD_TIME if _can_release(actor) else 0.0
	return DISARM_HOLD_TIME if actor.can_disarm(self) else 0.0


func complete_hold_action(actor: Node) -> void:
	if is_disarmed():
		set_disarmed(null)
	elif actor is CharacterController and actor.can_disarm(self):
		set_disarmed(actor)


func set_disarmed(by: CharacterController) -> void:
	if by == disarmed_by:
		return
	disarmed_by = by
	if by != null:
		items.drop_everything()
	status_label.text = "DISARMED"
	status_label.visible = by != null
	disarm_changed.emit(by != null)


func _can_release(actor: CharacterController) -> bool:
	return actor != self and actor.is_alive and not actor.is_disarmed()


func _check_disarm_release() -> void:
	if not is_disarmed():
		return
	var captor := disarmed_by
	if not is_instance_valid(captor) or not captor.is_alive or not captor.inventory.has_firearm() \
			or captor.global_position.distance_to(global_position) > MAX_DISARM_DISTANCE:
		set_disarmed(null)


# --- Internals ---

func _update_timers(delta: float) -> void:
	blind_time_left = maxf(blind_time_left - delta, 0.0)
	if _speed_boost_left > 0.0:
		_speed_boost_left -= delta
		if _speed_boost_left <= 0.0:
			_speed_multiplier = 1.0
	_check_disarm_release()


func _apply_movement(input: CharacterInput, delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif input.jump:
		velocity.y = jump_velocity

	var speed := sprint_speed if input.sprint and input.move.y > 0.0 else walk_speed
	speed *= _speed_multiplier * _class_speed
	var held := items.get_equipped()
	if held != null and held.data.kind == ItemData.Kind.FIREARM:
		speed *= held.data.move_speed
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


func _update_interaction(input: CharacterInput, delta: float) -> void:
	var target := _find_interactable()
	var prompt := ""
	var hold_duration := 0.0
	if target != null:
		prompt = target.get_interaction_prompt(self)
		if target.has_method("get_hold_duration"):
			hold_duration = target.get_hold_duration(self)
	if hold_duration > 0.0 and input.interact_held:
		if target != _hold_target:
			_hold_target = target
			_hold_time = 0.0
		_hold_time += delta
		hold_progress_changed.emit(_hold_time / hold_duration)
		if _hold_time >= hold_duration:
			target.complete_hold_action(self)
			_reset_hold()
	else:
		_reset_hold()
		if target != null and input.interact and hold_duration <= 0.0:
			target.interact(self)
	if prompt != _last_prompt:
		_last_prompt = prompt
		interaction_prompt_changed.emit(prompt)


func _reset_hold() -> void:
	if _hold_target != null:
		_hold_target = null
		_hold_time = 0.0
		hold_progress_changed.emit(-1.0)


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


func _on_died(source: Node) -> void:
	is_alive = false
	set_disarmed(null)
	items.equip(-1)
	interaction_prompt_changed.emit("")
	_reset_hold()
	velocity.x = 0.0
	velocity.z = 0.0
	model.die()
	# Simple death "animation": the camera drops to the floor and tilts.
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(head, "position:y", 0.25, 0.6)
	tween.tween_property(head, "rotation:z", deg_to_rad(75.0), 0.6)
	died.emit(source)


## Plays a footstep every stride while walking on the ground.
func _update_footsteps(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or speed < 0.5:
		_step_distance = 0.0
		return
	_step_distance += speed * delta
	var stride := 2.0 if speed > walk_speed + 0.5 else 1.5
	if _step_distance >= stride:
		_step_distance = 0.0
		Sfx.play_3d(self, "footstep", global_position, -8.0 if speed > walk_speed + 0.5 else -13.0, randf_range(0.85, 1.1))


func _update_head_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.5:
		_bob_time += delta * horizontal_speed * 2.2
	else:
		_bob_time = 0.0
	head.position.y = _head_base_height + sin(_bob_time) * head_bob_amount
