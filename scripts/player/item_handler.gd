class_name ItemHandler
extends Node
## Uses whatever the character holds: shoot, heal, throw grenades, reload,
## choose which item to hold (including hotkeys), throw and drop items.
## Like movement, it is driven only by CharacterInput, so bots and network
## players can use items in exactly the same way.

## Item hotkeys: pull out the best item of a type.
enum Hotkey { NONE, KEYCARD, MEDICAL, GRENADE, PRIMARY, SECONDARY }

signal equipped_changed(slot: int)
## Emitted whenever loaded ammo, spare ammo or reloading state changes.
signal weapon_state_changed
signal hit_confirmed
## progress 0..1 while using a medical item; -1 when not using anything.
signal use_progress_changed(progress: float, label: String)

const PICKUP_SCENE := preload("res://scenes/items/item_pickup.tscn")
const GRENADE_SCENE := preload("res://scenes/items/live_grenade.tscn")
## Bullets hit the world and characters (physics layers 1 and 2).
const SHOT_MASK := 0b11
## Medical hotkey order (unless the last used medical item is carried).
const MEDICAL_PRIORITY: Array[StringName] = [&"adrenaline", &"first_aid_kit", &"painkillers"]
const GRENADE_PRIORITY: Array[ItemData.GrenadeType] = [
	ItemData.GrenadeType.HIGH_EXPLOSIVE, ItemData.GrenadeType.FLASHBANG,
]
## The keycard hotkey looks for keycard doors this close (meters).
const NEARBY_DOOR_RANGE := 4.0

## Which inventory slot is in our hands (-1 = empty hands).
var equipped_slot := -1
var reload_time_left := 0.0
var use_time_left := 0.0

var _cooldown := 0.0
var _kick := 0.0
var _last_medical_id := &""

@onready var character: CharacterController = get_parent()


func get_equipped() -> ItemInstance:
	return character.inventory.get_item(equipped_slot)


func is_reloading() -> bool:
	return reload_time_left > 0.0


func is_using() -> bool:
	return use_time_left > 0.0


## Called by the character every physics tick.
func tick(input: CharacterInput, delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	# The held item may have been used up or removed.
	if equipped_slot != -1 and get_equipped() == null:
		equip(-1)
	if character.is_disarmed():
		return

	if input.select_slot != -1:
		equip(-1 if input.select_slot == equipped_slot else input.select_slot)
	if input.drop_slot != -1:
		drop_slot(input.drop_slot)
	if input.hotkey != Hotkey.NONE:
		_use_hotkey(input.hotkey)

	if is_reloading():
		reload_time_left -= delta
		if reload_time_left <= 0.0:
			_finish_reload()
	if is_using():
		use_time_left -= delta
		var item_in_use := get_equipped()
		use_progress_changed.emit(1.0 - use_time_left / item_in_use.data.use_time, item_in_use.data.display_name)
		if use_time_left <= 0.0:
			_finish_medical()

	var item := get_equipped()
	if item == null:
		return
	if input.drop_item:
		drop_slot(equipped_slot)
	elif input.throw_item:
		throw_slot(equipped_slot)
	elif input.reload:
		_start_reload(item)
	elif input.use_item:
		match item.data.kind:
			ItemData.Kind.FIREARM:
				_fire(item)
			ItemData.Kind.MEDICAL:
				_start_medical(item)
			ItemData.Kind.GRENADE:
				_throw_grenade()


## Takes the item in `slot` into the hands (-1 = empty hands). Armor is worn
## just by carrying it, so it can't be held.
func equip(slot: int) -> void:
	var item := character.inventory.get_item(slot)
	if slot != -1 and (item == null or item.data.kind == ItemData.Kind.ARMOR):
		return
	if slot == equipped_slot:
		return
	equipped_slot = slot
	reload_time_left = 0.0
	_cancel_use()
	_rebuild_view_model()
	equipped_changed.emit(slot)
	weapon_state_changed.emit()


# --- Hotkeys ---

func _use_hotkey(hotkey: Hotkey) -> void:
	var slot := -1
	match hotkey:
		Hotkey.KEYCARD:
			slot = _pick_keycard_slot()
		Hotkey.MEDICAL:
			slot = _pick_medical_slot()
		Hotkey.GRENADE:
			slot = _pick_grenade_slot()
		Hotkey.PRIMARY, Hotkey.SECONDARY:
			# Primary = first firearm in inventory order, secondary = the next.
			var firearms := character.inventory.find_slots(ItemData.Kind.FIREARM)
			var index := 0 if hotkey == Hotkey.PRIMARY else 1
			if index < firearms.size():
				slot = firearms[index]
	if slot != -1:
		equip(slot)


## The best keycard: if a keycard door is nearby, the highest-priority card
## that opens it; otherwise simply the highest-priority card.
func _pick_keycard_slot() -> int:
	var slots := character.inventory.find_slots(ItemData.Kind.KEYCARD)
	if slots.is_empty():
		return -1
	var inventory := character.inventory
	slots.sort_custom(func(a: int, b: int):
		return inventory.get_item(a).data.priority > inventory.get_item(b).data.priority)
	var door := _find_nearest_keycard_door()
	if door != null:
		for slot in slots:
			if door.card_opens(inventory.get_item(slot).data):
				return slot
	return slots[0]


func _find_nearest_keycard_door() -> Door:
	var nearest: Door = null
	var best := NEARBY_DOOR_RANGE
	for node in get_tree().get_nodes_in_group(Door.KEYCARD_DOOR_GROUP):
		var door := node as Door
		var distance := door.global_position.distance_to(character.global_position)
		if door.requires_keycard() and distance < best:
			best = distance
			nearest = door
	return nearest


## The last used kind of medical item if carried, otherwise by priority.
func _pick_medical_slot() -> int:
	var slots := character.inventory.find_slots(ItemData.Kind.MEDICAL)
	var best := -1
	var best_rank := 999
	for slot in slots:
		var id := character.inventory.get_item(slot).data.id
		var index := MEDICAL_PRIORITY.find(id)
		var rank := 0 if id == _last_medical_id else 1 + (index if index != -1 else MEDICAL_PRIORITY.size())
		if rank < best_rank:
			best_rank = rank
			best = slot
	return best


func _pick_grenade_slot() -> int:
	var slots := character.inventory.find_slots(ItemData.Kind.GRENADE)
	for grenade_type in GRENADE_PRIORITY:
		for slot in slots:
			if character.inventory.get_item(slot).data.grenade_type == grenade_type:
				return slot
	return slots[0] if not slots.is_empty() else -1


# --- Dropping and throwing ---

func drop_slot(slot: int) -> void:
	var item := _remove_from_inventory(slot)
	if item != null:
		_spawn_pickup(item, 2.5)
		_drop_excess()


## Throws the item hard. A thrown keycard that hits a door's card reader
## operates the door.
func throw_slot(slot: int) -> void:
	var item := _remove_from_inventory(slot)
	if item == null:
		return
	var speed := clampf(7.0 / (0.4 + item.data.weight), 4.0, 14.0)
	var pickup := _spawn_pickup(item, speed)
	pickup.thrown_by = character
	pickup.continuous_cd = true
	_drop_excess()


## Drops every item and all ammo (e.g. when disarmed).
func drop_everything() -> void:
	for slot in Inventory.SLOT_COUNT:
		var item := _remove_from_inventory(slot)
		if item != null:
			_spawn_pickup(item, 1.5)
	for ammo_type in character.inventory.ammo.keys():
		_drop_ammo(ammo_type, character.inventory.get_ammo(ammo_type))


func _remove_from_inventory(slot: int) -> ItemInstance:
	if slot == equipped_slot:
		equip(-1)
	return character.inventory.take_item(slot)


## Dropping armor can lower the limits; the extras fall to the floor.
func _drop_excess() -> void:
	for slot in character.inventory.get_excess_slots():
		_spawn_pickup(_remove_from_inventory(slot), 1.5)
	var excess_ammo := character.inventory.get_excess_ammo()
	for ammo_type in excess_ammo:
		_drop_ammo(ammo_type, excess_ammo[ammo_type])


func _drop_ammo(ammo_type: StringName, rounds: int) -> void:
	var box_data := AmmoTypes.box_item(ammo_type)
	var taken := character.inventory.take_ammo(ammo_type, rounds)
	if box_data != null and taken > 0:
		_spawn_pickup(ItemInstance.ammo_box(box_data, taken), 1.5)


func _spawn_pickup(item: ItemInstance, speed: float) -> ItemPickup:
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item = item
	character.get_parent().add_child(pickup)
	pickup.global_position = _safe_spawn_point(0.6)
	var forward := -character.camera.global_basis.z
	pickup.linear_velocity = forward * speed + character.velocity
	return pickup


## A point in front of the camera that isn't inside a wall.
func _safe_spawn_point(distance: float) -> Vector3:
	var camera := character.camera
	var forward := -camera.global_basis.z
	var hit := _raycast(camera.global_position, camera.global_position + forward * distance, 1)
	if hit:
		distance = maxf(camera.global_position.distance_to(hit.position) - 0.2, 0.0)
	return camera.global_position + forward * distance


# --- Using items ---

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
	if item.data.kind != ItemData.Kind.FIREARM or is_reloading():
		return
	if item.ammo >= item.data.magazine_size or character.inventory.get_ammo(item.data.ammo_type) <= 0:
		return
	reload_time_left = item.data.reload_time
	weapon_state_changed.emit()


func _finish_reload() -> void:
	reload_time_left = 0.0
	var item := get_equipped()
	if item != null and item.data.kind == ItemData.Kind.FIREARM:
		item.ammo += character.inventory.take_ammo(item.data.ammo_type, item.data.magazine_size - item.ammo)
	weapon_state_changed.emit()


func _start_medical(item: ItemInstance) -> void:
	if is_using():
		return
	var health := character.health
	var heals := item.data.medical_effect != ItemData.MedicalEffect.ADRENALINE
	if heals and health.current >= health.max_health:
		return
	use_time_left = item.data.use_time
	use_progress_changed.emit(0.0, item.data.display_name)


func _finish_medical() -> void:
	use_time_left = 0.0
	use_progress_changed.emit(-1.0, "")
	var item := get_equipped()
	var data := item.data
	match data.medical_effect:
		ItemData.MedicalEffect.HEAL_INSTANT:
			character.health.heal(data.heal_amount)
		ItemData.MedicalEffect.HEAL_OVER_TIME:
			character.health.heal_over_time(data.heal_amount, data.heal_duration)
		ItemData.MedicalEffect.ADRENALINE:
			character.health.add_shield(data.shield_amount)
			character.apply_speed_boost(data.speed_boost, data.speed_boost_duration)
	_last_medical_id = data.id
	_remove_from_inventory(equipped_slot)


func _cancel_use() -> void:
	if is_using():
		use_time_left = 0.0
		use_progress_changed.emit(-1.0, "")


func _throw_grenade() -> void:
	var item := _remove_from_inventory(equipped_slot)
	var grenade: LiveGrenade = GRENADE_SCENE.instantiate()
	grenade.data = item.data
	grenade.thrower = character
	character.get_parent().add_child(grenade)
	grenade.global_position = _safe_spawn_point(0.5)
	var forward := -character.camera.global_basis.z
	grenade.linear_velocity = forward * 11.0 + Vector3.UP * 2.0 + character.velocity


func _raycast(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, [character.get_rid()])
	return character.get_world_3d().direct_space_state.intersect_ray(query)


# --- Visuals (only matter for the player looking through this character) ---

func _process(delta: float) -> void:
	var holder := character.view_model
	_kick = move_toward(_kick, 0.0, delta * 8.0)
	# Recoil: pull back and up. Reload: tilt down. Using a medical item: raise it.
	var tilt := -0.6 if is_reloading() else (0.5 if is_using() else 0.0)
	holder.position.z = lerpf(holder.position.z, character.view_model_rest.z + _kick * 0.06, 0.5)
	holder.rotation.x = lerpf(holder.rotation.x, _kick * 0.15 + tilt, minf(delta * 14.0, 1.0))


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
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
