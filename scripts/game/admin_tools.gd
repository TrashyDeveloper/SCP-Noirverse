class_name AdminTools
extends Node
## Admin commands: teleporting, bringing players, god mode, noclip, giving
## items, switching roles and forcing warheads. The admin menu only calls
## these; later a server can run the same functions for admins online.

var round_manager: RoundManager
var level: Node3D

var _locations: Array[Dictionary] = []


func setup(manager: RoundManager, level_node: Node3D) -> void:
	round_manager = manager
	level = level_node


## Every character in the round (players and bots, alive or dead).
func get_characters() -> Array[CharacterController]:
	var list: Array[CharacterController] = []
	for c in round_manager.characters:
		if is_instance_valid(c) and (c.is_alive or c.input_source != null):
			list.append(c)
	return list


## One line about a character for lists.
func describe(c: CharacterController) -> String:
	var role := c.character_class.display_name if c.character_class != null else "?"
	if not c.is_alive:
		return "%s  -  %s  -  DEAD" % [c.player_name, role]
	return "%s  -  %s  -  %s  -  %d HP%s%s" % [c.player_name, role, round_manager.zone_at(c), ceili(c.health.current),
		"  - GOD" if c.god_mode else "", "  - NOCLIP" if c.noclip else ""]


## Places to teleport to: [{name, position}], sorted by zone.
func get_locations() -> Array[Dictionary]:
	if not _locations.is_empty():
		return _locations
	var counts := {}
	var zone_order := {"LCZ": 0, "HCZ": 1, "EZ": 2}
	var rooms: Array = level.get_meta("rooms", [])
	var list := []
	for r in rooms:
		var info: Dictionary = FacilityGenerator.ROOMS.get(r.type, {})
		var room_name: String = String(info.get("name", r.type)).capitalize() if r.type != "lift" else "Checkpoint lift"
		if r.type == "gate":
			room_name = "Gate"
		var key := "%s %s" % [r.zone, room_name]
		counts[key] = counts.get(key, 0) + 1
		var shown := room_name if counts[key] == 1 else "%s %d" % [room_name, counts[key]]
		list.append({"name": "%s  ·  %s" % [r.zone, shown], "position": r.position, "order": zone_order.get(r.zone, 3)})
	var extras := {
		"Surface  ·  Exit road (escape)": _first("*", "EscapeZone"),
		"Surface  ·  Gamma reactor": _first("*", "GammaConsole"),
		"Surface  ·  Warhead Control": _first("*", "DeltaConsole"),
		"Surface  ·  MTF helipad": _spawn("MTF"),
		"Surface  ·  Chaos trucks": _spawn("Chaos"),
	}
	for n in extras:
		if extras[n] != null:
			list.append({"name": n, "position": extras[n], "order": 4})
	list.sort_custom(func(a, b): return a.order < b.order or (a.order == b.order and a.name < b.name))
	for item in list:
		_locations.append({"name": item.name, "position": item.position})
	return _locations


func _first(pattern: String, node_name: String) -> Variant:
	var found := level.find_children(node_name, "", true, false)
	if found.is_empty():
		found = level.find_children(pattern, node_name, true, false)
	return (found[0] as Node3D).global_position if not found.is_empty() else null


func _spawn(group: String) -> Variant:
	var node := level.get_node_or_null("SpawnPoints/" + group)
	return node.get_child(0).global_position if node != null and node.get_child_count() > 0 else null


## Moves a character to (near) `pos`, onto free floor.
func teleport(c: CharacterController, pos: Vector3) -> void:
	c.global_position = find_free_spot(pos)
	c.velocity = Vector3.ZERO


func teleport_to(c: CharacterController, target: CharacterController) -> void:
	teleport(c, target.global_position - target.global_basis.z * 1.5)


## Brings `target` in front of `admin`.
func bring(target: CharacterController, admin: CharacterController) -> void:
	teleport(target, admin.global_position - admin.global_basis.z * 1.8)


## The nearest spot to `pos` where a person fits standing on a floor.
func find_free_spot(pos: Vector3) -> Vector3:
	var space := level.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.8
	for ring in 12:
		var steps := 1 if ring == 0 else ring * 8
		for i in steps:
			var a := TAU * i / steps
			var p := pos + Vector3(cos(a), 0, sin(a)) * ring * 0.9
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.5, 0), p + Vector3(0, -2.0, 0), 1))
			if not hit:
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = Transform3D(Basis(), hit.position + Vector3(0, 1.0, 0))
			q.collision_mask = 1
			if space.intersect_shape(q, 1).is_empty():
				return hit.position + Vector3(0, 0.05, 0)
	return pos + Vector3(0, 0.2, 0)


## Gives an item (dropped at their feet if it doesn't fit).
func give_item(c: CharacterController, item_id: String) -> bool:
	var data: ItemData = load("res://resources/items/%s.tres" % item_id)
	if data == null or not c.is_alive:
		return false
	var item := ItemInstance.new(data)
	if data.kind == ItemData.Kind.AMMO:
		c.inventory.give_ammo(data.ammo_type, data.ammo_amount)
		return true
	if not c.give_item(item):
		c.items.drop_item_instance(item)
		return false
	return true


## Switches a character's role. Returns the character (a new one if a dead
## character was brought back).
func set_role(c: CharacterController, class_id: String, at_spawn: bool) -> CharacterController:
	return round_manager.set_character_class(c, RoundManager.load_class(class_id), at_spawn)


func heal(c: CharacterController) -> void:
	if c.is_alive:
		c.health.heal(c.health.max_health)


func kill(c: CharacterController) -> void:
	if c.is_alive:
		var was_god := c.god_mode
		c.god_mode = false
		c.health.take_damage(100000.0, null)
		c.god_mode = was_god


func force_warhead(warhead: int, action: String) -> void:
	round_manager.force_warhead(warhead, action)


## All item ids (file names in res://resources/items).
static func all_items() -> Array[String]:
	var ids: Array[String] = []
	for f in ResourceLoader.list_directory("res://resources/items"):
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	ids.sort()
	return ids


## All class ids (file names in res://resources/classes).
static func all_classes() -> Array[String]:
	var ids: Array[String] = []
	for f in ResourceLoader.list_directory("res://resources/classes"):
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	ids.sort()
	return ids
