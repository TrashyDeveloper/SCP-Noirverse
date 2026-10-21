class_name ItemInstance
extends RefCounted
## One actual item in the world or in someone's inventory. Several pistols
## share the same ItemData but each has its own ammo, so that per-item state
## lives here.

var data: ItemData
## Rounds currently loaded (only used by weapons).
var ammo := 0


func _init(item_data: ItemData = null) -> void:
	data = item_data
	if data != null and data.kind == ItemData.Kind.PISTOL:
		ammo = data.magazine_size
