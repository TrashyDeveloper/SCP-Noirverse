class_name FacilityGenerator
extends RefCounted
## Builds the whole site for one round from a seed (same seed = same map).
##
##   Upper floor (y = 0):    Light Containment (research, Class-D, SCP-914...).
##   Lower floor (y = -20):  Heavy Containment + Entrance Zone.
##   Surface (y = 0, east):  the yard above the Entrance Zone.
##
## LayoutGenerator plans each zone (shape, room positions, corridors); this
## script turns the plan into geometry, doors, lights, props, loot and spawn
## points. Static boxes go into a MeshBatch (a few big meshes) instead of
## thousands of nodes, so building a new map each round stays fast.

const C := 12.0
const T := 0.4
const HW := 2.2
const DOOR_W := 1.1
const DOOR_H := 2.6
const LOWER_Y := -20.0
const ZONE_SIZE := Vector2i(9, 6)
const EZ_ORIGIN := Vector2i(10, 0)
const EZ_SIZE := Vector2i(7, 6)
## The corridor cell (on the lower floor) with the HCZ/EZ checkpoint.
const CONNECTOR_COL := 9
const DIRS := LayoutGenerator.DIRS
## Width of the Alpha Warhead shaft.
const SILO_SHAFT := 9.6

const ZONES := {
	"LCZ": {"wall": "concrete_wall", "floor": "concrete_floor", "ceiling": "ceiling", "corridor_h": 3.6, "room_h": 4.2,
		"code": "LCZ", "name": "LIGHT CONTAINMENT ZONE", "light": 1.7, "flicker": 0.25},
	"HCZ": {"wall": "wall_hcz", "floor": "floor_hcz", "ceiling": "ceiling_hcz", "corridor_h": 4.0, "room_h": 5.0,
		"code": "HCZ", "name": "HEAVY CONTAINMENT ZONE", "light": 2.6, "flicker": 0.4},
	"EZ": {"wall": "wall_ez", "floor": "floor_ez", "ceiling": "ceiling_ez", "corridor_h": 3.6, "room_h": 4.2,
		"code": "EZ", "name": "ENTRANCE ZONE", "light": 2.0, "flicker": 0.1},
}

## Sign text and keycard needed (Door.Access, level) for each room type.
## A room can override any of these in its "info" entry.
const ROOMS := {
	"class_d_block": {"name": "CLASS-D CONTAINMENT", "open": true},
	"scp914": {"name": "SCP-914", "access": 1, "level": 2, "height": 6.0},
	"silo": {"name": "ALPHA WARHEAD", "access": 3, "level": 1, "height": 9.0},
	"scp173": {"name": "SCP-173", "wide": true, "wall": "wall_white"},
	"server": {"name": "TERTIARY SERVER ROOM", "wall": "wall_server", "floor": "floor_server"},
	"lift": {"name": "CHECKPOINT", "access": 3, "level": 1},
	"armory": {"name": "ARMORY", "access": 2, "level": 1},
	"test": {"name": "TEST CHAMBER", "access": 1, "level": 2},
	"lockers": {"name": "LOCKER ROOM", "access": 1, "level": 1},
	"lab": {"name": "LABORATORY"},
	"office": {"name": "OFFICE"},
	"restroom": {"name": "RESTROOMS"},
	"storage": {"name": "STORAGE"},
	"janitor": {"name": "JANITOR'S CLOSET"},
	"medical": {"name": "MEDICAL BAY"},
	"break": {"name": "BREAK ROOM"},
	"meeting": {"name": "MEETING ROOM"},
	"scp999": {"name": "SCP-999 PEN", "access": 1, "level": 1},
	"scp055": {"name": "SCP-055 DISPLAY", "access": 1, "level": 2},
	"scp096": {"name": "SCP-096 CONTAINMENT", "access": 1, "level": 3, "scp": "SCP-096"},
	"scp049": {"name": "SCP-049 CONTAINMENT", "access": 1, "level": 3, "scp": "SCP-049"},
	"pit": {"name": "CONTAINMENT PIT", "access": 1, "level": 2},
	"generator": {"name": "GENERATOR ROOM", "access": 3, "level": 1},
	"pump": {"name": "PUMP STATION"},
	"archive": {"name": "ARCHIVE", "access": 1, "level": 2},
	"testing": {"name": "TESTING ROOM", "access": 1, "level": 2},
	"gate": {"name": "GATE", "access": 3, "level": 2},
	"security": {"name": "SECURITY OFFICE", "access": 2, "level": 1},
	"manager": {"name": "FACILITY MANAGER", "access": 3, "level": 2},
	"cafeteria": {"name": "CAFETERIA", "height": 7.0},
	"intercom": {"name": "INTERCOM ROOM"},
}

## Loose items that may lie around in a room type: [item id, chance].
const ROOM_LOOT := {
	"lab": [["painkillers", 0.4], ["keycard_scientist", 0.25], ["exp_serum", 0.2]],
	"office": [["keycard_janitor", 0.3], ["painkillers", 0.3], ["keycard_zone_manager", 0.1]],
	"restroom": [["painkillers", 0.2]],
	"storage": [["first_aid_kit", 0.3], ["barricade_kit", 0.35], ["ammo_9x19mm", 0.2]],
	"break": [["painkillers", 0.3], ["adrenaline", 0.15]],
	"meeting": [["keycard_scientist", 0.2], ["keycard_research_supervisor", 0.08]],
	"medical": [["first_aid_kit", 0.6], ["painkillers", 0.5]],
	"archive": [["keycard_research_supervisor", 0.25], ["painkillers", 0.3]],
	"testing": [["adrenaline", 0.3], ["first_aid_kit", 0.3]],
	"cafeteria": [["painkillers", 0.4]],
	"security": [["ammo_9x19mm", 0.6], ["first_aid_kit", 0.4]],
}

## What a locker can hold (weighted). "" = an empty roll.
const LOCKER_LOOT := {
	"staff": [["keycard_janitor", 3], ["keycard_scientist", 2], ["keycard_zone_manager", 1], ["first_aid_kit", 3],
		["painkillers", 3], ["adrenaline", 1], ["barricade_kit", 2], ["", 4]],
	"research": [["exp_serum", 3], ["exp_flashbang", 2], ["keycard_scientist", 2], ["keycard_research_supervisor", 1],
		["painkillers", 2], ["", 3]],
	"medical": [["first_aid_kit", 4], ["painkillers", 3], ["adrenaline", 2], ["exp_serum", 1]],
	"armory": [["pistol", 2], ["ammo_9x19mm", 4], ["armor_light", 2], ["armor_combat", 1], ["grenade_flashbang", 2],
		["grenade_he", 1], ["barricade_kit", 1]],
	"military": [["ammo_9x19mm", 3], ["ammo_556x45mm", 2], ["grenade_he", 2], ["grenade_flashbang", 2],
		["armor_combat", 1], ["first_aid_kit", 2]],
	"tools": [["barricade_kit", 4], ["keycard_janitor", 2], ["painkillers", 1], ["", 3]],
}

## Items every round must have somewhere in a zone (so the route out is
## always possible), placed in random rooms.
const GUARANTEED := {
	"LCZ": ["keycard_janitor", "keycard_janitor", "keycard_scientist", "keycard_zone_manager",
		"keycard_research_supervisor", "first_aid_kit", "first_aid_kit", "barricade_kit"],
	"HCZ": ["keycard_containment_engineer", "keycard_research_supervisor", "first_aid_kit", "adrenaline"],
	"EZ": ["keycard_guard", "first_aid_kit", "first_aid_kit", "painkillers"],
}

## Room types that never get loose loot or guaranteed items.
const NO_LOOT := ["lift", "gate", "class_d_block", "scp173", "scp914", "server", "pit", "scp096", "scp049", "silo"]

var rng := RandomNumberGenerator.new()
var level: Node3D
var mats := {}
var groups := {}
var counters := {}
var batch: MeshBatch
var floor_y := 0.0
var surface_mode := false
## Current floor: corridor cell -> "#"/"X"/"=", room cell -> room, cell -> zone.
var corridors := {}
var room_at := {}
var zone_of_cell := {}
## Lift name -> {cell, facing, bottom, top, surface}.
var lifts := {}
var surface_holes := {}
## Rooms that may receive loot, per zone: [[floor groups, centre], ...].
var loot_spots := {}
## Where the main menu camera looks from.
var showcase := Transform3D()
## Every room built: {type, zone, position (its centre, level coordinates)}.
## Saved as level meta "rooms" (handy for bots and tests).
var room_list: Array[Dictionary] = []

var _door_scene: PackedScene
var _cell_door_scene: PackedScene
var _pickup_scene: PackedScene
var _flicker_script: Script


## Builds the site. The result is a Node3D ready to add to the scene tree,
## with "SpawnPoints", "SurfaceArea" and meta "seed"/"showcase".
func generate(seed_value: int) -> Node3D:
	rng.seed = seed_value
	for f in ResourceLoader.list_directory("res://resources/materials"):
		if f.ends_with(".tres"):
			mats[f.get_basename()] = load("res://resources/materials/" + f)
	_door_scene = load("res://scenes/props/door.tscn")
	_cell_door_scene = load("res://scenes/props/cell_door.tscn")
	_pickup_scene = load("res://scenes/items/item_pickup.tscn")
	_flicker_script = load("res://scripts/props/flicker_light.gd")

	level = Node3D.new()
	level.name = "Facility"
	var spawns := add(level, Node3D.new(), "SpawnPoints")
	for sg in ["ClassD", "Scientist", "Guard", "SCP", "MTF", "Chaos", "Janitor", "ZoneManager", "Specialist"]:
		add(spawns, Node3D.new(), sg)
	add(level, Node3D.new(), "Lifts")

	var plan := _plan()
	_build_floor("LightContainment", plan.upper, 0.0)
	_build_floor("HeavyAndEntrance", plan.lower, LOWER_Y)
	var lift_batch := MeshBatch.new()
	for lift_name in lifts:
		_build_lift(lift_name, lift_batch)
	lift_batch.build(level.get_node("Lifts"))
	_build_surface()
	level.set_meta("seed", seed_value)
	level.set_meta("showcase", showcase)
	level.set_meta("rooms", room_list)
	return level


# --- planning ---------------------------------------------------------------

## Plans both floors. Retries with new random choices until every zone fits.
func _plan() -> Dictionary:
	for attempt in 30:
		var plan := _try_plan()
		if not plan.is_empty():
			return plan
	push_error("FacilityGenerator: could not plan the facility")
	return {}


func _try_plan() -> Dictionary:
	lifts.clear()
	var ra := rng.randi_range(0, ZONE_SIZE.y - 1)
	var rb := rng.randi_range(0, ZONE_SIZE.y - 1)
	var rc := ra
	while rc == ra:
		rc = rng.randi_range(0, ZONE_SIZE.y - 1)
	var lift_a := Vector2i(ZONE_SIZE.x - 1, ra)
	var lift_b := Vector2i(0, rb)
	lifts["CHECKPOINT A"] = {"cell": lift_a, "facing": Vector2i(-1, 0), "bottom": "HCZ", "top": "LCZ", "surface": false}
	lifts["CHECKPOINT B"] = {"cell": lift_b, "facing": Vector2i(1, 0), "bottom": "HCZ", "top": "LCZ", "surface": false}

	var lcz: LayoutGenerator = _retry(_plan_lcz.bind(lift_a, lift_b))
	var hcz: LayoutGenerator = _retry(_plan_hcz.bind(lift_a, lift_b, Vector2i(ZONE_SIZE.x - 1, rc)))
	var ez: LayoutGenerator = _retry(_plan_ez.bind(Vector2i(EZ_ORIGIN.x, rc)))
	if lcz == null or hcz == null or ez == null:
		return {}
	var lower := {"zones": [[hcz, "HCZ"], [ez, "EZ"]], "extra": {Vector2i(CONNECTOR_COL, rc): "="}}
	for room in ez.rooms:
		if room.type == "gate":
			var cell: Vector2i = room.rect.position
			var dir: Vector2i = DIRS[room.doors[0][1]]
			lifts[room.info.lift] = {"cell": cell, "facing": dir, "bottom": "EZ", "top": "SURFACE", "surface": true}
	return {"upper": {"zones": [[lcz, "LCZ"]], "extra": {}}, "lower": lower}


func _retry(planner: Callable) -> LayoutGenerator:
	for attempt in 25:
		var g: LayoutGenerator = planner.call()
		if g != null:
			return g
	return null


## Places a list of rooms: [type, w, h, opts, info]. False if one didn't fit.
func _place_all(g: LayoutGenerator, list: Array) -> bool:
	for entry in list:
		var room := g.place_room(entry[0], entry[1], entry[2], entry[3] if entry.size() > 3 else {})
		if room.is_empty():
			return false
		room.info = entry[4] if entry.size() > 4 else {}
	return true


func _plan_lcz(lift_a: Vector2i, lift_b: Vector2i) -> LayoutGenerator:
	var g := LayoutGenerator.new(rng, Vector2i.ZERO, ZONE_SIZE)
	g.carve_shape([lift_a, lift_a + Vector2i(-1, 0), lift_b, lift_b + Vector2i(1, 0)])
	var ok := _place_all(g, [
		["lift", 1, 1, {"at": lift_a, "door_dirs": ["W"]}, {"name": "CHECKPOINT A", "lift": "CHECKPOINT A"}],
		["lift", 1, 1, {"at": lift_b, "door_dirs": ["E"]}, {"name": "CHECKPOINT B", "lift": "CHECKPOINT B"}],
		["class_d_block", 3, 1, {"door_dirs": ["E"], "door_cell": "max"}],
		["scp914", 2, 1, {"door_dirs": ["N", "W", "E"]}],
		["scp173", 2, 1, {"door_dirs": ["W"], "door_cell": "min"}],
		["server", 2, 1, {"door_dirs": ["W", "N", "S"], "door_cell": "min"}],
		["armory", 1, 1, {}, {"name": "LCZ ARMORY"}],
		["test", 1, 1], ["lockers", 1, 1], ["scp999", 1, 1], ["scp055", 1, 1],
		["office", 1, 1], ["janitor", 1, 1],
	])
	if not ok or not g.connect_corridors():
		return null
	g.add_dead_ends(rng.randi_range(2, 3))
	g.add_loops(rng.randi_range(1, 2))
	g.add_lockroom()
	g.add_fillers([["lab", 4], ["office", 3], ["storage", 2], ["restroom", 2], ["break", 2], ["meeting", 1],
		["medical", 1], ["janitor", 1]], 0.75)
	return g


func _plan_hcz(lift_a: Vector2i, lift_b: Vector2i, connector: Vector2i) -> LayoutGenerator:
	var g := LayoutGenerator.new(rng, Vector2i.ZERO, ZONE_SIZE)
	g.carve_shape([lift_a, lift_a + Vector2i(-1, 0), lift_b, lift_b + Vector2i(1, 0), connector])
	g.require(connector)
	var ok := _place_all(g, [
		["lift", 1, 1, {"at": lift_a, "door_dirs": ["W"]}, {"name": "CHECKPOINT A", "lift": "CHECKPOINT A"}],
		["lift", 1, 1, {"at": lift_b, "door_dirs": ["E"]}, {"name": "CHECKPOINT B", "lift": "CHECKPOINT B"}],
		["silo", 2, 2], ["pit", 2, 2],
		["scp096", 1, 1, {"door_dirs": ["E", "W"]}], ["scp049", 1, 1, {"door_dirs": ["E", "W"]}],
		["generator", 1, 1], ["armory", 1, 1, {}, {"name": "HCZ ARMORY", "level": 2}],
		["archive", 1, 1], ["testing", 1, 1], ["pump", 1, 1],
	])
	if not ok or not g.connect_corridors():
		return null
	g.add_dead_ends(rng.randi_range(2, 4))
	g.add_loops(1)
	g.add_fillers([["storage", 3], ["pump", 2], ["archive", 1], ["break", 1], ["restroom", 1]], 0.5)
	return g


func _plan_ez(connector: Vector2i) -> LayoutGenerator:
	var g := LayoutGenerator.new(rng, EZ_ORIGIN, EZ_SIZE)
	g.carve_shape([connector])
	g.require(connector)
	var b_north := rng.randf() < 0.5
	var ok := _place_all(g, [
		["gate", 1, 1, {"edge": "N", "door_dirs": ["S"]}, {"name": "GATE A", "lift": "GATE A"}],
		["gate", 1, 1, {"edge": "N" if b_north else "S", "door_dirs": ["S" if b_north else "N"]}, {"name": "GATE B", "lift": "GATE B"}],
		["gate", 1, 1, {"edge": "S", "door_dirs": ["N"]}, {"name": "GATE C - EMERGENCY EXIT", "lift": "GATE C", "level": 1}],
		["cafeteria", 2, 1], ["security", 1, 1], ["manager", 1, 1], ["intercom", 1, 1],
		["medical", 1, 1], ["meeting", 1, 1], ["restroom", 1, 1],
	])
	if not ok or not g.connect_corridors():
		return null
	g.add_dead_ends(rng.randi_range(1, 2))
	g.add_loops(rng.randi_range(1, 2))
	g.add_fillers([["office", 4], ["meeting", 1], ["break", 2], ["restroom", 1], ["storage", 1]], 0.75)
	return g


# --- helpers ----------------------------------------------------------------

func add(parent: Node, node: Node, n: String) -> Node:
	node.name = n
	parent.add_child(node, true)
	return node


func uname(base: String) -> String:
	counters[base] = counters.get(base, 0) + 1
	return base if counters[base] == 1 else "%s%d" % [base, counters[base]]


func center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * C, 0, cell.y * C)


## A static box in floor coordinates (centre, size). `basis` rotates it.
func box(c: Vector3, size: Vector3, mat: String, collide := true, basis := Basis()) -> void:
	batch.add_box(Transform3D(basis, c + Vector3(0, floor_y, 0)), size, mats[mat], collide)


func box_mm(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, mat: String, collide := true) -> void:
	if x1 - x0 < 0.01 or y1 - y0 < 0.01 or z1 - z0 < 0.01:
		return
	box(Vector3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3(x1 - x0, y1 - y0, z1 - z0), mat, collide)


## A floor or ceiling slab, optionally with a rectangular hole.
func slab(x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, mat: String, hole := Rect2()) -> void:
	if hole.size == Vector2.ZERO:
		box_mm(x0, y0, z0, x1, y1, z1, mat)
		return
	box_mm(x0, y0, z0, x1, y1, hole.position.y, mat)
	box_mm(x0, y0, hole.end.y, x1, y1, z1, mat)
	box_mm(x0, y0, hole.position.y, hole.position.x, y1, hole.end.y, mat)
	box_mm(hole.end.x, y0, hole.position.y, x1, y1, hole.end.y, mat)


## A box node (for parts that move or belong to a scripted object).
func node_box(parent: Node, n: String, pos: Vector3, size: Vector3, mat: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mats[mat]
	m.position = pos
	return add(parent, m, n)


func yaw_towards(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


## Yaw that turns a node's -Z (its front) to face along `dir`.
func yaw_facing(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func label(text: String, pos: Vector3, yaw: float, size: int, pixel := 0.005) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation.y = yaw
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = Color(0.9, 0.9, 0.85)
	l.outline_size = 0
	l.shaded = true
	return add(groups["Signs"], l, uname("Sign"))


func lamp(pos: Vector3, energy: float, light_range: float, flicker_chance: float, shadows := true,
		color := Color(1.0, 0.95, 0.85), fixture := true) -> void:
	var g: Node3D = add(groups["Lights"], Node3D.new(), uname("Lamp"))
	g.position = pos
	if fixture:
		box(pos + Vector3(0, -0.04, 0), Vector3(1.2, 0.08, 0.25), "lamp", false)
	var light := OmniLight3D.new()
	light.omni_range = light_range
	light.omni_attenuation = 1.1
	light.position = Vector3(0, -0.15, 0)
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 1.5
	light.distance_fade_enabled = true
	light.distance_fade_begin = 45.0
	light.distance_fade_shadow = 30.0
	light.distance_fade_length = 10.0
	if rng.randf() < flicker_chance:
		light.set_script(_flicker_script)
	add(g, light, "Light")
	light.add_to_group("facility_lights")


func door(pos: Vector3, yaw: float, access: int, level_req: int, code: String, zname: String, open := false) -> Door:
	var d: Door = _door_scene.instantiate()
	d.position = pos
	d.rotation.y = yaw
	d.access = access
	d.required_level = level_req
	d.zone_code = code
	d.zone_name = zname
	d.start_open = open
	add(groups["Doors"], d, uname("Door"))
	return d


func item(id: String, pos: Vector3) -> void:
	var p: ItemPickup = _pickup_scene.instantiate()
	p.item_data = load("res://resources/items/%s.tres" % id)
	p.position = pos
	p.rotation.y = rng.randf() * TAU
	add(groups["Items"], p, uname(id.to_pascal_case()))


## Spawn markers live in one shared folder, so they get the floor height added.
func spawn(group: String, pos: Vector3, yaw: float) -> void:
	var m := Marker3D.new()
	m.position = pos + Vector3(0, floor_y, 0)
	m.rotation.y = yaw
	add(level.get_node("SpawnPoints/" + group), m, uname(group))


## Places a scripted prop (terminal, locker...) at `pos` facing `dir`.
func place(node: Node3D, n: String, pos: Vector3, dir: Vector3) -> Node3D:
	node.position = pos
	node.rotation.y = yaw_facing(dir)
	return add(groups["Props"], node, uname(n))


func terminal(pos: Vector3, facing: Vector3, kind := "status") -> void:
	var t := Terminal.new()
	t.kind = kind
	place(t, "Terminal", pos, facing)


func locker(pos: Vector3, facing: Vector3, table: String, access := 0, level_req := 0) -> void:
	var l := LootLocker.new()
	l.access = access
	l.required_level = level_req
	l.contents = roll_loot(table, rng.randi_range(1, 3))
	place(l, "Locker", pos, facing)


func crate(pos: Vector3, size := 1.0) -> void:
	var cr := Crate.new()
	cr.size = Vector3.ONE * size
	if rng.randf() < 0.5:
		cr.contents = roll_loot("staff" if rng.randf() < 0.6 else "military", 1)
	place(cr, "Crate", pos + Vector3(0, size / 2, 0), Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU))


func roll_loot(table: String, rolls: int) -> Array[String]:
	var result: Array[String] = []
	var entries: Array = LOCKER_LOOT[table]
	var total := 0.0
	for e in entries:
		total += e[1]
	for i in rolls:
		var r := rng.randf() * total
		for e in entries:
			r -= e[1]
			if r <= 0.0:
				if e[0] != "":
					result.append(e[0])
				break
	return result


## A simple railing from a to b (floor coordinates).
func railing(a: Vector3, b: Vector3, height := 1.0) -> void:
	var length := a.distance_to(b)
	var along_x := absf((b - a).x) > absf((b - a).z)
	var mid := (a + b) / 2
	for y in [height, height * 0.5]:
		box(mid + Vector3(0, y, 0), Vector3(length, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, length), "metal", false)
	var posts := maxi(int(length / 1.2), 1)
	for i in posts + 1:
		box(a + (b - a) * (float(i) / posts) + Vector3(0, height / 2, 0), Vector3(0.06, height, 0.06), "metal")
	# Invisible barrier so nobody walks through between the posts.
	box(mid + Vector3(0, height / 2, 0), Vector3(length, height, 0.02) if along_x else Vector3(0.02, height, length), "metal", true)


## A ramp from `low` (on the ground) to `high`, `width` wide.
func ramp(low: Vector3, high: Vector3, width: float, mat := "metal") -> void:
	var d := high - low
	var flat := Vector3(d.x, 0, d.z)
	var length := d.length()
	var yaw := atan2(flat.x, flat.z)
	var pitch := -atan2(d.y, flat.length())
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var mid := (low + high) / 2 - basis.y * 0.1
	box(mid, Vector3(width, 0.2, length), mat, true, basis)


## World-space footprint (Rect2 in x/z) of a lift, and its centre and yaw.
func lift_transform(lift_name: String) -> Dictionary:
	var spec: Dictionary = lifts[lift_name]
	var f: Vector2i = spec.facing
	var fv := Vector3(f.x, 0, f.y)
	var c := center(spec.cell) - fv * 3.5
	var half := Vector2(2.7, 2.1) if f.x == 0 else Vector2(2.1, 2.7)
	return {"center": c, "yaw": atan2(fv.x, fv.z), "rect": Rect2(c.x - half.x, c.z - half.y, half.x * 2, half.y * 2)}


## The first side of a 1x1 room that has no door and isn't in `busy`.
func free_wall(doors: Array, busy := []) -> String:
	for d in ["N", "E", "S", "W"]:
		if not doors.has(d) and not busy.has(d):
			return d
	for d in ["N", "E", "S", "W"]:
		if not doors.has(d):
			return d
	return "N"


# --- floors -----------------------------------------------------------------

func _build_floor(n: String, plan: Dictionary, y: float) -> void:
	floor_y = y
	corridors = plan.extra.duplicate()
	room_at = {}
	zone_of_cell = {}
	batch = MeshBatch.new()
	var node: Node3D = add(level, Node3D.new(), n)
	node.position.y = y
	groups = {}
	for g in ["Doors", "Lights", "Props", "Items", "Signs"]:
		groups[g] = add(node, Node3D.new(), g)
	var rooms := []
	for entry in plan.zones:
		var g: LayoutGenerator = entry[0]
		var zone: String = entry[1]
		for c in g.corridors:
			corridors[c] = g.corridors[c]
			zone_of_cell[c] = zone
		for c in g.room_at:
			room_at[c] = g.room_at[c]
			zone_of_cell[c] = zone
		for room in g.rooms:
			room.zone = zone
			rooms.append(room)
	for c in plan.extra:
		zone_of_cell[c] = "HCZ"
	for c in corridors:
		_build_corridor(c, corridors[c])
	for room in rooms:
		_build_room(room)
	for entry in plan.zones:
		_place_guaranteed(entry[1])
	var geometry: Node3D = add(node, Node3D.new(), "Geometry")
	geometry.position.y = -y  # the batch is in level coordinates
	batch.build(geometry)


func _place_guaranteed(zone: String) -> void:
	var spots: Array = loot_spots.get(zone, [])
	if spots.is_empty():
		return
	for id in GUARANTEED[zone]:
		var spot: Vector3 = spots[rng.randi() % spots.size()]
		item(id, spot + Vector3(rng.randf_range(-1.6, 1.6), 1.3, rng.randf_range(-1.6, 1.6)))


## Which sides of a corridor cell lead somewhere (corridors or room doors).
func connections(c: Vector2i) -> Array:
	var result := []
	for d in DIRS:
		var n: Vector2i = c + DIRS[d]
		if corridors.has(n):
			result.append(d)
		elif room_at.has(n):
			var opposite: String = {"N": "S", "S": "N", "E": "W", "W": "E"}[d]
			if room_at[n].doors.has([n, opposite]):
				result.append(d)
	return result


func _build_corridor(cell: Vector2i, ch: String) -> void:
	var zone: String = zone_of_cell[cell]
	var z: Dictionary = ZONES[zone]
	var h: float = z.corridor_h
	var c := center(cell)
	var conns := connections(cell)
	var e := C / 2
	slab(c.x - e, c.z - e, c.x + e, c.z + e, -T, 0, z.floor)
	slab(c.x - e, c.z - e, c.x + e, c.z + e, h, h + T, z.ceiling)
	var w: String = z.wall
	if not "N" in conns: box_mm(c.x - HW - T, 0, c.z - HW - T, c.x + HW + T, h, c.z - HW, w)
	if not "S" in conns: box_mm(c.x - HW - T, 0, c.z + HW, c.x + HW + T, h, c.z + HW + T, w)
	if not "E" in conns: box_mm(c.x + HW, 0, c.z - HW - T, c.x + HW + T, h, c.z + HW + T, w)
	if not "W" in conns: box_mm(c.x - HW - T, 0, c.z - HW - T, c.x - HW, h, c.z + HW + T, w)
	if "N" in conns:
		box_mm(c.x - HW - T, 0, c.z - e, c.x - HW, h, c.z - HW, w)
		box_mm(c.x + HW, 0, c.z - e, c.x + HW + T, h, c.z - HW, w)
	if "S" in conns:
		box_mm(c.x - HW - T, 0, c.z + HW, c.x - HW, h, c.z + e, w)
		box_mm(c.x + HW, 0, c.z + HW, c.x + HW + T, h, c.z + e, w)
	if "E" in conns:
		box_mm(c.x + HW, 0, c.z - HW - T, c.x + e, h, c.z - HW, w)
		box_mm(c.x + HW, 0, c.z + HW, c.x + e, h, c.z + HW + T, w)
	if "W" in conns:
		box_mm(c.x - e, 0, c.z - HW - T, c.x - HW, h, c.z - HW, w)
		box_mm(c.x - e, 0, c.z + HW, c.x - HW, h, c.z + HW + T, w)
	if ch == "=":
		box_mm(c.x - T / 2, 0, c.z - HW, c.x + T / 2, h, c.z - DOOR_W, w)
		box_mm(c.x - T / 2, 0, c.z + DOOR_W, c.x + T / 2, h, c.z + HW, w)
		box_mm(c.x - T / 2, DOOR_H, c.z - DOOR_W, c.x + T / 2, h, c.z + DOOR_W, w)
		door(c, PI / 2, 3, 1, "CHECKPOINT", "HCZ  -  EZ")
		label(ZONES.EZ.name + "  >", Vector3(c.x - T / 2 - 0.02, 3.15, c.z), -PI / 2, 30)
		label(ZONES.HCZ.name + "  <", Vector3(c.x + T / 2 + 0.02, 3.15, c.z), PI / 2, 30)
		lamp(Vector3(c.x - 3.5, h, c.z), z.light, 8.0, 0.0)
		lamp(Vector3(c.x + 3.5, h, c.z), z.light, 8.0, 0.0)
		terminal(Vector3(c.x + 3.0, 0, c.z - HW + 0.35), Vector3(0, 0, 1))
	elif ch == "X":
		# Lockroom: two doors in a row along the corridor.
		var along := Vector3(1, 0, 0) if "E" in conns else Vector3(0, 0, 1)
		var across := Vector3(along.z, 0, along.x)
		var yaw := PI / 2 if along.x > 0.5 else 0.0
		for s: float in [-3.0, 3.0]:
			var p := c + along * s
			for piece in [[-HW, -DOOR_W, 0.0, h], [DOOR_W, HW, 0.0, h], [-DOOR_W, DOOR_W, DOOR_H, h]]:
				var a: Vector3 = p + across * piece[0] - along * T / 2
				var b: Vector3 = p + across * piece[1] + along * T / 2
				box_mm(minf(a.x, b.x), piece[2], minf(a.z, b.z), maxf(a.x, b.x), piece[3], maxf(a.z, b.z), w)
			door(p, yaw, 0, 0, "LOCK", "LOCKROOM")
			label("LOCKROOM", p - along * signf(s) * (T / 2 + 0.02) + Vector3(0, 3.15, 0), yaw_facing(-along * signf(s)), 30)
		box(c + Vector3(0, 0.01, 0), Vector3(0.25, 0.02, 5.2) if along.x > 0.5 else Vector3(5.2, 0.02, 0.25), "hazard", false)
		lamp(Vector3(c.x, h, c.z), z.light, 7.0, 0.0)
	else:
		lamp(Vector3(c.x, h, c.z), z.light, 9.0, z.flicker)
		# Dead ends get some clutter (and sometimes a crate worth breaking).
		if conns.size() == 1:
			var back: Vector2i = -DIRS[conns[0]]
			var bv := Vector3(back.x, 0, back.y)
			crate(c + bv * 1.2 + Vector3(bv.z, 0, bv.x) * 1.0, 1.0)
			if zone == "HCZ":
				box(c + bv * 1.8 + Vector3(0, 0.5, 0) - Vector3(bv.z, 0, bv.x) * 1.2, Vector3(0.9, 1.0, 0.9), "metal_dark")


# --- rooms ------------------------------------------------------------------

func _build_room(room: Dictionary) -> void:
	var zone: String = room.zone
	var z: Dictionary = ZONES[zone]
	var info: Dictionary = ROOMS[room.type].duplicate()
	info.merge(room.get("info", {}), true)
	var rect: Rect2i = room.rect
	var h: float = info.get("height", z.room_h)
	var c0 := center(rect.position)
	var c1 := center(rect.end - Vector2i.ONE)
	var e := C / 2
	var x0 := c0.x - e
	var x1 := c1.x + e
	var z0 := c0.z - e
	var z1 := c1.z + e
	var w: String = info.get("wall", z.wall)
	room_list.append({"type": room.type, "zone": zone, "position": (c0 + c1) / 2 + Vector3(0, floor_y, 0)})
	var floor_hole := Rect2()
	var ceiling_hole := Rect2()
	if info.has("lift"):
		var r: Rect2 = lift_transform(info.lift).rect
		if zone == "LCZ":
			floor_hole = r  # the lift comes up through the floor
		else:
			ceiling_hole = r  # the lift goes up through the ceiling
	var inner := Rect2(x0 + T, z0 + T, x1 - x0 - 2 * T, z1 - z0 - 2 * T)
	if room.type == "pit":
		floor_hole = inner.grow(-3.2)
	elif room.type == "silo":
		floor_hole = inner.grow(-(inner.size.x - SILO_SHAFT) / 2.0)
	slab(x0, z0, x1, z1, -T, 0, info.get("floor", z.floor), floor_hole)
	slab(x0, z0, x1, z1, h, h + T, z.ceiling, ceiling_hole)
	var wide: bool = info.get("wide", false)
	var cells := []
	for x in rect.size.x:
		for y in rect.size.y:
			cells.append(rect.position + Vector2i(x, y))
	for rc: Vector2i in cells:
		var c := center(rc)
		for d in DIRS:
			if cells.has(rc + DIRS[d]):
				continue
			var has_door: bool = room.doors.has([rc, d])
			var half := HW if wide else DOOR_W
			var top := 3.0 if wide else DOOR_H
			match d:
				"N", "S":
					var fz := c.z - e + T / 2 if d == "N" else c.z + e - T / 2
					_room_wall("x", fz, c.x - e, c.x + e, c.x if has_door else NAN, h, w, half, top)
				"E", "W":
					var fx := c.x + e - T / 2 if d == "E" else c.x - e + T / 2
					var a0 := c.z - e + (T if not cells.has(rc + DIRS.N) else 0.0)
					var a1 := c.z + e - (T if not cells.has(rc + DIRS.S) else 0.0)
					_room_wall("z", fx, a0, a1, c.z if has_door else NAN, h, w, half, top)
	var door_dirs := []
	for dd in room.doors:
		door_dirs.append(dd[1])
		var dir: Vector2i = DIRS[dd[1]]
		var normal := Vector3(dir.x, 0, dir.y)
		var pos := center(dd[0]) + normal * (e - T / 2)
		var yaw := 0.0 if dir.x == 0 else PI / 2
		if wide:
			_wide_entrance(pos, normal, info)
			continue
		door(pos, yaw, info.get("access", 0), info.get("level", 0), z.code, z.name, info.get("open", false))
		var outside_zone: String = zone_of_cell.get(dd[0] + dir, zone)
		var sign_pos := pos + normal * (T / 2 + 0.02) + Vector3(0, minf(3.05, ZONES[outside_zone].corridor_h - 0.45), 0)
		label(info.name, sign_pos, yaw_towards(Vector3.ZERO, -normal), 26)
	if rect.size == Vector2i.ONE:
		lamp(Vector3(c0.x, h, c0.z), z.light * 1.25, 14.0, z.flicker)
		_furnish(room, info, c0, door_dirs, h, z)
		if not room.type in NO_LOOT:
			loot_spots.get_or_add(zone, []).append(c0)
			for l in ROOM_LOOT.get(room.type, []):
				if rng.randf() < l[1]:
					item(l[0], c0 + Vector3(rng.randf_range(-1.6, 1.6), 1.3, rng.randf_range(-1.6, 1.6)))
	else:
		_furnish_big(room, info, inner, h, z, door_dirs)


func _room_wall(axis: String, fixed: float, a0: float, a1: float, door_at: float, h: float, mat: String,
		half := DOOR_W, top := DOOR_H) -> void:
	var pieces := []
	if is_nan(door_at):
		pieces = [[a0, a1, 0.0, h]]
	else:
		pieces = [[a0, door_at - half, 0.0, h], [door_at + half, a1, 0.0, h], [door_at - half, door_at + half, top, h]]
	for p in pieces:
		if axis == "x":
			box_mm(p[0], p[2], fixed - T / 2, p[1], p[3], fixed + T / 2, mat)
		else:
			box_mm(fixed - T / 2, p[2], p[0], fixed + T / 2, p[3], p[1], mat)


## A wide open entrance with hazard-striped pillars (used by SCP-173).
func _wide_entrance(pos: Vector3, normal: Vector3, info: Dictionary) -> void:
	var along := Vector3(absf(normal.z), 0, absf(normal.x))
	for s: float in [-1.0, 1.0]:
		var size := Vector3(0.6, 3.0, 0.3) if along.x > 0.5 else Vector3(0.3, 3.0, 0.6)
		box(pos + along * s * (HW + 0.15) + Vector3(0, 1.5, 0), size, "hazard_stripes")
	var beam_size := Vector3(HW * 2 + 0.6, 0.3, 0.6) if along.x > 0.5 else Vector3(0.6, 0.3, HW * 2 + 0.6)
	box(pos + Vector3(0, 3.15, 0), beam_size, "metal_dark")
	var outside := pos + normal * (T / 2 + 0.03)
	var yaw := yaw_towards(Vector3.ZERO, -normal)
	box(outside + along * 3.2 + Vector3(0, 1.55, 0) - normal * 0.02, Vector3(0.5, 0.65, 0.5) * (along + Vector3(0, 1, 0)) + normal.abs() * 0.03, "cloth", false)
	label("%s\nEUCLID" % info.name, outside + along * 3.2 + Vector3(0, 1.45, 0) + normal * 0.01, yaw, 30, 0.0035).modulate = Color(0.08, 0.08, 0.08)


## Furniture for 1x1 rooms. `c` is the room centre, `door_dirs` its doors.
func _furnish(room: Dictionary, info: Dictionary, c: Vector3, door_dirs: Array, h: float, z: Dictionary) -> void:
	var corners := [Vector3(-3.8, 0, -3.8), Vector3(3.8, 0, -3.8), Vector3(-3.8, 0, 3.8), Vector3(3.8, 0, 3.8)]
	var wall := free_wall(door_dirs)
	var wv := Vector3(DIRS[wall].x, 0, DIRS[wall].y)
	# A spot against a free wall, facing into the room (for terminals etc.).
	var wall_spot := c + wv * (C / 2 - T - 0.45)
	# A second free wall for things that shouldn't block the door.
	var w2v := Vector3(DIRS[free_wall(door_dirs, [wall])].x, 0, DIRS[free_wall(door_dirs, [wall])].y)
	var spot2 := c + w2v * (C / 2 - T - 0.45)
	var side2 := Vector3(absf(w2v.z), 0, absf(w2v.x))
	match room.type:
		"lab":
			for k in corners:
				box(c + k * Vector3(0.95, 0, 0.9) + Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 1.1), "metal")
				box(c + k * Vector3(0.95, 0, 0.9) + Vector3(0.6, 1.1, 0), Vector3(0.5, 0.4, 0.3), "metal_dark")
				box(c + k * Vector3(0.95, 0, 0.9) + Vector3(-0.5, 1.0, 0), Vector3(0.15, 0.2, 0.15), "glass", false)
			for k in [Vector3(-1.5, 0, 0), Vector3(1.5, 0, 0)]:
				spawn("Scientist", c + k + Vector3(0, 0.1, 0), rng.randf() * TAU)
			locker(wall_spot + Vector3(wv.z, 0, wv.x) * 1.4, -wv, "research", 1, 1)
			terminal(wall_spot - Vector3(wv.z, 0, wv.x) * 1.4, -wv)
		"office":
			for k in corners:
				box(c + k * Vector3(0.9, 0, 0.95) + Vector3(0, 0.4, 0), Vector3(2.2, 0.8, 1.0), "wood")
				box(c + k * Vector3(0.9, 0, 0.95) + Vector3(0.4, 1.0, -0.2), Vector3(0.6, 0.4, 0.08), "metal_dark", false)
				box(c + k * Vector3(0.9, 0, 0.7) + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), "metal_dark")
			box(wall_spot + Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 0.6) if wv.x == 0 else Vector3(0.6, 2.0, 1.6), "metal")
			terminal(c + Vector3(0, 0, 0) - wv * 1.5, wv)
			if room.zone == "LCZ":
				spawn("Scientist", c + Vector3(1.5, 0.1, -1.5), rng.randf() * TAU)
				spawn("ZoneManager", c + Vector3(-1.5, 0.1, 1.5), rng.randf() * TAU)
			elif room.zone == "EZ":
				spawn("Guard", c + Vector3(1.5, 0.1, 1.5), rng.randf() * TAU)
		"restroom":
			var side := Vector3(absf(wv.z), 0, absf(wv.x))
			for s: float in [-4.6, -2.4, -0.2, 2.0, 4.2]:
				box(wall_spot - wv * 0.6 + side * s + Vector3(0, 1.0, 0), Vector3(0.08, 2.0, 2.2) if side.x > 0.5 else Vector3(2.2, 2.0, 0.08), "metal")
			for s: float in [-3.5, -1.3, 0.9, 3.1]:
				box(wall_spot + side * s + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.6), "cloth")
			var sink := c + w2v * 4.9 + side2 * 1.5
			box(sink + Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 0.6) if side2.x > 0.5 else Vector3(0.6, 0.9, 3.0), "metal")
			box(sink + w2v * 0.35 + Vector3(0, 1.7, 0), Vector3(2.8, 1.0, 0.04) if side2.x > 0.5 else Vector3(0.04, 1.0, 2.8), "metal", false)
		"storage":
			for k in corners:
				box(c + k * Vector3(1.0, 0, 0.8) + Vector3(0, 1.2, 0), Vector3(0.7, 2.4, 3.0), "metal_dark")
				box(c + k * Vector3(1.0, 0, 0.8) + Vector3(0, 0.3, 0), Vector3(0.6, 0.5, 0.6), "wood")
			crate(c + Vector3(-1.8, 0, 2.0), 1.1)
			crate(c + Vector3(2.0, 0, -1.6), 0.9)
			locker(wall_spot, -wv, "tools")
		"janitor":
			var side := Vector3(absf(wv.z), 0, absf(wv.x))
			box(wall_spot + side * 2.5 + Vector3(0, 1.1, 0), Vector3(2.4, 2.2, 0.6) if side.x > 0.5 else Vector3(0.6, 2.2, 2.4), "metal_dark")
			box(wall_spot - side * 3.0 + Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.6) if side.x > 0.5 else Vector3(0.6, 0.9, 1.2), "metal")
			box(c + Vector3(1.6, 0.3, 1.2), Vector3(0.5, 0.6, 0.5), "metal")  # mop bucket
			box(c + Vector3(1.6, 1.0, 1.2), Vector3(0.05, 1.6, 0.05), "wood", false)  # mop
			box(c + Vector3(-2.0, 0.5, 1.8), Vector3(1.2, 1.0, 0.6), "metal_dark")  # cleaning cart
			locker(wall_spot - side * 0.6, -wv, "tools")
			for k in [Vector3(-1.0, 0, -0.5), Vector3(1.0, 0, -0.5)]:
				spawn("Janitor", c + k + Vector3(0, 0.1, 0), yaw_facing(-wv))
		"medical":
			var side := Vector3(absf(wv.z), 0, absf(wv.x))
			for s: float in [-3.4, 0.0, 3.4]:
				var bed := wall_spot - wv * 0.8 + side * s
				box(bed + Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 2.0) if side.x > 0.5 else Vector3(2.0, 0.7, 1.0), "metal")
				box(bed + Vector3(0, 0.75, 0), Vector3(0.9, 0.1, 1.9) if side.x > 0.5 else Vector3(1.9, 0.1, 0.9), "cloth")
				box(bed + side * 0.85 + Vector3(0, 1.1, 0), Vector3(0.04, 2.2, 1.9) if side.x > 0.5 else Vector3(1.9, 2.2, 0.04), "cloth", false)
			locker(spot2 + side2 * 2.0, -w2v, "medical")
			terminal(spot2 - side2 * 2.0, -w2v)
		"break":
			var side := Vector3(absf(wv.z), 0, absf(wv.x))
			box(wall_spot + Vector3(0, 0.35, 0), Vector3(3.0, 0.7, 1.0) if side.x > 0.5 else Vector3(1.0, 0.7, 3.0), "cloth")  # sofa
			box(wall_spot - wv * 1.6 + Vector3(0, 0.25, 0), Vector3(1.6, 0.5, 0.8) if side.x > 0.5 else Vector3(0.8, 0.5, 1.6), "wood")
			var vend := spot2 + side2 * 3.0
			box(vend + Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.9) if side2.x > 0.5 else Vector3(0.9, 2.0, 1.2), "metal_dark")
			box(vend - w2v * 0.46 + Vector3(0, 1.4, 0), Vector3(0.8, 0.8, 0.02) if side2.x > 0.5 else Vector3(0.02, 0.8, 0.8), "screen_blue", false)
			var counter := c + w2v * 4.8 - side2 * 1.5
			box(counter + Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 0.7) if side2.x > 0.5 else Vector3(0.7, 0.9, 2.0), "metal")
			box(counter + Vector3(0, 1.1, 0), Vector3(0.4, 0.4, 0.4), "metal_dark")  # coffee machine
		"meeting":
			box(c + Vector3(0, 0.38, 0), Vector3(1.6, 0.76, 5.0) if wv.x != 0 else Vector3(5.0, 0.76, 1.6), "wood")
			for s: float in [-1.8, -0.6, 0.6, 1.8]:
				for t: float in [-1.3, 1.3]:
					var p := Vector3(t, 0.25, s) if wv.x != 0 else Vector3(s, 0.25, t)
					box(c + p, Vector3(0.5, 0.5, 0.5), "metal_dark")
			box(wall_spot + wv * 0.35 + Vector3(0, 1.8, 0), Vector3(2.6, 1.4, 0.06) if wv.x == 0 else Vector3(0.06, 1.4, 2.6), "metal_dark", false)
			terminal(spot2 + side2 * 3.0, -w2v, "status")
		"lockers":
			for k in corners:
				var dir := Vector3(-signf(k.x), 0, 0)
				locker(c + k * Vector3(1.25, 0, 0.75), dir, "staff")
				locker(c + k * Vector3(1.25, 0, 0.45), dir, "staff")
			box(c + Vector3(0, 0.25, 0), Vector3(3.0, 0.5, 0.5), "wood")
		"test":
			var dummy_scene: PackedScene = load("res://scenes/props/training_dummy.tscn")
			for k in [Vector3(-3.5, 0, -3.8), Vector3(0, 0, -3.8), Vector3(3.5, 0, -3.8)]:
				var dmy: Node3D = dummy_scene.instantiate()
				dmy.position = c + k
				add(groups["Props"], dmy, uname("Dummy"))
			box(c + Vector3(0, 0.01, -1.5), Vector3(9.0, 0.02, 0.3), "hazard", false)
			terminal(c + Vector3(-4.6, 0, 3.0), Vector3(1, 0, 0), "status")
		"armory":
			for k in corners:
				box(c + k * Vector3(1.2, 0, 1.0) + Vector3(0, 0.9, 0), Vector3(0.5, 1.8, 2.6), "metal_dark")
			box(c + Vector3(-3.0, 0.4, 0), Vector3(0.8, 0.8, 0.8), "wood")
			locker(wall_spot, -wv, "armory" if room.zone == "LCZ" else "military")
			item("pistol", c + Vector3(-1.0, 0.3, -1.0))
			item("ammo_9x19mm", c + Vector3(1.0, 0.3, -1.0))
			if room.zone == "HCZ":
				item("armor_combat", c + Vector3(1.0, 0.3, 1.0))
				item("grenade_he", c + Vector3(-1.0, 0.3, 1.0))
			else:
				item("armor_light", c + Vector3(1.0, 0.3, 1.0))
		"scp999":
			_build_scp999(c, wv, h)
		"scp055":
			_build_scp055(c, wv, h)
		"scp096", "scp049":
			var back := "N" if not "N" in door_dirs else "S"
			var n: Vector2i = DIRS[back]
			var nv := Vector3(n.x, 0, n.y)
			var cell_c := c + nv * 3.0
			box(cell_c + Vector3(0, 0.05, 0), Vector3(6.0, 0.1, 4.6) if nv.z != 0 else Vector3(4.6, 0.1, 6.0), "metal_dark")
			var perp := Vector3(absf(nv.z), 0, absf(nv.x))
			for sgn: float in [-1.0, 1.0]:
				var wall_size := Vector3(0.3, 4.0, 4.6) if perp.x > 0.5 else Vector3(4.6, 4.0, 0.3)
				box(cell_c + perp * 3.1 * sgn + Vector3(0, 2.0, 0), wall_size, "wall_hcz")
			box(c + nv * 0.6 + Vector3(0, 0.01, 0), Vector3(6.4, 0.02, 0.3) if absf(nv.z) > 0.5 else Vector3(0.3, 0.02, 6.4), "hazard", false)
			label(info.scp, c + nv * (C / 2 - T - 0.02) + Vector3(0, 4.2, 0), yaw_towards(Vector3.ZERO, nv), 120)
			spawn("SCP", cell_c + Vector3(0, 0.2, 0), yaw_towards(cell_c, c))
			terminal(c - nv * 2.0 + perp * 4.5, -perp)
		"generator":
			for k in [Vector3(-3.4, 0, -3.4), Vector3(3.4, 0, -3.4), Vector3(-3.4, 0, 3.4)]:
				box(c + k + Vector3(0, 1.3, 0), Vector3(2.4, 2.6, 1.8), "metal_dark")
				box(c + k + Vector3(0, 3.6, 0), Vector3(0.4, 2.0, 0.4), "metal")
			var hazard: Node3D = load("res://scenes/props/hazard_wiring.tscn").instantiate()
			hazard.position = c + Vector3(3.6, 0, 3.8)
			hazard.rotation.y = PI
			add(groups["Props"], hazard, uname("ExposedWiring"))
		"pump":
			_build_pump_room(c, wv, h, door_dirs)
		"archive":
			for x: float in [-4.0, -1.6, 1.6, 4.0]:
				box(c + Vector3(x, 1.25, -2.6), Vector3(0.7, 2.5, 4.2), "metal_dark")
				box(c + Vector3(x, 1.0, -2.6), Vector3(0.75, 0.3, 4.0), "cloth", false)
			terminal(spot2 + side2 * 1.5, -w2v)
			spawn("Specialist", c + Vector3(0, 0.1, 2.0), PI)
		"testing":
			for s: Vector3 in [Vector3(0, 0.01, -2.5), Vector3(0, 0.01, 2.5)]:
				box(c + s, Vector3(5.3, 0.02, 0.3), "hazard", false)
			for s: Vector3 in [Vector3(-2.5, 0.01, 0), Vector3(2.5, 0.01, 0)]:
				box(c + s, Vector3(0.3, 0.02, 5.3), "hazard", false)
			box(c + Vector3(-4.2, 0.45, -4.2), Vector3(1.6, 0.9, 1.0), "metal")
			crate(c + Vector3(4.0, 0, -4.0), 1.0)
			label("TESTING AREA", c + Vector3(0, 0.03, 0), 0.0, 60).rotation = Vector3(-PI / 2, 0, 0)
			spawn("Specialist", c + Vector3(3.5, 0.1, 3.5), rng.randf() * TAU)
		"lift":
			_furnish_lift(c, info, door_dirs, h, room.zone)
		"gate":
			var dv: Vector2i = DIRS[door_dirs[0]]
			var tw := Vector3(dv.x, 0, dv.y)
			var side := Vector3(absf(tw.z), 0, absf(tw.x))
			# Sandbag staging line between the lift and the door.
			for s: float in [-1.0, 1.0]:
				box(c + tw * 1.5 + side * s * 3.6 + Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 0.7) if side.x > 0.5 else Vector3(0.7, 0.9, 2.6), "cloth")
			box(c + tw * 3.2 - side * 4.6 + Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 3.0) if side.x > 0.5 else Vector3(3.0, 0.5, 0.6), "metal")
			terminal(c + tw * 4.6 + side * 4.5, -side)
		"security":
			for k in corners:
				box(c + k * Vector3(0.9, 0, 0.95) + Vector3(0, 0.4, 0), Vector3(2.2, 0.8, 1.0), "metal")
				box(c + k * Vector3(0.9, 0, 0.95) + Vector3(0, 1.05, 0), Vector3(1.8, 0.5, 0.2), "metal_dark")
			for k in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
				spawn("Guard", c + k + Vector3(0, 0.1, 0), rng.randf() * TAU)
			locker(wall_spot, -wv, "armory", 2, 1)
			terminal(spot2 + side2 * 2.0, -w2v)
		"manager":
			box(c + Vector3(0, 0.4, -3.6), Vector3(3.6, 0.8, 1.2), "wood")
			box(c + Vector3(-3.6, 0.35, 3.0), Vector3(2.6, 0.7, 1.0), "cloth")
			box(c + Vector3(4.6, 1.0, -3.6), Vector3(0.7, 2.0, 1.4), "metal")
			item("keycard_facility_manager", c + Vector3(0, 1.0, -3.6))
			terminal(c + Vector3(-1.2, 0, -2.6), Vector3(0, 0, 1))
			locker(spot2 + side2 * 2.0, -w2v, "medical", 3, 1)
		"intercom":
			var side := Vector3(absf(wv.z), 0, absf(wv.x))
			box(wall_spot - wv * 0.3 + Vector3(0, 0.45, 0), Vector3(3.6, 0.9, 1.0) if side.x > 0.5 else Vector3(1.0, 0.9, 3.6), "metal")
			for s: float in [-1.0, 1.0]:
				box(wall_spot + wv * 0.2 + side * s * 2.6 + Vector3(0, 2.6, 0), Vector3(0.8, 1.0, 0.5) if side.x > 0.5 else Vector3(0.5, 1.0, 0.8), "metal_dark")
			var ic := Intercom.new()
			place(ic, "Intercom", wall_spot - wv * 0.9 + Vector3(0, 0.9, 0), -wv)
			label("INTERCOM", wall_spot + wv * 0.4 + Vector3(0, 3.4, 0), yaw_facing(-wv), 60)
			terminal(spot2 + side2 * 2.0, -w2v)
			box(c + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), "metal_dark")


func _furnish_lift(c: Vector3, info: Dictionary, door_dirs: Array, h: float, zone: String) -> void:
	var dv: Vector2i = DIRS[door_dirs[0]]
	var towards_door := Vector3(dv.x, 0, dv.y)
	var side := Vector3(absf(towards_door.z), 0, absf(towards_door.x))
	var booth := c + towards_door * 3.6 + side * 3.6
	box(booth + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.6), "metal")
	box(booth + Vector3(0, 1.6, 0), Vector3(1.6, 1.2, 1.6), "glass")
	box(c + towards_door * 3.6 - side * 3.8 + Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 2.4) if side.z > 0.5 else Vector3(2.4, 0.5, 0.6), "metal")
	box(c - towards_door * 0.6 + Vector3(0, 0.01, 0), Vector3(0.3, 0.02, 5.6) if side.z > 0.5 else Vector3(5.6, 0.02, 0.3), "hazard", false)
	var lift_dir := "HEAVY CONTAINMENT" if zone == "LCZ" else "LIGHT CONTAINMENT"
	label("%s\nLIFT TO %s" % [info.name, lift_dir], c + Vector3(0, h - 0.7, 0) + side * (C / 2 - T - 0.02), yaw_towards(Vector3.ZERO, side), 40)
	terminal(c + towards_door * 1.2 - side * 4.6, side)


func _furnish_big(room: Dictionary, info: Dictionary, inner: Rect2, h: float, z: Dictionary, door_dirs: Array) -> void:
	match room.type:
		"class_d_block":
			_build_class_d_block(inner, h, z)
		"scp914":
			_build_scp914(inner, h, z)
		"server":
			_build_server_room(inner, h)
		"scp173":
			_build_scp173(inner, h)
		"pit":
			_build_pit(inner, h, z)
		"cafeteria":
			_build_cafeteria(inner, h, z, room, door_dirs)
		"silo":
			_build_silo(inner, h, z)


func _build_class_d_block(inner: Rect2, h: float, z: Dictionary) -> void:
	var w: String = z.wall
	var ix0 := inner.position.x
	var iz0 := inner.position.y
	var iz1 := inner.end.y
	var zc := (iz0 + iz1) / 2.0
	const CELL := 3.6
	const PITCH := 4.0
	const CELL_DOOR := 0.7
	const CELL_DOOR_H := 2.4
	var count := int((inner.size.x - 3.2) / PITCH)
	var row_end := ix0 + count * PITCH
	var number := 1
	for side: int in [-1, 1]:
		var zf := iz0 + CELL + T / 2 if side < 0 else iz1 - CELL - T / 2
		var back := iz0 if side < 0 else iz1
		var cursor := ix0
		for k in count:
			var xs := ix0 + k * PITCH
			var xc := xs + CELL / 2
			box_mm(xs + CELL, 0, minf(back, zf), xs + PITCH, h, maxf(back, zf), w)
			box_mm(cursor, 0, zf - T / 2, xc - CELL_DOOR, h, zf + T / 2, w)
			box_mm(xc - CELL_DOOR, CELL_DOOR_H, zf - T / 2, xc + CELL_DOOR, h, zf + T / 2, w)
			cursor = xc + CELL_DOOR
			var d: Node3D = _cell_door_scene.instantiate()
			d.position = Vector3(xc, 0, zf)
			add(groups["Doors"], d, "CellDoor%02d" % number)
			d.add_to_group("class_d_cell_doors")
			var inward := float(side)
			var cz := zf + inward * (T / 2 + CELL / 2)
			box(Vector3(xs + 0.55, 0.3, cz + inward * 0.2), Vector3(0.9, 0.6, 2.0), "metal_dark")
			box(Vector3(xs + 0.55, 0.66, cz + inward * 0.2), Vector3(0.8, 0.12, 1.9), "cloth")
			box(Vector3(xs + CELL - 0.45, 0.25, cz + inward * 1.35), Vector3(0.5, 0.5, 0.6), "cloth")
			box(Vector3(xs + CELL - 0.3, 0.85, cz - inward * 0.2), Vector3(0.45, 0.15, 0.5), "metal")
			label("D-%02d" % number, Vector3(xc, 2.85, zf - inward * (T / 2 + 0.02)), 0.0 if side < 0 else PI, 34)
			lamp(Vector3(xc, h, cz), 1.1, 5.0, 0.15, false)
			spawn("ClassD", Vector3(xc, 0.1, cz + inward * 0.3), 0.0 if side > 0 else PI)
			number += 1
		box_mm(cursor, 0, zf - T / 2, row_end, h, zf + T / 2, w)
	label("CLASS-D CONTAINMENT", Vector3(ix0 + 0.02, 3.2, zc), PI / 2, 44)
	box(Vector3((ix0 + row_end) / 2, 0.01, zc - 1.2), Vector3(row_end - ix0, 0.02, 0.15), "hazard", false)
	box(Vector3((ix0 + row_end) / 2, 0.01, zc + 1.2), Vector3(row_end - ix0, 0.02, 0.15), "hazard", false)
	var x := ix0 + 4.0
	while x < inner.end.x:
		lamp(Vector3(x, h, zc), z.light, 7.0, z.flicker)
		x += 8.0
	# The menu camera looks down the hall from the entrance.
	showcase = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(inner.end.x - 1.0, floor_y + 1.7, zc))


## SCP-914: the working clockwork machine (scripts/props/scp_914.gd) against
## the back wall, plus shelves, an observation desk and hazard markings.
func _build_scp914(inner: Rect2, h: float, _z: Dictionary) -> void:
	var xm := inner.get_center().x
	var zs := inner.end.y  # back (south) wall
	var machine := Scp914.new()
	machine.position = Vector3(xm, 0, zs)
	add(groups["Props"], machine, "SCP914")
	for side: float in [-1.0, 1.0]:
		box(Vector3(xm + side * 4.8, 0.015, zs - 3.9), Vector3(2.0, 0.02, 1.0), "hazard_stripes", false)
	box(Vector3(xm, 0.015, zs - 4.9), Vector3(2.4, 0.02, 0.15), "hazard", false)
	box(Vector3(inner.end.x - 0.45, 1.1, inner.position.y + 1.8), Vector3(0.8, 2.2, 2.8), "metal_dark")
	box(Vector3(inner.position.x + 1.6, 0.4, inner.position.y + 1.1), Vector3(3.0, 0.8, 1.0), "metal")
	terminal(Vector3(inner.position.x + 3.8, 0, inner.position.y + 0.5), Vector3(0, 0, 1))
	for x: float in [-6.0, 0.0, 6.0]:
		lamp(Vector3(xm + x, h, inner.get_center().y), 2.1, 11.0, 0.0)


## The Tertiary Server Room: control room behind a glass wall, dark server
## clusters with frosted glass heat shafts and blue neon floor lights.
func _build_server_room(inner: Rect2, h: float) -> void:
	var gx := inner.position.x + 8.6
	var zc := inner.get_center().y
	var iz0 := inner.position.y
	var iz1 := inner.end.y
	box(Vector3(gx, h / 2, (iz0 + zc - 0.9) / 2), Vector3(0.08, h, zc - 0.9 - iz0), "glass")
	box(Vector3(gx, h / 2, (zc + 0.9 + iz1) / 2), Vector3(0.08, h, iz1 - zc - 0.9), "glass")
	box(Vector3(gx, 2.55, zc), Vector3(0.12, 0.1, 1.8), "metal_dark")
	box_mm(gx - 0.04, 2.6, zc - 0.9, gx + 0.04, h, zc + 0.9, "glass")
	for zz: float in [iz0 + 0.05, zc - 0.9, zc + 0.9, iz1 - 0.05]:
		box(Vector3(gx, h / 2, zz), Vector3(0.1, h, 0.1), "metal_dark")
	for zz: float in [zc - 3.0, zc + 3.0]:
		box(Vector3(gx - 1.4, 0.4, zz), Vector3(1.0, 0.8, 3.2), "metal")
		for k: float in [-1.0, 0.0, 1.0]:
			box(Vector3(gx - 1.1, 1.05, zz + k), Vector3(0.12, 0.45, 0.65), "metal_dark")
		box(Vector3(gx - 2.4, 0.25, zz), Vector3(0.5, 0.5, 0.5), "metal_dark")
	label("TERTIARY SERVER ROOM", Vector3(gx - 0.06, 3.3, zc), -PI / 2, 40)
	terminal(Vector3(inner.position.x + 0.5, 0, zc + 4.2), Vector3(1, 0, 0), "personnel")
	for zz: float in [zc - 3.0, zc + 3.0]:
		lamp(Vector3(inner.position.x + 4.3, h, zz), 2.2, 9.0, 0.0)
	for k in [Vector3(inner.position.x + 3.0, 0.1, zc - 1.0), Vector3(inner.position.x + 3.0, 0.1, zc + 1.0)]:
		spawn("Scientist", k, -PI / 2)
	var sx0 := gx + 2.8
	var sx1 := inner.end.x - 2.6
	for cx: float in [sx0 + 1.3, sx1 - 1.3]:
		for cz: float in [zc - 2.8, zc + 2.8]:
			box(Vector3(cx, 1.15, cz), Vector3(2.6, 2.3, 1.5), "metal_dark")
			box(Vector3(cx, 3.05, cz), Vector3(2.6, 1.5, 1.5), "glass_frosted")
			box(Vector3(cx, 3.85, cz), Vector3(2.7, 0.08, 1.6), "metal_dark", false)
			for s: float in [-0.8, 0.8]:
				box(Vector3(cx, 0.03, cz + s), Vector3(2.6, 0.04, 0.06), "neon_blue", false)
				for row in 5:
					box(Vector3(cx, 0.5 + row * 0.35, cz + s * 0.76), Vector3(2.1, 0.025, 0.02), "screen_blue", false)
			lamp(Vector3(cx, 0.45, cz + (1.6 if cz > zc else -1.6)), 1.0, 4.5, 0.0, false, Color(0.3, 0.6, 1.0), false)
	for zz: float in [iz0 + 0.3, iz1 - 0.3]:
		box(Vector3((gx + inner.end.x) / 2, h - 0.5, zz), Vector3(inner.end.x - gx - 0.2, 0.08, 0.4), "neon_blue", false)
	for x: float in [sx0 + 1.3, sx1 - 1.3]:
		lamp(Vector3(x, h, zc), 0.6, 8.0, 0.2)


## SCP-173's chamber: striped entrance, white antechamber, containment door
## with a viewing window into the chamber.
func _build_scp173(inner: Rect2, h: float) -> void:
	var px := inner.position.x + 9.6
	var zc := inner.get_center().y
	var iz0 := inner.position.y
	var iz1 := inner.end.y
	var w := "wall_white"
	box_mm(px - T / 2, 0, iz0, px + T / 2, h, zc - DOOR_W, w)
	box_mm(px - T / 2, DOOR_H, zc - DOOR_W, px + T / 2, h, zc + DOOR_W, w)
	box_mm(px - T / 2, 0, zc + DOOR_W, px + T / 2, h, zc + 2.6, w)
	box_mm(px - T / 2, 0, zc + 2.6, px + T / 2, 1.2, iz1 - 0.6, w)
	box_mm(px - T / 2, 2.3, zc + 2.6, px + T / 2, h, iz1 - 0.6, w)
	box_mm(px - T / 2, 0, iz1 - 0.6, px + T / 2, h, iz1, w)
	box_mm(px - 0.04, 1.2, zc + 2.6, px + 0.04, 2.3, iz1 - 0.6, "glass")
	var d := door(Vector3(px, 0, zc), PI / 2, 1, 3, "SCP-173", "EUCLID")
	d.name = "Door_SCP173"
	box(Vector3(px - 1.0, 0.4, zc + 3.6), Vector3(1.0, 0.8, 2.4), "metal")
	box(Vector3(px - 1.2, 1.05, zc + 3.6), Vector3(0.12, 0.45, 0.8), "metal_dark")
	box(Vector3(inner.position.x + 0.6, 0.5, iz1 - 0.7), Vector3(0.8, 1.0, 0.8), "metal")
	terminal(Vector3(inner.position.x + 3.5, 0, iz0 + 0.5), Vector3(0, 0, 1))
	lamp(Vector3((inner.position.x + px) / 2, h, zc), 1.9, 10.0, 0.1)
	var cx := (px + inner.end.x) / 2
	box(Vector3(cx, 3.3, iz0 + 0.04), Vector3(6.0, 0.7, 0.06), "glass")
	box(Vector3(inner.end.x - 0.12, 3.0, zc), Vector3(0.2, 1.4, 1.4), "metal_dark")
	box(Vector3(inner.end.x - 0.24, 3.0, zc), Vector3(0.04, 1.2, 0.18), "metal", false)
	box(Vector3(inner.end.x - 0.24, 3.0, zc), Vector3(0.04, 0.18, 1.2), "metal", false)
	box(Vector3(cx, 0.012, zc + 0.5), Vector3(2.2, 0.02, 1.6), "metal_dark", false)
	label("SCP-173", Vector3(inner.end.x - 0.02, 2.0, zc - 3.0), -PI / 2, 90).modulate = Color(0.1, 0.1, 0.1)
	lamp(Vector3(cx - 3.0, h, zc), 2.0, 10.0, 0.0)
	lamp(Vector3(cx + 3.0, h, zc), 2.0, 10.0, 0.3)
	spawn("SCP", Vector3(cx + 2.0, 0.2, zc), PI / 2)


## SCP-999 pen: a low glass fence with a gap, a soft floor and the friendly
## orange blob wandering inside (it slowly heals people nearby).
func _build_scp999(c: Vector3, wv: Vector3, h: float) -> void:
	var pen := Rect2(c.x - 3.5, c.z - 3.5, 7.0, 7.0)
	pen.position += Vector2(wv.x, wv.z) * 1.2
	var pc := Vector3(pen.get_center().x, 0, pen.get_center().y)
	box(pc + Vector3(0, 0.02, 0), Vector3(pen.size.x, 0.04, pen.size.y), "cloth", false)
	var gap_side := -wv  # the gate faces the room's free middle
	for d in DIRS:
		var dv := Vector3(DIRS[d].x, 0, DIRS[d].y)
		var mid := pc + dv * 3.5
		var along := Vector3(absf(dv.z), 0, absf(dv.x))
		if dv.is_equal_approx(gap_side):
			for s: float in [-1.0, 1.0]:
				var a := mid + along * s * 1.0
				var b := mid + along * s * 3.5
				box((a + b) / 2 + Vector3(0, 0.6, 0), along * 2.5 + Vector3(0, 1.2, 0) + dv.abs() * 0.06, "glass")
		else:
			box(mid + Vector3(0, 0.6, 0), along * 7.0 + Vector3(0, 1.2, 0) + dv.abs() * 0.06, "glass")
	box(pc + Vector3(1.5, 0.2, 1.5), Vector3(0.8, 0.4, 0.8), "cloth")  # cushion
	var blob := Scp999.new()
	blob.pen = Rect2(pen.position + Vector2(0.8, 0.8), pen.size - Vector2(1.6, 1.6))
	blob.position = pc
	add(groups["Props"], blob, "SCP999")
	label("SCP-999\nSAFE", c - wv * 5.3 + Vector3(0, 2.6, 0), yaw_facing(wv), 40)
	terminal(c - wv * 4.8 + Vector3(wv.z, 0, wv.x) * 3.0, wv, "scp999")
	lamp(Vector3(pc.x, h, pc.z), 1.4, 9.0, 0.0, true, Color(1.0, 0.85, 0.6))


## SCP-055: a plain sealed crate in a glass display. Nobody quite remembers
## what is inside.
func _build_scp055(c: Vector3, wv: Vector3, h: float) -> void:
	var p := c + wv * 1.5
	box(p + Vector3(0, 0.4, 0), Vector3(2.6, 0.8, 2.6), "metal_dark")
	box(p + Vector3(0, 1.3, 0), Vector3(1.2, 1.0, 1.2), "wood")
	for d in DIRS:
		var dv := Vector3(DIRS[d].x, 0, DIRS[d].y)
		box(p + dv * 1.25 + Vector3(0, 1.8, 0), Vector3(absf(dv.z), 0, absf(dv.x)) * 2.5 + Vector3(0, 2.0, 0) + dv.abs() * 0.05, "glass")
	box(p + Vector3(0, 2.82, 0), Vector3(2.6, 0.06, 2.6), "metal_dark")
	label("SCP-055", p - wv * 1.35 + Vector3(0, 0.55, 0), yaw_facing(-wv), 40).modulate = Color(0.85, 0.85, 0.8)
	box(c - wv * 3.0 + Vector3(0, 0.01, 0), Vector3(4.0, 0.02, 0.2) if wv.x == 0 else Vector3(0.2, 0.02, 4.0), "hazard", false)
	terminal(c - wv * 4.6 + Vector3(wv.z, 0, wv.x) * 2.0, wv, "scp055")
	lamp(Vector3(p.x, h, p.z), 1.6, 7.0, 0.0)


## A pump station: tanks, pipes and floor vents that burst out scalding
## steam every few seconds.
func _build_pump_room(c: Vector3, wv: Vector3, h: float, door_dirs: Array) -> void:
	var side := Vector3(absf(wv.z), 0, absf(wv.x))
	for s: float in [-3.0, 3.0]:
		var tank := c + wv * 3.6 + side * s
		box(tank + Vector3(0, 1.6, 0), Vector3(2.4, 3.2, 2.4), "metal_dark")
		box(tank + Vector3(0, 3.3, 0), Vector3(1.6, 0.2, 1.6), "metal")
		box(tank + Vector3(0, (3.4 + h) / 2, 0), Vector3(0.4, h - 3.4, 0.4), "metal")
	box(c + Vector3(0, h - 0.6, 0) + wv * 1.0, side * 11.0 + Vector3(0, 0.4, 0.0) + wv.abs() * 0.4, "metal")
	box(c + Vector3(0, h - 1.1, 0) - wv * 0.5, side * 11.0 + Vector3(0, 0.3, 0.0) + wv.abs() * 0.3, "metal_dark")
	# A raised grated walkway with a ramp, over the vents.
	var walk := c - wv * 3.4
	box(walk + Vector3(0, 0.55, 0) + side * 1.5, side * 6.0 + Vector3(0, 0.1, 0) + wv.abs() * 2.0, "metal")
	ramp(walk - side * 3.5, walk - side * 1.5 + Vector3(0, 0.6, 0), 2.0)
	for s: float in [-1.0, 1.0]:
		railing(walk + side * -1.5 + wv * s * 1.0 + Vector3(0, 0.6, 0), walk + side * 4.5 + wv * s * 1.0 + Vector3(0, 0.6, 0))
	for k in [c + side * 1.8, c - side * 2.4 + wv * 0.8]:
		var vent := SteamVent.new()
		vent.phase = rng.randf() * 6.0
		vent.position = k
		add(groups["Props"], vent, uname("SteamVent"))
		box(k + Vector3(0, 0.02, 0), Vector3(1.4, 0.04, 1.4), "metal_dark", false)
	label("CAUTION: STEAM", c - wv * 5.5 + side * 3.0 + Vector3(0, 2.4, 0), yaw_facing(wv), 30)
	if door_dirs.size() > 0:
		lamp(Vector3(c.x, h, c.z) + side * 3.0, 1.4, 9.0, 0.5)


## The HCZ Containment Pit (2x2): a walkway around a deep pit with a ramp
## down to a containment unit at the bottom.
func _build_pit(inner: Rect2, h: float, z: Dictionary) -> void:
	var pit := inner.grow(-3.2)
	var depth := 4.5
	var w: String = z.wall
	box_mm(pit.position.x, -depth - 0.3, pit.position.y, pit.end.x, -depth, pit.end.y, z.floor)
	box_mm(pit.position.x - T, -depth, pit.position.y - T, pit.end.x + T, 0, pit.position.y, w)
	box_mm(pit.position.x - T, -depth, pit.end.y, pit.end.x + T, 0, pit.end.y + T, w)
	box_mm(pit.position.x - T, -depth, pit.position.y, pit.position.x, 0, pit.end.y, w)
	box_mm(pit.end.x, -depth, pit.position.y, pit.end.x + T, 0, pit.end.y, w)
	# Ramp along the north wall, from the east edge down to the bottom.
	var rz := pit.position.y + 1.3
	ramp(Vector3(pit.end.x - 11.0, -depth, rz), Vector3(pit.end.x, 0.0, rz), 2.4, "metal")
	ramp(Vector3(pit.end.x - 11.0, -depth + 1.0, rz + 1.25), Vector3(pit.end.x - 0.2, 1.0, rz + 1.25), 0.06)
	# Railings around the pit, leaving the ramp top open.
	railing(Vector3(pit.position.x, 0, pit.position.y), Vector3(pit.end.x, 0, pit.position.y))
	railing(Vector3(pit.position.x, 0, pit.end.y), Vector3(pit.end.x, 0, pit.end.y))
	railing(Vector3(pit.position.x, 0, pit.position.y), Vector3(pit.position.x, 0, pit.end.y))
	railing(Vector3(pit.end.x, 0, pit.position.y + 2.6), Vector3(pit.end.x, 0, pit.end.y))
	var pc := Vector3(pit.get_center().x, -depth, pit.get_center().y)
	box(pc + Vector3(0, 1.6, 2.0), Vector3(5.0, 3.2, 3.0), "metal_dark")
	box(pc + Vector3(0, 0.01, -0.6), Vector3(5.4, 0.02, 0.3), "hazard", false)
	label("CONTAINMENT UNIT", pc + Vector3(0, 2.6, 0.48), 0.0, 50)
	spawn("SCP", pc + Vector3(0, 0.2, -1.5), 0.0)
	spawn("Specialist", Vector3(inner.position.x + 1.5, 0.1, inner.end.y - 1.5), PI)
	terminal(Vector3(inner.position.x + 0.5, 0, inner.position.y + 4.5), Vector3(1, 0, 0), "personnel")
	for x: float in [-5.0, 5.0]:
		for zz: float in [-5.0, 5.0]:
			lamp(Vector3(pit.get_center().x + x, h, pit.get_center().y + zz), z.light, 13.0, z.flicker)
	lamp(pc + Vector3(0, 4.0, -3.0), 2.4, 11.0, 0.3, true, Color(1.0, 0.9, 0.75), false)
	var cr := inner.position + Vector2(1.2, 1.2)
	crate(Vector3(cr.x, 0, cr.y), 1.0)


## The Alpha Warhead silo (2x2): a deep shaft with the missile inside
## (scripts/props/alpha_warhead_silo.gd), railings, a control console and a
## status screen.
func _build_silo(inner: Rect2, h: float, z: Dictionary) -> void:
	var shaft := inner.grow(-(inner.size.x - SILO_SHAFT) / 2.0)
	var depth := 14.0
	var w: String = z.wall
	box_mm(shaft.position.x, -depth - 0.3, shaft.position.y, shaft.end.x, -depth, shaft.end.y, z.floor)
	box_mm(shaft.position.x - T, -depth, shaft.position.y - T, shaft.end.x + T, 0, shaft.position.y, w)
	box_mm(shaft.position.x - T, -depth, shaft.end.y, shaft.end.x + T, 0, shaft.end.y + T, w)
	box_mm(shaft.position.x - T, -depth, shaft.position.y, shaft.position.x, 0, shaft.end.y, w)
	box_mm(shaft.end.x, -depth, shaft.position.y, shaft.end.x + T, 0, shaft.end.y, w)
	# Hazard border and railings around the shaft.
	for side in [[shaft.position.x, shaft.position.y, shaft.end.x, shaft.position.y], [shaft.position.x, shaft.end.y, shaft.end.x, shaft.end.y],
			[shaft.position.x, shaft.position.y, shaft.position.x, shaft.end.y], [shaft.end.x, shaft.position.y, shaft.end.x, shaft.end.y]]:
		var a := Vector3(side[0], 0, side[1])
		var b := Vector3(side[2], 0, side[3])
		railing(a, b, 1.1)
		var mid := (a + b) / 2
		var along_x := absf(b.x - a.x) > 1.0
		box(mid + Vector3(0, 0.012, 0) + (mid - Vector3(shaft.get_center().x, 0, shaft.get_center().y)).normalized() * 0.5,
			Vector3(SILO_SHAFT + 1.0, 0.02, 0.6) if along_x else Vector3(0.6, 0.02, SILO_SHAFT + 1.0), "hazard_stripes", false)
	var silo := AlphaWarheadSilo.new()
	silo.position = Vector3(shaft.get_center().x, 0, shaft.get_center().y)
	silo.shaft_depth = depth
	add(groups["Props"], silo, "AlphaWarheadSilo")
	# The arming console on the north side, facing the shaft.
	var console: Node3D = load("res://scenes/props/warhead_console.tscn").instantiate()
	console.position = Vector3(shaft.get_center().x, 0, shaft.position.y - 1.6)
	console.rotation.y = 0.0
	console.warhead = WarheadConsole.Warhead.ALPHA
	add(groups["Props"], console, "AlphaConsole")
	label("ALPHA WARHEAD", Vector3(shaft.get_center().x, h - 1.0, inner.position.y + 0.02), 0.0, 140)
	for x: float in [-8.0, 8.0]:
		for zz: float in [-8.0, 8.0]:
			lamp(Vector3(shaft.get_center().x + x, h, shaft.get_center().y + zz), z.light * 1.7, 18.0, z.flicker)
	terminal(Vector3(inner.position.x + 0.5, 0, inner.end.y - 4.0), Vector3(1, 0, 0), "personnel")


## The cafeteria (2x1): tables, a serving counter and vending machines, with
## a balcony along the back wall reached by a ramp.
func _build_cafeteria(inner: Rect2, h: float, z: Dictionary, room: Dictionary, door_dirs: Array) -> void:
	var back_north := not "N" in door_dirs
	var bz := inner.position.y + 1.6 if back_north else inner.end.y - 1.6
	var inward := 1.0 if back_north else -1.0
	var bal_y := 3.2
	# Balcony.
	box_mm(inner.position.x, bal_y - 0.25, minf(bz - 1.6, bz + 1.6), inner.end.x, bal_y, maxf(bz - 1.6, bz + 1.6), "metal")
	var edge := bz + inward * 1.6
	if "W" in door_dirs:
		railing(Vector3(inner.position.x, bal_y, edge), Vector3(inner.end.x - 3.0, bal_y, edge))
	else:
		railing(Vector3(inner.position.x + 3.0, bal_y, edge), Vector3(inner.end.x, bal_y, edge))
	var ramp_x := inner.end.x - 1.5 if "W" in door_dirs else inner.position.x + 1.5
	ramp(Vector3(ramp_x, 0.0, edge + inward * 8.2), Vector3(ramp_x, bal_y, edge), 2.4)
	for x in [inner.position.x + 5.0, inner.end.x - 5.0]:
		box(Vector3(x, bal_y / 2, edge - inward * 0.2), Vector3(0.3, bal_y, 0.3), "metal_dark")
	for x in range(int(inner.position.x) + 5, int(inner.end.x) - 2, 4):
		box(Vector3(x, bal_y + 0.4, bz - inward * 0.6), Vector3(1.6, 0.8, 0.8), "wood")
	# Tables on the floor.
	var mid_z := (inner.position.y + inner.end.y) / 2 + inward * 0.4
	for x in range(int(inner.position.x) + 6, int(inner.end.x) - 3, 5):
		for dz: float in [-1.8, 1.8]:
			box(Vector3(x, 0.4, mid_z + dz), Vector3(2.4, 0.8, 1.2), "wood")
			box(Vector3(x, 0.22, mid_z + dz + 1.0), Vector3(2.4, 0.44, 0.4), "wood")
			box(Vector3(x, 0.22, mid_z + dz - 1.0), Vector3(2.4, 0.44, 0.4), "wood")
	var counter_z := inner.end.y - 0.8 if back_north else inner.position.y + 0.8
	box(Vector3(inner.get_center().x, 0.55, counter_z), Vector3(8.0, 1.1, 0.8), "metal")
	for k in 3:
		var vx := inner.end.x - 1.0 - k * 1.4
		box(Vector3(vx, 1.0, counter_z), Vector3(1.2, 2.0, 0.9), "metal_dark")
	terminal(Vector3(inner.position.x + 0.5, 0, mid_z), Vector3(1, 0, 0), "status")
	for x in [inner.position.x + 6.0, inner.get_center().x, inner.end.x - 6.0]:
		lamp(Vector3(x, h, mid_z), z.light * 1.2, 12.0, z.flicker)
		lamp(Vector3(x, h, bz), z.light * 0.8, 8.0, z.flicker, false)
	loot_spots.get_or_add(room.zone, []).append(Vector3(inner.get_center().x, 0, mid_z))
	for k in [Vector3(-3, 0, 0), Vector3(3, 0, 0)]:
		spawn("Guard", Vector3(inner.get_center().x, 0.1, mid_z) + k, rng.randf() * TAU)


# --- lifts ------------------------------------------------------------------

## A lift: shaft, cabin (walls, handrails, light, control panel), two-piece
## sliding doors with frames, CALL buttons and indicators at both stops.
func _build_lift(lift_name: String, lb: MeshBatch) -> void:
	var spec: Dictionary = lifts[lift_name]
	var lt := lift_transform(lift_name)
	var height := -LOWER_Y
	var lift := Elevator.new()
	lift.position = lt.center + Vector3(0, LOWER_Y, 0)
	lift.rotation.y = lt.yaw
	lift.lift_name = lift_name
	lift.bottom_name = spec.bottom
	lift.top_name = spec.top
	lift.travel_height = height
	var xf := Transform3D(Basis(Vector3.UP, lt.yaw), lift.position)
	var sbox := func(pos: Vector3, size: Vector3, mat: String, collide := true) -> void:
		lb.add_box(xf * Transform3D(Basis(), pos), size, mats[mat], collide)

	var top := height + 3.4
	var bottom := -0.6
	var tall := top - bottom
	var mid := (top + bottom) / 2
	var sw := "wall_lift"
	sbox.call(Vector3(0, mid, -1.95), Vector3(4.2, tall, 0.3), sw)
	sbox.call(Vector3(-1.95, mid, 0), Vector3(0.3, tall, 3.6), sw)
	sbox.call(Vector3(1.95, mid, 0), Vector3(0.3, tall, 3.6), sw)
	sbox.call(Vector3(-1.8, mid, 1.95), Vector3(1.8, tall, 0.3), sw)
	sbox.call(Vector3(1.8, mid, 1.95), Vector3(1.8, tall, 0.3), sw)
	sbox.call(Vector3(0, (2.4 + height) / 2, 1.95), Vector3(1.8, height - 2.4, 0.3), sw)
	sbox.call(Vector3(0, (height + 2.4 + top) / 2, 1.95), Vector3(1.8, top - height - 2.4, 0.3), sw)
	sbox.call(Vector3(0, -0.45, 0), Vector3(3.6, 0.3, 3.6), "metal_dark")
	sbox.call(Vector3(0, top + 0.15, 0), Vector3(4.2, 0.3, 4.2), sw)

	for stop in [["Bottom", 0.0], ["Top", height]]:
		var y: float = stop[1]
		for face: float in [1.0, -1.0]:
			var fz := 1.95 + face * 0.17
			sbox.call(Vector3(-1.0, y + 1.25, fz), Vector3(0.18, 2.5, 0.06), "metal_dark")
			sbox.call(Vector3(1.0, y + 1.25, fz), Vector3(0.18, 2.5, 0.06), "metal_dark")
			sbox.call(Vector3(0, y + 2.52, fz), Vector3(2.2, 0.18, 0.06), "metal_dark")
		sbox.call(Vector3(0, y + 0.01, 2.2), Vector3(1.8, 0.02, 0.3), "hazard_stripes", false)
		sbox.call(Vector3(0, y + 2.95, 2.12), Vector3(1.5, 0.42, 0.02), "metal_dark", false)
		var ind := Label3D.new()
		ind.position = Vector3(0, y + 2.95, 2.13)
		ind.font_size = 36
		ind.pixel_size = 0.0032
		ind.outline_size = 0
		ind.modulate = Color(0.95, 0.9, 0.75)
		add(lift, ind, stop[0] + "Indicator")
		var call := ElevatorButton.new()
		call.action = 1 if stop[0] == "Bottom" else 2
		call.elevator_path = NodePath("..")
		call.position = Vector3(1.45, y + 1.2, 2.14)
		add(lift, call, stop[0] + "Call")
		_shape(call, Vector3(0.28, 0.42, 0.08))
		node_box(call, "Plate", Vector3.ZERO, Vector3(0.24, 0.38, 0.04), "metal")
		node_box(call, "Button", Vector3(0, -0.03, 0.025), Vector3(0.09, 0.09, 0.03), "screen_blue")
		var cl := Label3D.new()
		cl.text = "CALL"
		cl.font_size = 24
		cl.pixel_size = 0.003
		cl.outline_size = 0
		cl.position = Vector3(0, 0.11, 0.025)
		cl.modulate = Color(0.1, 0.1, 0.1)
		add(call, cl, "Label")
		for side in [["L", -0.45], ["R", 0.45]]:
			var panel := AnimatableBody3D.new()
			panel.position = Vector3(side[1], y + 1.2, 1.95)
			add(lift, panel, "%sDoor%s" % [stop[0], side[0]])
			_shape(panel, Vector3(0.9, 2.4, 0.08))
			node_box(panel, "Mesh", Vector3.ZERO, Vector3(0.9, 2.4, 0.08), "lift_cabin")
			node_box(panel, "Seam", Vector3(-side[1] * 0.98, 0, 0), Vector3(0.02, 2.4, 0.09), "metal_dark")
			node_box(panel, "Window", Vector3(0, 0.55, 0), Vector3(0.12, 0.6, 0.09), "metal_dark")

	var car := AnimatableBody3D.new()
	add(lift, car, "Car")
	for part in [["Floor", Vector3(0, -0.075, 0), Vector3(3.5, 0.15, 3.5), "metal_dark"],
			["WallBack", Vector3(0, 1.35, -1.71), Vector3(3.5, 2.7, 0.08), "lift_cabin"],
			["WallL", Vector3(-1.71, 1.35, 0), Vector3(0.08, 2.7, 3.5), "lift_cabin"],
			["WallR", Vector3(1.71, 1.35, 0), Vector3(0.08, 2.7, 3.5), "lift_cabin"],
			["FrontPostL", Vector3(-1.32, 1.35, 1.71), Vector3(0.86, 2.7, 0.08), "lift_cabin"],
			["FrontPostR", Vector3(1.32, 1.35, 1.71), Vector3(0.86, 2.7, 0.08), "lift_cabin"],
			["FrontHeader", Vector3(0, 2.55, 1.71), Vector3(1.8, 0.3, 0.08), "lift_cabin"],
			["Ceiling", Vector3(0, 2.74, 0), Vector3(3.5, 0.08, 3.5), "metal_dark"]]:
		_shape(car, part[2], part[1])
		node_box(car, part[0], part[1], part[2], part[3])
	node_box(car, "LightPanel", Vector3(0, 2.69, 0), Vector3(1.6, 0.03, 0.8), "lamp")
	node_box(car, "RailBack", Vector3(0, 0.95, -1.6), Vector3(3.0, 0.05, 0.06), "metal")
	node_box(car, "RailL", Vector3(-1.6, 0.95, -0.2), Vector3(0.06, 0.05, 2.6), "metal")
	node_box(car, "RailR", Vector3(1.6, 0.95, -0.2), Vector3(0.06, 0.05, 2.6), "metal")
	node_box(car, "Kickplate", Vector3(0, 0.12, -1.66), Vector3(3.4, 0.24, 0.02), "metal")
	node_box(car, "FloorStripe", Vector3(0, 0.005, 1.55), Vector3(3.4, 0.01, 0.15), "hazard_stripes")
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.45, 0)
	light.omni_range = 5.0
	light.light_energy = 1.4
	light.light_color = Color(1, 0.96, 0.88)
	add(car, light, "Light")
	light.add_to_group("facility_lights")
	var panel_body := ElevatorButton.new()
	panel_body.action = 0
	panel_body.elevator_path = NodePath("../..")
	panel_body.position = Vector3(1.63, 1.25, 1.05)
	add(car, panel_body, "Panel")
	_shape(panel_body, Vector3(0.1, 0.6, 0.36))
	node_box(panel_body, "Plate", Vector3.ZERO, Vector3(0.04, 0.56, 0.32), "metal")
	node_box(panel_body, "Screen", Vector3(-0.025, 0.17, 0), Vector3(0.01, 0.12, 0.24), "metal_dark")
	node_box(panel_body, "ButtonUp", Vector3(-0.03, 0.0, 0), Vector3(0.03, 0.08, 0.08), "screen_blue")
	node_box(panel_body, "ButtonDown", Vector3(-0.03, -0.14, 0), Vector3(0.03, 0.08, 0.08), "screen_blue")
	var display := Label3D.new()
	display.position = Vector3(-0.035, 0.17, 0)
	display.rotation.y = -PI / 2
	display.font_size = 28
	display.pixel_size = 0.0028
	display.outline_size = 0
	display.modulate = Color(0.6, 0.9, 1.0)
	add(panel_body, display, "Display")
	add(level.get_node("Lifts"), lift, lift_name.replace(" ", ""))
	if spec.surface:
		surface_holes[spec.cell] = lt.rect


func _shape(body: CollisionObject3D, size: Vector3, pos := Vector3.ZERO) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)


# --- surface ----------------------------------------------------------------

func _surface_gate_building(lift_name: String) -> void:
	var spec: Dictionary = lifts[lift_name]
	var c := center(spec.cell)
	var e := C / 2 - 1.0
	var h := 7.0
	var open_side := "S" if spec.facing.y > 0 else "N"
	for d in ["N", "S", "E", "W"]:
		var n: Vector2i = DIRS[d]
		var pos := Vector3(c.x + n.x * e, 0, c.z + n.y * e)
		if d == open_side:
			box_mm(c.x - e, 0, pos.z - T / 2, c.x - 2.8, h, pos.z + T / 2, "wall_surface")
			box_mm(c.x + 2.8, 0, pos.z - T / 2, c.x + e, h, pos.z + T / 2, "wall_surface")
			box_mm(c.x - 2.8, 4.0, pos.z - T / 2, c.x + 2.8, h, pos.z + T / 2, "wall_surface")
			label(lift_name, Vector3(c.x, 5.0, pos.z + n.y * (T / 2 + 0.02)), 0.0 if n.y > 0 else PI, 110)
		elif n.x == 0:
			box_mm(c.x - e, 0, pos.z - T / 2, c.x + e, h, pos.z + T / 2, "wall_surface")
		else:
			box_mm(pos.x - T / 2, 0, c.z - e, pos.x + T / 2, h, c.z + e, "wall_surface")
	box_mm(c.x - e - T / 2, h, c.z - e - T / 2, c.x + e + T / 2, h + 0.4, c.z + e + T / 2, "wall_surface")
	lamp(Vector3(c.x, h, c.z + (2.5 if open_side == "S" else -2.5)), 1.8, 11.0, 0.0)


func _build_surface() -> void:
	surface_mode = true
	floor_y = 0.0
	batch = MeshBatch.new()
	var s: Node3D = add(level, Node3D.new(), "Surface")
	groups = {}
	for g in ["Doors", "Lights", "Props", "Items", "Signs"]:
		groups[g] = add(s, Node3D.new(), g)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.75, 0.9)
	moon.light_energy = 1.0
	moon.shadow_enabled = true
	moon.light_cull_mask = 8
	moon.directional_shadow_max_distance = 140.0
	moon.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	add(s, moon, "Moonlight")
	SurfaceBuilder.new(self).build(s)
	var geometry: Node3D = add(s, Node3D.new(), "Geometry")
	batch.build(geometry, 1 | 8)
	surface_mode = false


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp


func _helipad(c: Vector3, target: Vector3) -> void:
	box(c + Vector3(0, 0.03, 0), Vector3(10.0, 0.06, 10.0), "metal_dark", false)
	label("H", c + Vector3(0, 0.08, 0), 0.0, 900).rotation = Vector3(-PI / 2, 0, 0)
	for k in [Vector3(-2, 0, -2), Vector3(2, 0, -2), Vector3(-2, 0, 2), Vector3(2, 0, 2)]:
		spawn("MTF", c + k + Vector3(0, 0.2, 0), yaw_towards(c, target))
	for s: float in [-1.0, 1.0]:
		box(c + Vector3(s * 5.6, 0.45, 0), Vector3(0.7, 0.9, 4.0), "cloth")


func _chaos_staging(c: Vector3, target: Vector3) -> void:
	_truck(c + Vector3(-3.5, 0, -2.0), 0.0)
	_truck(c + Vector3(3.5, 0, -2.5), 0.1)
	for k in [Vector3(-1, 0, 2), Vector3(1, 0, 2), Vector3(-1, 0, 4), Vector3(1, 0, 4)]:
		spawn("Chaos", c + k + Vector3(0, 0.2, 0), yaw_towards(c, target))
	crate(c + Vector3(0, 0, -4.5), 1.0)


func _truck(c: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	box(c + b * Vector3(0, 1.6, 1.0), Vector3(2.6, 2.4, 5.0), "metal_dark", true, b)
	box(c + b * Vector3(0, 1.2, -2.6), Vector3(2.4, 1.8, 2.0), "metal_dark", true, b)
	box(c + b * Vector3(0, 1.6, -3.62), Vector3(2.0, 0.7, 0.04), "glass", false, b)
	for z: float in [-2.6, 0.0, 2.4]:
		for x: float in [-1.25, 1.25]:
			box(c + b * Vector3(x, 0.45, z), Vector3(0.4, 0.9, 0.9), "metal", true, b)


func _jeep(c: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	box(c + b * Vector3(0, 0.9, 0), Vector3(2.0, 0.8, 4.0), "metal_dark", true, b)
	box(c + b * Vector3(0, 1.45, -0.4), Vector3(1.9, 0.06, 0.04), "glass", false, b)
	box(c + b * Vector3(0, 1.6, 1.2), Vector3(1.9, 0.08, 1.6), "cloth", false, b)
	for z: float in [-1.3, 1.3]:
		for x: float in [-1.0, 1.0]:
			box(c + b * Vector3(x, 0.4, z), Vector3(0.35, 0.8, 0.8), "metal", true, b)


func _apc(c: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	box(c + b * Vector3(0, 1.4, 0), Vector3(2.8, 1.8, 6.4), "metal_dark", true, b)
	box(c + b * Vector3(0, 2.6, -0.5), Vector3(1.4, 0.6, 1.6), "metal_dark", true, b)
	box(c + b * Vector3(0, 2.7, -1.9), Vector3(0.15, 0.15, 1.6), "metal", false, b)
	for z: float in [-2.2, -0.7, 0.8, 2.3]:
		for x: float in [-1.35, 1.35]:
			box(c + b * Vector3(x, 0.5, z), Vector3(0.4, 1.0, 1.0), "metal", true, b)


## A watchtower: platform on legs with railings, a roof, a spotlight and a
## ramp up. `west`/`north` say which yard corner it stands in.
func _watchtower(c: Vector3, west: bool, north: bool) -> void:
	var sx := -1.0 if west else 1.0
	var sz := -1.0 if north else 1.0
	var p := c + Vector3(sx * 2.5, 0, sz * 2.5)
	var ph := 3.6
	box(p + Vector3(0, ph - 0.1, 0), Vector3(5.0, 0.2, 5.0), "metal")
	for x: float in [-2.3, 2.3]:
		for z: float in [-2.3, 2.3]:
			box(p + Vector3(x, ph / 2, z), Vector3(0.25, ph, 0.25), "metal_dark")
			box(p + Vector3(x, ph + 1.4, z), Vector3(0.12, 2.8, 0.12), "metal_dark")
	box(p + Vector3(0, ph + 2.85, 0), Vector3(5.4, 0.15, 5.4), "metal_dark")
	# Ramp comes down towards the middle of the yard (opposite the corner).
	var top := p + Vector3(-sx * 2.5, ph, -sz * 1.2)
	var low := top + Vector3(-sx * 7.0, -ph, 0)
	ramp(low, top, 2.2)
	var hy := ph
	railing(p + Vector3(-2.5, hy, sz * 2.5), p + Vector3(2.5, hy, sz * 2.5))
	railing(p + Vector3(sx * 2.5, hy, -2.5), p + Vector3(sx * 2.5, hy, 2.5))
	railing(p + Vector3(-2.5, hy, -sz * 2.5), p + Vector3(2.5, hy, -sz * 2.5))
	railing(p + Vector3(-sx * 2.5, hy, sz * 2.5), p + Vector3(-sx * 2.5, hy, -sz * 0.0))
	var g: Node3D = add(groups["Lights"], Node3D.new(), uname("TowerLight"))
	g.position = p + Vector3(0, ph + 2.6, 0)
	var spot := SpotLight3D.new()
	spot.spot_range = 30.0
	spot.spot_angle = 30.0
	spot.light_energy = 6.0
	spot.shadow_enabled = true
	spot.rotation = Vector3(deg_to_rad(-35), atan2(sx, sz) + PI, 0)
	add(g, spot, "Light")
	spot.add_to_group("facility_lights")
	spawn("MTF", p + Vector3(0, ph + 0.2, 0), atan2(sx, sz) + PI)


## Temporary fortifications: a ring of sandbags with crates and an ammo box.
func _staging_area(c: Vector3) -> void:
	for a in 8:
		var ang := a * TAU / 8.0
		if a == 2:
			continue  # a gap to walk through
		var p := c + Vector3(cos(ang), 0, sin(ang)) * 4.2
		box(p + Vector3(0, 0.5, 0), Vector3(2.8, 1.0, 0.8), "cloth", true, Basis(Vector3.UP, -ang + PI / 2))
	crate(c + Vector3(-1.0, 0, -1.0), 1.0)
	crate(c + Vector3(1.2, 0, 0.6), 0.8)
	item("ammo_9x19mm" if rng.randf() < 0.6 else "first_aid_kit", c + Vector3(0, 0.5, 1.6))


func _vehicle_park(c: Vector3) -> void:
	match rng.randi() % 3:
		0:
			_jeep(c + Vector3(-2.5, 0, 0), 0.2)
			_jeep(c + Vector3(2.5, 0, 0.5), -0.1)
		1:
			_apc(c, rng.randf_range(-0.4, 0.4))
		_:
			_truck(c + Vector3(0, 0, 1.0), PI / 2 + rng.randf_range(-0.2, 0.2))


## Concrete barriers scattered as cover.
func _barriers(c: Vector3) -> void:
	for i in rng.randi_range(2, 4):
		var p := c + Vector3(rng.randf_range(-4.0, 4.0), 0, rng.randf_range(-4.0, 4.0))
		var b := Basis(Vector3.UP, rng.randf() * PI)
		box(p + Vector3(0, 0.25, 0), Vector3(2.6, 0.5, 0.8), "wall_surface", true, b)
		box(p + Vector3(0, 0.75, 0), Vector3(2.6, 0.5, 0.4), "wall_surface", true, b)


func _warhead_building(wc: Vector3) -> void:
	var e := C / 2 - 1.0
	var h := 6.0
	box_mm(wc.x - e, 0, wc.z + e - T / 2, wc.x + e, h, wc.z + e + T / 2, "wall_surface")
	box_mm(wc.x + e - T / 2, 0, wc.z - e, wc.x + e + T / 2, h, wc.z + e, "wall_surface")
	box_mm(wc.x - e - T / 2, 0, wc.z - e, wc.x - e + T / 2, h, wc.z + e, "wall_surface")
	box_mm(wc.x - e, 0, wc.z - e - T / 2, wc.x - 1.6, h, wc.z - e + T / 2, "wall_surface")
	box_mm(wc.x + 1.6, 0, wc.z - e - T / 2, wc.x + e, h, wc.z - e + T / 2, "wall_surface")
	box_mm(wc.x - 1.6, 3.0, wc.z - e - T / 2, wc.x + 1.6, h, wc.z - e + T / 2, "wall_surface")
	box_mm(wc.x - e - T / 2, h, wc.z - e - T / 2, wc.x + e + T / 2, h + 0.4, wc.z + e + T / 2, "wall_surface")
	label("WARHEAD CONTROL", Vector3(wc.x, 4.2, wc.z - e - T / 2 - 0.02), PI, 70)
	var con: Node3D = load("res://scenes/props/warhead_console.tscn").instantiate()
	con.position = Vector3(wc.x, 0, wc.z + 2.0)
	con.rotation.y = PI
	con.warhead = WarheadConsole.Warhead.DELTA
	add(groups["Props"], con, "DeltaConsole")
	terminal(Vector3(wc.x - e + 0.6, 0, wc.z - 2.0), Vector3(1, 0, 0), "personnel")
	lamp(Vector3(wc.x, h, wc.z), 1.6, 11.0, 0.0)


## The Gamma Warhead: a fusion reactor (scripts/props/gamma_reactor.gd) with
## its console at the edge of the platform.
func _gamma_reactor(c: Vector3) -> void:
	var reactor := GammaReactor.new()
	reactor.position = c
	add(groups["Props"], reactor, "GammaReactor")
	var con: Node3D = load("res://scenes/props/warhead_console.tscn").instantiate()
	con.position = c + Vector3(0, 0, -5.2)
	con.rotation.y = PI
	con.warhead = WarheadConsole.Warhead.GAMMA
	add(groups["Props"], con, "GammaConsole")


func _floodlights(x0: float, x1: float, z0: float, z1: float) -> void:
	var points := []
	var x := x0 + 1.5
	while x <= x1:
		points.append(Vector3(x, 0, z0 + 1.5))
		points.append(Vector3(x, 0, z1 - 1.5))
		x += 28.0
	var z := z0 + 26.0
	while z < z1 - 10.0:
		points.append(Vector3(x0 + 1.5, 0, z))
		points.append(Vector3(x1 - 1.5, 0, z))
		z += 28.0
	for p: Vector3 in points:
		box(p + Vector3(0, 4.5, 0), Vector3(0.3, 9.0, 0.3), "metal_dark")
		var g: Node3D = add(groups["Lights"], Node3D.new(), uname("Floodlight"))
		g.position = p + Vector3(0, 9.0, 0)
		var spot := SpotLight3D.new()
		spot.spot_range = 40.0
		spot.spot_angle = 70.0
		spot.spot_angle_attenuation = 0.8
		spot.light_energy = 5.0
		spot.light_color = Color(0.9, 0.93, 1.0)
		spot.shadow_enabled = points.find(p) % 3 == 0
		var to_mid := Vector3((x0 + x1) / 2, 0, (z0 + z1) / 2) - p
		spot.rotation = Vector3(deg_to_rad(-60), atan2(-to_mid.x, -to_mid.z), 0)
		spot.distance_fade_enabled = true
		spot.distance_fade_begin = 90.0
		add(g, spot, "Light")
		spot.add_to_group("facility_lights")
		box(p + Vector3(0, 9.0, 0), Vector3(1.0, 0.3, 0.6), "lamp", false)
