class_name ItemData
extends Resource
## The definition of a kind of item ("Scientist Keycard", "Painkillers"...).
##
## Each item type is a .tres file in res://resources/items/. Double-click one
## in Godot to tweak its numbers in the Inspector. The actual items players
## carry are ItemInstances that point at one of these.

## What the item does when used.
enum Kind { KEYCARD, MEDICAL, FIREARM, AMMO, ARMOR, GRENADE }

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

## Item tier flags (an item can have more than one).
## Common items don't stop their holder from being disarmed; all others do.
## Later, tiers also decide how likely an item is lost in special places.
enum Tier { COMMON = 1, MILITARY_GRADE = 2, RARE = 4, EXTRA_RARE = 8 }

enum MedicalEffect { HEAL_INSTANT, HEAL_OVER_TIME, ADRENALINE }
enum GrenadeType { HIGH_EXPLOSIVE, FLASHBANG }
enum ArmorTier { NONE, LIGHT, COMBAT, HEAVY }

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

## Unique name used by code and config files, e.g. &"first_aid_kit".
@export var id := &""
@export var display_name := "Item"
@export var kind := Kind.KEYCARD
@export var category := Category.UNLIMITED
@export_flags("Common", "Military Grade", "Rare", "Extra Rare") var tiers: int = Tier.COMMON
@export var color := Color.WHITE
## Heavier items fly less far when thrown.
@export var weight := 0.3

@export_group("Keycard")
## Access levels (0-3) for each kind of door. A door opens if the held card's
## level for that door's access type is high enough.
@export_range(0, 3) var containment_level := 0
@export_range(0, 3) var armory_level := 0
@export_range(0, 3) var admin_level := 0
## For the keycard hotkey: higher = preferred.
@export var priority := 0

@export_group("Medical")
@export var medical_effect := MedicalEffect.HEAL_INSTANT
## Seconds the item takes to use. Switching items cancels it.
@export var use_time := 1.0
@export var heal_amount := 65.0
## For heal-over-time items, how long the healing lasts.
@export var heal_duration := 0.0
## Adrenaline: temporary extra hit points that slowly fade.
@export var shield_amount := 0.0
## Adrenaline: speed multiplier and how long it lasts.
@export var speed_boost := 1.0
@export var speed_boost_duration := 0.0

@export_group("Weapon")
@export var damage := 20.0
@export var magazine_size := 12
## Seconds between shots.
@export var fire_interval := 0.18
@export var reload_time := 1.6
@export var max_range := 60.0

@export_group("Ammo")
## Which ammo a firearm loads, or which ammo a box contains.
@export var ammo_type := &"9x19mm"
## Rounds in an ammo box.
@export var ammo_amount := 30

@export_group("Grenade")
@export var grenade_type := GrenadeType.HIGH_EXPLOSIVE
## Seconds from throw to detonation.
@export var fuse_time := 3.0
@export var blast_radius := 7.0
## Damage at the centre of an explosion (less further away).
@export var blast_damage := 160.0
## Flashbang: seconds a target looking at it stays blinded.
@export var blind_duration := 4.0

@export_group("Armor")
@export var armor_tier := ArmorTier.NONE
## While this armor is carried, these categories may hold extra items.
## Example: Heavy Armor gives {Treatment: +1, Firearm: +2, Grenade: +2}.
@export var limit_bonuses: Dictionary[Category, int] = {}


## Ammo goes into a separate counter instead of taking an inventory slot.
func uses_slot() -> bool:
	return category != Category.AMMO


## Holding this item stops other players from disarming you.
func blocks_disarm() -> bool:
	return tiers != Tier.COMMON


## Short name for the inventory and messages.
func get_short_name() -> String:
	return display_name


## Does this keycard open doors of `access` type needing `level`?
func grants_access(access: int, level: int) -> bool:
	if kind != Kind.KEYCARD:
		return false
	return get_access_level(access) >= level


func get_access_level(access: int) -> int:
	match access:
		Door.Access.CONTAINMENT:
			return containment_level
		Door.Access.ARMORY:
			return armory_level
		Door.Access.ADMIN:
			return admin_level
	return 0


static func category_name(value: Category) -> String:
	return CATEGORY_NAMES.get(value, "Items")
