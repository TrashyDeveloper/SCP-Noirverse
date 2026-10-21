class_name FusionReactorBackdrop
extends Node3D
## The alternative menu's backdrop: Innovation Inc.'s fusion reactor hall.
## A big ring-shaped reactor (a tokamak) with part of its shell cut away so
## the glowing plasma ring shows, magnet coils, a catwalk, pipes and
## ceiling lights. Built from simple shapes; everything is original.

const CORE_HEIGHT := 4.0
const RING_RADIUS := 6.5
const TUBE_RADIUS := 2.0
## Shell segments around the ring; the ones facing the camera are left out.
const SEGMENTS := 28
const GAP := 6

var plasma_light: OmniLight3D
var _plasma: MeshInstance3D
var _plasma_mat: StandardMaterial3D
var _sparks: Array[MeshInstance3D] = []
var _spark_phase: Array[float] = []
var _beacons: Array[OmniLight3D] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _mats := {}


func _ready() -> void:
	_rng.seed = 2077
	_environment()
	_room()
	_reactor()
	_catwalk()
	_pipes()
	_lights()


func _process(delta: float) -> void:
	_time += delta
	# The plasma breathes and shimmers.
	var pulse := 0.85 + 0.1 * sin(_time * 1.7) + 0.05 * sin(_time * 7.3)
	_plasma_mat.emission_energy_multiplier = 6.0 * pulse
	plasma_light.light_energy = 9.0 * pulse
	_plasma.rotation.y += delta * 0.4
	for i in _sparks.size():
		_spark_phase[i] += delta * (1.2 + 0.3 * float(i % 5))
		var a := _spark_phase[i]
		var wobble := 0.35 * sin(a * 3.0 + i)
		var r := RING_RADIUS + wobble * cos(a * 5.0)
		_sparks[i].position = Vector3(cos(a) * r, CORE_HEIGHT + wobble * sin(a * 5.0), sin(a) * r)
	for i in _beacons.size():
		_beacons[i].light_energy = 2.5 * maxf(0.0, sin(_time * 3.0 + i * PI))


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.4)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.22, 0.3)
	env.fog_density = 0.012
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _room() -> void:
	# Round hall with ribbed walls.
	var wall := CylinderMesh.new()
	wall.top_radius = 34.0
	wall.bottom_radius = 34.0
	wall.height = 20.0
	wall.flip_faces = true
	wall.radial_segments = 48
	_mesh(wall, Vector3(0, 10, 0), Vector3.ZERO, _mat("wall", Color(0.16, 0.17, 0.19), 0.2, 0.8))
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 34.0
	floor_mesh.bottom_radius = 34.0
	floor_mesh.height = 0.2
	_mesh(floor_mesh, Vector3(0, -0.1, 0), Vector3.ZERO, _mat("floor", Color(0.12, 0.12, 0.13), 0.5, 0.5))
	for i in 32:
		var a := TAU * i / 32.0
		_box(Vector3(cos(a) * 33.6, 10, sin(a) * 33.6), Vector3(0.6, 20, 1.2), -a, "rib", Color(0.22, 0.23, 0.25), 0.7)
	# Hazard stripes in a ring on the floor around the reactor.
	for i in 48:
		var a := TAU * i / 48.0
		var col := Color(0.85, 0.65, 0.1) if i % 2 == 0 else Color(0.05, 0.05, 0.05)
		_box(Vector3(cos(a) * 12.5, 0.01, sin(a) * 12.5), Vector3(0.6, 0.02, 1.6), -a, "stripe%d" % (i % 2), col, 0.1)
	# Ceiling ring and a gantry.
	var ceiling := TorusMesh.new()
	ceiling.inner_radius = 14.0
	ceiling.outer_radius = 16.0
	_mesh(ceiling, Vector3(0, 17, 0), Vector3.ZERO, _mat("metal", Color(0.3, 0.31, 0.33), 0.8, 0.4))


func _reactor() -> void:
	var shell := _mat("shell", Color(0.42, 0.44, 0.47), 0.85, 0.35)
	var inner := _mat("inner", Color(0.12, 0.1, 0.12), 0.6, 0.5)
	var coil_mat := _mat("coil", Color(0.72, 0.42, 0.2), 0.9, 0.3)
	# Shell: tube segments around the ring, with a cut-away on the camera side.
	for i in SEGMENTS:
		if i < GAP:
			continue
		var a := TAU * (i + 0.5) / SEGMENTS
		var seg := CylinderMesh.new()
		seg.top_radius = TUBE_RADIUS
		seg.bottom_radius = TUBE_RADIUS
		seg.height = TAU * RING_RADIUS / SEGMENTS * 1.02
		seg.radial_segments = 24
		var node := _mesh(seg, Vector3(cos(a) * RING_RADIUS, CORE_HEIGHT, sin(a) * RING_RADIUS), Vector3.ZERO, shell)
		node.basis = Basis.looking_at(Vector3(-sin(a), 0, cos(a)), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
	# The cut edges: dark rims, and the inside lining you can see through the gap.
	for edge: float in [0.0, float(GAP)]:
		var a := TAU * edge / SEGMENTS
		var rim := TorusMesh.new()
		rim.inner_radius = TUBE_RADIUS - 0.15
		rim.outer_radius = TUBE_RADIUS + 0.2
		var node := _mesh(rim, Vector3(cos(a) * RING_RADIUS, CORE_HEIGHT, sin(a) * RING_RADIUS), Vector3.ZERO, inner)
		node.basis = Basis.looking_at(Vector3(-sin(a), 0, cos(a)), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
	# Magnet coils: big copper D-rings around the tube.
	for i in 14:
		var a := TAU * (i + 0.25) / 14.0
		if a < TAU * GAP / SEGMENTS:
			continue
		var coil := TorusMesh.new()
		coil.inner_radius = TUBE_RADIUS + 0.15
		coil.outer_radius = TUBE_RADIUS + 0.75
		var node := _mesh(coil, Vector3(cos(a) * RING_RADIUS, CORE_HEIGHT, sin(a) * RING_RADIUS), Vector3.ZERO, coil_mat)
		node.basis = Basis.looking_at(Vector3(-sin(a), 0, cos(a)), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
		node.scale = Vector3(1.0, 1.0, 1.35)
	# Central column (the solenoid) and the stand.
	var column := CylinderMesh.new()
	column.top_radius = 2.3
	column.bottom_radius = 2.6
	column.height = 13.0
	_mesh(column, Vector3(0, 6.5, 0), Vector3.ZERO, coil_mat)
	for k in 6:
		var band := TorusMesh.new()
		band.inner_radius = 2.4
		band.outer_radius = 2.75
		_mesh(band, Vector3(0, 1.5 + k * 2.0, 0), Vector3.ZERO, shell)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		_box(Vector3(cos(a) * RING_RADIUS, 1.0, sin(a) * RING_RADIUS), Vector3(1.0, 2.0, 1.4), -a, "stand", Color(0.2, 0.2, 0.22), 0.7)
	# The plasma ring: a hot, glowing band inside the vessel.
	_plasma_mat = StandardMaterial3D.new()
	_plasma_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plasma_mat.albedo_color = Color(1.0, 0.55, 0.95)
	_plasma_mat.emission_enabled = true
	_plasma_mat.emission = Color(0.95, 0.35, 1.0)
	_plasma_mat.emission_energy_multiplier = 6.0
	var ring := TorusMesh.new()
	ring.inner_radius = RING_RADIUS - 0.55
	ring.outer_radius = RING_RADIUS + 0.55
	ring.rings = 96
	_plasma = _mesh(ring, Vector3(0, CORE_HEIGHT, 0), Vector3.ZERO, _plasma_mat)
	_plasma.scale = Vector3(1, 0.6, 1)
	var core_glow := _plasma_mat.duplicate() as StandardMaterial3D
	core_glow.albedo_color = Color(1, 0.9, 1)
	core_glow.emission = Color(1, 0.8, 1)
	core_glow.emission_energy_multiplier = 10.0
	for i in 40:
		var spark := SphereMesh.new()
		spark.radius = _rng.randf_range(0.05, 0.14)
		spark.height = spark.radius * 2.0
		_sparks.append(_mesh(spark, Vector3.ZERO, Vector3.ZERO, core_glow))
		_spark_phase.append(_rng.randf() * TAU)
	plasma_light = OmniLight3D.new()
	plasma_light.light_color = Color(0.9, 0.45, 1.0)
	plasma_light.omni_range = 26.0
	plasma_light.omni_attenuation = 1.2
	# Sits in the cut-away, so it lights the hall from the open side.
	var mid := TAU * GAP * 0.5 / SEGMENTS
	plasma_light.position = Vector3(cos(mid) * RING_RADIUS, CORE_HEIGHT, sin(mid) * RING_RADIUS)
	add_child(plasma_light)


func _catwalk() -> void:
	var grate := _mat("grate", Color(0.26, 0.27, 0.28), 0.8, 0.5)
	var rail := _mat("rail", Color(0.85, 0.65, 0.1), 0.4, 0.5)
	var walk := TorusMesh.new()
	walk.inner_radius = 9.6
	walk.outer_radius = 11.0
	var node := _mesh(walk, Vector3(0, 2.2, 0), Vector3.ZERO, grate)
	node.scale = Vector3(1, 0.08, 1)
	for r: float in [9.6, 11.0]:
		var bar := TorusMesh.new()
		bar.inner_radius = r - 0.04
		bar.outer_radius = r + 0.04
		_mesh(bar, Vector3(0, 3.25, 0), Vector3.ZERO, rail)
	for i in 36:
		var a := TAU * i / 36.0
		for r: float in [9.6, 11.0]:
			_box(Vector3(cos(a) * r, 2.75, sin(a) * r), Vector3(0.06, 1.0, 0.06), 0.0, "post", Color(0.85, 0.65, 0.1), 0.4)
		if i % 4 == 0:
			_box(Vector3(cos(a) * 10.3, 1.1, sin(a) * 10.3), Vector3(0.25, 2.2, 0.25), 0.0, "leg", Color(0.2, 0.2, 0.22), 0.7)


func _pipes() -> void:
	var pipe_mat := _mat("pipe", Color(0.55, 0.57, 0.6), 0.9, 0.3)
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		if a < TAU * (GAP + 1) / SEGMENTS:
			continue
		var from := Vector3(cos(a) * 33.0, 9.0 + _rng.randf_range(-3, 4), sin(a) * 33.0)
		var to := Vector3(cos(a) * (RING_RADIUS + 1.0), CORE_HEIGHT + 1.5, sin(a) * (RING_RADIUS + 1.0))
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.28
		pipe.bottom_radius = 0.28
		pipe.height = from.distance_to(to)
		var p := _mesh(pipe, (from + to) * 0.5, Vector3.ZERO, pipe_mat)
		p.basis = Basis.looking_at(to - from, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)


func _lights() -> void:
	# Cool work lights from the ceiling ring.
	for i in 6:
		var a := TAU * i / 6.0 + 0.5
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.75, 0.85, 1.0)
		spot.light_energy = 3.0
		spot.spot_range = 30.0
		spot.spot_angle = 30.0
		spot.shadow_enabled = i % 2 == 0
		add_child(spot)
		spot.position = Vector3(cos(a) * 15.0, 16.5, sin(a) * 15.0)
		spot.look_at(Vector3(cos(a) * 6.0, 0, sin(a) * 6.0))
	# Amber warning beacons around the hall.
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.5, 0.1)
	beacon_mat.emission_energy_multiplier = 4.0
	for i in 4:
		var a := TAU * i / 4.0 + 0.9
		var pos := Vector3(cos(a) * 32.8, 6.0, sin(a) * 32.8)
		var lamp := SphereMesh.new()
		lamp.radius = 0.25
		lamp.height = 0.5
		_mesh(lamp, pos, Vector3.ZERO, beacon_mat)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.1)
		light.omni_range = 9.0
		light.position = pos - pos.normalized() * 0.6
		add_child(light)
		_beacons.append(light)


## Where the camera looks: the middle of the cut-away.
func gap_direction() -> Vector3:
	var mid := TAU * GAP * 0.5 / SEGMENTS
	return Vector3(cos(mid), 0, sin(mid))


func _mesh(mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	add_child(m)
	return m


func _box(pos: Vector3, size: Vector3, yaw: float, mat_name: String, color: Color, metal: float) -> void:
	var b := BoxMesh.new()
	b.size = size
	_mesh(b, pos, Vector3(0, yaw, 0), _mat(mat_name, color, metal, 0.5))


func _mat(mat_name: String, color: Color, metal: float, rough: float) -> StandardMaterial3D:
	if not _mats.has(mat_name):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metal
		m.roughness = rough
		_mats[mat_name] = m
	return _mats[mat_name]
