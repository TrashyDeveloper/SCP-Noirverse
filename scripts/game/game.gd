extends Node3D
## The in-game scene: loads the level, lets the RoundManager run a round, and
## connects the local player to the HUD and menus.
##
## Everything about the match lives on this node and its children (no global
## singletons), so later a server can run the same logic for many players.

const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
## Explosions closer than this bring the colours back on screen.
const COLOR_BURST_RANGE := 30.0

@export var level_scene: PackedScene
## Default rules for this match (round, carry and ammo limits). Values from
## user://gameplay_config.cfg are applied on top when the match starts.
@export var gameplay_config: GameplayConfig

## Normal colour of every light, remembered while the alarm turns them red.
var _light_colors := {}
var _alarm_on := false

var config: GameplayConfig
var level: Node3D
var local_character: CharacterController
var local_input: LocalPlayerInput

@onready var level_root: Node3D = $Level
@onready var actors: Node3D = $Actors
@onready var round_manager: RoundManager = $RoundManager
@onready var hud: Hud = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var death_screen: DeathScreen = $DeathScreen
@onready var round_end_screen: RoundEndScreen = $RoundEndScreen
@onready var inventory_menu: InventoryMenu = $InventoryMenu
@onready var noir_overlay: NoirOverlay = $NoirOverlay


func _ready() -> void:
	config = GameplayConfig.load_with_overrides(gameplay_config)
	level = level_scene.instantiate()
	level_root.add_child(level)
	actors.child_entered_tree.connect(_on_actor_added)

	pause_menu.resume_requested.connect(set_paused.bind(false))
	pause_menu.main_menu_requested.connect(_go_to_main_menu)
	death_screen.restart_requested.connect(_restart)
	death_screen.main_menu_requested.connect(_go_to_main_menu)
	round_end_screen.next_round_requested.connect(_restart)
	round_end_screen.main_menu_requested.connect(_go_to_main_menu)

	local_input = LocalPlayerInput.new()
	local_input.name = "Input"
	inventory_menu.select_requested.connect(local_input.request_select_slot)
	inventory_menu.drop_requested.connect(local_input.request_drop_slot)

	round_manager.character_spawned.connect(_on_character_spawned)
	round_manager.character_escaped.connect(_on_character_escaped)
	round_manager.round_ended.connect(_on_round_ended)
	round_manager.warhead_changed.connect(_on_warhead_changed)
	round_manager.announcement.connect(func(text: String): hud.show_message(text, 5.0))
	round_manager.setup(level, actors, config)
	var players: Array[InputSource] = [local_input]
	round_manager.start_round(players)
	hud.round_manager = round_manager
	set_paused(false)


func _on_character_spawned(character: CharacterController, is_player: bool) -> void:
	if not is_player:
		return
	local_character = character
	character.died.connect(_on_local_player_died)
	character.disarm_changed.connect(func(disarmed: bool):
		if disarmed and inventory_menu.visible:
			set_inventory_open(false))
	hud.bind_character(character)
	inventory_menu.bind_character(character)
	hud.show_role(character.character_class, "YOU ARE", round_manager.get_unit_name(character.character_class))


func _on_character_escaped(character: CharacterController, _old: CharacterClass, new_class: CharacterClass) -> void:
	if character == local_character:
		hud.show_role(new_class, "YOU ESCAPED!", round_manager.get_unit_name(new_class))


func _on_round_ended(result: Dictionary) -> void:
	set_inventory_open(false)
	if get_tree().paused:
		set_paused(false)
	death_screen.visible = false
	hud.visible = false
	local_input.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player_side := local_character.get_side() if local_character != null else -1
	round_end_screen.show_result(result, player_side, config.restart_delay_seconds)


func _process(_delta: float) -> void:
	var lines := PackedStringArray()
	for warhead in round_manager.warhead_state:
		if round_manager.warhead_state[warhead] == RoundManager.WarheadState.COUNTDOWN:
			var t: float = round_manager.warhead_time_left[warhead]
			lines.append("%s - DETONATION IN %d:%02d" % [
				String(RoundManager.WARHEADS[warhead].name).to_upper(), int(t) / 60, int(t) % 60])
	hud.show_warhead("\n".join(lines))


## Presentation only: alarm lights while a warhead counts down, and a white
## flash when one goes off.
func _on_warhead_changed(_warhead: int, _state: int, _time_left: float) -> void:
	var counting := false
	for warhead in round_manager.warhead_state:
		counting = counting or round_manager.warhead_state[warhead] == RoundManager.WarheadState.COUNTDOWN
	_set_alarm(counting)
	if _state == RoundManager.WarheadState.DETONATED:
		hud.flash_white(3.0)
		noir_overlay.color_burst(1.0)


func _set_alarm(on: bool) -> void:
	if on == _alarm_on:
		return
	_alarm_on = on
	for light: Light3D in get_tree().get_nodes_in_group("facility_lights"):
		if on:
			_light_colors[light] = light.light_color
			light.light_color = Color(1.0, 0.18, 0.12)
		elif _light_colors.has(light):
			light.light_color = _light_colors[light]
	noir_overlay.set_base_saturation(0.4 if on else 0.06)


func _on_actor_added(node: Node) -> void:
	if node is LiveGrenade:
		node.detonated.connect(_on_grenade_detonated)


## Presentation only: the colours come back for a moment when a grenade goes
## off near the local player (stronger when closer).
func _on_grenade_detonated(origin: Vector3, _grenade: ItemData) -> void:
	if local_character == null:
		return
	var distance := origin.distance_to(local_character.camera.global_position)
	if distance < COLOR_BURST_RANGE:
		noir_overlay.color_burst(clampf(1.2 - distance / COLOR_BURST_RANGE, 0.35, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if local_character == null or not local_character.is_alive or round_end_screen.visible:
		return
	if event.is_action_pressed("pause"):
		if inventory_menu.visible:
			set_inventory_open(false)
		else:
			set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not get_tree().paused \
			and (inventory_menu.visible or not local_character.is_disarmed()):
		set_inventory_open(not inventory_menu.visible)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused \
			and not inventory_menu.visible:
		# Clicking back into the window grabs the mouse again.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_inventory_open(open: bool) -> void:
	if inventory_menu.visible == open:
		return
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
	set_inventory_open(false)
	local_input.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not round_end_screen.visible:
		death_screen.show_death(_describe_cause_of_death(source))


func _describe_cause_of_death(source: Node) -> String:
	if source == null:
		return "Cause of death: unknown"
	var cause = source.get("cause_of_death")
	if cause is String:
		return cause
	var attacker := CharacterController.resolve_attacker(source)
	if attacker != null and attacker.character_class != null:
		var how := "a grenade thrown by" if source is LiveGrenade else "a"
		if attacker == local_character:
			return "Killed by your own grenade" if source is LiveGrenade else "You killed yourself"
		return "Killed by %s %s" % [how, attacker.character_class.display_name]
	return "Killed by %s" % source.name


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_to_main_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
