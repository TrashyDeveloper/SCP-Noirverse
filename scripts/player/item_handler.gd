class_name ItemHandler
extends Node
## Uses whatever the character holds: shoot the pistol, use a medkit, reload,
## switch slots, drop items. Like movement, it is driven only by
## CharacterInput, so bots and network players can use items the same way.

signal equipped_changed(slot: int)
## Emitted whenever loaded ammo, spare ammo or reloading state changes.
signal weapon_state_changed
signal hit_confirmed

const PICKUP_SCENE := preload("res://scenes/items/item_pickup.tscn")
## Bullets hit the world and characters (physics layers 1 and 2).
const SHOT_MASK := 0b11

## Which inventory slot is in our hands (-1 = empty hands).
var equipped_slot := -1
var reload_time_left := 0.0

var _cooldown := 0.0
var _kick := 0.0

@onready var character: CharacterController = get_parent()


func get_equipped() -> ItemInstance:
	return character.inventory.get_item(equipped_slot)


func is_reloading() -> bool:
	return reload_time_left > 0.0


## Called by the character every physics tick.
func tick(input: CharacterInput, delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	# The held item may have been used up or removed.
	if equipped_slot != -1 and get_equipped() == null:
		equip(-1)

	if input.select_slot != -1:
		equip(-1 if input.select_slot == equipped_slot else input.select_slot)
	elif input.cycle_slot != 0:
		_cycle(input.cycle_slot)

	if is_reloading():
		reload_time_left -= delta
		if reload_time_left <= 0.0:
			_finish_reload()

	var item := get_equipped()
	if item == null:
		return
	if input.drop_item:
		drop_equipped()
	elif input.reload:
		_start_reload(item)
	elif input.use_item:
		match item.data.kind:
			ItemData.Kind.PISTOL:
				_fire(item)
			ItemData.Kind.MEDKIT:
				_use_medkit()


func equip(slot: int) -> void:
	if slot != -1 and character.inventory.get_item(slot) == null:
		return
	if slot == equipped_slot:
		return
	equipped_slot = slot
	reload_time_left = 0.0
	_rebuild_view_model()
	equipped_changed.emit(slot)
	weapon_state_changed.emit()


func drop_equipped() -> void:
	var item := character.inventory.take_item(equipped_slot)
	equip(-1)
	if item == null:
		return
	var camera := character.camera
	var forward := -camera.global_basis.z
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item = item
	character.get_parent().add_child(pickup)
	# Don't spawn the item inside a wall we are facing.
	var drop_distance := 0.6
	var hit := _raycast(camera.global_position, camera.global_position + forward * drop_distance, 1)
	if hit:
		drop_distance = maxf(camera.global_position.distance_to(hit.position) - 0.2, 0.0)
	pickup.global_position = camera.global_position + forward * drop_distance
	pickup.linear_velocity = forward * 2.5 + character.velocity


func _cycle(direction: int) -> void:
	var slot := equipped_slot
	for i in Inventory.SLOT_COUNT:
		slot = wrapi(slot + direction, 0, Inventory.SLOT_COUNT)
		if character.inventory.get_item(slot) != null:
			equip(slot)
			return


func _fire(item: ItemInstance) -> void:
	if is_reloading() or _cooldown > 0.0:
		return
	if item.ammo <= 0:
		_start_reload(item)
		return
	item.ammo -= 1
	_cooldown = item.data.fire_interval
	_kick = 1.0
	_show_muzzle_flash()
	var camera := character.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * item.data.max_range
	var hit := _raycast(from, to, SHOT_MASK)
	if hit:
		var target := Health.find_on(hit.collider)
		if target != null:
			target.take_damage(item.data.damage, character)
			hit_confirmed.emit()
		else:
			_spawn_bullet_hole(hit.position, hit.normal)
	weapon_state_changed.emit()


func _start_reload(item: ItemInstance) -> void:
	if item.data.kind != ItemData.Kind.PISTOL or is_reloading():
		return
	if item.ammo >= item.data.magazine_size or character.inventory.reserve_ammo <= 0:
		return
	reload_time_left = item.data.reload_time
	weapon_state_changed.emit()


func _finish_reload() -> void:
	reload_time_left = 0.0
	var item := get_equipped()
	if item != null and item.data.kind == ItemData.Kind.PISTOL:
		item.ammo += character.inventory.take_ammo(item.data.magazine_size - item.ammo)
	weapon_state_changed.emit()


func _use_medkit() -> void:
	var item := get_equipped()
	if character.health.current >= character.health.max_health:
		return
	character.health.heal(item.data.heal_amount)
	character.inventory.take_item(equipped_slot)
	equip(-1)


func _raycast(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, [character.get_rid()])
	return character.get_world_3d().direct_space_state.intersect_ray(query)


# --- Visuals (only matter for the player looking through this character) ---

func _process(delta: float) -> void:
	var holder := character.view_model
	_kick = move_toward(_kick, 0.0, delta * 8.0)
	# Recoil: pull the gun back and up. Reload: tilt it down.
	var reload_tilt := 0.6 if is_reloading() else 0.0
	holder.position.z = lerpf(holder.position.z, character.view_model_rest.z + _kick * 0.06, 0.5)
	holder.rotation.x = lerpf(holder.rotation.x, _kick * 0.15 - reload_tilt, minf(delta * 14.0, 1.0))


func _rebuild_view_model() -> void:
	var holder := character.view_model
	for child in holder.get_children():
		if child.name != "MuzzleFlash":
			child.queue_free()
	var item := get_equipped()
	if item == null:
		return
	var model := ItemVisuals.build(item.data)
	holder.add_child(model)
	if item.data.kind == ItemData.Kind.KEYCARD:
		model.rotation = Vector3(deg_to_rad(70), 0, 0)
	for mesh in model.get_children():
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _show_muzzle_flash() -> void:
	var flash: OmniLight3D = character.view_model.get_node("MuzzleFlash")
	flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(flash):
			flash.visible = false
	)


func _spawn_bullet_hole(pos: Vector3, normal: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.004)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.03)
	mesh.material = mat
	var hole := MeshInstance3D.new()
	hole.mesh = mesh
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	character.get_parent().add_child(hole)
	hole.global_position = pos + normal * 0.003
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	hole.look_at(pos + normal, up)
	get_tree().create_timer(20.0).timeout.connect(hole.queue_free)
