class_name InventoryMenu
extends CanvasLayer
## The inventory screen (Tab). Shows the 8 slots, carry limits and ammo.
##
## Left click a slot to hold that item (click again to put it away), right
## click to drop it. Like other menus it only *asks*: the requests go to the
## player's InputSource, so the character changes items during its normal
## physics tick, exactly like a bot or network player would.

signal select_requested(slot: int)
signal drop_requested(slot: int)

var _character: CharacterController
var _buttons: Array[Button] = []
var _style_normal := StyleBoxFlat.new()
var _style_held := StyleBoxFlat.new()
var _style_hover := StyleBoxFlat.new()

@onready var grid: GridContainer = %Grid
@onready var limits_label: RichTextLabel = %Limits
@onready var held_label: Label = %Held


func _ready() -> void:
	visible = false
	_style_normal.bg_color = Color(0.06, 0.06, 0.06, 0.85)
	_style_normal.set_border_width_all(1)
	_style_normal.border_color = Color(0.45, 0.45, 0.42)
	_style_normal.set_content_margin_all(8)
	_style_hover = _style_normal.duplicate()
	_style_hover.bg_color = Color(0.16, 0.16, 0.15, 0.9)
	_style_held = _style_normal.duplicate()
	_style_held.set_border_width_all(3)
	_style_held.border_color = Color(0.95, 0.95, 0.9)
	_style_held.bg_color = Color(0.2, 0.2, 0.19, 0.95)
	for slot in Inventory.SLOT_COUNT:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 96)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_stylebox_override("hover", _style_hover)
		button.add_theme_stylebox_override("pressed", _style_hover)
		button.pressed.connect(func(): select_requested.emit(slot))
		button.gui_input.connect(_on_slot_gui_input.bind(slot))
		grid.add_child(button)
		_buttons.append(button)


func bind_character(character: CharacterController) -> void:
	_character = character
	character.inventory.changed.connect(refresh)
	character.items.equipped_changed.connect(func(_slot: int): refresh())
	refresh()


func refresh() -> void:
	if _character == null:
		return
	var inventory := _character.inventory
	var held := _character.items.equipped_slot
	for slot in Inventory.SLOT_COUNT:
		var item := inventory.get_item(slot)
		var button := _buttons[slot]
		if item == null:
			button.text = "- empty -"
			button.disabled = true
		else:
			var note := ItemData.category_name(item.data.category)
			if item.data.kind == ItemData.Kind.ARMOR:
				note = "WORN"
			elif item.data.kind == ItemData.Kind.PISTOL:
				note = "%s  ·  %d/%d" % [note, item.ammo, item.data.magazine_size]
			button.text = "%s\n%s" % [item.data.display_name, note]
			button.disabled = false
		button.add_theme_stylebox_override("normal", _style_held if slot == held else _style_normal)
		button.add_theme_stylebox_override("disabled", _style_normal)
	var held_item := _character.items.get_equipped()
	held_label.text = "Holding: %s" % (held_item.data.display_name if held_item else "nothing")
	limits_label.text = _limits_text(inventory)


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
	lines.append("\n[b]AMMO[/b]")
	var any_ammo := false
	for ammo_type in inventory.config.ammo_limits:
		lines.append("%s  %d / %d" % [ammo_type, inventory.get_ammo(ammo_type), inventory.config.get_ammo_limit(ammo_type)])
		any_ammo = true
	if not any_ammo:
		lines.append("none")
	return "\n".join(lines)


func _on_slot_gui_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _character != null and _character.inventory.get_item(slot) != null:
			drop_requested.emit(slot)
