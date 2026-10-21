class_name ItemInstance
extends RefCounted
## One actual item in the world or in someone's inventory. Several pistols
## share the same ItemData but each has its own ammo, so that per-item state
## lives here.

var data: ItemData
## Rounds loaded in a firearm, or rounds left in an ammo box.
var ammo := 0


func _init(item_data: ItemData = null) -> void:
	data = item_data
	if data == null:
		return
	if data.kind == ItemData.Kind.FIREARM:
		ammo = data.magazine_size
	elif data.kind == ItemData.Kind.AMMO:
		ammo = data.ammo_amount


## An ammo box holding a specific number of rounds (used when dropping ammo).
static func ammo_box(box_data: ItemData, rounds: int) -> ItemInstance:
	var box := ItemInstance.new(box_data)
	box.ammo = rounds
	return box


func get_label() -> String:
	if data.kind == ItemData.Kind.AMMO:
		return "%s (%d)" % [data.display_name, ammo]
	return data.display_name
