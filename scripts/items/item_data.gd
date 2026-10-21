class_name ItemData
extends Resource
## The definition of a kind of item ("Level 1 Keycard", "Medkit", "Pistol"...).
##
## Each item type is a .tres file in res://resources/items/. Double-click one
## in Godot to tweak its numbers in the Inspector. The actual items players
## carry are ItemInstances that point at one of these.

enum Kind { KEYCARD, MEDKIT, PISTOL, AMMO }

@export var display_name := "Item"
## Short text shown in the inventory bar.
@export var short_name := "ITEM"
@export var kind := Kind.KEYCARD
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

@export_group("Ammo")
## Rounds given when an ammo box is picked up.
@export var ammo_amount := 24


## Ammo goes into a separate counter instead of taking an inventory slot.
func uses_slot() -> bool:
	return kind != Kind.AMMO
