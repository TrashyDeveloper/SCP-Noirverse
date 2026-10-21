class_name Inventory
extends Node
## A character's items: a few slots plus a pool of spare pistol rounds.

signal changed
signal item_added(item: ItemInstance)

const SLOT_COUNT := 6

@export var max_reserve_ammo := 120

## Fixed-size list; empty slots are null.
var slots: Array[ItemInstance] = []
var reserve_ammo := 0


func _init() -> void:
	slots.resize(SLOT_COUNT)


func get_item(slot: int) -> ItemInstance:
	if slot < 0 or slot >= SLOT_COUNT:
		return null
	return slots[slot]


func can_add(item: ItemInstance) -> bool:
	if not item.data.uses_slot():
		return reserve_ammo < max_reserve_ammo
	return slots.has(null)


## Puts the item in the first free slot. Returns false if there was no room.
func add_item(item: ItemInstance) -> bool:
	if not can_add(item):
		return false
	if item.data.uses_slot():
		slots[slots.find(null)] = item
	else:
		reserve_ammo = mini(reserve_ammo + item.data.ammo_amount, max_reserve_ammo)
	item_added.emit(item)
	changed.emit()
	return true


## Removes and returns the item in `slot` (or null if empty).
func take_item(slot: int) -> ItemInstance:
	var item := get_item(slot)
	if item != null:
		slots[slot] = null
		changed.emit()
	return item


## Removes up to `amount` spare rounds and returns how many were taken.
func take_ammo(amount: int) -> int:
	var taken := mini(amount, reserve_ammo)
	reserve_ammo -= taken
	changed.emit()
	return taken


## The best keycard level carried (0 if none).
func get_clearance() -> int:
	var best := 0
	for item in slots:
		if item != null and item.data.kind == ItemData.Kind.KEYCARD:
			best = maxi(best, item.data.clearance)
	return best
