class_name LootLocker
extends StaticBody3D
## A metal locker with random loot. Some are locked and need a keycard
## (held in hand, like doors). Opening it spills its contents out.

## Door.Access type and level needed (NONE = unlocked).
@export var access := 0
@export_range(0, 3) var required_level := 0
## Item ids (res://resources/items/<id>.tres), decided by the map generator.
@export var contents: Array[String] = []

var is_open := false
var _hinge: Node3D
var _light: MeshInstance3D


func _ready() -> void:
	var body_mat := PropBuilder.mat("metal")
	PropBuilder.add_box(self, Vector3(0, 1.0, 0.04), Vector3(0.8, 2.0, 0.42), PropBuilder.mat("metal_dark"))
	PropBuilder.add_box(self, Vector3(0, 0.9, 0.04), Vector3(0.7, 0.04, 0.38), body_mat)
	_hinge = Node3D.new()
	_hinge.position = Vector3(-0.4, 0, -0.19)
	add_child(_hinge)
	PropBuilder.add_box(_hinge, Vector3(0.4, 1.0, 0), Vector3(0.78, 1.96, 0.04), body_mat)
	for y in [1.7, 1.6, 1.5]:
		PropBuilder.add_box(_hinge, Vector3(0.4, y, -0.025), Vector3(0.5, 0.03, 0.01), PropBuilder.mat("metal_dark"))
	_light = PropBuilder.add_box(_hinge, Vector3(0.68, 1.1, -0.03), Vector3(0.06, 0.1, 0.02), StandardMaterial3D.new())
	if access != 0:
		var tag := PropBuilder.add_label(_hinge, _short_access(), Vector3(0.4, 1.3, -0.03), 28)
		tag.rotation.y = PI
		tag.modulate = Color(0.1, 0.1, 0.1)
	PropBuilder.add_shape(self, Vector3(0, 1.0, 0.0), Vector3(0.8, 2.0, 0.5))
	_update_light()


func _short_access() -> String:
	return "%s%d" % [["", "C", "A", "ADM"][access], required_level]


func _update_light() -> void:
	var m := _light.material_override as StandardMaterial3D
	m.emission_enabled = true
	var color := Color(0.2, 1.0, 0.3) if is_open or access == 0 else Color(1.0, 0.15, 0.1)
	m.albedo_color = color
	m.emission = color


func can_open(actor: Node) -> bool:
	if PropBuilder.is_disarmed(actor):
		return false
	if access == 0 or required_level <= 0:
		return true
	var card := PropBuilder.held_card(actor)
	return card != null and card.grants_access(access, required_level)


func get_interaction_prompt(actor: Node) -> String:
	if is_open:
		return "Locker (empty)" if contents.is_empty() else ""
	if PropBuilder.is_disarmed(actor):
		return "You are disarmed"
	if not can_open(actor):
		return "Locked: requires %s Level %d keycard" % [Door.ACCESS_NAMES[access], required_level]
	return "[E] Open locker"


func interact(actor: Node) -> void:
	if is_open or not can_open(actor):
		return
	open()


func open() -> void:
	is_open = true
	_update_light()
	create_tween().tween_property(_hinge, "rotation:y", deg_to_rad(-110), 0.5).set_trans(Tween.TRANS_BACK)
	var pickup_scene: PackedScene = load("res://scenes/items/item_pickup.tscn")
	var i := 0
	for id in contents:
		var data: ItemData = load("res://resources/items/%s.tres" % id)
		if data == null:
			continue
		var p: ItemPickup = pickup_scene.instantiate()
		p.item_data = data
		get_parent().add_child(p)
		p.global_position = to_global(Vector3(-0.2 + i * 0.2, 0.6 + i * 0.25, -0.55))
		p.linear_velocity = -global_basis.z * 1.0
		i += 1
	contents.clear()
