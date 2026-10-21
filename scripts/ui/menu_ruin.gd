class_name MenuRuin
extends Node3D
## The main menu backdrop: the Class-D cell block after the Gamma Warhead.
## A black hole hangs at the far end of the hall, time has all but stopped,
## and the wreckage - torn-off cell doors, chunks of wall, bunks, cables -
## drifts towards it ever so slowly. Pieces that reach it reappear further
## back, so the drift never ends.

## How slowly everything moves (time has nearly stopped).
const DRIFT_SPEED := 0.12
const DEBRIS_COUNT := 70

var hole: Singularity
var _start: Transform3D
var _hall_length := 30.0
var _debris: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _mats := {}


## `facility` is the generated map, `start` the camera's spot at the hall
## entrance (looking down the hall).
func build(facility: Node3D, start: Transform3D) -> void:
	_rng.seed = 914
	_start = start
	var forward := -start.basis.z
	# The black hole at the far end of the hall.
	hole = Singularity.new()
	hole.kind = "black"
	hole.ambient = true
	hole.time_scale = 0.05
	add_child(hole)
	hole.global_position = start.origin + forward * _hall_length + Vector3(0, 0.6, 0)
	hole.scale = Vector3.ONE * 0.32
	# Kill most of the lights; the rest are dim and steady (no flicker when
	# time stands still).
	for light in facility.find_children("*", "Light3D", true, false):
		var l := light as Light3D
		if l.global_position.distance_to(start.origin) > 60.0:
			continue
		if l.get_script() != null:
			l.set_script(null)
		if _rng.randf() < 0.55:
			l.visible = false
		else:
			l.light_energy *= 0.5
	# Cell doors: some blown open, some torn off and caught in the drift.
	for door in facility.find_children("CellDoor*", "", true, false):
		var d := door as Node3D
		if d.global_position.distance_to(start.origin) > 45.0:
			continue
		if _rng.randf() < 0.45:
			var panel := d.get_node_or_null("Panel") as Node3D
			if panel != null:
				var free_panel := panel.duplicate() as Node3D
				d.visible = false
				add_child(free_panel)
				free_panel.global_transform = panel.global_transform
				_add_debris(free_panel, 0.6)
		else:
			d.visible = _rng.randf() < 0.5
	# Chunks of concrete, metal and furniture floating in the hall.
	for i in DEBRIS_COUNT:
		var piece := _chunk()
		add_child(piece)
		piece.global_position = _random_spot(_rng.randf_range(0.0, _hall_length - 3.0))
		piece.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		_add_debris(piece, 1.0)
	_frozen_dust()


func _add_debris(node: Node3D, weight: float) -> void:
	node.set_meta("spin", Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.04, 0.04)))
	node.set_meta("speed", DRIFT_SPEED * _rng.randf_range(0.5, 1.6) / weight)
	_debris.append(node)


func _random_spot(along: float) -> Vector3:
	var forward := -_start.basis.z
	var side := _start.basis.x
	var across := _rng.randf_range(-4.5, 4.5)
	# Near the camera's path, keep the middle clear so nothing blocks the view.
	if along < 10.0:
		across = signf(across + 0.001) * _rng.randf_range(1.8, 4.5)
	return _start.origin + forward * along + side * across + Vector3(0, _rng.randf_range(-1.4, 2.0), 0)


func _process(delta: float) -> void:
	if hole == null:
		return
	var target := hole.global_position
	for piece in _debris:
		var to := target - piece.global_position
		var d := to.length()
		# Faster (but still slow) the closer it gets, spiralling a little.
		var speed: float = piece.get_meta("speed") * (1.0 + 6.0 / maxf(d, 1.5))
		var swirl := to.cross(Vector3.UP).normalized() * 0.25
		piece.global_position += (to.normalized() + swirl).normalized() * speed * delta
		var spin: Vector3 = piece.get_meta("spin")
		piece.rotation += spin * delta * (1.0 + 4.0 / maxf(d, 1.5))
		# Stretched and shrunk as it falls in.
		var squeeze := clampf(d / 4.0, 0.05, 1.0)
		piece.scale = Vector3(squeeze, squeeze, squeeze)
		if d < 1.2:
			piece.global_position = _random_spot(_rng.randf_range(-2.0, 6.0))
			piece.scale = Vector3.ONE


## Rough chunks: concrete lumps, bent beams, bunks, mattresses, pipes.
func _chunk() -> Node3D:
	var root := Node3D.new()
	var kind := _rng.randi() % 6
	match kind:
		0, 1:
			for k in _rng.randi_range(1, 3):
				_box(root, Vector3(_rng.randf_range(0.2, 0.9), _rng.randf_range(0.15, 0.6), _rng.randf_range(0.2, 0.8)),
					Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.3, 0.3)), Color(0.35, 0.35, 0.37))
		2:
			_box(root, Vector3(0.12, 0.12, _rng.randf_range(1.0, 2.6)), Vector3.ZERO, Color(0.2, 0.2, 0.22), 0.6)
		3:
			_box(root, Vector3(0.9, 0.12, 1.9), Vector3.ZERO, Color(0.12, 0.12, 0.13), 0.4)
			_box(root, Vector3(0.8, 0.12, 1.8), Vector3(0, 0.12, 0), Color(0.75, 0.72, 0.65))
		4:
			_box(root, Vector3(1.2, 0.05, 0.7), Vector3.ZERO, Color(0.3, 0.3, 0.32), 0.5)
		_:
			var pipe := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.06
			mesh.bottom_radius = 0.06
			mesh.height = _rng.randf_range(0.8, 2.0)
			pipe.mesh = mesh
			pipe.material_override = _mat(Color(0.4, 0.3, 0.2), 0.7)
			root.add_child(pipe)
	return root


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metal := 0.0) -> void:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = _mat(color, metal)
	m.position = pos
	parent.add_child(m)


func _mat(color: Color, metal: float) -> StandardMaterial3D:
	var key := color.to_html() + str(metal)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metal
		m.roughness = 0.8
		_mats[key] = m
	return _mats[key]


## Dust hanging motionless in the air.
func _frozen_dust() -> void:
	var p := CPUParticles3D.new()
	p.amount = 400
	p.lifetime = 60.0
	p.preprocess = 30.0
	p.speed_scale = 0.02
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5, 2, _hall_length / 2)
	p.direction = Vector3.DOWN
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.04, 0.04)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.8, 0.82, 0.85, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = m
	p.mesh = mesh
	add_child(p)
	var forward := -_start.basis.z
	p.global_position = _start.origin + forward * (_hall_length / 2) + Vector3(0, 0.2, 0)
	p.global_basis = _start.basis
