class_name SurfaceBuilder
extends RefCounted
## Builds the Surface: the walled compound above the Entrance Zone.
##
## Layout (north is -Z):
##   - EXIT checkpoint in the north wall, the escape road beyond it, the MTF
##     helipad with a helicopter.
##   - A deep ravine across the whole site with a road bridge and a
##     footbridge (and ramps to climb out of it).
##   - The gate yard: Gate A/B/C buildings (where the lifts come up) around
##     an inner yard with shipping containers and sandbags for cover.
##   - East: a vehicle hangar with a mezzanine, the two-storey security HQ
##     with roof access, Warhead Control and a container yard.
##   - South: the Gamma reactor compound and the Chaos Insurgency's breach in
##     the south wall, with their trucks.
## Everything uses the FacilityGenerator's helpers (static boxes go into its
## MeshBatch).

const X0 := 102.0
const X1 := 258.0
const Z0 := -102.0
const Z1 := 114.0
const WALL_H := 7.0
const TRENCH := Vector2(-42.0, -30.0)
const TRENCH_DEPTH := 7.0

var g: FacilityGenerator
var rng: RandomNumberGenerator
var road_x := 156.0
var gate_cells := {}
## Areas (Rect2 in x/z) that must stay free of random clutter.
var _keep_clear: Array[Rect2] = []


func _init(generator: FacilityGenerator) -> void:
	g = generator
	rng = generator.rng


func build(surface: Node3D) -> void:
	for lift_name in g.lifts:
		if g.lifts[lift_name].surface:
			var cell: Vector2i = g.lifts[lift_name].cell
			gate_cells[cell] = lift_name
			var c := g.center(cell)
			_keep_clear.append(Rect2(c.x - 7, c.z - 14, 14, 28))
	_pick_road()
	_ground()
	_perimeter()
	_trench()
	_roads()
	for lift_name in gate_cells.values():
		g._surface_gate_building(lift_name)
	_exit_checkpoint(surface)
	_helipad(Vector3(232, 0, -68))
	_hangar(Rect2(206, -26, 30, 30))
	_hq(Rect2(206, 20, 24, 22))
	g._warhead_building(Vector3(246, 0, 31))
	_container_yard(Rect2(202, 50, 52, 16), 6)
	_inner_yard()
	_reactor_compound(Vector3(156, 0, 92))
	_chaos_breach(Vector3(238, 0, 100))
	_fuel_depot(Vector3(108, 0, 34))
	g._watchtower(Vector3(110, 0, -94), true, true)
	g._watchtower(Vector3(250, 0, -94), false, true)
	g._watchtower(Vector3(110, 0, 106), true, false)
	_surface_area(surface)
	_lights()


## The main road runs north-south through a column without gate buildings.
func _pick_road() -> void:
	var options := []
	for col in [13, 12, 14, 11, 15]:
		if not gate_cells.has(Vector2i(col, 0)) and not gate_cells.has(Vector2i(col, 5)):
			options.append(col)
	road_x = (options[0] if not options.is_empty() else 13) * FacilityGenerator.C
	_keep_clear.append(Rect2(road_x - 6, Z0, 12, Z1 - Z0))


# --- Ground, walls, ravine --------------------------------------------------------

func _ground() -> void:
	var c := FacilityGenerator.C
	for col in range(9, 22):
		for row in range(-8, 10):
			var cell := Vector2i(col, row)
			var cc := g.center(cell)
			if row == -3:
				continue  # the ravine
			g.slab(cc.x - c / 2, cc.z - c / 2, cc.x + c / 2, cc.z + c / 2, -0.5, 0, "ground_surface", g.surface_holes.get(cell, Rect2()))
	# The escape road outside the north wall.
	g.slab(road_x - 6, Z0 - 14, road_x + 6, Z0, -0.5, 0, "asphalt")


func _perimeter() -> void:
	var h := WALL_H
	var gap_l := road_x - 6.0
	var gap_r := road_x + 6.0
	g.box_mm(X0, -0.5, Z0 - 1, X0 + 1, h, Z1 + 1, "wall_surface")
	g.box_mm(X1 - 1, -0.5, Z0 - 1, X1, h, Z1 + 1, "wall_surface")
	g.box_mm(X0, -0.5, Z0 - 1, gap_l, h, Z0, "wall_surface")
	g.box_mm(gap_r, -0.5, Z0 - 1, X1, h, Z0, "wall_surface")
	# South wall with the Chaos breach (a blown-out gap with rubble).
	g.box_mm(X0, -0.5, Z1, 230, h, Z1 + 1, "wall_surface")
	g.box_mm(246, -0.5, Z1, X1, h, Z1 + 1, "wall_surface")
	for i in 7:
		var p := Vector3(rng.randf_range(229, 247), 0, Z1 + rng.randf_range(-3, 2))
		g.box(p + Vector3(0, 0.4, 0), Vector3(rng.randf_range(0.8, 2.2), rng.randf_range(0.5, 1.4), rng.randf_range(0.8, 2.0)), "wall_surface", true,
			Basis(Vector3.UP, rng.randf() * PI) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
	# Fence on top of the walls: posts and wires.
	for side in [[X0 + 0.5, Z0, X0 + 0.5, Z1], [X1 - 0.5, Z0, X1 - 0.5, Z1]]:
		_fence_line(Vector3(side[0], h, side[1]), Vector3(side[2], h, side[3]), 2.0)
	_fence_line(Vector3(X0, h, Z0 - 0.5), Vector3(gap_l, h, Z0 - 0.5), 2.0)
	_fence_line(Vector3(gap_r, h, Z0 - 0.5), Vector3(X1, h, Z0 - 0.5), 2.0)
	# Walls along the escape road, and the far gate.
	g.box_mm(gap_l - 1, -0.5, Z0 - 14, gap_l, h, Z0, "wall_surface")
	g.box_mm(gap_r, -0.5, Z0 - 14, gap_r + 1, h, Z0, "wall_surface")
	g.box_mm(gap_l, -0.5, Z0 - 15, gap_r, h + 1, Z0 - 14, "metal_dark")
	g.label("EXIT", Vector3(road_x, 6.0, Z0 - 13.9), 0.0, 200)
	g.label("SITE EXIT - ESCAPE ROUTE", Vector3(road_x, 4.6, Z0 - 13.9), 0.0, 60)


func _fence_line(a: Vector3, b: Vector3, height: float) -> void:
	var length := a.distance_to(b)
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var mid := (a + b) / 2
	var posts := int(length / 4.0)
	for i in posts + 1:
		var p := a.lerp(b, float(i) / maxf(posts, 1))
		g.box(p + Vector3(0, height / 2, 0), Vector3(0.1, height, 0.1), "metal_dark", false)
	g.box(mid + Vector3(0, height / 2, 0), Vector3(length, height * 0.9, 0.02) if along_x else Vector3(0.02, height * 0.9, length), "fence", false)
	for y: float in [height * 0.33, height * 0.66, height]:
		g.box(mid + Vector3(0, y, 0), Vector3(length, 0.03, 0.03) if along_x else Vector3(0.03, 0.03, length), "metal", false)


## A ravine across the whole site: bridge, footbridge, ramps out.
func _trench() -> void:
	var d := TRENCH_DEPTH
	var z0 := TRENCH.x
	var z1 := TRENCH.y
	g.box_mm(X0, -d - 0.5, z0, X1, -d, z1, "dirt")
	g.box_mm(X0, -d, z0 - 0.4, X1, 0, z0, "wall_surface")
	g.box_mm(X0, -d, z1, X1, 0, z1 + 0.4, "wall_surface")
	# Rocks and junk at the bottom.
	for i in 16:
		var p := Vector3(rng.randf_range(X0 + 4, X1 - 4), -d, rng.randf_range(z0 + 1.5, z1 - 1.5))
		if absf(p.x - road_x) < 6.0:
			continue
		g.box(p + Vector3(0, 0.5, 0), Vector3(rng.randf_range(1, 2.5), rng.randf_range(0.6, 1.4), rng.randf_range(1, 2.2)), "dirt", true, Basis(Vector3.UP, rng.randf() * PI))
	# Road bridge with railings and pillars.
	g.box_mm(road_x - 4.5, -0.5, z0 - 2, road_x + 4.5, 0.05, z1 + 2, "asphalt")
	g.box_mm(road_x - 4.5, -1.3, z0 - 2, road_x + 4.5, -0.5, z1 + 2, "metal_dark")
	for s: float in [-1.0, 1.0]:
		g.railing(Vector3(road_x + s * 4.4, 0.05, z0 - 2), Vector3(road_x + s * 4.4, 0.05, z1 + 2), 1.1)
		for z: float in [z0 + 2.0, z1 - 2.0]:
			g.box(Vector3(road_x + s * 3.0, -d / 2 - 0.6, z), Vector3(1.0, d, 1.0), "wall_surface")
	g.label("BRIDGE  -  WEIGHT LIMIT 30 T", Vector3(road_x, 2.4, z1 + 2.2), PI, 30)
	# Narrow footbridge to the east.
	g.box_mm(229.5, -0.3, z0 - 1, 232.5, 0.05, z1 + 1, "metal")
	g.railing(Vector3(229.6, 0.05, z0 - 1), Vector3(229.6, 0.05, z1 + 1), 1.0)
	g.railing(Vector3(232.4, 0.05, z0 - 1), Vector3(232.4, 0.05, z1 + 1), 1.0)
	# Ramps out of the ravine (one up to each side).
	g.ramp(Vector3(107, -d, z1 - 0.6), Vector3(107, 0, z0 + 0.1), 3.0, "wall_surface")
	g.ramp(Vector3(253, -d, z0 + 0.6), Vector3(253, 0, z1 - 0.1), 3.0, "wall_surface")
	g.lamp(Vector3(road_x, -1.6, (z0 + z1) / 2), 1.2, 12.0, 0.3, false, Color(1.0, 0.8, 0.6), false)


# --- Roads ------------------------------------------------------------------------

func _roads() -> void:
	# North-south main road from the exit to the reactor compound.
	_road(Vector3(road_x, 0, Z0), Vector3(road_x, 0, TRENCH.x - 2))
	_road(Vector3(road_x, 0, TRENCH.y + 2), Vector3(road_x, 0, 76))
	# East-west road between the gates and the ravine, to the hangar.
	_road(Vector3(X0 + 2, 0, -12), Vector3(206, 0, -12))
	# South road from the yard to the Chaos breach.
	_road(Vector3(road_x, 0, 76), Vector3(238, 0, 76))
	_road(Vector3(238, 0, 76), Vector3(238, 0, Z1))


func _road(a: Vector3, b: Vector3) -> void:
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var length := a.distance_to(b)
	var mid := (a + b) / 2
	g.box(mid + Vector3(0, 0.01, 0), Vector3(length + 8, 0.02, 8) if along_x else Vector3(8, 0.02, length + 8), "asphalt", false)
	var n := int(length / 6.0)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		g.box(p + Vector3(0, 0.025, 0), Vector3(2.4, 0.02, 0.18) if along_x else Vector3(0.18, 0.02, 2.4), "road_paint", false)


# --- Exit, helipad -------------------------------------------------------------

func _exit_checkpoint(surface: Node3D) -> void:
	var z := Z0
	# Guard booth with windows and a boom barrier across the road.
	var bx := road_x + 8.0
	g.box_mm(bx - 2, 0, z + 6, bx + 2, 1.0, z + 10, "wall_surface")
	g.box_mm(bx - 2, 1.0, z + 6, bx + 2, 2.4, z + 10, "glass")
	g.box_mm(bx - 2.2, 2.4, z + 5.8, bx + 2.2, 2.7, z + 10.2, "metal_dark")
	g.box(Vector3(road_x - 4.8, 0.6, z + 8), Vector3(0.5, 1.2, 0.5), "metal_dark")
	var bar := 9.0
	g.box(Vector3(road_x - 4.8 + bar / 2, 1.05, z + 8), Vector3(bar, 0.12, 0.12), "hazard_stripes", false)
	for x: float in [-3.0, 0.0, 3.0]:
		g.box(Vector3(road_x + x, 0.03, z + 3.0), Vector3(0.3, 0.02, 5.0), "road_paint", false)
	g.lamp(Vector3(bx, 2.6, z + 8), 1.5, 8.0, 0.0, false)
	# The escape zone is the road outside.
	var zone := EscapeZone.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector3(road_x, 0, z - 7.5)
	g.add(surface, zone, "EscapeZone")
	g._shape(zone, Vector3(11.0, 4.0, 11.0), Vector3(0, 2.0, 0))
	g.label("ESCAPE", Vector3(road_x, 0.04, z - 5.0), 0.0, 160).rotation = Vector3(-PI / 2, 0, 0)
	# Concrete barriers in a chicane before the checkpoint.
	for p in [Vector3(road_x - 2.5, 0, z + 18), Vector3(road_x + 2.5, 0, z + 24)]:
		g.box(p + Vector3(0, 0.45, 0), Vector3(4.0, 0.9, 0.6), "wall_surface")
	_keep_clear.append(Rect2(road_x - 10, z, 22, 30))


func _helipad(c: Vector3) -> void:
	var target := Vector3(road_x, 0, 0)
	g._helipad(c, target)
	_helicopter(c + Vector3(0, 0, -1.0), 0.6)
	_keep_clear.append(Rect2(c.x - 8, c.z - 8, 16, 16))


## A parked transport helicopter.
func _helicopter(c: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var body := Basis(Vector3.RIGHT, PI / 2)
	g.box(c + b * Vector3(0, 1.9, 0), Vector3(2.4, 2.0, 5.6), "metal_dark", true, b)
	g.box(c + b * Vector3(0, 1.6, -3.3), Vector3(2.0, 1.4, 1.2), "metal_dark", true, b)
	g.box(c + b * Vector3(0, 2.0, -3.6), Vector3(1.8, 0.9, 0.8), "glass", false, b * Basis(Vector3.RIGHT, 0.4))
	g.box(c + b * Vector3(0, 2.4, 6.0), Vector3(0.6, 0.6, 7.0), "metal_dark", true, b)
	g.box(c + b * Vector3(0, 3.3, 9.2), Vector3(0.15, 1.8, 1.2), "metal_dark", false, b)
	g.box(c + b * Vector3(0.3, 3.0, 9.4), Vector3(0.05, 1.6, 0.18), "metal", false, b)
	for s: float in [-1.0, 1.0]:
		g.box(c + b * Vector3(s * 1.1, 0.15, 0), Vector3(0.12, 0.12, 5.0), "metal", true, b)
		for z: float in [-1.5, 1.5]:
			g.box(c + b * Vector3(s * 1.1, 0.5, z), Vector3(0.08, 0.7, 0.08), "metal", false, b)
	g.box(c + b * Vector3(0, 3.05, 0), Vector3(0.5, 0.3, 0.5), "metal", false, b)
	for i in 4:
		var a := yaw + i * PI / 2 + 0.3
		g.box(c + Vector3(0, 3.2, 0) + Vector3(sin(a), 0, cos(a)) * 3.6, Vector3(0.35, 0.05, 7.2), "metal_dark", false, Basis(Vector3.UP, a))
	g.box(c + b * Vector3(-1.21, 1.9, 0.6), Vector3(0.02, 1.5, 1.6), "glass", false, b)
	g.label("MTF", c + b * Vector3(1.22, 2.0, 1.0), yaw + PI / 2, 120)


# --- East: hangar, HQ, containers -------------------------------------------------

## A vehicle hangar with a big door to the west, a mezzanine and vehicles.
func _hangar(r: Rect2) -> void:
	var h := 11.0
	var door := [r.get_center().y, 12.0, 8.0]
	_walls(r, h, {"W": [door], "E": [], "N": [[r.position.x + 6, 2.2, 2.6]], "S": []}, "wall_surface")
	g.box_mm(r.position.x - 0.4, h, r.position.y - 0.4, r.end.x + 0.4, h + 0.5, r.end.y + 0.4, "metal_dark")
	g.box_mm(r.position.x, 0, r.position.y, r.end.x, 0.05, r.end.y, "concrete_floor")
	# Roof trusses.
	for z in range(int(r.position.y) + 3, int(r.end.y), 6):
		g.box(Vector3(r.get_center().x, h - 0.6, z), Vector3(r.size.x, 0.4, 0.3), "metal", false)
	# Mezzanine along the east wall with a ramp and railing.
	var mx := r.end.x - 3.0
	g.box_mm(r.end.x - 6.0, 3.8, r.position.y + 0.4, r.end.x - 0.4, 4.1, r.end.y - 0.4, "metal")
	g.railing(Vector3(r.end.x - 6.0, 4.1, r.position.y + 9.0), Vector3(r.end.x - 6.0, 4.1, r.end.y - 0.4))
	g.ramp(Vector3(r.end.x - 8.5, 0, r.position.y + 1.6), Vector3(r.end.x - 8.5 + 0.01, 4.1, r.position.y + 9.0), 2.4)
	for z in range(int(r.position.y) + 4, int(r.end.y), 7):
		g.box(Vector3(r.end.x - 6.0, 1.9, z), Vector3(0.3, 3.8, 0.3), "metal_dark")
	g.crate(Vector3(mx, 4.1, r.get_center().y), 1.2)
	g.locker(Vector3(r.end.x - 0.8, 4.1, r.position.y + 14), Vector3(-1, 0, 0), "military")
	# Vehicles and clutter.
	g._apc(Vector3(r.position.x + 9, 0, r.position.y + 9), 0.1)
	g._truck(Vector3(r.position.x + 9, 0, r.end.y - 9), PI + 0.05)
	g._jeep(Vector3(r.get_center().x + 4, 0, r.get_center().y + 1), 1.4)
	for i in 3:
		g.crate(Vector3(r.position.x + 2 + i * 1.4, 0, r.end.y - 1.2), 1.0)
	g.label("HANGAR 2", Vector3(r.position.x - 0.42, 9.2, r.get_center().y), -PI / 2, 140)
	for z: float in [r.position.y + 7, r.end.y - 7]:
		for x: float in [r.position.x + 8, r.end.x - 9]:
			g.lamp(Vector3(x, h, z), 2.2, 16.0, 0.1)
	g.box(Vector3(r.get_center().x, 0.02, r.get_center().y), Vector3(0.3, 0.02, r.size.y - 4), "road_paint", false)


## Two-storey security HQ: ground floor, upper floor with windows and a roof
## you can stand on, connected by ramps.
func _hq(r: Rect2) -> void:
	var h := 8.0
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var windows := []
	for i in range(8, int(r.size.x) - 2, 4):
		windows.append([x0 + i, 1.6, 5.2, 6.6])
	_walls(r, h, {"W": [[(z0 + z1) / 2, 2.4, 2.8], [z0 + 4, 2.2, 5.2, 6.6], [z1 - 4, 2.2, 5.2, 6.6]],
		"N": [[x0 + 4, 2.2, 2.6]] + windows, "S": windows.duplicate(), "E": []}, "wall_ez")
	# Upper floor (with a hole for the ramp) and roof (hole for the second ramp).
	g.box_mm(x0, 3.8, z0, x1 - 4.0, 4.1, z1, "floor_ez")
	g.box_mm(x1 - 4.0, 3.8, z0 + 12.0, x1, 4.1, z1, "floor_ez")
	g.ramp(Vector3(x1 - 2.0, 0, z0 + 1.8), Vector3(x1 - 2.0 + 0.01, 4.1, z0 + 11.8), 3.2)
	g.box_mm(x0 + 4.0, h, z0, x1, h + 0.3, z1, "metal_dark")
	g.box_mm(x0, h, z0, x0 + 4.0, h + 0.3, z0 + 10.0, "metal_dark")
	g.ramp(Vector3(x0 + 2.0, 4.1, z1 - 1.8), Vector3(x0 + 2.0 + 0.01, h + 0.3, z0 + 10.2), 3.2)
	# Roof edge railings.
	g.railing(Vector3(x0, h + 0.3, z0), Vector3(x1, h + 0.3, z0), 1.1)
	g.railing(Vector3(x0, h + 0.3, z1), Vector3(x1, h + 0.3, z1), 1.1)
	g.railing(Vector3(x1, h + 0.3, z0), Vector3(x1, h + 0.3, z1), 1.1)
	g.railing(Vector3(x0, h + 0.3, z0), Vector3(x0, h + 0.3, z1), 1.1)
	# Furniture: desks, monitors, lockers, a terminal on each floor.
	for i in 3:
		g.box(Vector3(x0 + 5 + i * 4, 0.4, z1 - 2.5), Vector3(2.4, 0.8, 1.0), "metal")
		g.box(Vector3(x0 + 5 + i * 4, 1.05, z1 - 2.8), Vector3(1.6, 0.5, 0.15), "metal_dark")
		g.spawn("MTF", Vector3(x0 + 5 + i * 4, 0.1, z1 - 4.5), 0.0)
	g.terminal(Vector3(x0 + 1.0, 0, z0 + 8), Vector3(1, 0, 0), "personnel")
	g.terminal(Vector3(x0 + 9.0, 4.1, z1 - 1.0), Vector3(0, 0, -1), "status")
	g.locker(Vector3(x0 + 13, 4.1, z0 + 1.0), Vector3(0, 0, 1), "armory")
	g.locker(Vector3(x0 + 14, 4.1, z0 + 1.0), Vector3(0, 0, 1), "military")
	g.crate(Vector3(x1 - 6, h + 0.3, z0 + 5), 1.0)
	g.label("SECURITY HQ", Vector3(x0 - 0.42, 6.8, (z0 + z1) / 2), -PI / 2, 110)
	for p in [Vector3(x0 + 6, 3.8, z0 + 6), Vector3(x0 + 6, 3.8, z1 - 6), Vector3(x1 - 8, 3.8, z1 - 6)]:
		g.lamp(p, 1.8, 10.0, 0.1)
	for p in [Vector3(x0 + 6, h, z0 + 6), Vector3(x0 + 10, h, z1 - 6), Vector3(x1 - 8, h, z1 - 6)]:
		g.lamp(p, 1.6, 10.0, 0.1)


## Walls of a building. `openings` per side: [[centre along the wall, width,
## height], ...] for doors, or [centre, width, y0, y1] for windows.
func _walls(r: Rect2, h: float, openings: Dictionary, mat: String) -> void:
	var t := 0.4
	for side in ["N", "S", "W", "E"]:
		var holes: Array = openings.get(side, [])
		var along_x: bool = side == "N" or side == "S"
		var fixed: float = r.position.y if side == "N" else (r.end.y if side == "S" else (r.position.x if side == "W" else r.end.x))
		var a0: float = r.position.x if along_x else r.position.y
		var a1: float = r.end.x if along_x else r.end.y
		var cuts := []
		for o in holes:
			var y0: float = 0.0 if o.size() == 3 else o[2]
			var y1: float = o[2] if o.size() == 3 else o[3]
			cuts.append([o[0] - o[1] / 2.0, o[0] + o[1] / 2.0, y0, y1])
		cuts.sort_custom(func(p, q): return p[0] < q[0])
		var cursor := a0
		for cut in cuts:
			_wall_piece(along_x, fixed, cursor, cut[0], 0.0, h, t, mat)
			_wall_piece(along_x, fixed, cut[0], cut[1], 0.0, cut[2], t, mat)
			_wall_piece(along_x, fixed, cut[0], cut[1], cut[3], h, t, mat)
			if cut[2] > 0.0:
				_wall_piece(along_x, fixed, cut[0], cut[1], cut[2], cut[3], 0.06, "glass")
			cursor = cut[1]
		_wall_piece(along_x, fixed, cursor, a1, 0.0, h, t, mat)


func _wall_piece(along_x: bool, fixed: float, a0: float, a1: float, y0: float, y1: float, t: float, mat: String) -> void:
	if along_x:
		g.box_mm(a0, y0, fixed - t / 2, a1, y1, fixed + t / 2, mat)
	else:
		g.box_mm(fixed - t / 2, y0, a0, fixed + t / 2, y1, a1, mat)


## Shipping containers (some stacked two high, with crates to climb up).
func _container_yard(r: Rect2, count: int) -> void:
	for i in count:
		var along_x := rng.randf() < 0.5
		var p := Vector3(rng.randf_range(r.position.x + 4, r.end.x - 4), 0, rng.randf_range(r.position.y + 3, r.end.y - 3))
		if _blocked(p, 5.0):
			continue
		var stack := 2 if rng.randf() < 0.4 else 1
		for level in stack:
			_container(p + Vector3(rng.randf_range(-0.3, 0.3), level * 2.6, rng.randf_range(-0.3, 0.3)), along_x, rng.randf() < 0.5)
		if stack == 2:
			var side := Vector3(0, 0, 1.9) if along_x else Vector3(1.9, 0, 0)
			g.box(p + side + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2), "wood")
			g.box(p + side * 1.5 + Vector3(0, 0.3, 0) + (Vector3(1.4, 0, 0) if along_x else Vector3(0, 0, 1.4)), Vector3(1.0, 0.6, 1.0), "wood")
			g.box(p + side + Vector3(0, 1.85, 0) + (Vector3(-1.2, 0, 0) if along_x else Vector3(0, 0, -1.2)), Vector3(1.2, 1.3, 1.2), "wood")
		_keep_clear.append(Rect2(p.x - 3.5, p.z - 3.5, 7, 7))


func _container(p: Vector3, along_x: bool, blue: bool) -> void:
	var size := Vector3(6.0, 2.6, 2.44) if along_x else Vector3(2.44, 2.6, 6.0)
	var mat := "container_blue" if blue else "container"
	g.box(p + Vector3(0, 1.3, 0), size, mat)
	# Corrugation ribs and door bars.
	var n := 10
	for i in n:
		var t := (i + 0.5) / n - 0.5
		var off := Vector3(t * size.x, 0, 0) if along_x else Vector3(0, 0, t * size.z)
		var rib := Vector3(0.08, 2.4, size.z + 0.04) if along_x else Vector3(size.x + 0.04, 2.4, 0.08)
		g.box(p + off + Vector3(0, 1.3, 0), rib, mat, false)
	var end := Vector3(size.x / 2 + 0.03, 0, 0) if along_x else Vector3(0, 0, size.z / 2 + 0.03)
	for s: float in [-0.4, 0.4]:
		var bar_off := Vector3(0, 0, s) if along_x else Vector3(s, 0, 0)
		g.box(p + end + bar_off + Vector3(0, 1.3, 0), Vector3(0.05, 2.3, 0.05), "metal", false)


# --- Gate yard -------------------------------------------------------------------

func _inner_yard() -> void:
	var r := Rect2(116, 12, 80, 36)
	# Containers and sandbag positions for cover between the gates.
	var placed := 0
	for attempt in 30:
		if placed >= 5:
			break
		var p := Vector3(rng.randf_range(r.position.x + 4, r.end.x - 4), 0, rng.randf_range(r.position.y + 4, r.end.y - 4))
		if _blocked(p, 5.0):
			continue
		_container(p, rng.randf() < 0.5, rng.randf() < 0.5)
		_keep_clear.append(Rect2(p.x - 4, p.z - 4, 8, 8))
		placed += 1
	for i in 2:
		var p := Vector3(rng.randf_range(r.position.x + 6, r.end.x - 6), 0, rng.randf_range(r.position.y + 6, r.end.y - 6))
		if not _blocked(p, 5.0):
			g._staging_area(p)
			_keep_clear.append(Rect2(p.x - 5, p.z - 5, 10, 10))
	for i in 3:
		var p := Vector3(rng.randf_range(r.position.x, r.end.x), 0, rng.randf_range(r.position.y, r.end.y))
		if not _blocked(p, 4.0):
			g._barriers(p)
	# North strip between the gates and the ravine.
	for i in 3:
		var p := Vector3(rng.randf_range(112, 200), 0, rng.randf_range(-26, -18))
		if not _blocked(p, 4.0):
			_container(p, true, rng.randf() < 0.5)
			_keep_clear.append(Rect2(p.x - 4, p.z - 3, 8, 6))
	# North of the ravine: jeeps and barriers near the exit road.
	g._jeep(Vector3(road_x - 14, 0, -60), 0.3)
	g._barriers(Vector3(road_x + 16, 0, -56))
	g._staging_area(Vector3(road_x - 22, 0, -78))
	_container_yard(Rect2(118, -90, 30, 30), 3)


func _blocked(p: Vector3, radius: float) -> bool:
	for rect in _keep_clear:
		if rect.grow(radius * 0.5).has_point(Vector2(p.x, p.z)):
			return true
	return false


# --- South: reactor, Chaos breach, fuel depot --------------------------------------

func _reactor_compound(c: Vector3) -> void:
	g._gamma_reactor(c)
	# A ring fence with a gap to the north and warning signs.
	var radius := 15.0
	for i in 28:
		var a := i * TAU / 28.0
		if absf(wrapf(a - PI * 1.5, -PI, PI)) < 0.35:
			continue
		var p := c + Vector3(cos(a), 0, sin(a)) * radius
		var q := c + Vector3(cos(a + TAU / 28.0), 0, sin(a + TAU / 28.0)) * radius
		g.box(p + Vector3(0, 1.4, 0), Vector3(0.12, 2.8, 0.12), "metal_dark")
		var mid := (p + q) / 2
		g.box(mid + Vector3(0, 1.4, 0), Vector3(0.02, 2.5, p.distance_to(q)), "fence", true, Basis(Vector3.UP, atan2(q.x - p.x, q.z - p.z) + PI / 2))
	g.label("DANGER - GAMMA REACTOR", c + Vector3(0, 3.4, -radius - 0.2), 0.0, 50)
	_keep_clear.append(Rect2(c.x - radius - 2, c.z - radius - 2, radius * 2 + 4, radius * 2 + 4))


func _chaos_breach(c: Vector3) -> void:
	g._chaos_staging(c, Vector3(road_x, 0, 30))
	g._truck(c + Vector3(6, 0, 8), 0.4)
	# Scorch marks and debris around the hole in the wall.
	g.box(Vector3(238, 0.02, Z1 - 4), Vector3(14, 0.02, 7), "metal_dark", false)
	for i in 4:
		g.crate(c + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 2)), 1.0)
	g.label("BREACH", Vector3(238, 3.6, Z1 - 0.1), PI, 90)
	_keep_clear.append(Rect2(c.x - 10, c.z - 10, 20, 24))


func _fuel_depot(c: Vector3) -> void:
	for i in 3:
		var p := c + Vector3(0, 0, i * 7.0)
		g.box(p + Vector3(0, 0.3, 0), Vector3(3.6, 0.6, 5.6), "metal_dark")
		# Horizontal tank made of a few boxes for the batch (round enough at night).
		for k in 4:
			g.box(p + Vector3(0, 2.1, 0), Vector3(3.0, 2.6, 5.4), "metal", true, Basis(Vector3.FORWARD, k * PI / 8.0))
		g.label("FUEL", p + Vector3(1.75, 2.1, 0), PI / 2, 60)
	_keep_clear.append(Rect2(c.x - 3, c.z - 4, 6, 22))


# --- Bookkeeping ----------------------------------------------------------------

func _surface_area(surface: Node3D) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	g.add(g.level, area, "SurfaceArea")
	g._shape(area, Vector3(X1 - X0 + 4, 40.0, Z1 - Z0 + 34), Vector3((X0 + X1) / 2, 10.0, (Z0 + Z1) / 2 - 7))
	surface.set_meta("road_x", road_x)


func _lights() -> void:
	# Street lamps along the roads.
	var z := Z0 + 10
	while z < 76:
		if z < TRENCH.x - 3 or z > TRENCH.y + 3:
			_street_lamp(Vector3(road_x + 4.6, 0, z), PI / 2)
		z += 18.0
	var x := X0 + 14
	while x < 206:
		if absf(x - road_x) > 8:
			_street_lamp(Vector3(x, 0, -7.6), PI)
		x += 20.0
	g._floodlights(X0 + 1, X1 - 1, Z0 + 1, Z1 - 1)


func _street_lamp(p: Vector3, yaw: float) -> void:
	g.box(p + Vector3(0, 3.0, 0), Vector3(0.18, 6.0, 0.18), "metal_dark")
	var arm := Vector3(cos(yaw), 0, -sin(yaw)) * -1.0
	g.box(p + Vector3(0, 6.0, 0) + arm * 0.6, Vector3(0.1, 0.1, 1.3) if absf(arm.z) > 0.5 else Vector3(1.3, 0.1, 0.1), "metal_dark", false)
	g.lamp(p + Vector3(0, 5.95, 0) + arm * 1.2, 2.2, 16.0, 0.05, false, Color(1.0, 0.88, 0.7))
