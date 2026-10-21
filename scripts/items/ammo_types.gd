class_name AmmoTypes
extends RefCounted
## The ammunition types in the game (constant data, not game state).

const NINE_MM := &"9x19mm"
const FIVE_FIVE_SIX := &"556x45mm"
const SEVEN_SIX_TWO := &"762x39mm"
const BUCKSHOT := &"12_70_buckshot"
const FORTY_FOUR := &"44_mag"

const ALL: Array[StringName] = [NINE_MM, FIVE_FIVE_SIX, SEVEN_SIX_TWO, BUCKSHOT, FORTY_FOUR]

const DISPLAY_NAMES := {
	NINE_MM: "9x19mm",
	FIVE_FIVE_SIX: "5.56x45mm",
	SEVEN_SIX_TWO: "7.62x39mm",
	BUCKSHOT: "12/70 Buckshot",
	FORTY_FOUR: ".44 Mag",
}

## The ammo box item for each type (used when ammo is dropped).
const BOX_ITEMS := {
	NINE_MM: "res://resources/items/ammo_9x19mm.tres",
	FIVE_FIVE_SIX: "res://resources/items/ammo_556x45mm.tres",
	SEVEN_SIX_TWO: "res://resources/items/ammo_762x39mm.tres",
	BUCKSHOT: "res://resources/items/ammo_12_70_buckshot.tres",
	FORTY_FOUR: "res://resources/items/ammo_44_mag.tres",
}


static func display_name(ammo_type: StringName) -> String:
	return DISPLAY_NAMES.get(ammo_type, String(ammo_type))


static func box_item(ammo_type: StringName) -> ItemData:
	return load(BOX_ITEMS[ammo_type]) if BOX_ITEMS.has(ammo_type) else null
