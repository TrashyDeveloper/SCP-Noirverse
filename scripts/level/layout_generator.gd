class_name LayoutGenerator
extends RefCounted
## Plans the rooms and corridors of one zone on a grid of 12 m cells.
## Pure data (no nodes): FacilityGenerator turns the result into geometry.
##
## Steps: carve an irregular zone shape, place the important rooms, connect
## their doors with winding corridors, add dead-end branches and a few loops,
## then fill the gaps next to corridors with smaller rooms.

const DIRS := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}

var rng: RandomNumberGenerator
var origin: Vector2i
var size: Vector2i
## Cells inside the zone's shape.
var inside := {}
## Cells already used by rooms.
var room_at := {}
## Cells that must become corridors (in front of doors, zone connections).
var required := {}
## Corridor cells: Vector2i -> "#" (corridor), "X" (lockroom), "=" (checkpoint).
var corridors := {}
## Rooms: {type, rect: Rect2i, doors: [[cell, dir], ...]}
var rooms: Array[Dictionary] = []


func _init(random: RandomNumberGenerator, zone_origin: Vector2i, zone_size: Vector2i) -> void:
	rng = random
	origin = zone_origin
	size = zone_size
	for x in size.x:
		for y in size.y:
			inside[origin + Vector2i(x, y)] = true


## Cuts 1-2 rectangles off the corners so the zone isn't a plain rectangle.
## Cells in `keep` are never removed.
func carve_shape(keep: Array) -> void:
	var corners := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	corners.shuffle()
	for i in rng.randi_range(1, 2):
		var corner: Vector2i = corners[i]
		var w := rng.randi_range(1, 3)
		var h := rng.randi_range(1, 2)
		var cells := []
		for x in w:
			for y in h:
				var cx := x if corner.x == 0 else size.x - 1 - x
				var cy := y if corner.y == 0 else size.y - 1 - y
				cells.append(origin + Vector2i(cx, cy))
		if cells.any(func(c): return keep.has(c)):
			continue
		for c in cells:
			inside.erase(c)


func is_free(cell: Vector2i) -> bool:
	return inside.has(cell) and not room_at.has(cell) and not required.has(cell) and not corridors.has(cell)


func walkable(cell: Vector2i) -> bool:
	return inside.has(cell) and not room_at.has(cell)


## Marks a cell as a corridor that must exist (e.g. where another zone joins).
func require(cell: Vector2i) -> void:
	inside[cell] = true
	required[cell] = true


## Places a room of w x h cells. Options:
##   at: Vector2i       fixed position (otherwise random)
##   edge: "N"/"S"      the room must touch that edge of the zone
##   door_dirs: [...]   allowed sides for its door (default all)
##   door_cell: "min"/"max"/"any"  which cell of the room may have the door
##   doors: int         how many doors (default 1)
## Returns the room, or an empty Dictionary if it didn't fit.
func place_room(type: String, w: int, h: int, opts := {}) -> Dictionary:
	var positions := []
	if opts.has("at"):
		positions = [opts.at]
	else:
		for x in size.x - w + 1:
			for y in size.y - h + 1:
				positions.append(origin + Vector2i(x, y))
		positions.shuffle()
	for pos: Vector2i in positions:
		var rect := Rect2i(pos, Vector2i(w, h))
		if not _rect_free(rect, opts.has("at")):
			continue
		if opts.has("edge"):
			var edge_y := origin.y if opts.edge == "N" else origin.y + size.y - 1
			if (opts.edge == "N" and rect.position.y != edge_y) or (opts.edge == "S" and rect.end.y - 1 != edge_y):
				continue
		var candidates := _door_candidates(rect, opts)
		if candidates.is_empty():
			continue
		candidates.shuffle()
		var room := {"type": type, "rect": rect, "doors": []}
		for i in mini(opts.get("doors", 1), candidates.size()):
			var cand: Array = candidates[i]
			room.doors.append(cand)
			require(cand[0] + DIRS[cand[1]])
		for x in w:
			for y in h:
				room_at[pos + Vector2i(x, y)] = room
		rooms.append(room)
		return room
	return {}


func _rect_free(rect: Rect2i, allow_fixed: bool) -> bool:
	for x in rect.size.x:
		for y in rect.size.y:
			var c := rect.position + Vector2i(x, y)
			if allow_fixed:
				inside[c] = true
			if not inside.has(c) or room_at.has(c) or required.has(c) or corridors.has(c):
				return false
	return true


func _door_candidates(rect: Rect2i, opts: Dictionary) -> Array:
	var allowed: Array = opts.get("door_dirs", ["N", "S", "E", "W"])
	var which: String = opts.get("door_cell", "any")
	var result := []
	for x in rect.size.x:
		for y in rect.size.y:
			var c := rect.position + Vector2i(x, y)
			if which == "min" and c != rect.position:
				continue
			if which == "max" and c != rect.end - Vector2i.ONE:
				continue
			for d in allowed:
				var n: Vector2i = c + DIRS[d]
				if rect.has_point(n):
					continue
				if is_free(n) or required.has(n) or corridors.has(n):
					result.append([c, d])
	return result


## Connects all required cells with corridors (winding shortest paths).
## Returns false if some cell can't be reached.
func connect_corridors() -> bool:
	var targets: Array = required.keys()
	if targets.is_empty():
		return true
	targets.shuffle()
	var tree := {targets[0]: true}
	corridors[targets[0]] = "#"
	for t: Vector2i in targets.slice(1):
		if tree.has(t):
			continue
		var path := _path_to_tree(t, tree)
		if path.is_empty():
			return false
		for c in path:
			tree[c] = true
			corridors[c] = "#"
	return true


## Dijkstra with random step costs, so corridors wind a little.
func _path_to_tree(start: Vector2i, tree: Dictionary) -> Array:
	var dist := {start: 0.0}
	var prev := {}
	var open := [start]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best]]:
				best = i
		var cur: Vector2i = open.pop_at(best)
		if tree.has(cur) and cur != start:
			var path := [cur]
			while prev.has(path[-1]):
				path.append(prev[path[-1]])
			return path
		for d in DIRS.values():
			var n: Vector2i = cur + d
			if not walkable(n):
				continue
			var cost: float = dist[cur] + 1.0 + rng.randf() * 1.5 - (0.6 if corridors.has(n) else 0.0)
			if not dist.has(n) or cost < dist[n]:
				dist[n] = cost
				prev[n] = cur
				if not open.has(n):
					open.append(n)
	return []


## Short corridor branches that end nowhere (hiding spots, ambushes).
func add_dead_ends(count: int) -> void:
	var cells: Array = corridors.keys()
	for i in count:
		if cells.is_empty():
			return
		var c: Vector2i = cells[rng.randi() % cells.size()]
		var d: Vector2i = DIRS.values()[rng.randi() % 4]
		for step in rng.randi_range(1, 3):
			var n := c + d
			if not is_free(n):
				break
			corridors[n] = "#"
			c = n


## Extra links between corridors that are two cells apart (loops).
func add_loops(count: int) -> void:
	var cells: Array = corridors.keys()
	cells.shuffle()
	var added := 0
	for c: Vector2i in cells:
		if added >= count:
			return
		for d in DIRS.values():
			var mid: Vector2i = c + d
			if is_free(mid) and corridors.has(c + d * 2):
				corridors[mid] = "#"
				added += 1
				break


## Puts small rooms in free cells next to corridors. `types` is a list of
## [type, weight]; `chance` is the probability per free cell.
func add_fillers(types: Array, chance: float) -> void:
	var cells: Array = inside.keys()
	cells.shuffle()
	for c: Vector2i in cells:
		if not is_free(c) or rng.randf() > chance:
			continue
		var doors := []
		for d in DIRS:
			if corridors.has(c + DIRS[d]) and corridors[c + DIRS[d]] == "#":
				doors.append([c, d])
		if doors.is_empty():
			continue
		var room := {"type": _weighted(types), "rect": Rect2i(c, Vector2i.ONE), "doors": [doors[rng.randi() % doors.size()]]}
		room_at[c] = room
		rooms.append(room)


## Turns one straight corridor cell into a lockroom (two doors in a row).
func add_lockroom() -> void:
	var cells: Array = corridors.keys()
	cells.shuffle()
	for c: Vector2i in cells:
		if required.has(c) or corridors[c] != "#":
			continue
		var conn := connections(c)
		if conn.size() == 2 and ((conn.has("E") and conn.has("W")) or (conn.has("N") and conn.has("S"))):
			corridors[c] = "X"
			return


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


func _weighted(types: Array) -> String:
	var total := 0.0
	for t in types:
		total += t[1]
	var r := rng.randf() * total
	for t in types:
		r -= t[1]
		if r <= 0.0:
			return t[0]
	return types[0][0]
