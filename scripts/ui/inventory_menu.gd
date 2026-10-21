class_name InventoryMenu
extends CanvasLayer
## The inventory screen (Tab): a wheel with the 8 slots, plus carry limits and
## ammo on the side.
##
## Left click a slot to hold that item (click again to put it away), right
## click to drop it. Like other menus it only *asks*: the requests go to the
## player's InputSource, so the character changes items during its normal
## physics tick, exactly like a bot or network player would.

signal select_requested(slot: int)
signal drop_requested(slot: int)

var _character: CharacterController

@onready var wheel: InventoryWheel = %Wheel
@onready var limits_label: RichTextLabel = %Limits


func _ready() -> void:
	visible = false
	wheel.slot_clicked.connect(_on_slot_clicked)
	wheel.hovered_changed.connect(func(_slot: int): _update_center())


func bind_character(character: CharacterController) -> void:
	_character = character
	character.inventory.changed.connect(refresh)
	character.items.equipped_changed.connect(func(_slot: int): refresh())
	refresh()


func refresh() -> void:
	if _character == null:
		return
	var inventory := _character.inventory
	var info: Array[Dictionary] = []
	for slot in Inventory.SLOT_COUNT:
		var item := inventory.get_item(slot)
		if item == null:
			info.append({})
		else:
			info.append({"title": _short_title(item.data), "subtitle": _subtitle(item)})
	wheel.set_slots(info, _character.items.equipped_slot)
	limits_label.text = _limits_text(inventory)
	_update_center()


func _update_center() -> void:
	if _character == null:
		return
	var slot := wheel.hovered_slot
	var item := _character.inventory.get_item(slot) if slot != -1 else null
	if item != null:
		var action := "Left click: put away" if slot == _character.items.equipped_slot else "Left click: hold"
		wheel.center_lines = [item.data.display_name, _subtitle(item), action, "Right click: drop"]
	else:
		var held := _character.items.get_equipped()
		wheel.center_lines = ["INVENTORY", "Holding: %s" % (held.data.display_name if held else "nothing"), "Tab: close"]


func _short_title(data: ItemData) -> String:
	return data.display_name.replace(" Keycard", "").replace(" Grenade", "")


func _subtitle(item: ItemInstance) -> String:
	match item.data.kind:
		ItemData.Kind.ARMOR:
			return "Worn"
		ItemData.Kind.FIREARM:
			return "%d / %d" % [item.ammo, item.data.magazine_size]
		ItemData.Kind.KEYCARD:
			return "Keycard"
	return ItemData.category_name(item.data.category)


func _limits_text(inventory: Inventory) -> String:
	var lines := PackedStringArray(["[b]CARRY LIMITS[/b]"])
	for category: ItemData.Category in ItemData.CATEGORY_NAMES:
		if category == ItemData.Category.UNLIMITED or category == ItemData.Category.AMMO:
			continue
		var count := inventory.count_category(category)
		var limit := inventory.get_limit(category)
		var line := "%s  %d / %d" % [ItemData.category_name(category), count, limit]
		if count > 0:
			line = "[color=#ffffff]%s[/color]" % line
		elif limit == 0:
			line = "[color=#666666]%s[/color]" % line
		lines.append(line)
	var armor := inventory.get_armor()
	lines.append("\n[b]AMMO[/b]  (%s)" % (armor.display_name if armor else "no armor"))
	for ammo_type in AmmoTypes.ALL:
		var limit := inventory.get_ammo_limit(ammo_type)
		var limit_text := "unlimited" if limit >= GameplayConfig.UNLIMITED_AMMO else str(limit)
		var line := "%s  %d / %s" % [AmmoTypes.display_name(ammo_type), inventory.get_ammo(ammo_type), limit_text]
		if inventory.get_ammo(ammo_type) > 0:
			line = "[color=#ffffff]%s[/color]" % line
		lines.append(line)
	return "\n".join(lines)


func _on_slot_clicked(slot: int, button: MouseButton) -> void:
	if _character == null or _character.inventory.get_item(slot) == null:
		return
	if button == MOUSE_BUTTON_LEFT:
		select_requested.emit(slot)
	elif button == MOUSE_BUTTON_RIGHT:
		drop_requested.emit(slot)
