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

## How long the current use takes (medical items, barricade kits).
var _use_duration := 1.0
## The door a barricade kit is being used on.
var _barricade_door: Door
## True while aiming down the sights with a firearm.
var aiming := false
var _cooldown := 0.0
var _base_fov := -1.0
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
		use_progress_changed.emit(1.0 - use_time_left / _use_duration, item_in_use.data.display_name)
		if use_time_left <= 0.0:
			if item_in_use.data.kind == ItemData.Kind.BARRICADE:
				_finish_barricade()
			else:
				_finish_medical()

	var item := get_equipped()
	aiming = input.aim and item != null and item.data.kind == ItemData.Kind.FIREARM and not is_reloading()
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
			ItemData.Kind.BARRICADE:
				_start_barricade()
	elif input.use_held and item.data.kind == ItemData.Kind.FIREARM and item.data.automatic:
		_fire(item)


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


## Drops an item that isn't in the inventory (e.g. equipment that didn't fit).
func drop_item_instance(item: ItemInstance) -> void:
	_spawn_pickup(item, 1.0)


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
		if character.inventory.get_ammo(item.data.ammo_type) <= 0 and _cooldown <= 0.0:
			Sfx.play_3d(character, "dry_fire", character.camera.global_position, -8.0)
			_cooldown = 0.3
		_start_reload(item)
		return
	item.ammo -= 1
	_cooldown = item.data.fire_interval
	_kick = 1.0
	_show_muzzle_flash()
	var camera := character.camera
	var from := camera.global_position
	# Random spread inside a cone (tighter while aiming, wider while moving).
	var spread := deg_to_rad(item.data.spread_degrees) * (0.3 if aiming else 1.0)
	spread *= 1.0 + clampf(Vector2(character.velocity.x, character.velocity.z).length() / 6.0, 0.0, 1.0)
	var basis := camera.global_basis
	var dir := (-basis.z + basis.x * randf_range(-1, 1) * tan(spread) + basis.y * randf_range(-1, 1) * tan(spread)).normalized()
	var to := from + dir * item.data.max_range
	var hit := _raycast(from, to, SHOT_MASK)
	var kick := deg_to_rad(item.data.recoil) * (0.6 if aiming else 1.0)
	character.input_source.add_recoil(kick, randf_range(-0.3, 0.3) * kick)
	Sfx.play_3d(character, "shot_" + String(item.data.shot_sound), from, 0.0, randf_range(0.95, 1.05))
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
	Sfx.play_3d(character, "reload", character.camera.global_position, -6.0)
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
	_use_duration = item.data.use_time * (0.5 if character.has_perk(&"medic") else 1.0)
	use_time_left = _use_duration
	use_progress_changed.emit(0.0, item.data.display_name)


func _finish_medical() -> void:
	use_time_left = 0.0
	use_progress_changed.emit(-1.0, "")
	var item := get_equipped()
	var data := item.data
	var bonus := 1.25 if character.has_perk(&"medic") else 1.0
	match data.medical_effect:
		ItemData.MedicalEffect.HEAL_INSTANT:
			character.health.heal(data.heal_amount * bonus)
		ItemData.MedicalEffect.HEAL_OVER_TIME:
			character.health.heal_over_time(data.heal_amount * bonus, data.heal_duration)
		ItemData.MedicalEffect.ADRENALINE:
			character.health.add_shield(data.shield_amount)
			character.apply_speed_boost(data.speed_boost, data.speed_boost_duration)
	_last_medical_id = data.id
	_remove_from_inventory(equipped_slot)


# --- Barricades ---

## The closed door the character is looking at that could be barricaded.
func find_barricade_target() -> Door:
	var node: Node = character.interact_ray.get_collider() if character.interact_ray.is_colliding() else null
	while node != null and not node is Door:
		node = node.get_parent()
	var door := node as Door
	return door if door != null and door.can_barricade() else null


func _start_barricade() -> void:
	if is_using():
		return
	_barricade_door = find_barricade_target()
	if _barricade_door == null:
		return
	var item := get_equipped()
	_use_duration = item.data.use_time * (0.5 if character.has_perk(&"fast_barricade") else 1.0)
	use_time_left = _use_duration
	use_progress_changed.emit(0.0, item.data.display_name)


func _finish_barricade() -> void:
	use_time_left = 0.0
	use_progress_changed.emit(-1.0, "")
	var door := _barricade_door
	_barricade_door = null
	# The door must still be closed and in front of us.
	if door == null or not is_instance_valid(door) or find_barricade_target() != door:
		return
	door.add_barricade(character)
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
	var strength := 1.4 if character.has_perk(&"demolitions") else 1.0
	grenade.linear_velocity = (forward * 11.0 + Vector3.UP * 2.0) * strength + character.velocity


func _raycast(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, [character.get_rid()])
	return character.get_world_3d().direct_space_state.intersect_ray(query)


# --- Visuals (only matter for the player looking through this character) ---

func _process(delta: float) -> void:
	var holder := character.view_model
	# Aiming: zoom the camera; a sniper scope hides the gun.
	var camera := character.camera
	if _base_fov < 0.0:
		_base_fov = camera.fov
	var item := get_equipped()
	var target_fov := _base_fov
	if aiming and item != null and item.data.zoom_fov > 0.0:
		target_fov = item.data.zoom_fov
	camera.fov = lerpf(camera.fov, target_fov, minf(delta * 12.0, 1.0))
	holder.visible = character.view_model_visible and not (aiming and item != null and item.data.zoom_fov < 30.0)
	var aim_offset := Vector3(-0.18, 0.08, 0.1) if aiming else Vector3.ZERO
	holder.position.x = lerpf(holder.position.x, character.view_model_rest.x + aim_offset.x, minf(delta * 14.0, 1.0))
	holder.position.y = lerpf(holder.position.y, character.view_model_rest.y + aim_offset.y, minf(delta * 14.0, 1.0))
	_kick = move_toward(_kick, 0.0, delta * 8.0)
	# Recoil: pull back and up. Reload: tilt down. Using a medical item: raise it.
	var tilt := -0.6 if is_reloading() else (0.5 if is_using() else 0.0)
	holder.position.z = lerpf(holder.position.z, character.view_model_rest.z + aim_offset.z + _kick * 0.06, 0.5)
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
	var flash: OmniLight3D = holder.get_node("MuzzleFlash")
	flash.position = model.get_meta("muzzle", Vector3(0, 0.04, -0.2))
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _show_muzzle_flash() -> void:
	var flash: OmniLight3D = character.view_model.get_node("MuzzleFlash")
	if not flash.has_node("Burst"):
		# A small bright star at the muzzle.
		var burst := MeshInstance3D.new()
		burst.name = "Burst"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.14, 0.14)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = _flash_texture()
		m.albedo_color = Color(1.0, 0.85, 0.55)
		quad.material = m
		burst.mesh = quad
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.add_child(burst)
	flash.get_node("Burst").rotation.z = randf() * TAU
	flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(flash):
			flash.visible = false
	)


static var _flash_tex: Texture2D


## A soft star-shaped glow, drawn once.
static func _flash_texture() -> Texture2D:
	if _flash_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var p := Vector2(x - 31.5, y - 31.5) / 32.0
				var star := maxf(1.0 - absf(p.x) * 6.0 - absf(p.y), 1.0 - absf(p.y) * 6.0 - absf(p.x))
				var a := clampf(maxf(star, 1.0 - p.length() * 2.2), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_flash_tex = ImageTexture.create_from_image(img)
	return _flash_tex


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
