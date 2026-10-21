class_name ItemData
extends Resource
## The definition of a kind of item ("Level 1 Keycard", "Medkit", "Pistol"...).
##
## Each item type is a .tres file in res://resources/items/. Double-click one
## in Godot to tweak its numbers in the Inspector. The actual items players
## carry are ItemInstances that point at one of these.

## What the item does when used.
enum Kind { KEYCARD, MEDKIT, PISTOL, AMMO, ARMOR }

## Which carry limit the item counts towards (see GameplayConfig).
## UNLIMITED items (e.g. coins) are only limited by the 8 inventory slots.
enum Category {
	SCP_ITEM,
	KEYCARD,
	TREATMENT,
	FIREARM,
	GRENADE,
	RADIO,
	SPECIAL_WEAPON,
	ARMOR,
	UNLIMITED,
	AMMO,
}

const CATEGORY_NAMES := {
	Category.SCP_ITEM: "SCP Items",
	Category.KEYCARD: "Keycards",
	Category.TREATMENT: "Treatment Items",
	Category.FIREARM: "Firearms",
	Category.GRENADE: "Grenades",
	Category.RADIO: "Radios",
	Category.SPECIAL_WEAPON: "Special Weapons",
	Category.ARMOR: "Armor",
	Category.UNLIMITED: "Other",
	Category.AMMO: "Ammo",
}

@export var display_name := "Item"
## Short text shown in the inventory.
@export var short_name := "ITEM"
@export var kind := Kind.KEYCARD
@export var category := Category.UNLIMITED
@export var color := Color.WHITE

@export_group("Keycard")
## Doors with a required clearance up to this level will open.
@export_range(0, 5) var clearance := 0

@export_group("Medkit")
@export var heal_amount := 65.0

@export_group("Weapon")
@export var damage := 20.0
@export var magazine_size := 12
## Seconds between shots.
@export var fire_interval := 0.18
@export var reload_time := 1.6
@export var max_range := 60.0
## Which ammo this weapon loads (must match an ammo box's ammo_type).
@export var ammo_type := &"9mm"

@export_group("Ammo")
## Ammo boxes: which ammo they contain and how many rounds.
@export var ammo_amount := 24

@export_group("Armor")
## While this armor is carried, these categories may hold extra items.
## Example: Heavy Armor gives {Treatment: +1, Firearm: +2, Grenade: +2}.
@export var limit_bonuses: Dictionary[Category, int] = {}


## Ammo goes into a separate counter instead of taking an inventory slot.
func uses_slot() -> bool:
	return category != Category.AMMO


static func category_name(value: Category) -> String:
	return CATEGORY_NAMES.get(value, "Items")
