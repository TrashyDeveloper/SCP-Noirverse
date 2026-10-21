class_name RoundManager
extends Node
## Runs one round: picks everyone's class from the spawn queue, spawns the
## characters, handles escapes, keeps statistics and decides when the round
## is over and who won.
##
## It lives inside the Game scene (no global state) and only talks to
## InputSources, so later a server can run it for networked players too.

signal character_spawned(character: CharacterController, is_player: bool)
signal character_escaped(character: CharacterController, old_class: CharacterClass, new_class: CharacterClass)
signal round_ended(result: Dictionary)

enum State { WAITING, RUNNING, ENDED }

const CHARACTER_SCENE := preload("res://scenes/player/character.tscn")
## Used for the "winner" field of the result when nobody wins.
const NO_WINNER := -1

## Spawn queue letters and the class each one spawns.
@export var queue_classes: Dictionary = {}
## Class used for unknown letters in the queue.
@export var fallback_class: CharacterClass

var state := State.WAITING
var config: GameplayConfig
var level: Node3D
var actors: Node3D
var characters: Array[CharacterController] = []
## Seconds since the round started.
var elapsed := 0.0
var stats := {
	"class_d_escaped": 0,
	"class_d_escaped_disarmed": 0,
	"scientists_escaped": 0,
	"scientists_escaped_disarmed": 0,
	"kills": {},  # side -> number of enemies killed
	"deaths": 0,
}

var _elimination_possible := false
var _spawn_points := {}  # group name -> Array[Node3D] (shuffled)
var _spawn_counters := {}  # group name -> how many used


func setup(level_node: Node3D, actors_node: Node3D, match_config: GameplayConfig) -> void:
	level = level_node
	actors = actors_node
	config = match_config
	for zone in level.find_children("*", "EscapeZone", true, false):
		zone.character_entered.connect(_on_escape_zone_entered)


## Starts the round. `player_inputs` are the human players (here: just the
## local player); the remaining slots are filled with bots.
func start_round(player_inputs: Array[InputSource]) -> void:
	var classes := build_class_list()
	classes.shuffle()
	for i in classes.size():
		var is_player := i < player_inputs.size()
		var input: InputSource = player_inputs[i] if is_player else IdleInput.new()
		spawn_character(classes[i], input, is_player)
	var sides := {}
	for character in characters:
		sides[character.get_side()] = true
	# With only one side present nobody can "win by elimination".
	_elimination_possible = sides.size() > 1
	elapsed = 0.0
	state = State.RUNNING


## The classes for this round, read from the config's spawn queue.
func build_class_list() -> Array[CharacterClass]:
	var queue := config.spawn_queue.strip_edges().to_upper()
	if queue.is_empty():
		queue = "D"
	var list: Array[CharacterClass] = []
	for i in config.player_count:
		var letter := queue[i % queue.length()]
		list.append(queue_classes.get(letter, fallback_class))
	return list


func spawn_character(character_class: CharacterClass, input: InputSource, is_player: bool) -> CharacterController:
	var character: CharacterController = CHARACTER_SCENE.instantiate()
	character.name = "%s_%d" % [character_class.id, characters.size()]
	actors.add_child(character)
	character.inventory.config = config
	character.friendly_fire = config.friendly_fire
	var spawn := _take_spawn_transform(character_class.spawn_group)
	character.global_position = spawn.origin
	if input is LocalPlayerInput:
		input.set_view_angles(spawn.basis.get_euler().y, 0.0)
	elif input is IdleInput:
		input.yaw = spawn.basis.get_euler().y
	character.possess(input, input is LocalPlayerInput)
	character.apply_class(character_class)
	character.died.connect(_on_character_died.bind(character))
	characters.append(character)
	character_spawned.emit(character, is_player)
	return character


func get_time_left() -> float:
	if config.round_time_limit_minutes <= 0.0:
		return -1.0
	return maxf(config.round_time_limit_minutes * 60.0 - elapsed, 0.0)


func _physics_process(delta: float) -> void:
	if state != State.RUNNING:
		return
	elapsed += delta
	_check_round_end()


func _check_round_end() -> void:
	var alive_sides := {}
	for character in characters:
		if character.is_alive:
			alive_sides[character.get_side()] = true
	if alive_sides.is_empty():
		_end_round(NO_WINNER, "Everyone is dead.")
	elif _elimination_possible and alive_sides.size() == 1:
		var winner: int = alive_sides.keys()[0]
		_end_round(winner, "Only the %s are left alive." % CharacterClass.side_name(winner))
	elif config.round_time_limit_minutes > 0.0 and get_time_left() <= 0.0:
		var scores := get_escape_scores()
		var foundation: int = scores[CharacterClass.Side.FOUNDATION]
		var insurgency: int = scores[CharacterClass.Side.INSURGENCY]
		if insurgency > foundation:
			_end_round(CharacterClass.Side.INSURGENCY, "Time is up. More Class-D escaped.")
		elif foundation > insurgency:
			_end_round(CharacterClass.Side.FOUNDATION, "Time is up. More Scientists escaped.")
		else:
			_end_round(NO_WINNER, "Time is up. Nobody got ahead.")


## Escape points per side. A disarmed escapee counts for the side that
## captured them.
func get_escape_scores() -> Dictionary:
	return {
		CharacterClass.Side.INSURGENCY: stats.class_d_escaped + stats.scientists_escaped_disarmed,
		CharacterClass.Side.FOUNDATION: stats.scientists_escaped + stats.class_d_escaped_disarmed,
	}


func _end_round(winner: int, reason: String) -> void:
	state = State.ENDED
	var scores := get_escape_scores()
	round_ended.emit({
		"winner": winner,
		"reason": reason,
		"duration": elapsed,
		"stats": stats.duplicate(true),
		"escape_scores": scores,
	})


func _on_escape_zone_entered(character: CharacterController) -> void:
	if state != State.RUNNING or not character.is_alive:
		return
	var old_class := character.character_class
	if old_class == null or not old_class.can_escape:
		return
	var disarmed := character.is_disarmed()
	var new_class := old_class.escape_class_disarmed if disarmed else old_class.escape_class
	match old_class.id:
		&"class_d":
			stats.class_d_escaped_disarmed += 1 if disarmed else 0
			stats.class_d_escaped += 0 if disarmed else 1
		&"scientist":
			stats.scientists_escaped_disarmed += 1 if disarmed else 0
			stats.scientists_escaped += 0 if disarmed else 1
	if new_class == null:
		return
	var spawn := _take_spawn_transform(new_class.spawn_group)
	character.global_position = spawn.origin
	character.velocity = Vector3.ZERO
	character.apply_class(new_class, true)
	character_escaped.emit(character, old_class, new_class)


func _on_character_died(source: Node, victim: CharacterController) -> void:
	stats.deaths += 1
	var attacker := CharacterController.resolve_attacker(source)
	if attacker != null and attacker != victim and not attacker.is_ally_of(victim):
		var side := attacker.get_side()
		stats.kills[side] = stats.kills.get(side, 0) + 1


## A position + facing for a new character of a spawn group. Markers are
## used in random order; if there are more characters than markers they
## are reused with a small random offset.
func _take_spawn_transform(group: String) -> Transform3D:
	if not _spawn_points.has(group):
		var node := level.get_node_or_null("SpawnPoints/" + group)
		var markers: Array = node.get_children() if node != null else []
		markers.shuffle()
		_spawn_points[group] = markers
		_spawn_counters[group] = 0
	var markers: Array = _spawn_points[group]
	if markers.is_empty():
		push_warning("No spawn points in group '%s'" % group)
		return Transform3D(Basis(), Vector3(0, 1, 0))
	var index: int = _spawn_counters[group]
	_spawn_counters[group] = index + 1
	var marker: Node3D = markers[index % markers.size()]
	var result := marker.global_transform
	if index >= markers.size():
		result.origin += Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	return result
