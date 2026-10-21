class_name Inventory
extends Node
## A character's items: 8 slots plus spare ammo per ammo type.
##
## How many items of each category fit is decided by the match's
## GameplayConfig plus bonuses from carried armor. Ammo limits depend on the
## armor worn.

signal changed
signal item_added(item: ItemInstance, amount: int)

const SLOT_COUNT := 8

## The rules to follow. Set by the match when the character spawns; a
## default config is used if nobody sets one.
var config: GameplayConfig = GameplayConfig.new()
## Extra carry limits from the character's class (e.g. an Explosives
## Specialist carries more grenades): {Category: +amount}.
var extra_limits: Dictionary = {}
## Multiplies the ammo limits (e.g. 2 for a Heavy Gunner).
var ammo_multiplier := 1.0
## Fixed-size list; empty slots are null.
var slots: Array[ItemInstance] = []
## Spare rounds per ammo type, e.g. {&"9x19mm": 24}.
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


## The armor being worn (carried), or null.
func get_armor() -> ItemData:
	for item in slots:
		if item != null and item.data.kind == ItemData.Kind.ARMOR:
			return item.data
	return null


func get_armor_tier() -> ItemData.ArmorTier:
	var armor := get_armor()
	return armor.armor_tier if armor != null else ItemData.ArmorTier.NONE


## The carry limit for `category`, including bonuses from carried armor.
func get_limit(category: ItemData.Category) -> int:
	var limit := config.get_item_limit(category)
	if limit == 0:
		return 0  # 0 means "can never be picked up", armor or not.
	var armor := get_armor()
	if armor != null:
		limit += armor.limit_bonuses.get(category, 0)
	limit += extra_limits.get(category, 0)
	return clampi(limit, 0, SLOT_COUNT)


func get_ammo(ammo_type: StringName) -> int:
	return ammo.get(ammo_type, 0)


func get_ammo_limit(ammo_type: StringName) -> int:
	var limit := config.get_ammo_limit(ammo_type, get_armor_tier())
	if limit >= GameplayConfig.UNLIMITED_AMMO:
		return limit
	return int(limit * ammo_multiplier)


## Why `item` can't be picked up, or "" if it can.
func get_block_reason(item: ItemInstance) -> String:
	var data := item.data
	if not data.uses_slot():
		var limit := get_ammo_limit(data.ammo_type)
		if get_ammo(data.ammo_type) >= limit:
			return "Can't carry more %s ammo (%d/%d)" % [
				AmmoTypes.display_name(data.ammo_type), get_ammo(data.ammo_type), limit]
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


## Takes the item. Returns true if it was taken completely. An ammo box may be
## taken only partly (its `ammo` goes down) when the ammo limit is reached.
func add_item(item: ItemInstance) -> bool:
	if not can_add(item):
		return false
	if item.data.uses_slot():
		slots[slots.find(null)] = item
		item_added.emit(item, 1)
		changed.emit()
		return true
	var ammo_type := item.data.ammo_type
	var room := get_ammo_limit(ammo_type) - get_ammo(ammo_type)
	var taken := mini(room, item.ammo)
	ammo[ammo_type] = get_ammo(ammo_type) + taken
	item.ammo -= taken
	item_added.emit(item, taken)
	changed.emit()
	return item.ammo <= 0


## Adds spare rounds directly (e.g. starting ammo), up to the limit.
func give_ammo(ammo_type: StringName, amount: int) -> void:
	ammo[ammo_type] = mini(get_ammo(ammo_type) + amount, get_ammo_limit(ammo_type))
	changed.emit()


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
## dropped). Later slots count as the extras.
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


## Spare rounds above the current limits, per ammo type.
func get_excess_ammo() -> Dictionary[StringName, int]:
	var excess: Dictionary[StringName, int] = {}
	for ammo_type in ammo:
		var extra := get_ammo(ammo_type) - get_ammo_limit(ammo_type)
		if extra > 0:
			excess[ammo_type] = extra
	return excess


## Slot numbers of carried items matching `kind`, in inventory order.
func find_slots(kind: ItemData.Kind) -> Array[int]:
	var found: Array[int] = []
	for slot in SLOT_COUNT:
		if slots[slot] != null and slots[slot].data.kind == kind:
			found.append(slot)
	return found


func has_firearm() -> bool:
	return not find_slots(ItemData.Kind.FIREARM).is_empty()
