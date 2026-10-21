class_name AlphaWarheadSilo
extends Node3D
## The Alpha Warhead in its Heavy Containment silo: a missile standing in a
## deep shaft, held by gantry arms and lit by floodlights.
##
## Purely visual: the RoundManager decides (arming is done at the console
## next to the silo). When armed, the gantry arms swing away, the clamps
## let go, red beacons spin, steam pours out and the warhead rises out of
## the shaft while the big screen counts down.
## Origin = floor level at the centre of the shaft.

const IDLE_HEIGHT := -13.6
const ARMED_HEIGHT := -6.2
const WHITE := Color(0.82, 0.82, 0.8)
const DARK := Color(0.1, 0.1, 0.11)
const STEEL := Color(0.3, 0.3, 0.32)

@export var shaft_depth := 14.0

var _missile: Node3D
var _arms: Array[Node3D] = []
var _beacons: Array[Node3D] = []
var _status_lights: Array[MeshInstance3D] = []
var _status_mat: StandardMaterial3D
var _screen: Label3D
var _steam: Array[CPUParticles3D] = []
var _state := 0
var _time_left := 0.0
var _mats := {}
var _tween: Tween


func _ready() -> void:
	add_to_group(&"warhead_listeners")
	_build_shaft_details()
	_build_missile()
	_build_gantry()
	_build_beacons()
	_screen = PropBuilder.add_label(self, "", Vector3(0, 3.6, -5.6), 60, 0.006)
	_screen.modulate = Color(0.5, 1.0, 0.6)
	_set_state(RoundManager.WarheadState.IDLE, 0.0)


## Called by the RoundManager whenever a warhead changes state.
func on_warhead_changed(warhead: int, state: int, time_left: float) -> void:
	if warhead != WarheadConsole.Warhead.ALPHA:
		return
	_set_state(state, time_left)


func _process(delta: float) -> void:
	for i in _beacons.size():
		_beacons[i].rotation.y += delta * (6.0 if _state == RoundManager.WarheadState.COUNTDOWN else 0.0)
	if _state == RoundManager.WarheadState.COUNTDOWN:
		_time_left = maxf(_time_left - delta, 0.0)
		_screen.text = "ALPHA WARHEAD\nDETONATION IN %d:%02d" % [int(_time_left) / 60, int(_time_left) % 60]
		var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		_status_mat.emission_energy_multiplier = 1.0 + blink * 4.0


func _set_state(state: int, time_left: float) -> void:
	var armed := state == RoundManager.WarheadState.COUNTDOWN
	_state = state
	_time_left = time_left
	if _tween != null:
		_tween.kill()
	var t := create_tween().set_parallel()
	_tween = t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_missile, "position:y", ARMED_HEIGHT if armed else IDLE_HEIGHT, 14.0 if armed else 8.0)
	for arm in _arms:
		t.tween_property(arm, "rotation:y", arm.get_meta("open") if armed else 0.0, 3.0)
	for beacon in _beacons:
		beacon.visible = armed
	for steam in _steam:
		steam.emitting = armed
	var color := Color(1.0, 0.15, 0.1) if armed else Color(0.2, 1.0, 0.35)
	if state == RoundManager.WarheadState.DETONATED:
		color = Color(0.3, 0.3, 0.3)
	_status_mat.albedo_color = color
	_status_mat.emission = color
	_status_mat.emission_energy_multiplier = 2.0
	_screen.modulate = color.lightened(0.3)
	match state:
		RoundManager.WarheadState.IDLE:
			_screen.text = "ALPHA WARHEAD\nSTANDBY"
		RoundManager.WarheadState.DETONATED:
			_screen.text = "ALPHA WARHEAD\nDETONATED"


# --- Model ----------------------------------------------------------------------

func _build_missile() -> void:
	_missile = Node3D.new()
	add_child(_missile)
	var m := _missile
	# Lift platform it stands on.
	_cyl(m, 2.2, 0.4, Vector3(0, -0.2, 0), DARK, 32)
	_torus(m, 2.2, 0.08, Vector3(0, 0.0, 0), Color(0.9, 0.75, 0.2))
	for i in 8:
		var a := i * TAU / 8.0
		_box(m, Vector3(0.3, 0.6, 0.5), Vector3(cos(a) * 1.25, 0.3, sin(a) * 1.25), STEEL, a)  # clamps
	# Engine bell and the four fins.
	_cone(m, 0.75, 0.95, 0.9, Vector3(0, 0.45, 0), DARK)
	for i in 4:
		var fin_pivot := Node3D.new()
		fin_pivot.rotation.y = i * PI / 2 + PI / 4
		m.add_child(fin_pivot)
		var fin := PrismMesh.new()
		fin.size = Vector3(1.2, 1.8, 0.08)
		fin.left_to_right = 0.0
		_mesh(fin_pivot, fin, Vector3(1.35, 1.9, 0), DARK)
	# Body: white with dark bands, a hazard band and status lights.
	_cyl(m, 1.05, 6.5, Vector3(0, 4.15, 0), WHITE, 40)
	for y: float in [1.2, 3.0, 5.4, 7.2]:
		_torus(m, 1.06, 0.05, Vector3(0, y, 0), DARK)
	var band := _cyl(m, 1.07, 0.5, Vector3(0, 6.3, 0), WHITE, 40)
	band.material_override = load("res://resources/materials/hazard_stripes.tres")
	_status_mat = StandardMaterial3D.new()
	_status_mat.emission_enabled = true
	for i in 6:
		var a := i * TAU / 6.0
		var light := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.12, 1.4, 0.04)
		light.mesh = lm
		light.material_override = _status_mat
		light.position = Vector3(sin(a) * 1.06, 4.0, cos(a) * 1.06)
		light.rotation.y = a
		m.add_child(light)
		_status_lights.append(light)
	# Warhead cone and a black nose tip.
	_cone(m, 1.05, 0.12, 2.6, Vector3(0, 8.7, 0), WHITE)
	_sphere(m, 0.14, Vector3(0, 10.0, 0), DARK)
	var text := PropBuilder.add_label(m, "A L P H A", Vector3(0, 4.5, -1.08), 90, 0.006)
	text.rotation.z = PI / 2
	text.rotation.y = PI
	text.modulate = Color(0.08, 0.08, 0.08)
	var text2 := PropBuilder.add_label(m, "A L P H A", Vector3(0, 4.5, 1.08), 90, 0.006)
	text2.rotation.z = -PI / 2
	text2.modulate = Color(0.08, 0.08, 0.08)
	_missile.position.y = IDLE_HEIGHT
	# Steam at the base when armed.
	for i in 4:
		var p := CPUParticles3D.new()
		p.position = Vector3(cos(i * PI / 2) * 1.6, 0.2, sin(i * PI / 2) * 1.6)
		p.amount = 30
		p.lifetime = 2.0
		p.direction = Vector3.UP
		p.spread = 20.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 4.0
		p.gravity = Vector3(0, 0.8, 0)
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.5
		var puff := SphereMesh.new()
		puff.radius = 0.3
		puff.height = 0.6
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.9, 0.9, 0.9, 0.18)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material = pm
		p.mesh = puff
		p.emitting = false
		m.add_child(p)
		_steam.append(p)


## Gantry towers in the shaft corners with arms reaching to the missile.
func _build_gantry() -> void:
	for i in 4:
		var a := i * PI / 2 + PI / 4
		var corner := Vector3(cos(a), 0, sin(a)) * 4.6
		_cyl(self, 0.22, shaft_depth, corner + Vector3(0, -shaft_depth / 2, 0), STEEL, 12)
		for y in range(-13, 0, 3):
			_torus(self, 0.24, 0.04, corner + Vector3(0, y, 0), Color(0.9, 0.75, 0.2))
		for y: float in [-9.5, -5.5]:
			var arm := Node3D.new()
			arm.position = corner + Vector3(0, y, 0)
			arm.set_meta("open", 1.3 if i % 2 == 0 else -1.3)
			add_child(arm)
			var dir := -corner.normalized()
			var length := 4.6 - 1.15
			var beam := _box(arm, Vector3(0.25, 0.25, length), dir * length / 2, STEEL)
			beam.rotation.y = atan2(dir.x, dir.z)
			_cyl(arm, 0.08, length, dir * length / 2 + Vector3(0, -0.25, 0), Color(0.6, 0.15, 0.1), 8).rotation = Vector3(PI / 2, atan2(dir.x, dir.z), 0)
			_arms.append(arm)
		# Floodlights pointing into the shaft.
		var flood := SpotLight3D.new()
		flood.position = corner * 0.95 + Vector3(0, -0.6, 0)
		flood.spot_range = 18.0
		flood.spot_angle = 40.0
		flood.light_energy = 3.0
		flood.light_color = Color(1.0, 0.95, 0.85)
		flood.shadow_enabled = true
		add_child(flood)
		flood.look_at(to_global(Vector3(0, -6, 0)), Vector3.UP)
		flood.add_to_group("facility_lights")
		_cyl(self, 0.25, 0.3, corner * 0.95 + Vector3(0, -0.6, 0), DARK, 12)


## Rotating red beacons at the four corners of the shaft (on when armed).
func _build_beacons() -> void:
	for i in 4:
		var a := i * PI / 2 + PI / 4
		var p := Vector3(cos(a), 0, sin(a)) * 5.4 + Vector3(0, 0.0, 0)
		_cyl(self, 0.18, 0.5, p + Vector3(0, 0.25, 0), DARK, 12)
		var beacon := Node3D.new()
		beacon.position = p + Vector3(0, 0.65, 0)
		add_child(beacon)
		var glass := _sphere(self, 0.2, p + Vector3(0, 0.65, 0), Color(1.0, 0.2, 0.1))
		glass.material_override = _glow(Color(1.0, 0.15, 0.1))
		for s: float in [0.0, PI]:
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.15, 0.1)
			spot.light_energy = 6.0
			spot.spot_range = 14.0
			spot.spot_angle = 22.0
			spot.rotation = Vector3(-0.15, s, 0)
			beacon.add_child(spot)
		beacon.visible = false
		_beacons.append(beacon)


## Pipes and hazard rings on the shaft walls.
func _build_shaft_details() -> void:
	for y in range(-12, 0, 4):
		for i in 4:
			var a := i * PI / 2
			var dir := Vector3(cos(a), 0, sin(a))
			_sphere(self, 0.12, dir * 4.4 + Vector3(0, y, 0), Color(1.0, 0.85, 0.6)).material_override = _glow(Color(1.0, 0.8, 0.5))
	for i in 3:
		_cyl(self, 0.15, shaft_depth, Vector3(-4.2 + i * 0.4, -shaft_depth / 2, 4.4), Color(0.4, 0.25, 0.15), 10)
	# A warm work light low in the shaft.
	var low := OmniLight3D.new()
	low.position = Vector3(2.5, -10.0, -2.5)
	low.omni_range = 12.0
	low.light_energy = 2.0
	low.light_color = Color(1.0, 0.85, 0.6)
	add_child(low)


# --- Mesh helpers ---------------------------------------------------------------

func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	return m


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		# Painted metal: only the dark parts look metallic.
		m.metallic = 0.6 if color.get_luminance() < 0.4 else 0.05
		m.roughness = 0.45
		_mats[key] = m
	return _mats[key]


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(color)
	m.position = pos
	parent.add_child(m)
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := _mesh(parent, mesh, pos, color)
	m.rotation.y = yaw
	return m


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, segments := 16) -> MeshInstance3D:
	return _cone(parent, radius, radius, height, pos, color, segments)


func _cone(parent: Node3D, bottom: float, top: float, height: float, pos: Vector3, color: Color, segments := 32) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	return _mesh(parent, mesh, pos, color)


func _torus(parent: Node3D, radius: float, thickness: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 40
	mesh.ring_segments = 8
	return _mesh(parent, mesh, pos, color)


func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	return _mesh(parent, mesh, pos, color)
