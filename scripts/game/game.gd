extends Node3D
## The in-game scene: loads a level and spawns the local player into it.
##
## Everything about the match lives on this node and its children (no global
## singletons), so later a server can run the same logic for many players.

const CHARACTER_SCENE := preload("res://scenes/player/character.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"

@export var level_scene: PackedScene

var level: Node3D
var local_character: CharacterController
var local_input: LocalPlayerInput

@onready var level_root: Node3D = $Level
@onready var actors: Node3D = $Actors
@onready var hud: Hud = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	level = level_scene.instantiate()
	level_root.add_child(level)
	_spawn_local_player()
	pause_menu.resume_requested.connect(set_paused.bind(false))
	pause_menu.main_menu_requested.connect(_go_to_main_menu)
	set_paused(false)


func _spawn_local_player() -> void:
	local_character = CHARACTER_SCENE.instantiate()
	local_character.name = "LocalPlayer"
	actors.add_child(local_character)
	var spawn := _pick_spawn_point()
	local_character.global_position = spawn.global_position
	local_character.rotation.y = spawn.global_rotation.y

	local_input = LocalPlayerInput.new()
	local_input.name = "Input"
	local_input.set_view_angles(spawn.global_rotation.y, 0.0)
	local_character.possess(local_input, true)
	hud.bind_character(local_character)


func _pick_spawn_point() -> Node3D:
	var points := level.get_node("SpawnPoints").get_children()
	return points.pick_random()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused:
		# Clicking back into the window grabs the mouse again.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_menu.visible = paused
	local_input.enabled = not paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _go_to_main_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
