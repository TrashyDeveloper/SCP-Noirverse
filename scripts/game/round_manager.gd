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
## Something every player should be told (facility announcements).
signal announcement(text: String)
## A warhead started, was cancelled or detonated. `state` is a WarheadState.
signal warhead_changed(warhead: int, state: int, time_left: float)
## Someone used a terminal; `text` is what it shows them.
signal terminal_report(actor: Node, text: String)
## Someone may speak on the intercom now (Game asks the local player what
## to say and calls broadcast_intercom).
signal intercom_requested(actor: Node)
## A character earned influence for their side (and XP for themselves).
signal influence_earned(character: CharacterController, amount: int, reason: String)
## A side's influence changed (tier = 0..3).
signal influence_changed(side: int, total: int, tier: int)
## A reinforcement wave arrived on the Surface.
signal wave_spawned(side: int, unit_name: String, count: int)

enum State { WAITING, RUNNING, ENDED }
enum WarheadState { IDLE, COUNTDOWN, DETONATED }

const CHARACTER_SCENE := preload("res://scenes/player/character.tscn")
## Used for the "winner" field of the result when nobody wins.
const NO_WINNER := -1
## Seconds after the round starts before the Class-D cell doors open.
const CELL_DOORS_OPEN_AFTER := 6.0
## Fallback if a level has no "SurfaceArea": anyone above this height counts
## as being on the Surface.
const SURFACE_HEIGHT := 15.0
## Warhead rules: keycard Admin level needed, countdown seconds, and until
## how many seconds before detonation it can still be cancelled (-1 = never).
const WARHEADS := {
	WarheadConsole.Warhead.DELTA: {"name": "Delta Warhead", "admin": 2, "countdown": 90.0, "cancel_until": 10.0},
	WarheadConsole.Warhead.GAMMA: {"name": "Gamma Warhead", "admin": 3, "countdown": 120.0, "cancel_until": -1.0},
	WarheadConsole.Warhead.ALPHA: {"name": "Alpha Warhead", "admin": 2, "countdown": 100.0, "cancel_until": 15.0},
}

## Influence a side needs for each tier (tier 0 = start).
const INFLUENCE_TIERS: Array[int] = [0, 20, 50, 90]
const TIER_NAMES: Array[String] = ["Standard", "Reinforced", "Elite", "Spearhead"]
## Personal XP needed for each personal rank, and the rank names.
const XP_RANKS: Array[int] = [0, 10, 25, 45]
const XP_RANK_NAMES: Array[String] = ["Personnel", "Commended", "Decorated", "Veteran"]
## Influence rewards.
const INFLUENCE := {
	"escape": 10, "escape_disarmed": 15, "escort": 5, "disarm": 3, "kill": 2,
}
## Allies within this distance of an escapee count as escorts.
const ESCORT_RANGE := 15.0
## Class ids for reinforcement waves, per side: the squad leader and the
## troopers depend on the side's influence tier; specialists are handed
## out first (to the players with the most XP), one more per tier.
const WAVES := {
	CharacterClass.Side.FOUNDATION: {
		"leader": ["mtf_sergeant", "mtf_sergeant", "mtf_commander", "mtf_commander"],
		"trooper": ["mtf_recruit", "mtf_cadet", "mtf_rifleman", "mtf_rifleman"],
		"specialists": ["mtf_medic", "mtf_engineer", "mtf_explosives", "mtf_heavy_gunner"],
	},
	CharacterClass.Side.INSURGENCY: {
		"leader": ["chaos_rifleman", "chaos_vanguard", "chaos_vanguard", "chaos_operations_director"],
		"trooper": ["chaos_recruit", "chaos_recruit", "chaos_rifleman", "chaos_rifleman"],
		"specialists": ["chaos_medic", "chaos_engineer", "chaos_explosives", "chaos_heavy_gunner"],
	},
}
## Escapees become a better rank when their new side has more influence.
const ESCAPE_LADDERS := {
	&"mtf_recruit": ["mtf_recruit", "mtf_cadet", "mtf_rifleman", "mtf_sergeant"],
	&"chaos_recruit": ["chaos_recruit", "chaos_rifleman", "chaos_rifleman", "chaos_vanguard"],
}
## Minor starting roles that can replace a Scientist (see minor_role_chance).
const MINOR_ROLES: Array[String] = ["janitor", "zone_manager", "containment_specialist"]
const INTERCOM_COOLDOWN := 60.0
const INTERCOM_PRIORITY_COOLDOWN := 15.0
const INTERCOM_MAX_LENGTH := 120

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

## This round's Mobile Task Force unit and Chaos Insurgency cell (see Factions).
var mtf_unit: Dictionary = {}
var chaos_cell: Dictionary = {}
var warhead_state := {WarheadConsole.Warhead.DELTA: WarheadState.IDLE, WarheadConsole.Warhead.GAMMA: WarheadState.IDLE,
	WarheadConsole.Warhead.ALPHA: WarheadState.IDLE}
var warhead_time_left := {WarheadConsole.Warhead.DELTA: 0.0, WarheadConsole.Warhead.GAMMA: 0.0,
	WarheadConsole.Warhead.ALPHA: 0.0}

## Influence per side, and XP per player/bot (keyed by their InputSource so
## it survives escapes and respawns).
var influence := {CharacterClass.Side.FOUNDATION: 0, CharacterClass.Side.INSURGENCY: 0}
var personal_xp := {}
## Round time (elapsed) of the next reinforcement wave (-1 = none).
var next_wave_at := -1.0
var waves_spawned := 0

var _consoles: Array[WarheadConsole] = []
var _intercoms: Array[Intercom] = []
var _intercom_ready_at := 0.0
var _last_wave_side := CharacterClass.Side.INSURGENCY
var _cells_opened := false
var _elimination_possible := false
var _spawn_points := {}  # group name -> Array[Node3D] (shuffled)
var _spawn_counters := {}  # group name -> how many used


func setup(level_node: Node3D, actors_node: Node3D, match_config: GameplayConfig) -> void:
	level = level_node
	actors = actors_node
	config = match_config
	for zone in level.find_children("*", "EscapeZone", true, false):
		zone.character_entered.connect(_on_escape_zone_entered)
	for console in level.find_children("*", "WarheadConsole", true, false):
		_consoles.append(console)
		console.use_requested.connect(_on_warhead_console_used)
		console.prompt_provider = _warhead_prompt
	_update_consoles()
	# Things that show warhead states (the Alpha silo, the Gamma reactor).
	for node in get_tree().get_nodes_in_group(&"warhead_listeners"):
		if level.is_ancestor_of(node):
			warhead_changed.connect(node.on_warhead_changed)
	for terminal in level.find_children("*", "Terminal", true, false):
		terminal.use_requested.connect(_on_terminal_used)
	for intercom in level.find_children("*", "Intercom", true, false):
		_intercoms.append(intercom)
		intercom.use_requested.connect(_on_intercom_used)
		intercom.prompt_provider = _intercom_prompt


## Starts the round. `player_inputs` are the human players (here: just the
## local player); the remaining slots are filled with bots.
func start_round(player_inputs: Array[InputSource]) -> void:
	mtf_unit = Factions.MTF_UNITS.pick_random()
	chaos_cell = Factions.CI_CELLS.pick_random()
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
	next_wave_at = config.respawn_wave_seconds if config.respawn_wave_seconds > 0.0 else -1.0
	state = State.RUNNING
	announcement.emit("Class-D cell doors open in %d seconds..." % int(CELL_DOORS_OPEN_AFTER))


## The classes for this round, read from the config's spawn queue.
func build_class_list() -> Array[CharacterClass]:
	var queue := config.spawn_queue.strip_edges().to_upper()
	if queue.is_empty():
		queue = "D"
	var list: Array[CharacterClass] = []
	for i in config.player_count:
		var letter := queue[i % queue.length()]
		var character_class: CharacterClass = queue_classes.get(letter, fallback_class)
		# Some Scientists are replaced by a minor role.
		if letter == "S" and randf() < config.minor_role_chance:
			character_class = load_class(MINOR_ROLES.pick_random())
		list.append(character_class)
	return list


static func load_class(id: String) -> CharacterClass:
	return load("res://resources/classes/%s.tres" % id)


func spawn_character(character_class: CharacterClass, input: InputSource, is_player: bool) -> CharacterController:
	var character: CharacterController = CHARACTER_SCENE.instantiate()
	character.name = "%s_%d" % [character_class.id, characters.size()]
	character.player_name = "Player" if is_player else "Bot %d" % (characters.size() + 1)
	# A respawned controller keeps its name.
	for old in characters:
		if old.input_source == null and old.has_meta("input") and old.get_meta("input") == input:
			character.player_name = old.player_name
	character.set_meta("input", input)
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
	character.disarm_changed.connect(_on_disarm_changed.bind(character))
	characters.append(character)
	character_spawned.emit(character, is_player)
	return character


## The unit name a character of this class belongs to this round, e.g.
## 'Epsilon-11 "Nine-Tailed Fox"' (empty for facility staff).
func get_unit_name(character_class: CharacterClass) -> String:
	match character_class.unit:
		CharacterClass.Unit.MTF:
			return Factions.unit_name(mtf_unit)
		CharacterClass.Unit.CHAOS:
			return Factions.unit_name(chaos_cell)
	return ""


func get_time_left() -> float:
	if config.round_time_limit_minutes <= 0.0:
		return -1.0
	return maxf(config.round_time_limit_minutes * 60.0 - elapsed, 0.0)


func _physics_process(delta: float) -> void:
	if state != State.RUNNING:
		return
	elapsed += delta
	if not _cells_opened and elapsed >= CELL_DOORS_OPEN_AFTER:
		_open_class_d_cells()
	if next_wave_at >= 0.0 and elapsed >= next_wave_at:
		_spawn_wave()
		next_wave_at += config.respawn_wave_seconds
	if Engine.get_physics_frames() % 30 == 0:
		_update_intercoms()
	_update_warheads(delta)
	if state == State.RUNNING:
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
		"influence": influence.duplicate(),
		"tiers": {
			CharacterClass.Side.FOUNDATION: get_tier(CharacterClass.Side.FOUNDATION),
			CharacterClass.Side.INSURGENCY: get_tier(CharacterClass.Side.INSURGENCY),
		},
		"waves": waves_spawned,
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
	var captor := character.disarmed_by
	var new_class := old_class.escape_class_disarmed if disarmed else old_class.escape_class
	if new_class != null and ESCAPE_LADDERS.has(new_class.id):
		var ladder: Array = ESCAPE_LADDERS[new_class.id]
		new_class = load_class(ladder[mini(get_tier(new_class.side), ladder.size() - 1)])
	# Janitors, Zone Managers etc. count as scientists (facility staff).
	if old_class.side == CharacterClass.Side.INSURGENCY:
		stats.class_d_escaped_disarmed += 1 if disarmed else 0
		stats.class_d_escaped += 0 if disarmed else 1
	else:
		stats.scientists_escaped_disarmed += 1 if disarmed else 0
		stats.scientists_escaped += 0 if disarmed else 1
	if new_class == null:
		return
	# Influence: the escapee, whoever disarmed them, and allies escorting them.
	if disarmed and is_instance_valid(captor):
		award(captor, new_class.side, INFLUENCE.escape_disarmed, "Captive escaped")
	else:
		award(character, new_class.side, INFLUENCE.escape, "Escaped")
		for ally in characters:
			if ally != character and ally.is_alive and ally.get_side() == new_class.side \
					and ally.global_position.distance_to(character.global_position) < ESCORT_RANGE:
				award(ally, new_class.side, INFLUENCE.escort, "Escort")
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
		award(attacker, side, INFLUENCE.kill, "Kill")


func _on_disarm_changed(disarmed: bool, character: CharacterController) -> void:
	if disarmed and character.disarmed_by != null:
		award(character.disarmed_by, character.disarmed_by.get_side(), INFLUENCE.disarm, "Disarmed an enemy")


# --- Influence and XP ---------------------------------------------------

## Gives `amount` influence to `side` and the same XP to `character`.
func award(character: CharacterController, side: int, amount: int, reason: String) -> void:
	if state != State.RUNNING or not influence.has(side):
		return
	var old_tier := get_tier(side)
	influence[side] += amount
	if character != null and character.input_source != null:
		personal_xp[character.input_source] = get_xp(character.input_source) + amount
	influence_earned.emit(character, amount, reason)
	var tier := get_tier(side)
	influence_changed.emit(side, influence[side], tier)
	if tier > old_tier:
		var who := "Foundation" if side == CharacterClass.Side.FOUNDATION else "Chaos Insurgency"
		announcement.emit("%s influence: %s. Their reinforcements and escapees are better equipped." % [who, TIER_NAMES[tier].to_upper()])


func get_tier(side: int) -> int:
	var tier := 0
	for i in INFLUENCE_TIERS.size():
		if influence.get(side, 0) >= INFLUENCE_TIERS[i]:
			tier = i
	return tier


func get_xp(input: InputSource) -> int:
	return personal_xp.get(input, 0)


static func xp_rank(xp: int) -> int:
	var rank := 0
	for i in XP_RANKS.size():
		if xp >= XP_RANKS[i]:
			rank = i
	return rank


# --- Reinforcement waves --------------------------------------------------

func get_wave_time_left() -> float:
	return maxf(next_wave_at - elapsed, 0.0) if next_wave_at >= 0.0 else -1.0


## The side the next wave will be for: the one with more influence (on a tie
## the sides take turns).
func get_next_wave_side() -> int:
	var f: int = influence[CharacterClass.Side.FOUNDATION]
	var c: int = influence[CharacterClass.Side.INSURGENCY]
	if f != c:
		return CharacterClass.Side.FOUNDATION if f > c else CharacterClass.Side.INSURGENCY
	return CharacterClass.Side.FOUNDATION if _last_wave_side == CharacterClass.Side.INSURGENCY else CharacterClass.Side.INSURGENCY


## Brings dead players and bots back as an MTF or Chaos squad.
func _spawn_wave() -> void:
	var dead: Array[CharacterController] = []
	for character in characters:
		if not character.is_alive and character.input_source != null:
			dead.append(character)
	if dead.is_empty():
		return
	var side := get_next_wave_side()
	_last_wave_side = side
	var tier := get_tier(side)
	var plan: Dictionary = WAVES[side]
	# Most XP first: they get the leader slot and the specialist roles.
	dead.sort_custom(func(a, b): return get_xp(a.input_source) > get_xp(b.input_source))
	var specialists := mini(1 + tier, plan.specialists.size())
	for i in dead.size():
		var id: String
		if i == 0:
			id = plan.leader[tier]
		elif i <= specialists:
			id = plan.specialists[i - 1]
		else:
			id = plan.trooper[tier]
		_respawn(dead[i], load_class(id))
	waves_spawned += 1
	var unit := get_unit_name(load_class(plan.trooper[0]))
	announcement.emit(("MTF unit %s has entered the facility." if side == CharacterClass.Side.FOUNDATION
		else "Chaos Insurgency cell %s has breached the Surface.") % unit)
	wave_spawned.emit(side, unit, dead.size())


## Moves a dead character's controller into a fresh character of `new_class`.
func _respawn(old: CharacterController, new_class: CharacterClass) -> void:
	var input := old.input_source
	old.remove_child(input)
	old.input_source = null
	var is_player := input is LocalPlayerInput
	var character := spawn_character(new_class, input, is_player)
	# Personal rank bonuses: a spare medkit, then a shield.
	var rank := xp_rank(get_xp(input))
	if rank >= 1:
		character.give_item(ItemInstance.new(load("res://resources/items/first_aid_kit.tres")))
	if rank >= 3:
		character.health.add_shield(25.0)


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


func _open_class_d_cells() -> void:
	_cells_opened = true
	for door in get_tree().get_nodes_in_group("class_d_cell_doors"):
		if level.is_ancestor_of(door):
			door.set_open(true)
	announcement.emit("FACILITY ANNOUNCEMENT: Containment breach. Class-D cell doors are open.")


# --- Terminals and the intercom -------------------------------------------

## Which zone a position is in ("LCZ", "HCZ", "EZ" or "Surface").
func zone_at(character: CharacterController) -> String:
	if is_on_surface(character):
		return "Surface"
	var p := character.global_position
	if p.y > FacilityGenerator.LOWER_Y / 2:
		return "LCZ"
	return "HCZ" if p.x < FacilityGenerator.EZ_ORIGIN.x * FacilityGenerator.C - FacilityGenerator.C / 2 else "EZ"


## Full terminal access: the perk, or holding a keycard with Admin access or
## Containment level 2+.
func has_terminal_access(actor: Node) -> bool:
	if actor is CharacterController and actor.has_perk(&"terminal_access"):
		return true
	var card := PropBuilder.held_card(actor)
	return card != null and (card.admin_level >= 1 or card.containment_level >= 2)


func _on_terminal_used(terminal: Terminal, actor: Node) -> void:
	terminal_report.emit(actor, get_terminal_text(terminal, actor))


func get_terminal_text(terminal: Terminal, actor: Node) -> String:
	match terminal.kind:
		"scp055":
			return "SCP-055 - Object Class: KETER\nDescription: SCP-055 is a\n\n...\n\n[You read the entry twice. You can't remember a word of it.]"
		"scp999":
			return "SCP-999 - Object Class: SAFE\nA friendly, orange, gelatinous organism. Contact is reported to be soothing.\nStaff may visit the pen to recover (it slowly heals people near it)."
	var lines := PackedStringArray(["SITE-NET TERMINAL", ""])
	var t := elapsed
	lines.append("Round time: %d:%02d" % [int(t) / 60, int(t) % 60])
	lines.append("Class-D cells: %s" % ("OPEN" if _cells_opened else "LOCKED"))
	for warhead in warhead_state:
		var w_state: int = warhead_state[warhead]
		lines.append("%s: %s" % [WARHEADS[warhead].name, ["STANDBY", "COUNTDOWN %ds" % int(warhead_time_left[warhead]), "DETONATED"][w_state]])
	var full := terminal.kind == "personnel" or has_terminal_access(actor)
	if not full:
		lines.append("")
		lines.append("[ACCESS LIMITED] Personnel tracking needs a Containment 2 / Admin keycard in hand.")
		return "\n".join(lines)
	var counts := {}
	for character in characters:
		if character.is_alive:
			var key := "%s|%d" % [zone_at(character), character.get_side()]
			counts[key] = counts.get(key, 0) + 1
	lines.append("")
	lines.append("LIFE SIGNS      Foundation / Class-D & Chaos")
	for zone in ["LCZ", "HCZ", "EZ", "Surface"]:
		lines.append("  %-8s      %d / %d" % [zone, counts.get("%s|0" % zone, 0), counts.get("%s|1" % zone, 0)])
	lines.append("")
	lines.append("Influence: Foundation %d (%s), Chaos %d (%s)" % [
		influence[CharacterClass.Side.FOUNDATION], TIER_NAMES[get_tier(CharacterClass.Side.FOUNDATION)],
		influence[CharacterClass.Side.INSURGENCY], TIER_NAMES[get_tier(CharacterClass.Side.INSURGENCY)]])
	var wave := get_wave_time_left()
	if wave >= 0.0:
		lines.append("Next reinforcements (%s) in %d:%02d" % [
			"MTF" if get_next_wave_side() == CharacterClass.Side.FOUNDATION else "Chaos", int(wave) / 60, int(wave) % 60])
	return "\n".join(lines)


func can_use_intercom(actor: Node) -> bool:
	if state != State.RUNNING:
		return false
	if actor is CharacterController and actor.has_perk(&"intercom_priority"):
		return true
	return elapsed >= _intercom_ready_at


func _intercom_prompt(_intercom: Intercom, actor: Node) -> String:
	if state != State.RUNNING:
		return ""
	if not can_use_intercom(actor):
		return "Intercom cooling down (%ds)" % ceili(_intercom_ready_at - elapsed)
	if actor is CharacterController and actor.has_perk(&"intercom_priority") and elapsed < _intercom_ready_at:
		return "[E] Cut in on the intercom (priority)"
	return "[E] Speak on the intercom"


func _on_intercom_used(_intercom: Intercom, actor: Node) -> void:
	if can_use_intercom(actor):
		intercom_requested.emit(actor)


## Says `text` over the facility speakers on behalf of `actor`.
func broadcast_intercom(actor: Node, text: String) -> void:
	text = text.strip_edges().left(INTERCOM_MAX_LENGTH)
	if text.is_empty() or not can_use_intercom(actor):
		return
	var priority: bool = actor is CharacterController and actor.has_perk(&"intercom_priority")
	_intercom_ready_at = elapsed + (INTERCOM_PRIORITY_COOLDOWN if priority else INTERCOM_COOLDOWN)
	var who := "UNKNOWN"
	if actor is CharacterController and actor.character_class != null:
		who = actor.character_class.display_name.to_upper()
	announcement.emit("[INTERCOM - %s] %s" % [who, text])
	_update_intercoms()


func _update_intercoms() -> void:
	var left := _intercom_ready_at - elapsed
	for intercom in _intercoms:
		intercom.set_status("READY" if left <= 0.0 else "WAIT %ds" % ceili(left))


## Is this character on the Surface (outside the facility)? Uses the level's
## "SurfaceArea" volume.
func is_on_surface(character: CharacterController) -> bool:
	var area := level.get_node_or_null("SurfaceArea") as Area3D
	if area == null:
		return character.global_position.y > SURFACE_HEIGHT
	return area.overlaps_body(character)


# --- Warheads ------------------------------------------------------------

## Admin: start, cancel or immediately detonate a warhead, ignoring
## keycards and the "can't cancel" rule. `action`: "start", "cancel", "detonate".
func force_warhead(warhead: int, action: String) -> void:
	if state != State.RUNNING:
		return
	match action:
		"start":
			if warhead_state[warhead] != WarheadState.IDLE:
				return
			warhead_state[warhead] = WarheadState.COUNTDOWN
			warhead_time_left[warhead] = WARHEADS[warhead].countdown
		"cancel":
			if warhead_state[warhead] != WarheadState.COUNTDOWN:
				return
			warhead_state[warhead] = WarheadState.IDLE
		"detonate":
			if warhead_state[warhead] == WarheadState.DETONATED:
				return
			_detonate(warhead)
			return
	warhead_changed.emit(warhead, warhead_state[warhead], warhead_time_left[warhead])
	_update_consoles()


## Admin: turns a character into `new_class`. Dead characters come back
## to life (at the class's spawn point).
func set_character_class(character: CharacterController, new_class: CharacterClass, at_spawn: bool) -> CharacterController:
	if not character.is_alive:
		if character.input_source == null:
			return character
		var input := character.input_source
		_respawn(character, new_class)
		for c in characters:
			if c.input_source == input:
				return c
		return character
	character.apply_class(new_class)
	if at_spawn:
		var spawn := _take_spawn_transform(new_class.spawn_group)
		character.global_position = spawn.origin
		character.velocity = Vector3.ZERO
	return character

func _held_admin_level(actor: Node) -> int:
	if not actor is CharacterController:
		return 0
	var held: ItemInstance = actor.get_held_item()
	if held == null or held.data.kind != ItemData.Kind.KEYCARD:
		return 0
	return held.data.admin_level


func _can_cancel(warhead: int) -> bool:
	var rules: Dictionary = WARHEADS[warhead]
	return rules.cancel_until >= 0.0 and warhead_time_left[warhead] > rules.cancel_until


func _warhead_prompt(console: WarheadConsole, actor: Node) -> String:
	var warhead := console.warhead
	var rules: Dictionary = WARHEADS[warhead]
	match warhead_state[warhead]:
		WarheadState.DETONATED:
			return "%s has detonated" % rules.name
		WarheadState.COUNTDOWN:
			if not _can_cancel(warhead):
				return "Detonation can't be stopped"
			if _held_admin_level(actor) < rules.admin:
				return "Cancel needs an Admin level %d keycard (hold it)" % rules.admin
			return "[E] CANCEL %s detonation" % rules.name
	if state != State.RUNNING:
		return ""
	if _held_admin_level(actor) < rules.admin:
		return "Activate: hold an Admin level %d keycard" % rules.admin
	return "[E] ACTIVATE %s" % rules.name


func _on_warhead_console_used(console: WarheadConsole, actor: Node) -> void:
	if state != State.RUNNING:
		return
	var warhead := console.warhead
	var rules: Dictionary = WARHEADS[warhead]
	if _held_admin_level(actor) < rules.admin:
		return
	match warhead_state[warhead]:
		WarheadState.IDLE:
			warhead_state[warhead] = WarheadState.COUNTDOWN
			warhead_time_left[warhead] = rules.countdown
		WarheadState.COUNTDOWN:
			if not _can_cancel(warhead):
				return
			warhead_state[warhead] = WarheadState.IDLE
		_:
			return
	warhead_changed.emit(warhead, warhead_state[warhead], warhead_time_left[warhead])
	_update_consoles()


func _update_warheads(delta: float) -> void:
	var any := false
	for warhead in warhead_state:
		if warhead_state[warhead] != WarheadState.COUNTDOWN:
			continue
		any = true
		warhead_time_left[warhead] = maxf(warhead_time_left[warhead] - delta, 0.0)
		if warhead_time_left[warhead] <= 0.0:
			_detonate(warhead)
	if any and Engine.get_physics_frames() % 15 == 0:
		_update_consoles()


func _detonate(warhead: int) -> void:
	warhead_state[warhead] = WarheadState.DETONATED
	var rules: Dictionary = WARHEADS[warhead]
	var blast := WarheadBlast.new()
	blast.cause_of_death = "Killed by the %s" % rules.name
	add_child(blast)
	for character in characters:
		if not character.is_alive:
			continue
		if warhead == WarheadConsole.Warhead.GAMMA or not is_on_surface(character):
			character.health.take_damage(100000.0, blast)
	if warhead != WarheadConsole.Warhead.GAMMA:
		# The facility below is destroyed: the elevators stop working.
		for elevator in level.find_children("*", "Elevator", true, false):
			elevator.disabled = true
	warhead_changed.emit(warhead, WarheadState.DETONATED, 0.0)
	_update_consoles()
	if warhead == WarheadConsole.Warhead.GAMMA and state == State.RUNNING:
		var scores := get_escape_scores()
		var foundation: int = scores[CharacterClass.Side.FOUNDATION]
		var insurgency: int = scores[CharacterClass.Side.INSURGENCY]
		var winner := NO_WINNER
		if insurgency > foundation:
			winner = CharacterClass.Side.INSURGENCY
		elif foundation > insurgency:
			winner = CharacterClass.Side.FOUNDATION
		var reason := "The Gamma Warhead destroyed the site. "
		reason += "Neither side had more escapes." if winner == NO_WINNER else "The side with more escapes wins."
		_end_round(winner, reason)


func _update_consoles() -> void:
	for console in _consoles:
		var rules: Dictionary = WARHEADS[console.warhead]
		match warhead_state[console.warhead]:
			WarheadState.IDLE:
				console.set_status("STANDBY - ADMIN %d" % rules.admin)
			WarheadState.COUNTDOWN:
				var t: float = warhead_time_left[console.warhead]
				console.set_status("DETONATION IN %d:%02d" % [int(t) / 60, int(t) % 60])
			WarheadState.DETONATED:
				console.set_status("DETONATED")
