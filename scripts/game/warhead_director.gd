class_name WarheadDirector
extends Node
## Everything you see and hear when a warhead is armed (presentation only;
## the RoundManager decides who dies):
##   - its music track, timed so the bomb goes off just before the track ends
##   - the announcer voice (start, 60 s, 30 s, 10 s, cancel)
##   - the ground shaking, harder the closer you are to the danger: Alpha and
##     Delta shake the facility far more than the Surface; Gamma shakes the
##     Surface around its reactor
##   - dust falling from the ceilings, flickering lights, distant rumbles
##   - the explosion itself: fireballs, flashes, smoke columns rising out of
##     the gates, a supernova from the Gamma reactor

## Music files (see README): res://assets/audio/music/warheads/<name>.ogg
const TRACKS := {
	WarheadConsole.Warhead.ALPHA: "AlphaWarheadEnhancedAudio",
	WarheadConsole.Warhead.DELTA: "DeltaWarheadEnhancedAudio",
	WarheadConsole.Warhead.GAMMA: "GammaWarheadEnhancedAudio",
}
## The bomb goes off this many seconds before its track ends (fade-out).
const TAIL := 6.0
const LINES := {
	WarheadConsole.Warhead.ALPHA: "Attention, all personnel. The Alpha Warhead emergency detonation sequence has been engaged. The underground facility will be detonated in T minus %d seconds. All personnel must evacuate to the surface immediately.",
	WarheadConsole.Warhead.DELTA: "Attention. Delta Warhead detonation sequence engaged from the surface. All underground sections of the site will be destroyed in %d seconds. Evacuate now.",
	WarheadConsole.Warhead.GAMMA: "Warning. The Gamma Warhead has been activated. The reactor core is going critical. This is not a drill. The entire site, including the surface, will be destroyed in %d seconds. This sequence cannot be stopped.",
}

var round_manager: RoundManager
var level: Node3D
var hud: Hud
var overlay: NoirOverlay
var announcer: Announcer
## func() -> CharacterController: the local player (may be null).
var get_player: Callable

## The black (or white) hole left by the Gamma Warhead, once it exists.
var singularity: Singularity
var _tracks := {}
var _music: AudioStreamPlayer
var _music_warhead := -1
var _milestones := {}
var _impulse := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()
var _dust: CPUParticles3D
var _rumble_time := 4.0
var _flicker_time := 0.0
var _dimmed: Array[Light3D] = []


func setup(manager: RoundManager, level_node: Node3D, hud_node: Hud, noir: NoirOverlay, voice: Announcer, player_getter: Callable) -> void:
	round_manager = manager
	level = level_node
	hud = hud_node
	overlay = noir
	announcer = voice
	get_player = player_getter
	_noise.frequency = 2.5
	for warhead in TRACKS:
		var stream := Music.load_track("warheads/" + TRACKS[warhead], false, false)
		if stream != null:
			_tracks[warhead] = stream
			round_manager.countdown_override[warhead] = maxf(stream.get_length() - TAIL, 20.0)
	round_manager.warhead_changed.connect(_on_warhead_changed)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)


func has_music(warhead: int) -> bool:
	return _tracks.has(warhead)


func _on_warhead_changed(warhead: int, state: int, time_left: float) -> void:
	match state:
		RoundManager.WarheadState.COUNTDOWN:
			_milestones[warhead] = {}
			_play_music(warhead)
			announcer.say(LINES[warhead] % int(time_left), true)
		RoundManager.WarheadState.IDLE:
			if _music_warhead == warhead:
				_fade_music()
			announcer.say("%s detonation cancelled. Restarting systems." % RoundManager.WARHEADS[warhead].name, true)
		RoundManager.WarheadState.DETONATED:
			announcer.stop()
			_explode(warhead)


func _play_music(warhead: int) -> void:
	if not _tracks.has(warhead):
		return
	_music.stop()
	_music.volume_db = 0.0
	_music.stream = _tracks[warhead]
	_music.play()
	_music_warhead = warhead


func _fade_music() -> void:
	var t := create_tween()
	t.tween_property(_music, "volume_db", -40.0, 2.0)
	t.tween_callback(_music.stop)
	_music_warhead = -1


# --- Every frame: announcements, shaking, dust, flicker ------------------------

func _process(delta: float) -> void:
	_time += delta
	_impulse = maxf(_impulse - delta * 0.35, 0.0)
	var player: CharacterController = get_player.call() if get_player.is_valid() else null
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var underground := cam.global_position.y < -5.0
	var shake := _impulse
	var any_countdown := false
	for warhead in round_manager.warhead_state:
		if round_manager.warhead_state[warhead] != RoundManager.WarheadState.COUNTDOWN:
			continue
		any_countdown = true
		var left: float = round_manager.warhead_time_left[warhead]
		var total := round_manager.get_countdown(warhead)
		var progress := clampf(1.0 - left / total, 0.0, 1.0)
		_announce_milestones(warhead, left)
		# The Gamma music swells as the reactor overheats.
		if warhead == WarheadConsole.Warhead.GAMMA and _music_warhead == warhead:
			_music.volume_db = lerpf(-3.0, 4.0, progress)
		shake += _shake_for(warhead, progress, cam.global_position, underground)
		if underground and warhead != WarheadConsole.Warhead.GAMMA:
			_flicker(delta, progress)
			_rumbles(delta, progress)
	_apply_shake(cam, shake)
	_update_dust(cam, underground and shake > 0.035 and any_countdown)
	if not any_countdown and not _dimmed.is_empty():
		_restore_lights()


func _announce_milestones(warhead: int, left: float) -> void:
	var said: Dictionary = _milestones.get(warhead, {})
	for mark in [60, 30, 10]:
		if left <= mark and left > mark - 1.5 and not said.has(mark) and round_manager.get_countdown(warhead) > mark + 5:
			said[mark] = true
			var cancel: float = RoundManager.WARHEADS[warhead].cancel_until
			var line := "%d seconds until detonation." % mark
			if mark == 10:
				line = "Ten seconds. Brace for impact."
			elif cancel < 0.0 or left < cancel:
				line += " The sequence can no longer be stopped."
			announcer.say(line, true)
	_milestones[warhead] = said


## How hard the ground shakes for the camera because of one warhead.
func _shake_for(warhead: int, progress: float, pos: Vector3, underground: bool) -> float:
	var build := pow(progress, 1.6)
	if warhead == WarheadConsole.Warhead.GAMMA:
		var reactor := level.find_child("GammaReactor", true, false) as Node3D
		var near := 1.0
		if reactor != null:
			near = clampf(1.0 - pos.distance_to(reactor.global_position) / 160.0, 0.15, 1.0)
		return (0.01 + build * 0.12) * (0.35 if underground else near)
	# Alpha / Delta: the facility shakes, the Surface only trembles.
	return (0.015 + build * 0.11) if underground else build * 0.018


func _apply_shake(cam: Camera3D, amount: float) -> void:
	amount = clampf(amount, 0.0, 1.5)
	var t := _time * 25.0
	cam.h_offset = _noise.get_noise_2d(t, 0.0) * amount * 0.35
	cam.v_offset = _noise.get_noise_2d(0.0, t) * amount * 0.35
	cam.rotation.z = _noise.get_noise_2d(t, t) * amount * 0.08


func _update_dust(cam: Camera3D, on: bool) -> void:
	if _dust == null:
		_dust = CPUParticles3D.new()
		_dust.amount = 70
		_dust.lifetime = 2.2
		_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_dust.emission_box_extents = Vector3(5, 0.2, 5)
		_dust.direction = Vector3.DOWN
		_dust.spread = 10.0
		_dust.gravity = Vector3(0, -2.5, 0)
		_dust.initial_velocity_min = 0.2
		_dust.initial_velocity_max = 1.0
		_dust.scale_amount_min = 0.5
		_dust.scale_amount_max = 1.5
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.05, 0.05)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(0.7, 0.68, 0.62, 0.7)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = m
		_dust.mesh = mesh
		_dust.local_coords = false
		add_child(_dust)
	_dust.emitting = on
	if on:
		_dust.global_position = cam.global_position + Vector3(0, 2.0, 0)


func _flicker(delta: float, progress: float) -> void:
	_flicker_time -= delta
	if _flicker_time > 0.0:
		return
	_flicker_time = randf_range(0.15, 0.6) / (0.4 + progress)
	_restore_lights()
	var lights := get_tree().get_nodes_in_group("facility_lights")
	for i in int(2 + progress * 10):
		var light := lights.pick_random() as Light3D
		if light != null and light.global_position.y < -5.0 and level.is_ancestor_of(light):
			light.set_meta("energy", light.light_energy)
			light.light_energy *= 0.1
			_dimmed.append(light)


func _restore_lights() -> void:
	for light in _dimmed:
		if is_instance_valid(light) and light.has_meta("energy"):
			light.light_energy = light.get_meta("energy")
	_dimmed.clear()


func _rumbles(delta: float, progress: float) -> void:
	_rumble_time -= delta
	if _rumble_time > 0.0:
		return
	_rumble_time = randf_range(5.0, 11.0) * (1.2 - progress)
	Sfx.play_2d(self, "explosion", -20.0 + progress * 8.0, randf_range(0.3, 0.45))
	_impulse = maxf(_impulse, 0.08 + progress * 0.2)


# --- The explosions ---------------------------------------------------------------

func _explode(warhead: int) -> void:
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam != null else Vector3.ZERO
	var underground := cam_pos.y < -5.0
	if warhead == WarheadConsole.Warhead.GAMMA:
		_supernova()
		return
	var center := _epicenter(warhead)
	# Deep booms everywhere; much stronger down below.
	Sfx.play_2d(self, "explosion", 8.0 if underground else 2.0, 0.42)
	get_tree().create_timer(0.35).timeout.connect(func(): Sfx.play_2d(self, "explosion", 4.0 if underground else -2.0, 0.3))
	if underground:
		_impulse = 1.4
		hud.flash_white(2.5)
		overlay.color_burst(1.0)
		_fireball(center, 90.0, Color(1.0, 0.55, 0.2), 3.0)
		_fireball(cam_pos + (center - cam_pos).normalized() * 6.0, 18.0, Color(1.0, 0.7, 0.35), 1.5)
	else:
		_impulse = 0.55
		overlay.color_burst(0.5)
	# Below ground the power dies: most lights go out, the rest glow red.
	for light in get_tree().get_nodes_in_group("facility_lights"):
		if light is Light3D and light.global_position.y < -5.0 and level.is_ancestor_of(light):
			if randf() < 0.85:
				light.visible = false
			else:
				light.light_color = Color(1.0, 0.25, 0.1)
	# Fire and smoke pour out of the gate buildings on the Surface.
	for lift in level.find_children("*", "Elevator", true, false):
		if lift.top_name == "SURFACE":
			var top: Vector3 = lift.global_position + Vector3(0, lift.travel_height, 0)
			_smoke_column(top + Vector3(0, 3, 0))
			_fireball(top + Vector3(0, 2, 0), 9.0, Color(1.0, 0.5, 0.15), 2.0)


func _epicenter(warhead: int) -> Vector3:
	if warhead == WarheadConsole.Warhead.ALPHA:
		var silo := level.find_child("AlphaWarheadSilo", true, false) as Node3D
		if silo != null:
			return silo.global_position + Vector3(0, 2, 0)
	for r in level.get_meta("rooms", []):
		if r.zone == "EZ":
			return r.position + Vector3(0, 2, 0)
	return Vector3(150, -18, 30)


## The Gamma reactor goes supernova: a blinding sphere sweeps over the site,
## a shockwave ring races outwards and all the colours come back at once.
func _supernova() -> void:
	var reactor := level.find_child("GammaReactor", true, false) as Node3D
	var c := reactor.global_position + Vector3(0, GammaReactor.CORE_HEIGHT, 0) if reactor != null else Vector3(156, 5, 92)
	Sfx.play_2d(self, "explosion", 10.0, 0.25)
	Sfx.play_2d(self, "flashbang", 0.0, 0.5)
	get_tree().create_timer(0.6).timeout.connect(func(): Sfx.play_2d(self, "explosion", 8.0, 0.35))
	_impulse = 1.6
	overlay.set_base_saturation(1.0)
	overlay.color_burst(1.0)
	hud.flash_white(6.0)
	_fireball(c, 420.0, Color(0.75, 0.95, 1.0), 5.0)
	_fireball(c, 140.0, Color(1.0, 0.9, 0.6), 2.5)
	# What's left: a black hole - or, rarely, a white hole.
	get_tree().create_timer(1.5).timeout.connect(func():
		singularity = Singularity.new()
		singularity.white = randf() < Singularity.WHITE_CHANCE
		level.add_child(singularity)
		singularity.global_position = c + Vector3(0, 4.0, 0)
		announcer.say("Gravitational anomaly detected." if not singularity.white else "Unknown radiation source detected.", true))
	# Shockwave ring along the ground.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 64
	ring.mesh = torus
	ring.material_override = _glow_material(Color(1.0, 0.95, 0.85, 0.9))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(ring)
	ring.global_position = Vector3(c.x, 1.0, c.z)
	ring.scale = Vector3(1, 3, 1)
	var t := create_tween().set_parallel()
	t.tween_property(ring, "scale", Vector3(320, 30, 320), 4.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(ring.material_override, "albedo_color:a", 0.0, 4.0)
	t.chain().tween_callback(ring.queue_free)
	_smoke_column(c + Vector3(0, 6, 0))


## A glowing sphere that grows to `radius` and fades, with a bright light.
func _fireball(pos: Vector3, radius: float, color: Color, duration: float) -> void:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	ball.mesh = sphere
	ball.material_override = _glow_material(color)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(ball)
	ball.global_position = pos
	ball.scale = Vector3.ONE * 0.5
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 16.0
	light.omni_range = radius * 1.2
	ball.add_child(light)
	var t := create_tween().set_parallel()
	t.tween_property(ball, "scale", Vector3.ONE * radius, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(ball.material_override, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	t.tween_property(light, "light_energy", 0.0, duration * 1.3)
	t.chain().tween_callback(ball.queue_free)


func _smoke_column(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 9.0
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0.6, 0.5, 0)
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.5
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.17, 0.16, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	p.mesh = mesh
	level.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(25.0).timeout.connect(func():
		if is_instance_valid(p):
			p.emitting = false)


func _glow_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	return m
