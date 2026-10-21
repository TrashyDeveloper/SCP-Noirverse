class_name CharacterClass
extends Resource
## A playable class ("role"): Class-D, Scientist, Facility Guard...
##
## Each class is a .tres file in res://resources/classes/. Double-click one to
## change its health, starting items or colour in the Inspector.

## Which side a class fights for. Classes on the same side are allies.
enum Side { FOUNDATION, INSURGENCY, SCP }

## Which group a class belongs to; escapees and reinforcements join the
## round's MTF unit or Chaos cell (see Factions).
enum Unit { NONE, MTF, CHAOS }

const SIDE_NAMES := {
	Side.FOUNDATION: "Foundation",
	Side.INSURGENCY: "Class-D & Chaos Insurgency",
	Side.SCP: "SCPs",
}

## Unique name used by code and the spawn queue, e.g. &"class_d".
@export var id := &""
@export var display_name := "Class"
## One line shown when you spawn as this class.
@export_multiline var objective := ""
@export var side := Side.FOUNDATION
@export var unit := Unit.NONE
## Body colour (in black & white this mostly shows as brightness).
@export var color := Color.WHITE
@export var max_health := 100.0
## Name of the group under the level's "SpawnPoints" node to spawn at.
@export var spawn_group := ""

## Special abilities, e.g. &"medic" (faster, stronger healing),
## &"fast_barricade", &"demolitions" (throws further, more grenades),
## &"intercom_priority", &"terminal_access". See CharacterClass.PERKS.
@export var perks: Array[StringName] = []
## Walking/sprinting speed multiplier (heavy gunners are slower).
@export var speed_multiplier := 1.0
## Extra carry limits per item category: {ItemData.Category: +amount}.
@export var limit_bonuses: Dictionary[ItemData.Category, int] = {}

## Notes for later steps (e.g. which weapon this class will get).
@export_multiline var notes := ""

@export_group("Starting equipment")
@export var starting_items: Array[ItemData] = []
## Spare ammo given at spawn, e.g. {&"9x19mm": 60}.
@export var starting_ammo: Dictionary[StringName, int] = {}

@export_group("Escaping")
## Can this class escape through an escape zone?
@export var can_escape := false
## The class you become after escaping freely.
@export var escape_class: CharacterClass
## The class you become if you escape while disarmed (you switch sides).
@export var escape_class_disarmed: CharacterClass


## What each perk does (shown when you spawn).
const PERKS := {
	&"medic": "Medical items work twice as fast and heal more",
	&"fast_barricade": "Builds and tears down barricades twice as fast",
	&"demolitions": "Throws grenades further and carries more of them",
	&"heavy": "Tough but slower; carries extra ammo",
	&"intercom_priority": "Intercom priority (short cooldown, can cut in)",
	&"terminal_access": "Full access to facility terminals",
}


## One line per perk, for the HUD.
func describe_perks() -> String:
	var lines := PackedStringArray()
	for perk in perks:
		lines.append("• " + PERKS.get(perk, String(perk)))
	return "\n".join(lines)


static func side_name(value: Side) -> String:
	return SIDE_NAMES.get(value, "Unknown")
