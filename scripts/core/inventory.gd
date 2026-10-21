class_name Inventory
extends Node
## A character's items: 8 slots plus spare ammo per ammo type.
##
## How many items of each category fit is decided by the match's
## GameplayConfig, plus bonuses from any armor being carried.

signal changed
signal item_added(item: ItemInstance)

const SLOT_COUNT := 8

## The rules to follow. Set by the match when the character spawns; a
## default config is used if nobody sets one.
var config: GameplayConfig = GameplayConfig.new()
## Fixed-size list; empty slots are null.
var slots: Array[ItemInstance] = []
## Spare rounds per ammo type, e.g. {&"9mm": 24}.
var ammo: Dictionary[StringName, int] = {}


func _init() -> void:
	slots.resize(SLOT_COUNT)


func get_item(slot: int) -> ItemInstance:
	if slot < 0 or slot >= SLOT_COUNT:
		return null
	return slots[slot]


## How many carried items belong to `category`.
func count_category(category: ItemData.Category) -> int:
	var total := 0
	for item in slots:
		if item != null and item.data.category == category:
			total += 1
	return total


## The carry limit for `category`, including bonuses from carried armor.
func get_limit(category: ItemData.Category) -> int:
	var limit := config.get_item_limit(category)
	if limit == 0:
		return 0  # 0 means "can never be picked up", armor or not.
	for item in slots:
		if item != null and item.data.kind == ItemData.Kind.ARMOR:
			limit += item.data.limit_bonuses.get(category, 0)
	return clampi(limit, 0, SLOT_COUNT)


func get_ammo(ammo_type: StringName) -> int:
	return ammo.get(ammo_type, 0)


## Why `item` can't be picked up, or "" if it can.
func get_block_reason(item: ItemInstance) -> String:
	var data := item.data
	if not data.uses_slot():
		var ammo_limit := config.get_ammo_limit(data.ammo_type)
		if get_ammo(data.ammo_type) >= ammo_limit:
			return "Can't carry more %s ammo (%d/%d)" % [data.ammo_type, get_ammo(data.ammo_type), ammo_limit]
		return ""
	var limit := get_limit(data.category)
	var category_name := ItemData.category_name(data.category)
	if limit == 0:
		return "%s can't be picked up" % category_name
	var count := count_category(data.category)
	if count >= limit:
		return "Can't carry more %s (%d/%d)" % [category_name, count, limit]
	if not slots.has(null):
		return "Inventory full"
	return ""


func can_add(item: ItemInstance) -> bool:
	return get_block_reason(item) == ""


## Puts the item in the first free slot. Returns false if it doesn't fit.
func add_item(item: ItemInstance) -> bool:
	if not can_add(item):
		return false
	if item.data.uses_slot():
		slots[slots.find(null)] = item
	else:
		var ammo_type := item.data.ammo_type
		ammo[ammo_type] = mini(get_ammo(ammo_type) + item.data.ammo_amount, config.get_ammo_limit(ammo_type))
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
func take_ammo(ammo_type: StringName, amount: int) -> int:
	var taken := mini(amount, get_ammo(ammo_type))
	ammo[ammo_type] = get_ammo(ammo_type) - taken
	changed.emit()
	return taken


## Slots holding items above their category's limit (e.g. after armor was
## dropped). The newest extras come last so they are the ones dropped.
func get_excess_slots() -> Array[int]:
	var excess: Array[int] = []
	var seen := {}
	for slot in SLOT_COUNT:
		var item := slots[slot]
		if item == null:
			continue
		var category := item.data.category
		seen[category] = seen.get(category, 0) + 1
		if seen[category] > get_limit(category):
			excess.append(slot)
	return excess


## The best keycard level carried (0 if none).
func get_clearance() -> int:
	var best := 0
	for item in slots:
		if item != null and item.data.kind == ItemData.Kind.KEYCARD:
			best = maxi(best, item.data.clearance)
	return best
