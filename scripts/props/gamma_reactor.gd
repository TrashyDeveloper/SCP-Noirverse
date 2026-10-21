class_name GammaReactor
extends Node3D
## The Gamma Warhead: a fusion reactor on the Surface. A blazing core hangs
## between four pylons inside spinning gyroscope rings, with two pulsar
## beams sweeping around it.
##
## Idle it turns slowly. When the Gamma Warhead is activated it spins up
## faster and faster, like a pulsar, until it spins so fast that the noir
## filter can't hold: colour floods back into the world around it (Game reads
## get_color_strength() / get_color_radius() for the screen filter).
## Origin = ground level at the centre.

const CORE_HEIGHT := 4.6
const IDLE_SPIN := 0.6
const MAX_SPIN := 70.0

var spin := IDLE_SPIN
var _state := 0
var _time_left := 0.0
var _countdown := 120.0
var _rings: Array[Node3D] = []
var _pulsar: Node3D
var _core: MeshInstance3D
var _core_light: OmniLight3D
var _beam_lights: Array[SpotLight3D] = []
var _hum: AudioStreamPlayer3D
var _time := 0.0
var _mats := {}


func _ready() -> void:
	add_to_group(&"warhead_listeners")
	_build()
	_hum = Sfx.play_3d(self, "reactor_hum_loop", global_position + Vector3(0, CORE_HEIGHT, 0), -6.0, 0.6, self, 60.0)


## Called by the RoundManager whenever a warhead changes state.
func on_warhead_changed(warhead: int, state: int, time_left: float) -> void:
	if warhead != WarheadConsole.Warhead.GAMMA:
		return
	if state == RoundManager.WarheadState.COUNTDOWN and _state != state:
		_countdown = maxf(time_left, 1.0)
	_state = state
	_time_left = time_left


## 0 = no colour, 1 = full colour around the reactor.
func get_color_strength() -> float:
	return clampf(0.12 + (spin - IDLE_SPIN) / (MAX_SPIN - IDLE_SPIN) * 1.2, 0.0, 1.0)


## How far (meters) the colour reaches.
func get_color_radius() -> float:
	return 8.0 + (spin - IDLE_SPIN) / (MAX_SPIN - IDLE_SPIN) * 60.0


func get_core_position() -> Vector3:
	return global_position + Vector3(0, CORE_HEIGHT, 0)


func _process(delta: float) -> void:
	_time += delta
	var target := IDLE_SPIN
	if _state == RoundManager.WarheadState.COUNTDOWN:
		_time_left = maxf(_time_left - delta, 0.0)
		var progress := 1.0 - _time_left / _countdown
		target = lerpf(2.0, MAX_SPIN, pow(progress, 2.2))
	elif _state == RoundManager.WarheadState.DETONATED:
		target = 0.0
	spin = lerpf(spin, target, minf(delta * 0.8, 1.0))
	# Gyroscope rings on different axes, the pulsar beams sweeping around.
	for i in _rings.size():
		var axis: Vector3 = _rings[i].get_meta("axis")
		_rings[i].rotate_object_local(axis, delta * spin * (0.6 + i * 0.35) * (1.0 if i % 2 == 0 else -1.0))
	_pulsar.rotate_y(delta * spin * 1.5)
	var pulse := 0.5 + 0.5 * sin(_time * (3.0 + spin * 0.6))
	var heat := clampf(spin / MAX_SPIN, 0.0, 1.0)
	_core.scale = Vector3.ONE * (1.0 + pulse * 0.08 + heat * 0.25)
	_core_light.light_energy = 3.0 + heat * 12.0 + pulse * 1.5
	_core_light.omni_range = 14.0 + heat * 30.0
	for l in _beam_lights:
		l.light_energy = 4.0 + heat * 20.0
	if _hum != null:
		_hum.pitch_scale = 0.6 + heat * 2.6
		_hum.volume_db = -6.0 + heat * 8.0


# --- Model ----------------------------------------------------------------------

func _build() -> void:
	var dark := Color(0.12, 0.12, 0.14)
	var steel := Color(0.35, 0.36, 0.4)
	# Base: a stepped round platform with glowing rings in the floor.
	_cyl(self, 5.6, 0.1, Vector3(0, 0.05, 0), dark, 48)
	_cyl(self, 3.6, 0.2, Vector3(0, 0.1, 0), steel, 48)
	for r: float in [4.4, 2.6]:
		_torus(self, r, 0.06, Vector3(0, 0.11, 0), _glow(Color(0.2, 0.8, 1.0), 2.0))
	_cyl(self, 1.2, 1.2, Vector3(0, 0.6, 0), dark, 24)
	_cone(self, 0.9, 0.3, 1.6, Vector3(0, 2.0, 0), steel, 24)
	# Four pylons leaning in, with glowing coils and cables to the core.
	var body := StaticBody3D.new()
	add_child(body)
	PropBuilder.add_shape(body, Vector3(0, 1.0, 0), Vector3(2.6, 2.0, 2.6))
	for i in 4:
		var a := i * PI / 2 + PI / 4
		var dir := Vector3(cos(a), 0, sin(a))
		var base := dir * 4.3
		var pylon := Node3D.new()
		pylon.position = base
		pylon.basis = Basis(Vector3(-dir.z, 0, dir.x), -0.18)
		add_child(pylon)
		_cone(pylon, 0.45, 0.22, 8.0, Vector3(0, 4.0, 0), dark, 16)
		for y: float in [2.0, 3.2, 4.4, 5.6, 6.8]:
			_torus(pylon, 0.36 - y * 0.02, 0.07, Vector3(0, y, 0), _glow(Color(1.0, 0.35, 0.8), 2.5))
		_sphere(pylon, 0.35, Vector3(0, 8.1, 0), _glow(Color(0.3, 0.9, 1.0), 4.0))
		PropBuilder.add_shape(body, base + Vector3(0, 2.0, 0), Vector3(1.0, 4.0, 1.0))
		_cable(base + Vector3(0, 6.0, 0) - dir * 0.9, Vector3(0, CORE_HEIGHT, 0) + dir * 1.0)
	# The core and its gyroscope rings.
	var hub := Node3D.new()
	hub.position = Vector3(0, CORE_HEIGHT, 0)
	add_child(hub)
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.9
	core_mesh.height = 1.8
	_core = MeshInstance3D.new()
	_core.mesh = core_mesh
	_core.material_override = _glow(Color(0.75, 0.95, 1.0), 6.0)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub.add_child(_core)
	var halo := _sphere(hub, 1.3, Vector3.ZERO, _glow(Color(0.3, 0.6, 1.0, 0.25), 2.0, true))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_specs := [
		[1.8, 0.08, Color(1.0, 0.75, 0.2), Vector3(1, 0, 0)],
		[2.4, 0.1, Color(1.0, 0.25, 0.7), Vector3(0, 0, 1)],
		[3.0, 0.12, Color(0.2, 0.9, 1.0), Vector3(1, 0, 1).normalized()],
	]
	for spec in ring_specs:
		var ring := Node3D.new()
		ring.set_meta("axis", spec[3])
		hub.add_child(ring)
		_torus(ring, spec[0], spec[1], Vector3.ZERO, _glow(spec[2], 3.0))
		_torus(ring, spec[0], spec[1] * 1.8, Vector3.ZERO, _metal(Color(0.2, 0.2, 0.22))).scale = Vector3(1, 0.4, 1)
		for k in 4:
			var a := k * PI / 2
			_sphere(ring, spec[1] * 2.2, Vector3(cos(a), 0, sin(a)) * spec[0], _glow(Color(1, 1, 1), 5.0))
		_rings.append(ring)
	# Pulsar: two beams along a tilted axis, sweeping round.
	_pulsar = Node3D.new()
	hub.add_child(_pulsar)
	var axis := Node3D.new()
	axis.rotation.z = deg_to_rad(28)
	_pulsar.add_child(axis)
	for s: float in [1.0, -1.0]:
		var beam := CylinderMesh.new()
		beam.top_radius = 0.02 if s > 0 else 0.7
		beam.bottom_radius = 0.7 if s > 0 else 0.02
		beam.height = 16.0
		beam.radial_segments = 16
		var bm := MeshInstance3D.new()
		bm.mesh = beam
		bm.material_override = _beam_material()
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bm.position = Vector3(0, s * 8.6, 0)
		axis.add_child(bm)
		var spot := SpotLight3D.new()
		spot.rotation.x = PI / 2 if s > 0 else -PI / 2
		spot.spot_range = 40.0
		spot.spot_angle = 8.0
		spot.light_color = Color(0.5, 0.85, 1.0)
		spot.light_energy = 4.0
		axis.add_child(spot)
		_beam_lights.append(spot)
	_core_light = OmniLight3D.new()
	_core_light.light_color = Color(0.55, 0.85, 1.0)
	_core_light.omni_range = 14.0
	_core_light.light_energy = 3.0
	_core_light.shadow_enabled = true
	hub.add_child(_core_light)
	var sign := PropBuilder.add_label(self, "GAMMA REACTOR", Vector3(0, 0.25, 5.0), 120, 0.006)
	sign.rotation.x = -PI / 2
	sign.modulate = Color(0.5, 0.85, 1.0)


func _cable(a: Vector3, b: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.06
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _metal(Color(0.08, 0.08, 0.09))
	m.position = (a + b) / 2
	m.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	add_child(m)


func _beam_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.35, 0.75, 1.0, 0.35)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _glow(color: Color, energy: float, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = energy
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _metal(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = 0.7
		m.roughness = 0.35
		_mats[key] = m
	return _mats[key]


func _place(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position = pos
	parent.add_child(m)
	return m


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, segments := 16) -> MeshInstance3D:
	return _cone(parent, radius, radius, height, pos, color, segments)


func _cone(parent: Node3D, bottom: float, top: float, height: float, pos: Vector3, color: Color, segments := 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	return _place(parent, mesh, pos, _metal(color))


func _torus(parent: Node3D, radius: float, thickness: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 48
	mesh.ring_segments = 10
	return _place(parent, mesh, pos, material)


func _sphere(parent: Node3D, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	return _place(parent, mesh, pos, material)
