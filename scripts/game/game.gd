extends Node3D
## The in-game scene: loads a level and spawns the local player into it.
##
## Everything about the match lives on this node and its children (no global
## singletons), so later a server can run the same logic for many players.

const CHARACTER_SCENE := preload("res://scenes/player/character.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"

@export var level_scene: PackedScene
## Default rules for this match (carry limits, ammo limits). Values from
## user://gameplay_config.cfg are applied on top when the match starts.
@export var gameplay_config: GameplayConfig

var config: GameplayConfig

var level: Node3D
var local_character: CharacterController
var local_input: LocalPlayerInput

@onready var level_root: Node3D = $Level
@onready var actors: Node3D = $Actors
@onready var hud: Hud = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var death_screen: DeathScreen = $DeathScreen
@onready var inventory_menu: InventoryMenu = $InventoryMenu


func _ready() -> void:
	config = GameplayConfig.load_with_overrides(gameplay_config)
	level = level_scene.instantiate()
	level_root.add_child(level)
	_spawn_local_player()
	pause_menu.resume_requested.connect(set_paused.bind(false))
	pause_menu.main_menu_requested.connect(_go_to_main_menu)
	death_screen.restart_requested.connect(_restart)
	death_screen.main_menu_requested.connect(_go_to_main_menu)
	inventory_menu.select_requested.connect(local_input.request_select_slot)
	inventory_menu.drop_requested.connect(local_input.request_drop_slot)
	set_paused(false)


func _spawn_local_player() -> void:
	local_character = CHARACTER_SCENE.instantiate()
	local_character.name = "LocalPlayer"
	actors.add_child(local_character)
	local_character.inventory.config = config
	var spawn := _pick_spawn_point()
	local_character.global_position = spawn.global_position
	local_character.rotation.y = spawn.global_rotation.y

	local_input = LocalPlayerInput.new()
	local_input.name = "Input"
	local_input.set_view_angles(spawn.global_rotation.y, 0.0)
	local_character.possess(local_input, true)
	local_character.died.connect(_on_local_player_died)
	hud.bind_character(local_character)
	inventory_menu.bind_character(local_character)


func _pick_spawn_point() -> Node3D:
	var points := level.get_node("SpawnPoints").get_children()
	return points.pick_random()


func _unhandled_input(event: InputEvent) -> void:
	if not local_character.is_alive:
		return
	if event.is_action_pressed("pause"):
		if inventory_menu.visible:
			set_inventory_open(false)
		else:
			set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not get_tree().paused:
		set_inventory_open(not inventory_menu.visible)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused \
			and not inventory_menu.visible:
		# Clicking back into the window grabs the mouse again.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_inventory_open(open: bool) -> void:
	inventory_menu.visible = open
	inventory_menu.refresh()
	local_input.look_enabled = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func set_paused(paused: bool) -> void:
	if paused and inventory_menu.visible:
		set_inventory_open(false)
	get_tree().paused = paused
	pause_menu.visible = paused
	local_input.enabled = not paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _on_local_player_died(source: Node) -> void:
	inventory_menu.visible = false
	local_input.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	death_screen.show_death(_describe_cause_of_death(source))


func _describe_cause_of_death(source: Node) -> String:
	if source == null:
		return "Cause of death: unknown"
	var cause = source.get("cause_of_death")
	if cause is String:
		return cause
	return "Killed by %s" % source.name


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_to_main_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
