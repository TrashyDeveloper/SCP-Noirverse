extends Node3D
## The in-game scene: builds a new facility layout, lets the RoundManager run
## a round, and connects the local player to the HUD and menus.
##
## Everything about the match lives on this node and its children (no global
## singletons), so later a server can run the same logic for many players.

const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
## Explosions closer than this bring the colours back on screen.
const COLOR_BURST_RANGE := 30.0

## Default rules for this match (round, carry and ammo limits). Values from
## user://gameplay_config.cfg are applied on top when the match starts.
@export var gameplay_config: GameplayConfig

## Normal colour of every light, remembered while the alarm turns them red.
var _light_colors := {}
var _alarm_on := false
var _alarm_sound: AudioStreamPlayer

var _reactor: GammaReactor
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
	# A new map every round (unless the config fixes the seed).
	var map_seed := config.map_seed if config.map_seed != 0 else randi_range(1, 2147483646)
	level = FacilityGenerator.new().generate(map_seed)
	level_root.add_child(level)
	print("Map seed: %d" % map_seed)
	var reactors := level.find_children("*", "GammaReactor", true, false)
	_reactor = reactors[0] if not reactors.is_empty() else null
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
	round_manager.announcement.connect(func(text: String):
		hud.show_message(text, 5.0)
		Sfx.play_2d(self, "intercom_chime", -12.0))
	# Low facility hum in the background.
	Sfx.play_2d(self, "ambience_loop", -20.0)
	round_manager.terminal_report.connect(func(actor: Node, text: String):
		if actor == local_character:
			hud.show_terminal(text))
	round_manager.intercom_requested.connect(_on_intercom_requested)
	round_manager.influence_earned.connect(func(character: CharacterController, amount: int, reason: String):
		if character == local_character:
			hud.show_message("+%d INFLUENCE  -  %s" % [amount, reason], 2.5))
	hud.intercom_submitted.connect(_on_intercom_submitted)
	hud.player_input = local_input
	round_manager.setup(level, actors, config)
	var players: Array[InputSource] = [local_input]
	round_manager.start_round(players)
	hud.round_manager = round_manager
	set_paused(false)


func _on_character_spawned(character: CharacterController, is_player: bool) -> void:
	if not is_player:
		return
	local_character = character
	if death_screen.visible:
		# Back with a reinforcement wave.
		death_screen.visible = false
		local_input.enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	result.player_xp = round_manager.get_xp(local_input)
	round_end_screen.show_result(result, player_side, config.restart_delay_seconds)


func _process(_delta: float) -> void:
	var lines := PackedStringArray()
	for warhead in round_manager.warhead_state:
		if round_manager.warhead_state[warhead] == RoundManager.WarheadState.COUNTDOWN:
			var t: float = round_manager.warhead_time_left[warhead]
			lines.append("%s - DETONATION IN %d:%02d" % [
				String(RoundManager.WARHEADS[warhead].name).to_upper(), int(t) / 60, int(t) % 60])
	hud.show_warhead("\n".join(lines))
	_update_reactor_colors()


## Colour comes back on screen around the spinning Gamma reactor.
func _update_reactor_colors() -> void:
	var cam := get_viewport().get_camera_3d()
	if _reactor == null or cam == null:
		noir_overlay.set_color_zone(Vector2.ZERO, 0.0, 0.0)
		return
	var core := _reactor.get_core_position()
	var reach := _reactor.get_color_radius()
	var strength := _reactor.get_color_strength()
	var distance := cam.global_position.distance_to(core)
	var size := get_viewport().get_visible_rect().size
	if distance < reach * 0.6:
		# Standing inside the field: the whole screen gets its colour back.
		noir_overlay.set_color_zone(Vector2(0.5, 0.5), 3.0, strength * (1.0 - distance / (reach * 0.6)) + strength * 0.3)
		return
	if cam.is_position_behind(core) or distance > reach * 4.0:
		noir_overlay.set_color_zone(Vector2.ZERO, 0.0, 0.0)
		return
	var screen := cam.unproject_position(core)
	var edge := cam.unproject_position(core + cam.global_basis.x * reach)
	var radius := screen.distance_to(edge) / size.y
	# Walls between you and the reactor block most of it.
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, core, 1))
	if hit and hit.position.distance_to(core) > 2.5:
		strength *= 0.2
	noir_overlay.set_color_zone(screen / size, radius, strength * clampf(1.5 - distance / (reach * 4.0), 0.0, 1.0))


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
	if on:
		_alarm_sound = Sfx.play_2d(self, "alarm_loop", -14.0)
	elif _alarm_sound != null:
		_alarm_sound.queue_free()
		_alarm_sound = null
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


func _on_intercom_requested(actor: Node) -> void:
	if actor != local_character or hud.is_intercom_open():
		return
	local_input.enabled = false
	hud.open_intercom()


func _on_intercom_submitted(text: String) -> void:
	local_input.enabled = not get_tree().paused and local_character != null and local_character.is_alive
	if text.strip_edges() != "":
		round_manager.broadcast_intercom(local_character, text)


func _unhandled_input(event: InputEvent) -> void:
	if local_character == null or not local_character.is_alive or round_end_screen.visible:
		return
	if hud.is_intercom_open():
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
		death_screen.show_death(_describe_cause_of_death(source), config.respawn_wave_seconds > 0.0)


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
