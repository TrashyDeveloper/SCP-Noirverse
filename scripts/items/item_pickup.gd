class_name ItemPickup
extends RigidBody3D
## An item lying in the world. Look at it and press E to pick it up.
##
## To place one in a level: add the scene res://scenes/items/item_pickup.tscn
## and drag an item .tres from res://resources/items/ into "Item Data".

## How long after a throw a hit on a card reader still counts as a swipe.
const THROW_ACTIVE_TIME := 2.0

@export var item_data: ItemData

## Set this before adding to the scene to drop an existing item (keeps ammo).
var item: ItemInstance
## The character who threw this item (null if it was just dropped/placed).
var thrown_by: Node:
	set(value):
		thrown_by = value
		_throw_time_left = THROW_ACTIVE_TIME if value != null else 0.0
		contact_monitor = value != null
		max_contacts_reported = 4 if value != null else 0

var _throw_time_left := 0.0


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
	mass = maxf(item.data.weight, 0.05)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if thrown_by != null:
		_throw_time_left -= delta
		if _throw_time_left <= 0.0:
			thrown_by = null


func get_interaction_prompt(actor: Node) -> String:
	if actor.has_method("get_pickup_block_reason"):
		var reason: String = actor.get_pickup_block_reason(item)
		if reason != "":
			return reason
	return "[E] Pick up %s" % item.get_label()


func interact(actor: Node) -> void:
	if actor.has_method("give_item") and actor.give_item(item):
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _throw_time_left <= 0.0:
		return
	if body is DoorReader and item.data.kind == ItemData.Kind.KEYCARD:
		body.on_card_hit(item.data)
		# Only one swipe per throw. (Physics settings can't change mid-callback.)
		_throw_time_left = 0.0
		set_deferred("thrown_by", null)
