class_name Scp914
extends Node3D
## SCP-914, "The Clockworks": a huge clockwork machine with an Intake booth
## and an Output booth. Put items (or yourself...) in the Intake, set the
## dial, turn the key: the doors close, the machine grinds, and refined
## versions come out of the Output booth.
##
## Settings: Rough (destroys), Coarse (worse), 1:1 (swaps for something
## similar), Fine (better), Very Fine (much better - or worse).
## The machine builds its own model; front faces -Z, the back wall is at z=0.

enum Setting { ROUGH, COARSE, ONE_TO_ONE, FINE, VERY_FINE }

const SETTING_NAMES: Array[String] = ["ROUGH", "COARSE", "1:1", "FINE", "VERY FINE"]
const INTAKE_X := 4.8
const BOOTH_Z := -1.9
const BOOTH_RADIUS := 1.3
const RUN_TIME := 8.0
## Result per setting [rough, coarse, 1:1, fine, very fine]. "" = destroyed,
## "=" = unchanged. Items not listed come out unchanged (rough destroys).
const RECIPES := {
	"keycard_janitor": ["", "=", "keycard_zone_manager", "keycard_scientist", "keycard_research_supervisor"],
	"keycard_zone_manager": ["", "keycard_janitor", "keycard_janitor", "keycard_research_supervisor", "keycard_containment_engineer"],
	"keycard_scientist": ["", "keycard_janitor", "keycard_guard", "keycard_research_supervisor", "keycard_containment_engineer"],
	"keycard_guard": ["", "keycard_janitor", "keycard_scientist", "keycard_mtf_private", "keycard_mtf_sergeant"],
	"keycard_research_supervisor": ["", "keycard_scientist", "keycard_mtf_private", "keycard_containment_engineer", "keycard_facility_manager"],
	"keycard_mtf_private": ["", "keycard_guard", "keycard_research_supervisor", "keycard_mtf_sergeant", "keycard_mtf_commander"],
	"keycard_containment_engineer": ["", "keycard_research_supervisor", "keycard_mtf_sergeant", "keycard_facility_manager", "keycard_o5"],
	"keycard_mtf_sergeant": ["", "keycard_mtf_private", "keycard_containment_engineer", "keycard_mtf_commander", "keycard_o5"],
	"keycard_containment_captain": ["", "keycard_guard", "keycard_mtf_sergeant", "keycard_mtf_commander", "keycard_o5"],
	"keycard_facility_manager": ["", "keycard_containment_engineer", "keycard_mtf_commander", "keycard_o5", "keycard_o5"],
	"keycard_mtf_commander": ["", "keycard_mtf_sergeant", "keycard_facility_manager", "keycard_o5", "keycard_o5"],
	"keycard_chaos_device": ["", "keycard_mtf_sergeant", "keycard_mtf_commander", "keycard_o5", "keycard_o5"],
	"keycard_o5": ["", "keycard_facility_manager", "keycard_chaos_device", "=", "="],
	"painkillers": ["", "=", "=", "first_aid_kit", "adrenaline"],
	"first_aid_kit": ["", "painkillers", "=", "adrenaline", "exp_serum"],
	"adrenaline": ["", "painkillers", "=", "exp_serum", "exp_serum"],
	"exp_serum": ["", "first_aid_kit", "=", "=", "="],
	"pistol": ["ammo_9x19mm", "=", "=", "smg", "vector"],
	"smg": ["ammo_9x19mm", "pistol", "vector", "vector", "m4"],
	"vector": ["ammo_9x19mm", "smg", "smg", "m4", "ak47"],
	"m4": ["ammo_556x45mm", "smg", "ak47", "lmg", "sniper"],
	"ak47": ["ammo_762x39mm", "smg", "m4", "lmg", "sniper"],
	"lmg": ["ammo_762x39mm", "ak47", "mg60", "mg60", "mg60"],
	"mg60": ["ammo_762x39mm", "lmg", "lmg", "=", "="],
	"sniper": ["ammo_762x39mm", "ak47", "=", "=", "="],
	"ammo_9x19mm": ["", "=", "ammo_556x45mm", "=", "="],
	"ammo_556x45mm": ["", "ammo_9x19mm", "ammo_762x39mm", "=", "="],
	"ammo_762x39mm": ["", "ammo_556x45mm", "ammo_9x19mm", "=", "="],
	"armor_light": ["", "=", "=", "armor_combat", "armor_heavy"],
	"armor_combat": ["", "armor_light", "=", "armor_heavy", "armor_heavy"],
	"armor_heavy": ["", "armor_combat", "=", "=", "="],
	"grenade_flashbang": ["", "=", "grenade_he", "exp_flashbang", "exp_flashbang"],
	"grenade_he": ["", "grenade_flashbang", "grenade_flashbang", "=", "="],
	"exp_flashbang": ["", "grenade_flashbang", "grenade_he", "=", "="],
}
const BRASS := Color(0.72, 0.55, 0.28)
const COPPER := Color(0.66, 0.36, 0.22)
const IRON := Color(0.12, 0.12, 0.13)
const DARK_BRASS := Color(0.42, 0.31, 0.15)

var setting := Setting.ONE_TO_ONE
var running := false
## Shown on the death screen if the machine kills someone.
var cause_of_death := "Refined by SCP-914"

var _gears: Array[Node3D] = []
var _gear_speed := 0.2
var _target_speed := 0.2
var _pointer: Node3D
var _key: Node3D
var _doors: Array[AnimatableBody3D] = []
var _intake: Area3D
var _lamps: Array[OmniLight3D] = []
var _loop_sound: AudioStreamPlayer3D
var _time := 0.0
var _mats := {}


func _ready() -> void:
	_build_machine()
	for side: float in [1.0, -1.0]:
		_build_booth(side)
	_build_console()
	_update_pointer(true)


func _process(delta: float) -> void:
	_time += delta
	_gear_speed = lerpf(_gear_speed, _target_speed, minf(delta * 1.5, 1.0))
	for i in _gears.size():
		_gears[i].rotation.z += delta * _gear_speed * (1.0 if i % 2 == 0 else -1.6) * (1.0 + i * 0.3)
	for lamp in _lamps:
		lamp.light_energy = (1.2 + sin(_time * 14.0) * 0.8) if running else 0.6


# --- Using the machine ----------------------------------------------------------

func _dial_prompt(_actor: Node) -> String:
	if running:
		return "SCP-914 is running..."
	return "[E] Turn the dial  (setting: %s)" % SETTING_NAMES[setting]


func _turn_dial(_actor: Node) -> void:
	if running:
		return
	setting = ((setting + 1) % SETTING_NAMES.size()) as Setting
	_update_pointer(false)
	Sfx.play_3d(self, "button", _pointer.global_position, -4.0, 0.7)


func _key_prompt(_actor: Node) -> String:
	if running:
		return "SCP-914 is running..."
	return "[E] Turn the key - refine on %s" % SETTING_NAMES[setting]


func _turn_key(_actor: Node) -> void:
	if running:
		return
	start()


## Runs one refining cycle.
func start() -> void:
	running = true
	_target_speed = 9.0
	create_tween().tween_property(_key, "rotation:z", -PI / 2, 0.3)
	Sfx.play_3d(self, "machine_914_start", global_position + Vector3(0, 1.5, -2.5), 2.0)
	_loop_sound = Sfx.play_3d(self, "machine_914_loop", global_position + Vector3(0, 2.0, -2.5), 0.0, 1.0, self)
	_set_doors(false)
	var t := get_tree().create_timer(RUN_TIME * 0.45)
	t.timeout.connect(_refine)
	get_tree().create_timer(RUN_TIME).timeout.connect(_finish)


func _finish() -> void:
	running = false
	_target_speed = 0.2
	if _loop_sound != null:
		_loop_sound.queue_free()
	Sfx.play_3d(self, "machine_914_done", global_position + Vector3(0, 2.0, -2.5), 0.0)
	create_tween().tween_property(_key, "rotation:z", 0.0, 0.3)
	_set_doors(true)


## Moves everything in the Intake booth to the Output booth, refined.
func _refine() -> void:
	var output := to_global(Vector3(-INTAKE_X, 0, BOOTH_Z))
	var pickup_scene: PackedScene = load("res://scenes/items/item_pickup.tscn")
	var k := 0
	for body in _intake.get_overlapping_bodies():
		if body is ItemPickup:
			var result := refine_item(String(body.item.data.id), setting)
			var old_item: ItemInstance = body.item
			body.queue_free()
			if result == "":
				continue
			var data: ItemData = load("res://resources/items/%s.tres" % result)
			var p: ItemPickup = pickup_scene.instantiate()
			p.item = old_item if data == old_item.data else ItemInstance.new(data)
			get_parent().add_child(p)
			p.global_position = output + Vector3(randf_range(-0.4, 0.4), 0.4 + k * 0.15, randf_range(-0.4, 0.4))
			k += 1
		elif body is CharacterController and body.is_alive:
			_refine_person(body)
			body.global_position = output + Vector3(randf_range(-0.3, 0.3), 0.1, randf_range(-0.3, 0.3))
			body.velocity = Vector3.ZERO


## What `item_id` turns into on `which` setting ("" = destroyed).
static func refine_item(item_id: String, which: int) -> String:
	var recipe: Array = RECIPES.get(item_id, ["", "=", "=", "=", "="])
	var result: String = recipe[which]
	# Very Fine is unstable: sometimes the item doesn't survive.
	if which == Setting.VERY_FINE and randf() < 0.2:
		return ""
	return item_id if result == "=" else result


func _refine_person(person: CharacterController) -> void:
	match setting:
		Setting.ROUGH:
			person.health.take_damage(85.0, self)
		Setting.COARSE:
			person.health.take_damage(40.0, self)
		Setting.FINE:
			person.health.heal(50.0)
			person.apply_speed_boost(1.25, 20.0)
		Setting.VERY_FINE:
			if randf() < 0.5:
				person.health.add_shield(60.0)
				person.apply_speed_boost(1.45, 30.0)
			else:
				person.health.take_damage(60.0, self)


func _set_doors(open: bool) -> void:
	for door in _doors:
		var closed_x: float = door.get_meta("closed_x")
		var t := create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t.tween_property(door, "position:x", closed_x + (1.45 if open else 0.0) * signf(closed_x), 0.9).set_trans(Tween.TRANS_CUBIC)
		Sfx.play_3d(self, "door_open" if open else "door_close", door.global_position + Vector3.UP, -2.0, 0.8)


func _update_pointer(instant: bool) -> void:
	var angle := -PI * 0.8 + setting * (PI * 1.6 / 4.0)
	if instant:
		_pointer.rotation.y = -angle
	else:
		create_tween().tween_property(_pointer, "rotation:y", -angle, 0.25).set_trans(Tween.TRANS_BACK)


# --- Model ----------------------------------------------------------------------

func _build_machine() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	# Iron plinth with chamfered front.
	_box(self, Vector3(5.2, 0.35, 3.2), Vector3(0, 0.175, -1.6), IRON)
	_box(self, Vector3(5.0, 0.12, 0.3), Vector3(0, 0.3, -3.2), DARK_BRASS)
	PropBuilder.add_shape(body, Vector3(0, 1.9, -1.6), Vector3(4.6, 3.8, 3.0))
	# The great drum lying on its side, with banding and bolted end caps.
	_cyl(self, 1.45, 3.7, Vector3(0, 2.0, -1.55), BRASS, Vector3(0, 0, PI / 2), 32)
	for x: float in [-1.5, -0.5, 0.5, 1.5]:
		_torus(self, 1.47, 0.05, Vector3(x, 2.0, -1.55), DARK_BRASS, Vector3(0, 0, PI / 2))
	for side: float in [-1.0, 1.0]:
		_cyl(self, 1.55, 0.18, Vector3(side * 1.92, 2.0, -1.55), DARK_BRASS, Vector3(0, 0, PI / 2), 32)
		_cyl(self, 0.5, 0.3, Vector3(side * 2.1, 2.0, -1.55), IRON, Vector3(0, 0, PI / 2), 20)
		for i in 12:
			var a := i * TAU / 12.0
			_sphere(self, 0.06, Vector3(side * 2.02, 2.0 + sin(a) * 1.35, -1.55 + cos(a) * 1.35), IRON)
		# Legs holding the drum.
		_box(self, Vector3(0.3, 1.2, 0.5), Vector3(side * 1.6, 0.9, -1.55), IRON)
	# Clockwork on the front: gears turning against each other.
	_gears.append(_gear(Vector3(-0.8, 2.15, -3.05), 0.95, 22, BRASS))
	_gears.append(_gear(Vector3(0.72, 2.7, -3.12), 0.6, 14, COPPER))
	_gears.append(_gear(Vector3(0.62, 1.35, -3.12), 0.42, 10, BRASS))
	_gears.append(_gear(Vector3(1.45, 1.95, -3.0), 0.3, 8, DARK_BRASS))
	# Pistons, a chimney and a pressure gauge on top.
	for x: float in [-1.0, 1.0]:
		_cyl(self, 0.12, 0.9, Vector3(x, 3.75, -1.2), IRON, Vector3.ZERO, 14)
		_cyl(self, 0.07, 0.6, Vector3(x, 4.3, -1.2), BRASS, Vector3.ZERO, 12)
		_sphere(self, 0.13, Vector3(x, 4.62, -1.2), BRASS)
	_cyl(self, 0.22, 1.2, Vector3(0, 3.9, -0.7), IRON, Vector3.ZERO, 16)
	_torus(self, 0.24, 0.04, Vector3(0, 4.45, -0.7), BRASS)
	_cyl(self, 0.28, 0.08, Vector3(0, 3.0, -3.0), BRASS, Vector3(PI / 2, 0, 0), 24)
	_cyl(self, 0.24, 0.02, Vector3(0, 3.0, -3.045), Color(0.9, 0.88, 0.8), Vector3(PI / 2, 0, 0), 24)
	_box(self, Vector3(0.02, 0.2, 0.01), Vector3(0.04, 3.04, -3.06), Color(0.6, 0.1, 0.05))
	# Amber warning lamps.
	for x: float in [-1.4, 1.4]:
		_sphere(self, 0.12, Vector3(x, 3.5, -2.2), Color(1.0, 0.6, 0.2), true)
		var l := OmniLight3D.new()
		l.position = Vector3(x, 3.5, -2.45)
		l.light_color = Color(1.0, 0.6, 0.25)
		l.omni_range = 6.0
		l.light_energy = 0.6
		add_child(l)
		_lamps.append(l)
	# Copper pipes to the booths, with elbow joints.
	for side: float in [-1.0, 1.0]:
		var start := Vector3(side * 2.05, 3.1, -1.55)
		var corner := Vector3(side * INTAKE_X, 3.1, -1.55)
		_pipe(start, corner, 0.13)
		_sphere(self, 0.17, corner, COPPER)
		_pipe(corner, Vector3(side * INTAKE_X, 2.7, BOOTH_Z + 0.3), 0.13)
	var title := PropBuilder.add_label(self, "SCP-914", Vector3(0, 4.0, -3.0), 90, 0.006)
	title.rotation.y = PI
	title.modulate = Color(0.9, 0.85, 0.7)


func _build_booth(side: float) -> void:
	var c := Vector3(side * INTAKE_X, 0, BOOTH_Z)
	var body := StaticBody3D.new()
	add_child(body)
	_cyl(self, BOOTH_RADIUS + 0.1, 0.12, c + Vector3(0, 0.06, 0), IRON, Vector3.ZERO, 28)
	_torus(self, BOOTH_RADIUS, 0.05, c + Vector3(0, 0.13, 0), BRASS)
	_torus(self, BOOTH_RADIUS, 0.06, c + Vector3(0, 2.6, 0), BRASS)
	var dome := _sphere(self, BOOTH_RADIUS + 0.05, c + Vector3(0, 2.6, 0), DARK_BRASS)
	(dome.mesh as SphereMesh).is_hemisphere = true
	(dome.mesh as SphereMesh).height = BOOTH_RADIUS + 0.05
	_sphere(self, 0.12, c + Vector3(0, 2.6 + BOOTH_RADIUS, 0), BRASS)
	# Cage of vertical bars, open at the front (towards -Z).
	for i in 18:
		var a := i * TAU / 18.0
		var dir := Vector3(sin(a), 0, cos(a))
		if dir.z < -0.72:
			continue
		var p := c + dir * BOOTH_RADIUS
		_cyl(self, 0.05, 2.5, p + Vector3(0, 1.35, 0), BRASS, Vector3.ZERO, 8)
		var shape := PropBuilder.add_shape(body, p + Vector3(0, 1.3, 0), Vector3(0.45, 2.6, 0.45))
		shape.rotation.y = a
	# Frosted panels behind the bars, so you can't see in from the side.
	for i in 6:
		var a := PI * 0.33 + i * PI * 0.27
		var dir := Vector3(sin(a), 0, cos(a))
		var panel := _box(self, Vector3(0.75, 2.3, 0.04), c + dir * (BOOTH_RADIUS - 0.05) + Vector3(0, 1.35, 0), Color(0.6, 0.62, 0.6))
		panel.rotation.y = a
	# Sliding door across the opening.
	var door := AnimatableBody3D.new()
	door.position = c + Vector3(0.0, 1.3, -BOOTH_RADIUS - 0.12)
	door.set_meta("closed_x", door.position.x)
	add_child(door)
	PropBuilder.add_shape(door, Vector3.ZERO, Vector3(1.6, 2.5, 0.08))
	_box(door, Vector3(1.55, 2.45, 0.06), Vector3.ZERO, IRON)
	_box(door, Vector3(1.2, 0.5, 0.07), Vector3(0, 0.6, 0), Color(0.25, 0.3, 0.32))
	for y: float in [-0.9, -0.3, 0.3]:
		_box(door, Vector3(1.4, 0.04, 0.075), Vector3(0, y, 0), BRASS)
	door.position.x += 1.45 * signf(door.position.x)
	_doors.append(door)
	# Sign above the opening.
	_box(self, Vector3(1.6, 0.4, 0.06), c + Vector3(0, 2.95, -BOOTH_RADIUS - 0.1), Color(0.85, 0.55, 0.2))
	var sign := PropBuilder.add_label(self, "INTAKE" if side > 0 else "OUTPUT", c + Vector3(0, 2.95, -BOOTH_RADIUS - 0.14), 40, 0.005)
	sign.rotation.y = PI
	sign.modulate = Color(0.08, 0.08, 0.08)
	var light := OmniLight3D.new()
	light.position = c + Vector3(0, 2.3, 0)
	light.omni_range = 3.5
	light.light_energy = 1.0
	light.light_color = Color(1.0, 0.85, 0.6)
	add_child(light)
	if side > 0:
		_intake = Area3D.new()
		_intake.collision_layer = 0
		_intake.collision_mask = 0b110
		add_child(_intake)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = BOOTH_RADIUS - 0.25
		cyl.height = 2.4
		shape.shape = cyl
		shape.position = c + Vector3(0, 1.2, 0)
		_intake.add_child(shape)


func _build_console() -> void:
	var c := Vector3(0, 0, -4.0)
	_cyl(self, 0.3, 1.0, c + Vector3(0, 0.5, 0), IRON, Vector3.ZERO, 20)
	_torus(self, 0.32, 0.04, c + Vector3(0, 0.05, 0), BRASS)
	var top := Node3D.new()
	top.position = c + Vector3(0, 1.08, 0)
	top.rotation.x = -0.45  # tilted towards the operator
	add_child(top)
	_cyl(top, 0.55, 0.1, Vector3.ZERO, DARK_BRASS, Vector3.ZERO, 32)
	_torus(top, 0.55, 0.035, Vector3(0, 0.05, 0), BRASS)
	_cyl(top, 0.38, 0.02, Vector3(0, 0.06, 0), Color(0.88, 0.85, 0.75), Vector3.ZERO, 32)
	# Setting names around the dial.
	for i in SETTING_NAMES.size():
		var angle := -PI * 0.8 + i * (PI * 1.6 / 4.0)
		var l := PropBuilder.add_label(top, SETTING_NAMES[i], Vector3(sin(angle) * 0.3, 0.075, -cos(angle) * 0.3), 22, 0.0018)
		l.rotation = Vector3(-PI / 2, -angle, 0)
		l.modulate = Color(0.08, 0.08, 0.08)
	# Pointer knob (clickable).
	_pointer = Node3D.new()
	_pointer.position = Vector3(0, 0.08, 0)
	top.add_child(_pointer)
	_cyl(_pointer, 0.07, 0.06, Vector3.ZERO, BRASS, Vector3.ZERO, 16)
	_box(_pointer, Vector3(0.03, 0.025, 0.22), Vector3(0, 0.02, -0.1), IRON)
	var dial := InteractProxy.new()
	dial.prompt = _dial_prompt
	dial.action = _turn_dial
	top.add_child(dial)
	PropBuilder.add_shape(dial, Vector3(0, 0.08, 0), Vector3(0.8, 0.15, 0.8))
	# The key, on its own little post beside the dial.
	var post := Node3D.new()
	post.position = c + Vector3(0.75, 0, 0)
	add_child(post)
	_cyl(post, 0.1, 1.15, Vector3(0, 0.575, 0), IRON, Vector3.ZERO, 14)
	_cyl(post, 0.13, 0.05, Vector3(0, 1.17, 0), BRASS, Vector3(PI / 2, 0, 0), 16)
	_key = Node3D.new()
	_key.position = Vector3(0, 1.17, -0.04)
	post.add_child(_key)
	_cyl(_key, 0.012, 0.12, Vector3(0, 0, -0.06), BRASS, Vector3(PI / 2, 0, 0), 8)
	_torus(_key, 0.04, 0.012, Vector3(0, 0, -0.13), BRASS, Vector3(PI / 2, 0, 0))
	var key_body := InteractProxy.new()
	key_body.prompt = _key_prompt
	key_body.action = _turn_key
	post.add_child(key_body)
	PropBuilder.add_shape(key_body, Vector3(0, 1.17, -0.08), Vector3(0.3, 0.3, 0.2))
	var key_label := PropBuilder.add_label(post, "KEY", Vector3(0, 1.36, -0.05), 26, 0.003)
	key_label.rotation.y = PI


# --- Mesh helpers ---------------------------------------------------------------

func _gear(pos: Vector3, radius: float, teeth: int, color: Color) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	_cyl(g, radius * 0.86, 0.1, Vector3.ZERO, color, Vector3(PI / 2, 0, 0), 32)
	_torus(g, radius * 0.8, radius * 0.06, Vector3(0, 0, -0.06), color.darkened(0.25), Vector3(PI / 2, 0, 0))
	_cyl(g, radius * 0.18, 0.18, Vector3(0, 0, -0.04), IRON, Vector3(PI / 2, 0, 0), 16)
	for i in teeth:
		var a := i * TAU / teeth
		var t := _box(g, Vector3(radius * 0.16, radius * 0.2, 0.09), Vector3(cos(a), sin(a), 0) * radius * 0.93, color)
		t.rotation.z = a
	for i in 5:
		var a := i * TAU / 5.0
		var spoke := _box(g, Vector3(radius * 0.65, radius * 0.08, 0.04), Vector3(cos(a), sin(a), -0.05) * radius * 0.45, color.darkened(0.35))
		spoke.rotation.z = a
	return g


func _pipe(a: Vector3, b: Vector3, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 16
	var m := _mesh(self, mesh, (a + b) / 2, COPPER)
	var dir := (b - a).normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		return
	m.basis = Basis(Quaternion(Vector3.UP, dir))
	for t: float in [0.15, 0.85]:
		_torus(self, radius + 0.02, 0.025, a.lerp(b, t), BRASS, Vector3.ZERO).basis = Basis(Quaternion(Vector3.UP, dir))


func _mat(color: Color, glow := false) -> StandardMaterial3D:
	var key := color.to_html() + str(glow)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		var metal := color in [BRASS, COPPER, DARK_BRASS, IRON]
		m.metallic = 0.85 if metal else 0.1
		m.roughness = 0.35 if metal else 0.7
		if glow:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 2.5
		_mats[key] = m
	return _mats[key]


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(color, glow)
	m.position = pos
	m.rotation = rot
	parent.add_child(m)
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, pos, color)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, segments := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return _mesh(parent, mesh, pos, color, rot)


func _torus(parent: Node3D, radius: float, thickness: float, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 32
	mesh.ring_segments = 8
	return _mesh(parent, mesh, pos, color, rot)


func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 20
	mesh.rings = 10
	return _mesh(parent, mesh, pos, color, Vector3.ZERO, glow)
