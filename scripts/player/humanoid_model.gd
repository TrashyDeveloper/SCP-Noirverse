class_name HumanoidModel
extends Node3D
## The visible body of a character: a jointed humanoid built from rounded
## meshes, dressed for its class (orange jumpsuit, lab coat, tactical gear...)
## and animated in code (walking, running, aiming, idle breathing, being
## disarmed, dying). It only shows things; the CharacterController decides.
##
## Joints (Node3D pivots) are rotated each frame; the parts hang off them.

const SKIN_TONES: Array[Color] = [
	Color(0.93, 0.78, 0.66), Color(0.82, 0.64, 0.5), Color(0.66, 0.48, 0.35), Color(0.45, 0.32, 0.23), Color(0.3, 0.21, 0.15),
]

var hips: Node3D
var spine: Node3D
var neck: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
## Where a held gun is attached (in front of the chest).
var weapon_mount: Node3D
## Where small held items go (the right hand).
var hand_mount: Node3D

var _layers := 2
var _phase := 0.0
var _time := 0.0
var _dead := false
var _held_kind := -1
var _held_model: Node3D
var _mats := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Builds (or rebuilds) the body dressed for `character_class`.
func dress(character_class: CharacterClass) -> void:
	for child in get_children():
		child.queue_free()
	_held_model = null
	_held_kind = -1
	var outfit := _outfit_for(character_class)
	_build_body(outfit)
	set_layers(_layers)


## Render layers for every mesh (2 = seen by others, 4 = own body hidden
## from our own first-person camera).
func set_layers(mask: int) -> void:
	_layers = mask
	for node in find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = mask


## Shows `item` in the hands (null = empty hands).
func hold(item: ItemData) -> void:
	if _held_model != null:
		_held_model.queue_free()
		_held_model = null
	_held_kind = item.kind if item != null else -1
	if item == null or weapon_mount == null:
		return
	_held_model = ItemVisuals.build(item)
	if item.kind == ItemData.Kind.FIREARM:
		weapon_mount.add_child(_held_model)
	else:
		hand_mount.add_child(_held_model)
		_held_model.scale = Vector3.ONE * 0.9
	set_layers(_layers)


## Called every frame. `local_velocity` is relative to where the body faces
## (x = right, z = backwards), `pitch` is where the head looks.
func animate(delta: float, local_velocity: Vector3, on_floor: bool, pitch: float, disarmed: bool, aiming: bool) -> void:
	if _dead or hips == null:
		return
	_time += delta
	var flat := Vector2(local_velocity.x, local_velocity.z)
	var speed := flat.length()
	var moving := on_floor and speed > 0.3
	var running := speed > 4.5
	var direction := -1.0 if local_velocity.z > 0.3 else 1.0
	_phase += delta * speed * (2.6 if running else 3.1) * direction
	var amp := clampf(speed / 5.0, 0.0, 1.0) * (0.8 if running else 0.55) if moving else 0.0
	var s := sin(_phase)
	var blend := minf(delta * 12.0, 1.0)

	# Legs: swing from the hips, bend the knee on the way back.
	_rot_x(hip_l, s * amp + (0.35 if not on_floor else 0.0), blend)
	_rot_x(hip_r, -s * amp + (0.2 if not on_floor else 0.0), blend)
	_rot_x(knee_l, -maxf(0.0, -cos(_phase)) * amp * 1.4 - (0.6 if not on_floor else 0.05), blend)
	_rot_x(knee_r, -maxf(0.0, cos(_phase)) * amp * 1.4 - (0.4 if not on_floor else 0.05), blend)
	# Sidesteps: turn the hips a little towards the movement.
	var side := clampf(local_velocity.x / 4.0, -1.0, 1.0) * (0.5 if moving else 0.0)
	hips.rotation.y = lerp_angle(hips.rotation.y, -side * direction, blend)
	# Body bob and lean.
	hips.position.y = 0.95 + (absf(sin(_phase)) * 0.04 * amp if moving else 0.0) - (0.03 if running else 0.0)
	var breathe := sin(_time * 1.6) * 0.012
	spine.rotation.x = lerpf(spine.rotation.x, (-0.18 if running else -0.04 * amp) + breathe + pitch * 0.15, blend)
	neck.rotation.x = lerpf(neck.rotation.x, pitch * 0.65, blend)
	spine.rotation.y = lerp_angle(spine.rotation.y, side * direction * 0.6, blend)

	# Arms.
	if disarmed:
		# Hands on the head.
		_pose_arm(shoulder_l, elbow_l, Vector3(2.6, 0, -0.9), 2.2, blend)
		_pose_arm(shoulder_r, elbow_r, Vector3(2.6, 0, 0.9), 2.2, blend)
	elif _held_kind == ItemData.Kind.FIREARM:
		var raise := 1.35 + pitch * 0.9 if aiming or not running else 0.6
		_pose_arm(shoulder_r, elbow_r, Vector3(raise, 0, -0.12), 0.45, blend)
		_pose_arm(shoulder_l, elbow_l, Vector3(raise + 0.15, 0, 0.6), 0.6, blend)
		weapon_mount.rotation.x = lerpf(weapon_mount.rotation.x, (pitch * 0.85 if aiming or not running else -0.5), blend)
		weapon_mount.position.y = 0.36 if aiming else 0.3
	elif _held_kind != -1:
		_pose_arm(shoulder_r, elbow_r, Vector3(0.7 + pitch * 0.4, 0, -0.1), 0.9, blend)
		_pose_arm(shoulder_l, elbow_l, Vector3(-s * amp * 0.9, 0, -0.08), 0.25, blend)
	else:
		var sway := sin(_time * 1.6 + 1.0) * 0.03
		_pose_arm(shoulder_l, elbow_l, Vector3(-s * amp * 0.9 + sway, 0, -0.08), 0.2 + amp * 0.5, blend)
		_pose_arm(shoulder_r, elbow_r, Vector3(s * amp * 0.9 + sway, 0, 0.08), 0.2 + amp * 0.5, blend)


## Falls over backwards and goes limp.
func die() -> void:
	if _dead:
		return
	_dead = true
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	t.tween_property(self, "rotation", Vector3(PI / 2 - 0.05, 0, 0.15 * side), 0.7)
	t.tween_property(self, "position:y", 0.12, 0.7)
	if shoulder_l != null:
		t.tween_property(shoulder_l, "rotation", Vector3(2.0, 0, 0.9), 0.6)
		t.tween_property(shoulder_r, "rotation", Vector3(1.2, 0, -1.1), 0.6)
		t.tween_property(elbow_l, "rotation:x", 0.3, 0.6)
		t.tween_property(neck, "rotation", Vector3(-0.3, 0.5 * side, 0), 0.6)
		t.tween_property(hip_l, "rotation:x", 0.25, 0.6)
		t.tween_property(knee_r, "rotation:x", -0.7, 0.6)


func _rot_x(joint: Node3D, target: float, blend: float) -> void:
	joint.rotation.x = lerpf(joint.rotation.x, target, blend)


func _pose_arm(shoulder: Node3D, elbow: Node3D, shoulder_rot: Vector3, elbow_bend: float, blend: float) -> void:
	shoulder.rotation.x = lerpf(shoulder.rotation.x, shoulder_rot.x, blend)
	shoulder.rotation.z = lerpf(shoulder.rotation.z, shoulder_rot.z, blend)
	elbow.rotation.x = lerpf(elbow.rotation.x, elbow_bend, blend)


# --- Outfits ------------------------------------------------------------------

## Colours and accessories for a class.
func _outfit_for(c: CharacterClass) -> Dictionary:
	var id := String(c.id) if c != null else "class_d"
	var main: Color = c.color if c != null else Color(0.85, 0.45, 0.15)
	var o := {
		"skin": SKIN_TONES[_rng.randi() % SKIN_TONES.size()],
		"shirt": main, "pants": main, "shoes": Color(0.08, 0.08, 0.08), "hair": _hair_color(),
		"gloves": null, "acc": [],
	}
	if id == "class_d":
		o.acc = ["jumpsuit", "number", "shaved" if _rng.randf() < 0.5 else "short_hair"]
		o.number = "D-%04d" % _rng.randi_range(1000, 9999)
	elif id == "scientist":
		o.shirt = Color(0.7, 0.78, 0.86)
		o.pants = Color(0.18, 0.18, 0.2)
		o.acc = ["lab_coat", "tie", "glasses" if _rng.randf() < 0.6 else "", "badge", "short_hair"]
	elif id == "janitor":
		o.shirt = Color(0.32, 0.38, 0.45)
		o.pants = o.shirt
		o.gloves = Color(0.8, 0.7, 0.15)
		o.acc = ["cap", "overalls", "short_hair"]
	elif id == "zone_manager":
		o.shirt = Color(0.88, 0.88, 0.86)
		o.pants = Color(0.16, 0.16, 0.18)
		o.acc = ["suit", "tie", "badge", "short_hair", "glasses" if _rng.randf() < 0.4 else ""]
	elif id == "containment_specialist":
		o.shirt = Color(0.82, 0.74, 0.3)
		o.pants = o.shirt
		o.gloves = Color(0.15, 0.15, 0.15)
		o.acc = ["hazmat", "respirator"]
	elif id == "facility_guard":
		o.shirt = Color(0.2, 0.24, 0.32)
		o.pants = Color(0.16, 0.18, 0.24)
		o.gloves = Color(0.08, 0.08, 0.08)
		o.acc = ["helmet", "vest", "badge", "short_hair"]
	elif id == "containment_captain":
		o.shirt = Color(0.14, 0.16, 0.22)
		o.pants = Color(0.12, 0.13, 0.17)
		o.gloves = Color(0.08, 0.08, 0.08)
		o.acc = ["officer_cap", "vest", "shoulder_pads", "badge", "short_hair"]
	elif id.begins_with("mtf_") or id.begins_with("chaos_"):
		var chaos := id.begins_with("chaos_")
		o.shirt = main.darkened(0.1)
		o.pants = main.darkened(0.25)
		o.gloves = Color(0.07, 0.07, 0.07)
		o.acc = ["vest", "pouches", "knee_pads", "balaclava"]
		o.acc.append("beanie" if chaos and _rng.randf() < 0.4 else ("helmet_goggles" if chaos else "helmet_visor"))
		if id.ends_with("heavy") or id.ends_with("heavy_gunner") or id.ends_with("suppressor"):
			o.acc += ["shoulder_pads", "heavy_plates"]
		if id.ends_with("medic"):
			o.acc.append("medic_band")
		if id.ends_with("engineer") or id.ends_with("explosives") or chaos:
			o.acc.append("backpack")
		if id.ends_with("commander") or id.ends_with("operations_director"):
			o.acc.append("shoulder_pads")
	else:
		o.acc = ["short_hair"]
	return o


func _hair_color() -> Color:
	return [Color(0.08, 0.06, 0.05), Color(0.25, 0.16, 0.09), Color(0.55, 0.42, 0.25), Color(0.6, 0.6, 0.58)][_rng.randi() % 4]


# --- Building the body --------------------------------------------------------

func _build_body(o: Dictionary) -> void:
	var acc: Array = o.acc
	var skin: Color = o.skin
	var shirt: Color = o.shirt
	var pants: Color = o.pants
	var sleeve: Color = Color(0.92, 0.92, 0.9) if acc.has("lab_coat") else (Color(0.22, 0.22, 0.25) if acc.has("suit") else shirt)

	hips = _joint(self, Vector3(0, 0.95, 0))
	# Pelvis.
	_capsule(hips, 0.15, 0.36, Vector3(0, 0.0, 0), pants, Vector3(0, 0, PI / 2), Vector3(1, 1, 0.75))
	_box(hips, Vector3(0.34, 0.05, 0.22), Vector3(0, 0.08, 0), Color(0.07, 0.07, 0.07))  # belt
	spine = _joint(hips, Vector3(0, 0.08, 0))
	# Chest and belly (a slightly tapered torso).
	_capsule(spine, 0.19, 0.58, Vector3(0, 0.27, 0), shirt, Vector3.ZERO, Vector3(1.05, 1, 0.68))
	_capsule(spine, 0.16, 0.36, Vector3(0, 0.1, 0.0), shirt, Vector3.ZERO, Vector3(1, 1, 0.75))
	neck = _joint(spine, Vector3(0, 0.52, 0))
	_capsule(neck, 0.055, 0.16, Vector3(0, 0.03, 0), skin)
	_build_head(neck, o)

	# Arms.
	shoulder_l = _joint(spine, Vector3(-0.235, 0.44, 0))
	shoulder_r = _joint(spine, Vector3(0.235, 0.44, 0))
	for side: Array in [[shoulder_l, -1.0], [shoulder_r, 1.0]]:
		var sh: Node3D = side[0]
		var sx: float = side[1]
		_sphere(sh, 0.075, Vector3.ZERO, sleeve)
		_capsule(sh, 0.058, 0.32, Vector3(0, -0.14, 0), sleeve)
		var el := _joint(sh, Vector3(0, -0.28, 0))
		_capsule(el, 0.05, 0.28, Vector3(0, -0.13, 0), sleeve)
		var hand_color: Color = o.gloves if o.gloves != null else skin
		_sphere(el, 0.05, Vector3(0, -0.29, 0.0), hand_color, Vector3(0.8, 1.1, 0.95))
		if sx < 0:
			elbow_l = el
		else:
			elbow_r = el
			hand_mount = _joint(el, Vector3(0, -0.31, -0.02))
			hand_mount.rotation.x = -PI / 2
	# Legs.
	hip_l = _joint(hips, Vector3(-0.1, -0.03, 0))
	hip_r = _joint(hips, Vector3(0.1, -0.03, 0))
	for leg: Node3D in [hip_l, hip_r]:
		_capsule(leg, 0.078, 0.46, Vector3(0, -0.21, 0), pants)
		var kn := _joint(leg, Vector3(0, -0.43, 0))
		_capsule(kn, 0.064, 0.44, Vector3(0, -0.2, 0), pants)
		# Shoe: a rounded box pointing forward.
		_capsule(kn, 0.055, 0.26, Vector3(0, -0.44, -0.05), o.shoes, Vector3(PI / 2, 0, 0), Vector3(1.1, 1, 0.75))
		if acc.has("knee_pads"):
			_sphere(kn, 0.07, Vector3(0, -0.02, -0.05), Color(0.08, 0.08, 0.08), Vector3(1, 1.1, 0.6))
		if leg == hip_l:
			knee_l = kn
		else:
			knee_r = kn

	weapon_mount = _joint(spine, Vector3(0.1, 0.3, -0.32))
	_build_clothing(o)


func _build_head(parent: Node3D, o: Dictionary) -> void:
	var acc: Array = o.acc
	var skin: Color = o.skin
	var head := _joint(parent, Vector3(0, 0.17, 0))
	_sphere(head, 0.115, Vector3(0, 0, 0), skin, Vector3(0.95, 1.12, 1.05))
	_sphere(head, 0.08, Vector3(0, -0.06, -0.025), skin, Vector3(1.0, 0.75, 1.0))  # jaw
	_box(head, Vector3(0.025, 0.04, 0.03), Vector3(0, -0.01, -0.115), skin.darkened(0.05))  # nose
	for x: float in [-0.04, 0.04]:
		_sphere(head, 0.014, Vector3(x, 0.025, -0.1), Color(0.95, 0.95, 0.95))
		_sphere(head, 0.008, Vector3(x, 0.025, -0.112), Color(0.05, 0.05, 0.05))
		_box(head, Vector3(0.035, 0.008, 0.01), Vector3(x, 0.05, -0.108), o.hair)  # eyebrows
		_sphere(head, 0.022, Vector3(x * 2.85, 0.0, 0.0), skin, Vector3(0.5, 1.0, 0.8))  # ears
	_box(head, Vector3(0.04, 0.006, 0.01), Vector3(0, -0.055, -0.105), skin.darkened(0.35))  # mouth
	if acc.has("short_hair"):
		_sphere(head, 0.12, Vector3(0, 0.035, 0.012), o.hair, Vector3(0.98, 0.95, 1.05), PI * 0.62)
	elif acc.has("shaved"):
		_sphere(head, 0.118, Vector3(0, 0.03, 0.01), skin.darkened(0.12), Vector3(0.97, 0.95, 1.03), PI * 0.55)
	if acc.has("glasses"):
		for x: float in [-0.042, 0.042]:
			_ring(head, 0.022, 0.003, Vector3(x, 0.025, -0.118), Color(0.05, 0.05, 0.05), Vector3(PI / 2, 0, 0))
		_box(head, Vector3(0.03, 0.004, 0.004), Vector3(0, 0.028, -0.12), Color(0.05, 0.05, 0.05))
	if acc.has("balaclava"):
		_sphere(head, 0.122, Vector3(0, -0.005, 0.0), Color(0.07, 0.07, 0.07), Vector3(0.97, 1.14, 1.05))
		_box(head, Vector3(0.12, 0.035, 0.02), Vector3(0, 0.025, -0.118), o.skin)  # eye slit
		for x: float in [-0.04, 0.04]:
			_sphere(head, 0.012, Vector3(x, 0.025, -0.124), Color(0.05, 0.05, 0.05))
	if acc.has("respirator") or acc.has("hazmat"):
		_sphere(head, 0.135, Vector3(0, 0.0, 0.01), o.shirt, Vector3(1.0, 1.15, 1.05))  # hood
		_box(head, Vector3(0.17, 0.09, 0.03), Vector3(0, 0.03, -0.125), Color(0.3, 0.4, 0.45))  # visor
		_cyl(head, 0.035, 0.05, Vector3(0, -0.05, -0.135), Color(0.1, 0.1, 0.1), Vector3(PI / 2, 0, 0))
		for x: float in [-0.06, 0.06]:
			_cyl(head, 0.03, 0.035, Vector3(x, -0.07, -0.11), Color(0.15, 0.15, 0.15), Vector3(PI / 2, 0, x * 6))
	if acc.has("helmet") or acc.has("helmet_visor") or acc.has("helmet_goggles"):
		var hc := Color(0.1, 0.11, 0.13) if not acc.has("helmet_goggles") else Color(0.3, 0.3, 0.2)
		_sphere(head, 0.14, Vector3(0, 0.04, 0.0), hc, Vector3(1.0, 0.85, 1.08), PI * 0.55)
		_ring(head, 0.135, 0.008, Vector3(0, 0.02, 0.0), hc.darkened(0.3), Vector3.ZERO, Vector3(1, 1, 1.08))
		if acc.has("helmet_visor"):
			_box(head, Vector3(0.2, 0.07, 0.02), Vector3(0, 0.03, -0.14), Color(0.05, 0.08, 0.1))
		if acc.has("helmet_goggles"):
			for x: float in [-0.045, 0.045]:
				_cyl(head, 0.028, 0.03, Vector3(x, 0.1, -0.11), Color(0.12, 0.12, 0.12), Vector3(PI / 2 - 0.4, 0, 0))
		if acc.has("helmet_visor"):
			_cyl(head, 0.012, 0.05, Vector3(0.12, 0.06, -0.04), Color(0.1, 0.1, 0.1), Vector3(0, 0, PI / 2))  # helmet light
	if acc.has("beanie"):
		_sphere(head, 0.128, Vector3(0, 0.045, 0.005), Color(0.15, 0.15, 0.12), Vector3(1.0, 0.85, 1.05), PI * 0.55)
		_ring(head, 0.122, 0.012, Vector3(0, 0.03, 0.0), Color(0.12, 0.12, 0.1), Vector3.ZERO, Vector3(1, 1, 1.05))
	if acc.has("cap"):
		_sphere(head, 0.124, Vector3(0, 0.045, 0.005), o.shirt.darkened(0.2), Vector3(1.0, 0.75, 1.05), PI * 0.55)
		_box(head, Vector3(0.17, 0.012, 0.09), Vector3(0, 0.06, -0.14), o.shirt.darkened(0.3))
	if acc.has("officer_cap"):
		_cyl(head, 0.12, 0.08, Vector3(0, 0.12, 0.0), Color(0.1, 0.11, 0.14), Vector3.ZERO, 1.15)
		_box(head, Vector3(0.16, 0.01, 0.08), Vector3(0, 0.08, -0.13), Color(0.05, 0.05, 0.05))
		_box(head, Vector3(0.04, 0.03, 0.01), Vector3(0, 0.13, -0.135), Color(0.75, 0.62, 0.3))


func _build_clothing(o: Dictionary) -> void:
	var acc: Array = o.acc
	var shirt: Color = o.shirt
	if acc.has("jumpsuit"):
		_box(spine, Vector3(0.07, 0.04, 0.02), Vector3(0.09, 0.4, -0.13), Color(0.92, 0.92, 0.9))  # chest patch
		var number := Label3D.new()
		number.text = o.get("number", "D-0000")
		number.font_size = 14
		number.pixel_size = 0.0028
		number.outline_size = 0
		number.modulate = Color(0.05, 0.05, 0.05)
		number.position = Vector3(0, 0.33, 0.135)
		number.rotation.y = PI
		spine.add_child(number)
		_box(spine, Vector3(0.012, 0.42, 0.01), Vector3(0, 0.27, -0.13), shirt.darkened(0.25))  # zip
	if acc.has("lab_coat"):
		var coat := Color(0.92, 0.92, 0.9)
		_capsule(spine, 0.2, 0.6, Vector3(0, 0.25, 0.005), coat, Vector3.ZERO, Vector3(1.07, 1, 0.72))
		_box(spine, Vector3(0.08, 0.36, 0.01), Vector3(0, 0.3, -0.142), o.shirt)  # shirt showing at the front
		# Coat tails hanging down over the legs.
		for x: float in [-0.1, 0.1]:
			var tail := _box(hips, Vector3(0.22, 0.55, 0.04), Vector3(x, -0.25, -0.11), coat)
			tail.rotation.x = 0.05
			var back := _box(hips, Vector3(0.2, 0.55, 0.04), Vector3(x, -0.25, 0.12), coat)
			back.rotation.x = -0.05
		_box(spine, Vector3(0.05, 0.03, 0.01), Vector3(-0.1, 0.35, -0.142), Color(0.3, 0.35, 0.5))  # pens
	if acc.has("suit"):
		var jacket := Color(0.22, 0.22, 0.25)
		_capsule(spine, 0.2, 0.6, Vector3(0, 0.25, 0.005), jacket, Vector3.ZERO, Vector3(1.07, 1, 0.72))
		_box(spine, Vector3(0.09, 0.3, 0.01), Vector3(0, 0.33, -0.142), o.shirt)
		for x: float in [-0.04, 0.04]:
			var lapel := _box(spine, Vector3(0.04, 0.22, 0.01), Vector3(x, 0.36, -0.145), jacket.darkened(0.2))
			lapel.rotation.z = -x * 6.0
	if acc.has("tie"):
		_box(spine, Vector3(0.035, 0.26, 0.012), Vector3(0, 0.33, -0.15), Color(0.35, 0.08, 0.08))
	if acc.has("badge"):
		_box(spine, Vector3(0.05, 0.07, 0.006), Vector3(0.1, 0.36, -0.145), Color(0.9, 0.9, 0.85))
	if acc.has("overalls"):
		_box(spine, Vector3(0.24, 0.24, 0.02), Vector3(0, 0.22, -0.13), shirt.darkened(0.2))
		for x: float in [-0.08, 0.08]:
			_box(spine, Vector3(0.04, 0.3, 0.02), Vector3(x, 0.4, -0.12), shirt.darkened(0.2))
	if acc.has("hazmat"):
		_capsule(spine, 0.21, 0.62, Vector3(0, 0.25, 0.0), shirt, Vector3.ZERO, Vector3(1.08, 1, 0.75))
		_box(spine, Vector3(0.2, 0.3, 0.12), Vector3(0, 0.3, 0.16), Color(0.2, 0.2, 0.22))  # air pack
		_cyl(spine, 0.05, 0.3, Vector3(0, 0.32, 0.24), Color(0.6, 0.6, 0.62), Vector3.ZERO)
	if acc.has("vest"):
		var vc := shirt.darkened(0.45)
		_box(spine, Vector3(0.38, 0.38, 0.06), Vector3(0, 0.3, -0.13), vc)
		_box(spine, Vector3(0.38, 0.38, 0.06), Vector3(0, 0.3, 0.13), vc)
		for x: float in [-0.13, 0.13]:
			_box(spine, Vector3(0.08, 0.06, 0.28), Vector3(x, 0.5, 0.0), vc)  # straps over the shoulders
	if acc.has("pouches"):
		for x: float in [-0.12, -0.04, 0.04, 0.12]:
			_box(spine, Vector3(0.07, 0.11, 0.06), Vector3(x, 0.17, -0.18), shirt.darkened(0.55))
		_box(spine, Vector3(0.1, 0.06, 0.04), Vector3(-0.1, 0.42, -0.17), Color(0.15, 0.15, 0.15))  # radio
		_cyl(spine, 0.006, 0.12, Vector3(-0.12, 0.5, -0.17), Color(0.1, 0.1, 0.1), Vector3.ZERO)
	if acc.has("heavy_plates"):
		_box(spine, Vector3(0.42, 0.44, 0.09), Vector3(0, 0.29, -0.15), shirt.darkened(0.6))
		_box(hips, Vector3(0.3, 0.16, 0.06), Vector3(0, -0.06, -0.15), shirt.darkened(0.6))  # groin plate
	if acc.has("shoulder_pads"):
		for sh: Node3D in [shoulder_l, shoulder_r]:
			_sphere(sh, 0.1, Vector3(0, 0.02, 0), shirt.darkened(0.5), Vector3(1.1, 0.7, 1.1), PI * 0.5)
	if acc.has("medic_band"):
		_cyl(shoulder_l, 0.062, 0.06, Vector3(0, -0.12, 0), Color(0.95, 0.95, 0.95), Vector3.ZERO)
		_box(shoulder_l, Vector3(0.01, 0.04, 0.012), Vector3(-0.063, -0.12, 0), Color(0.8, 0.1, 0.1))
		_box(shoulder_l, Vector3(0.01, 0.012, 0.04), Vector3(-0.063, -0.12, 0), Color(0.8, 0.1, 0.1))
	if acc.has("backpack"):
		_capsule(spine, 0.14, 0.42, Vector3(0, 0.3, 0.22), shirt.darkened(0.35), Vector3.ZERO, Vector3(1.2, 1, 0.7))
		_box(spine, Vector3(0.22, 0.08, 0.1), Vector3(0, 0.14, 0.24), shirt.darkened(0.45))
	if acc.has("cap") or acc.has("overalls"):
		_box(hips, Vector3(0.12, 0.08, 0.04), Vector3(0.13, -0.04, -0.12), Color(0.15, 0.15, 0.15))  # tool pouch


# --- Mesh helpers -------------------------------------------------------------

func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.75
		_mats[key] = m
	return _mats[key]


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(color)
	m.position = pos
	m.rotation = rot
	m.scale = scale
	parent.add_child(m)
	return m


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 14
	mesh.rings = 4
	return _mesh(parent, mesh, pos, color, rot, scale)


## A sphere; with `cap_angle` < PI only the top part (a dome, for hair/helmets).
func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, scale := Vector3.ONE, cap_angle := PI) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	if cap_angle < PI:
		mesh.is_hemisphere = true
		mesh.height = radius
	return _mesh(parent, mesh, pos, color, Vector3.ZERO, scale)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, pos, color)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, top_scale := 1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * top_scale
	mesh.height = height
	mesh.radial_segments = 14
	return _mesh(parent, mesh, pos, color, rot)


func _ring(parent: Node3D, radius: float, thickness: float, pos: Vector3, color: Color, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 20
	mesh.ring_segments = 6
	return _mesh(parent, mesh, pos, color, rot, scale)
