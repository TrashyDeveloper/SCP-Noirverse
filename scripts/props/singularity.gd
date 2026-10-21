class_name Singularity
extends Node3D
## What the Gamma reactor leaves behind:
##   - "black": a black hole - a black sphere with burning accretion disks
##     that slowly sucks in everything (people, bodies, loose objects) and
##     bends the light around it; whoever reaches it is torn apart;
##   - "white" (5%): a white hole that blazes and slowly pushes everything
##     away from it;
##   - "pulsar" (0.1%): the core collapses into a giant pulsar, a tiny star
##     spinning madly with two enormous beams sweeping the sky.
## 15 seconds after a black or white hole forms, the site's automated
## TEMPORAL STASIS PROTOCOL stops time around it: a field spreads over it in
## which everything freezes and people can only crawl along at a tenth of
## their speed - and the hole stops pulling or pushing.

const WHITE_CHANCE := 0.05
const PULSAR_CHANCE := 0.001
const RADIUS := 6.0
## How far the pull / push reaches (meters) and how strong it is.
const REACH := 170.0
const PULL := 3.2
## Seconds after forming until the time-stop protocol starts.
const STASIS_DELAY := 15.0
const STASIS_RADIUS := 70.0
## How fast time runs inside the stasis field.
const STASIS_TIME := 0.1

## "black", "white" or "pulsar".
var kind := "black"
## Shown on the death screen of someone torn apart by it.
var cause_of_death := "Torn apart by the black hole"
## Time-stop field: 0 = none, grows to 1 while it spreads.
var stasis := 0.0
var _disks: Array[Node3D] = []
var _rays: Node3D
var _beams: Node3D
var _particles_nodes: Array[CPUParticles3D] = []
var _dome: MeshInstance3D
var _clock_rings: Array[Node3D] = []
var _time := 0.0
var _bodies: Array = []
var _frozen_bodies := {}

signal stasis_started


## Picks what the reactor turns into: mostly a black hole, sometimes white,
## very rarely a pulsar.
static func roll_kind() -> String:
	var r := randf()
	if r < PULSAR_CHANCE:
		return "pulsar"
	if r < PULSAR_CHANCE + WHITE_CHANCE:
		return "white"
	return "black"


func _ready() -> void:
	match kind:
		"white":
			_build_white()
		"pulsar":
			_build_pulsar()
		_:
			_build_black()
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 3.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	if kind != "pulsar":
		get_tree().create_timer(STASIS_DELAY).timeout.connect(start_stasis)


## How strongly it bends the light on screen (+ pulls in, - pushes out).
func get_lens_strength() -> float:
	if kind == "pulsar":
		return 0.0
	return (-0.5 if kind == "white" else 0.9) * scale.x * (1.0 - stasis * 0.7)


func get_world_radius() -> float:
	return RADIUS * scale.x


func is_frozen() -> bool:
	return stasis >= 1.0


## Starts the TEMPORAL STASIS PROTOCOL (also from the admin menu).
func start_stasis() -> void:
	if _dome != null or not is_inside_tree():
		return
	_dome = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_dome.mesh = sphere
	_dome.material_override = _unshaded(Color(0.45, 0.65, 1.0, 0.07), true)
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dome.top_level = true
	add_child(_dome)
	_dome.global_position = global_position
	_dome.scale = Vector3.ONE * 0.1
	# Slowly turning "clock" rings marking the field.
	for i in 3:
		var pivot := Node3D.new()
		pivot.top_level = true
		add_child(pivot)
		pivot.global_position = global_position
		pivot.rotation = Vector3(i * 0.9, i * 1.3, 0)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.985
		torus.outer_radius = 1.0
		torus.rings = 96
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = _unshaded(Color(0.6, 0.8, 1.0, 0.6), true)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(ring)
		pivot.scale = Vector3.ONE * 0.1
		_clock_rings.append(pivot)
	var t := create_tween().set_parallel()
	t.tween_property(_dome, "scale", Vector3.ONE * STASIS_RADIUS, 4.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for pivot in _clock_rings:
		t.tween_property(pivot, "scale", Vector3.ONE * STASIS_RADIUS * 1.01, 4.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "stasis", 1.0, 4.0)
	Sfx.play_2d(self, "explosion", -6.0, 0.2)
	Sfx.play_2d(self, "flashbang", -14.0, 0.3)
	stasis_started.emit()


## Is `pos` inside the time-stop field?
func in_stasis(pos: Vector3) -> bool:
	return _dome != null and pos.distance_to(global_position) < STASIS_RADIUS * stasis


func _physics_process(delta: float) -> void:
	_time += delta
	# Inside the field time almost stands still - the hole included.
	var speed := 1.0 - stasis * (1.0 - STASIS_TIME * 0.2)
	for i in _disks.size():
		_disks[i].rotate_object_local(Vector3.UP, delta * (2.5 - i * 0.8) * speed)
	for p in _particles_nodes:
		p.speed_scale = speed
	for pivot in _clock_rings:
		pivot.rotate_object_local(Vector3.UP, delta * 0.05)
	if _rays != null:
		_rays.rotate_y(delta * 0.6 * speed)
		_rays.scale = Vector3.ONE * (1.0 + sin(_time * 3.0 * speed) * 0.08)
	if _beams != null:
		_beams.rotate_y(delta * 9.0)
	_affect_characters(speed)
	_affect_bodies(speed)


## Pulls (or pushes) people and bodies; slows them down inside the field.
func _affect_characters(speed: float) -> void:
	for node in get_tree().get_nodes_in_group(&"characters"):
		var c := node as CharacterController
		if c == null:
			continue
		var in_field := in_stasis(c.global_position)
		c.time_dilation = STASIS_TIME if in_field else 1.0
		if kind == "pulsar" or in_field:
			continue
		var to := global_position - c.global_position
		var d := to.length()
		if d > REACH or d < 0.01:
			continue
		var strength := (PULL * (1.0 - d / REACH) + 60.0 / maxf(d, 4.0)) * scale.x * speed
		if kind == "white":
			c.external_velocity += -to.normalized() * strength * 0.8
		else:
			c.external_velocity += to.normalized() * strength
			if d < get_world_radius() * 1.1 and c.is_alive:
				c.health.take_damage(100000.0, self)


func _affect_bodies(speed: float) -> void:
	if Engine.get_physics_frames() % 30 == 0:
		var scene := get_tree().current_scene
		_bodies = scene.find_children("*", "RigidBody3D", true, false) if scene != null else []
	for node in _bodies:
		if not is_instance_valid(node):
			continue
		var b := node as RigidBody3D
		var frozen := in_stasis(b.global_position)
		if frozen != _frozen_bodies.has(b):
			if frozen:
				_frozen_bodies[b] = true
			else:
				_frozen_bodies.erase(b)
			b.freeze = frozen
		if frozen or kind == "pulsar":
			continue
		var to := global_position - b.global_position
		var d := to.length()
		if d < REACH and d > 0.5:
			var force := to.normalized() * (600.0 / maxf(d, 3.0) + 20.0) * b.mass * speed * (-0.7 if kind == "white" else 1.0)
			b.apply_central_force(force)
			if kind == "black" and d < get_world_radius() * 0.8:
				b.queue_free()


func _exit_tree() -> void:
	for node in get_tree().get_nodes_in_group(&"characters"):
		(node as CharacterController).time_dilation = 1.0


## The pulsar: a tiny, blinding star spinning madly, field lines around it
## and two enormous beams sweeping round.
func _build_pulsar() -> void:
	cause_of_death = "Burned by the pulsar"
	var core := _sphere(2.2, _unshaded(Color(0.85, 0.95, 1.0, 1), false, 6.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := _sphere(4.0, _unshaded(Color(0.4, 0.7, 1.0, 0.25), true))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beams = Node3D.new()
	add_child(_beams)
	var axis := Node3D.new()
	axis.rotation.z = deg_to_rad(35)
	_beams.add_child(axis)
	# Magnetic field lines: loops through the poles.
	for i in 6:
		var loop := Node3D.new()
		loop.rotation.y = i * PI / 6
		axis.add_child(loop)
		var torus := TorusMesh.new()
		torus.inner_radius = 6.8
		torus.outer_radius = 7.0
		torus.rings = 64
		var m := MeshInstance3D.new()
		m.mesh = torus
		m.rotation.x = PI / 2
		m.scale = Vector3(1, 1, 1.6)
		m.material_override = _unshaded(Color(0.5, 0.75, 1.0, 0.35), true)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		loop.add_child(m)
	for s: float in [1.0, -1.0]:
		var beam := CylinderMesh.new()
		beam.top_radius = 0.3 if s > 0 else 14.0
		beam.bottom_radius = 14.0 if s > 0 else 0.3
		beam.height = 260.0
		beam.radial_segments = 24
		var bm := MeshInstance3D.new()
		bm.mesh = beam
		bm.material_override = _unshaded(Color(0.4, 0.8, 1.0, 0.3), true)
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bm.position = Vector3(0, s * 132.0, 0)
		axis.add_child(bm)
		var spot := SpotLight3D.new()
		spot.rotation.x = PI / 2 if s > 0 else -PI / 2
		spot.spot_range = 200.0
		spot.spot_angle = 6.0
		spot.light_energy = 30.0
		spot.light_color = Color(0.6, 0.85, 1.0)
		axis.add_child(spot)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.85, 1.0)
	light.light_energy = 20.0
	light.omni_range = 120.0
	add_child(light)
	var p := _particles(Color(0.6, 0.85, 1.0, 0.8))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 10.0
	p.tangential_accel_min = 20.0
	p.tangential_accel_max = 40.0


func _build_black() -> void:
	var core := _sphere(RADIUS, _unshaded(Color(0, 0, 0, 1), false))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Photon ring hugging the horizon.
	_ring(RADIUS * 1.08, 0.12, Color(1.0, 0.95, 0.85, 1.0), 0.0)
	# Accretion disks: hot inner, cooler outer, slightly tilted.
	_disks.append(_disk(RADIUS * 1.6, RADIUS * 2.6, Color(1.0, 0.75, 0.4, 0.9), 0.12))
	_disks.append(_disk(RADIUS * 2.6, RADIUS * 4.2, Color(1.0, 0.4, 0.15, 0.6), 0.08))
	var halo := _sphere(RADIUS * 1.35, _unshaded(Color(1.0, 0.55, 0.2, 0.15), true))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 8.0
	light.omni_range = 70.0
	add_child(light)
	# Matter spiralling in.
	var p := _particles(Color(1.0, 0.7, 0.4, 0.8))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = RADIUS * 5.0
	p.emission_ring_inner_radius = RADIUS * 3.5
	p.emission_ring_height = 1.0
	p.radial_accel_min = -30.0
	p.radial_accel_max = -18.0
	p.tangential_accel_min = 20.0
	p.tangential_accel_max = 30.0


func _build_white() -> void:
	var core := _sphere(RADIUS, _unshaded(Color(1, 1, 1, 1), false, 8.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := _sphere(RADIUS * 1.6, _unshaded(Color(0.85, 0.95, 1.0, 0.25), true))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring(RADIUS * 1.25, 0.2, Color(1, 1, 1, 1), 0.0)
	# Rays shooting out in all directions.
	_rays = Node3D.new()
	add_child(_rays)
	for i in 24:
		var ray := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.02
		mesh.bottom_radius = 0.5
		mesh.height = 40.0
		ray.mesh = mesh
		ray.material_override = _unshaded(Color(0.9, 0.95, 1.0, 0.35), true)
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		ray.basis = Basis(Quaternion(Vector3.UP, dir))
		ray.position = dir * (RADIUS + 20.0)
		_rays.add_child(ray)
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.97, 1.0)
	light.light_energy = 25.0
	light.omni_range = 140.0
	add_child(light)
	# Matter pouring out.
	var p := _particles(Color(0.9, 0.95, 1.0, 0.8))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = RADIUS
	p.spread = 180.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 25.0
	p.radial_accel_min = 10.0
	p.radial_accel_max = 20.0


func _particles(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 400
	p.lifetime = 4.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _unshaded(color, true)
	p.mesh = mesh
	add_child(p)
	_particles_nodes.append(p)
	return p


func _disk(inner: float, outer: float, color: Color, tilt: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.rotation.x = tilt
	add_child(pivot)
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 64
	mesh.ring_segments = 12
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.scale = Vector3(1, 0.04, 1)
	m.material_override = _unshaded(color, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(m)
	return pivot


func _ring(radius: float, thickness: float, color: Color, tilt: float) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 64
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.rotation.x = PI / 2 + tilt
	m.material_override = _unshaded(color, true, 4.0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Always faces the viewer, like a real photon ring.
	var face := Node3D.new()
	add_child(face)
	face.add_child(m)
	face.set_meta("billboard", true)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for child in get_children():
		if child.has_meta("billboard") and child is Node3D:
			var to := cam.global_position - global_position
			if to.length() > 0.1:
				(child as Node3D).look_at(global_position - to, Vector3.UP)


func _sphere(radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 48
	mesh.rings = 24
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	add_child(m)
	return m


func _unshaded(color: Color, additive: bool, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a) if energy > 1.0 else color
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
