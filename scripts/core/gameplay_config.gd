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

@export_group("Item limits (0-8, 0 = can't be picked up)")
@export_range(0, 8) var scp_items := 3
@export_range(0, 8) var keycards := 3
@export_range(0, 8) var treatment_items := 3
@export_range(0, 8) var firearms := 1
@export_range(0, 8) var grenades := 2
@export_range(0, 8) var radios := 1
@export_range(0, 8) var special_weapons := 1
@export_range(0, 8) var armor := 1

@export_group("Ammo limits (rounds per ammo type)")
@export var ammo_limits: Dictionary[StringName, int] = {&"9mm": 120}

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


## How many items of this category may be carried (before armor bonuses).
func get_item_limit(category: ItemData.Category) -> int:
	if not _CATEGORY_KEYS.has(category):
		return MAX_SLOTS  # Unlimited items: only the slot count limits them.
	return clampi(get(_CATEGORY_KEYS[category]), 0, MAX_SLOTS)


func get_ammo_limit(ammo_type: StringName) -> int:
	return maxi(ammo_limits.get(ammo_type, 0), 0)


## Returns a copy of `defaults` with values from the config file applied.
## Writes the file (with all current values) so owners can find and edit it.
static func load_with_overrides(defaults: GameplayConfig, path := FILE_PATH) -> GameplayConfig:
	var config: GameplayConfig = defaults.duplicate(true)
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key in _CATEGORY_KEYS.values():
			config.set(key, clampi(int(file.get_value("item_limits", key, config.get(key))), 0, MAX_SLOTS))
		if file.has_section("ammo_limits"):
			for ammo_type in file.get_section_keys("ammo_limits"):
				config.ammo_limits[StringName(ammo_type)] = maxi(int(file.get_value("ammo_limits", ammo_type)), 0)
	config.save_to_file(path)
	return config


func save_to_file(path := FILE_PATH) -> void:
	var file := ConfigFile.new()
	for key in _CATEGORY_KEYS.values():
		file.set_value("item_limits", key, get(key))
	for ammo_type in ammo_limits:
		file.set_value("ammo_limits", String(ammo_type), ammo_limits[ammo_type])
	file.save(path)
