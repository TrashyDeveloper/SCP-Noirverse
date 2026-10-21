class_name GameplayConfig
extends Resource
## Rules a server owner can change: item carry limits and ammo limits.
##
## Defaults live in res://resources/gameplay_config.tres (edit it in the
## Inspector). When the game starts, it also reads
## `user://gameplay_config.cfg`, a plain text file, and creates it with the
## current values if it doesn't exist yet, so the rules can be changed
## without opening Godot. (On Windows, user:// is
## %APPDATA%\Godot\app_userdata\SCP Noirverse\.)
##
## The match owns its own config object (no global settings), so later the
## server can send its rules to every player.

const FILE_PATH := "user://gameplay_config.cfg"
const MAX_SLOTS := 8
const MAX_AMMO_LIMIT := 65535
## What "0 = unlimited" ammo turns into.
const UNLIMITED_AMMO := 1 << 30

@export_group("Item limits (0-8, 0 = can't be picked up)")
@export_range(0, 8) var scp_items := 3
@export_range(0, 8) var keycards := 3
@export_range(0, 8) var treatment_items := 3
@export_range(0, 8) var firearms := 1
@export_range(0, 8) var grenades := 2
@export_range(0, 8) var radios := 1
@export_range(0, 8) var special_weapons := 1
@export_range(0, 8) var armor := 1

@export_group("Ammo limits per armor (0-65535 rounds, 0 = unlimited)")
@export var ammo_no_armor: Dictionary[StringName, int] = {
	&"9x19mm": 40, &"556x45mm": 40, &"762x39mm": 40, &"12_70_buckshot": 14, &"44_mag": 18,
}
@export var ammo_light_armor: Dictionary[StringName, int] = {
	&"9x19mm": 70, &"556x45mm": 40, &"762x39mm": 40, &"12_70_buckshot": 14, &"44_mag": 18,
}
@export var ammo_combat_armor: Dictionary[StringName, int] = {
	&"9x19mm": 170, &"556x45mm": 120, &"762x39mm": 120, &"12_70_buckshot": 54, &"44_mag": 48,
}
@export var ammo_heavy_armor: Dictionary[StringName, int] = {
	&"9x19mm": 210, &"556x45mm": 200, &"762x39mm": 200, &"12_70_buckshot": 74, &"44_mag": 68,
}

const _CATEGORY_KEYS := {
	ItemData.Category.SCP_ITEM: "scp_items",
	ItemData.Category.KEYCARD: "keycards",
	ItemData.Category.TREATMENT: "treatment_items",
	ItemData.Category.FIREARM: "firearms",
	ItemData.Category.GRENADE: "grenades",
	ItemData.Category.RADIO: "radios",
	ItemData.Category.SPECIAL_WEAPON: "special_weapons",
	ItemData.Category.ARMOR: "armor",
}

## Config-file section and property name for each armor tier's ammo table.
const _AMMO_TABLES := {
	ItemData.ArmorTier.NONE: "ammo_no_armor",
	ItemData.ArmorTier.LIGHT: "ammo_light_armor",
	ItemData.ArmorTier.COMBAT: "ammo_combat_armor",
	ItemData.ArmorTier.HEAVY: "ammo_heavy_armor",
}


## How many items of this category may be carried (before armor bonuses).
func get_item_limit(category: ItemData.Category) -> int:
	if not _CATEGORY_KEYS.has(category):
		return MAX_SLOTS  # Unlimited items: only the slot count limits them.
	return clampi(get(_CATEGORY_KEYS[category]), 0, MAX_SLOTS)


## Max spare rounds of `ammo_type` for someone wearing `armor_tier`.
## A limit of 0 means unlimited.
func get_ammo_limit(ammo_type: StringName, armor_tier: ItemData.ArmorTier) -> int:
	var table: Dictionary = get(_AMMO_TABLES[armor_tier])
	var limit := clampi(table.get(ammo_type, 0), 0, MAX_AMMO_LIMIT)
	return UNLIMITED_AMMO if limit == 0 else limit


## Returns a copy of `defaults` with values from the config file applied.
## Writes the file (with all current values) so owners can find and edit it.
static func load_with_overrides(defaults: GameplayConfig, path := FILE_PATH) -> GameplayConfig:
	var config: GameplayConfig = defaults.duplicate(true)
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key in _CATEGORY_KEYS.values():
			var value := int(file.get_value("item_limits", key, config.get(key)))
			config.set(key, clampi(value, 0, MAX_SLOTS))
		for section in _AMMO_TABLES.values():
			if not file.has_section(section):
				continue
			var table: Dictionary = config.get(section)
			for ammo_type in file.get_section_keys(section):
				table[StringName(ammo_type)] = clampi(int(file.get_value(section, ammo_type)), 0, MAX_AMMO_LIMIT)
	config.save_to_file(path)
	return config


func save_to_file(path := FILE_PATH) -> void:
	var file := ConfigFile.new()
	for key in _CATEGORY_KEYS.values():
		file.set_value("item_limits", key, get(key))
	for section in _AMMO_TABLES.values():
		var table: Dictionary = get(section)
		for ammo_type in table:
			file.set_value(section, String(ammo_type), table[ammo_type])
	file.save(path)
