class_name ItemPickup
extends RigidBody3D
## An item lying in the world. Look at it and press E to pick it up.
##
## To place one in a level: add the scene res://scenes/items/item_pickup.tscn
## and drag an item .tres from res://resources/items/ into "Item Data".

@export var item_data: ItemData

## Set this before adding to the scene to drop an existing item (keeps ammo).
var item: ItemInstance


func _ready() -> void:
	if item == null:
		item = ItemInstance.new(item_data)
	item_data = item.data
	add_child(ItemVisuals.build(item.data))
	var shape := BoxShape3D.new()
	shape.size = ItemVisuals.get_pickup_size(item.data)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func get_interaction_prompt(actor: Node) -> String:
	if actor.has_method("can_take_item") and not actor.can_take_item(item):
		return "Inventory full"
	return "[E] Pick up %s" % item.data.display_name


func interact(actor: Node) -> void:
	if actor.has_method("give_item") and actor.give_item(item):
		queue_free()
