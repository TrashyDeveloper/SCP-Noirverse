class_name WeaponModels
extends RefCounted
## Detailed firearm models built from simple meshes (cylinders, cones, rings
## and angled blocks), so we need no model files.
##
## Every model points along -Z, with its origin at the pistol grip (where
## the hand holds it). `build()` returns where the muzzle is.

const STEEL := Color(0.16, 0.16, 0.17)
const BLACK := Color(0.055, 0.055, 0.06)
const POLY := Color(0.085, 0.085, 0.09)
const WOOD := Color(0.36, 0.2, 0.1)
const BAKELITE := Color(0.32, 0.14, 0.07)
const OLIVE := Color(0.26, 0.28, 0.17)
const TAN := Color(0.56, 0.48, 0.34)
const BRASS := Color(0.75, 0.58, 0.25)
const GLASS := Color(0.2, 0.35, 0.45)


static func build(id: StringName, root: Node3D) -> Vector3:
	match id:
		&"smg":
			return _smg(root)
		&"vector":
			return _vector(root)
		&"m4":
			return _m4(root)
		&"ak47":
			return _ak47(root)
		&"lmg":
			return _lmg(root)
		&"mg60":
			return _mg60(root)
		&"sniper":
			return _sniper(root)
	return _pistol(root)


## Length of the model (front to back), used for pickup collision boxes.
static func length_of(id: StringName) -> float:
	match id:
		&"smg", &"vector":
			return 0.55
		&"m4", &"ak47":
			return 0.95
		&"lmg":
			return 1.05
		&"mg60", &"sniper":
			return 1.2
	return 0.26


# --- Models -------------------------------------------------------------------

static func _pistol(r: Node3D) -> Vector3:
	# Slide with a bevelled top, cocking serrations and an ejection port.
	_box(r, Vector3(0.03, 0.03, 0.19), Vector3(0, 0.034, -0.045), STEEL, 0.75, 0.3)
	_box(r, Vector3(0.022, 0.008, 0.19), Vector3(0, 0.052, -0.045), STEEL, 0.75, 0.3)
	for i in 6:
		_box(r, Vector3(0.032, 0.024, 0.0025), Vector3(0, 0.036, 0.022 + i * 0.006), BLACK)
	_box(r, Vector3(0.002, 0.012, 0.035), Vector3(0.0155, 0.042, -0.02), BLACK)
	# Barrel crown sticking out of the slide.
	_cyl(r, 0.0085, 0.012, Vector3(0, 0.034, -0.143), STEEL, 0.8)
	_cyl(r, 0.0045, 0.013, Vector3(0, 0.034, -0.144), BLACK)
	# Polymer frame with an accessory rail.
	_box(r, Vector3(0.028, 0.02, 0.15), Vector3(0, 0.011, -0.06), POLY)
	for i in 3:
		_box(r, Vector3(0.024, 0.006, 0.008), Vector3(0, -0.002, -0.08 - i * 0.016), POLY)
	# Trigger guard (a stretched ring) and trigger.
	_ring(r, 0.016, 0.0035, Vector3(0, -0.012, -0.035), POLY, Vector3(0, 0, PI / 2), Vector3(1, 1, 1.35))
	_box(r, Vector3(0.005, 0.02, 0.005), Vector3(0, -0.008, -0.03), BLACK, 0.5, 0.5, Vector3(0.35, 0, 0))
	# Angled grip with textured panels and the magazine base plate.
	var grip := _pivot(r, Vector3(0, -0.005, 0.02), Vector3(0.3, 0, 0))
	_box(grip, Vector3(0.03, 0.1, 0.044), Vector3(0, -0.05, 0), POLY)
	_box(grip, Vector3(0.033, 0.06, 0.028), Vector3(0, -0.05, 0.002), BLACK, 0.0, 0.95)
	_box(grip, Vector3(0.034, 0.012, 0.05), Vector3(0, -0.104, 0.0), STEEL, 0.6)
	# Sights and hammer.
	_box(r, Vector3(0.004, 0.007, 0.005), Vector3(0, 0.06, -0.128), STEEL)
	_box(r, Vector3(0.007, 0.008, 0.006), Vector3(-0.0065, 0.06, 0.04), STEEL)
	_box(r, Vector3(0.007, 0.008, 0.006), Vector3(0.0065, 0.06, 0.04), STEEL)
	_box(r, Vector3(0.01, 0.014, 0.01), Vector3(0, 0.046, 0.055), STEEL, 0.7, 0.3, Vector3(-0.4, 0, 0))
	return Vector3(0, 0.034, -0.155)


static func _smg(r: Node3D) -> Vector3:
	# Round receiver tube and handguard with grip ridges.
	_cyl(r, 0.025, 0.26, Vector3(0, 0.04, -0.06), STEEL, 0.6)
	_cyl(r, 0.031, 0.12, Vector3(0, 0.035, -0.16), POLY)
	for i in 4:
		_ring(r, 0.031, 0.003, Vector3(0, 0.035, -0.12 - i * 0.025), BLACK, Vector3(PI / 2, 0, 0))
	_cyl(r, 0.009, 0.07, Vector3(0, 0.04, -0.255), STEEL, 0.8)
	_cyl(r, 0.012, 0.03, Vector3(0, 0.04, -0.29), BLACK)
	# Sights: hooded front post and a rotary drum rear sight.
	_box(r, Vector3(0.012, 0.012, 0.2), Vector3(0, 0.07, -0.06), STEEL)
	_ring(r, 0.012, 0.003, Vector3(0, 0.082, -0.19), STEEL, Vector3(PI / 2, 0, 0))
	_cyl(r, 0.012, 0.03, Vector3(0, 0.083, 0.04), STEEL, 0.5, Vector3(0, 0, PI / 2))
	# Cocking handle tube on the left.
	_cyl(r, 0.006, 0.12, Vector3(-0.026, 0.06, -0.15), STEEL)
	_cyl(r, 0.005, 0.03, Vector3(-0.042, 0.06, -0.2), BLACK, 0.3, Vector3(0, 0, PI / 2))
	# Curved magazine.
	_curved_mag(r, Vector3(0, 0.0, -0.075), 4, Vector3(0.022, 0.05, 0.034), 0.1, BLACK)
	_grip(r, Vector3(0, 0.0, 0.025), POLY)
	_ring(r, 0.017, 0.0035, Vector3(0, -0.006, -0.02), POLY, Vector3(0, 0, PI / 2), Vector3(1, 1, 1.4))
	# Retractable stock: two rods and a butt plate.
	for x: float in [-0.017, 0.017]:
		_cyl(r, 0.005, 0.17, Vector3(x, 0.045, 0.15), STEEL, 0.8)
	_box(r, Vector3(0.05, 0.085, 0.018), Vector3(0, 0.03, 0.235), BLACK)
	return Vector3(0, 0.04, -0.31)


static func _vector(r: Node3D) -> Vector3:
	# Angular upper and the slanted lower housing.
	_box(r, Vector3(0.036, 0.05, 0.3), Vector3(0, 0.045, -0.07), POLY)
	_box(r, Vector3(0.038, 0.13, 0.07), Vector3(0, -0.015, -0.13), POLY, 0.1, 0.7, Vector3(0.55, 0, 0))
	_box(r, Vector3(0.04, 0.012, 0.25), Vector3(0, 0.074, -0.06), BLACK)
	for i in 10:
		_box(r, Vector3(0.026, 0.006, 0.006), Vector3(0, 0.083, -0.17 + i * 0.022), BLACK)
	# Straight magazine in front of the trigger.
	_box(r, Vector3(0.026, 0.15, 0.036), Vector3(0, -0.085, -0.06), BLACK, 0.1, 0.6, Vector3(0.05, 0, 0))
	_grip(r, Vector3(0, 0.005, 0.035), POLY)
	_ring(r, 0.017, 0.0035, Vector3(0, -0.005, -0.005), POLY, Vector3(0, 0, PI / 2), Vector3(1, 1, 1.2))
	# Suppressor.
	_cyl(r, 0.012, 0.04, Vector3(0, 0.04, -0.24), STEEL, 0.8)
	_cyl(r, 0.02, 0.15, Vector3(0, 0.04, -0.33), BLACK, 0.4)
	for i in 3:
		_ring(r, 0.02, 0.0025, Vector3(0, 0.04, -0.28 - i * 0.04), STEEL, Vector3(PI / 2, 0, 0))
	# Red-dot sight.
	_box(r, Vector3(0.024, 0.012, 0.04), Vector3(0, 0.086, -0.02), BLACK)
	_cyl(r, 0.017, 0.05, Vector3(0, 0.108, -0.02), BLACK, 0.4)
	_cyl(r, 0.013, 0.052, Vector3(0, 0.108, -0.02), GLASS, 0.9)
	# Folding skeleton stock.
	_box(r, Vector3(0.02, 0.012, 0.19), Vector3(0, 0.06, 0.17), BLACK)
	_box(r, Vector3(0.02, 0.012, 0.17), Vector3(0, 0.0, 0.17), BLACK, 0.1, 0.6, Vector3(-0.18, 0, 0))
	_box(r, Vector3(0.04, 0.09, 0.02), Vector3(0, 0.03, 0.265), BLACK)
	return Vector3(0, 0.04, -0.41)


static func _m4(r: Node3D) -> Vector3:
	# Upper and lower receivers.
	_box(r, Vector3(0.032, 0.045, 0.2), Vector3(0, 0.045, -0.025), STEEL, 0.5)
	_box(r, Vector3(0.03, 0.038, 0.15), Vector3(0, 0.006, -0.03), BLACK)
	_box(r, Vector3(0.026, 0.006, 0.2), Vector3(0, 0.07, -0.025), BLACK)
	for i in 8:
		_box(r, Vector3(0.028, 0.004, 0.006), Vector3(0, 0.075, -0.11 + i * 0.022), STEEL)
	_box(r, Vector3(0.012, 0.012, 0.03), Vector3(0, 0.062, 0.085), STEEL)
	# Octagonal free-floating handguard with a top rail.
	_cyl(r, 0.028, 0.26, Vector3(0, 0.045, -0.255), BLACK, 0.3, Vector3.ZERO, 8)
	_box(r, Vector3(0.016, 0.008, 0.26), Vector3(0, 0.076, -0.255), BLACK)
	for i in 5:
		_box(r, Vector3(0.006, 0.014, 0.03), Vector3(0.029, 0.045, -0.18 - i * 0.04), STEEL)
	# Barrel, front sight and birdcage flash hider.
	_cyl(r, 0.009, 0.14, Vector3(0, 0.045, -0.45), STEEL, 0.8)
	_box(r, Vector3(0.008, 0.04, 0.012), Vector3(0, 0.075, -0.4), BLACK, 0.3, 0.6, Vector3(-0.3, 0, 0))
	_cyl(r, 0.012, 0.045, Vector3(0, 0.045, -0.535), BLACK, 0.5, Vector3.ZERO, 6)
	# Magazine (slightly curved) and grip.
	_curved_mag(r, Vector3(0, -0.01, -0.07), 3, Vector3(0.022, 0.055, 0.06), 0.08, POLY)
	_grip(r, Vector3(0, -0.01, 0.025), POLY)
	_ring(r, 0.018, 0.003, Vector3(0, -0.016, -0.02), BLACK, Vector3(0, 0, PI / 2), Vector3(1, 1, 1.5))
	# Magnified optic on mounts.
	for z: float in [-0.06, 0.03]:
		_box(r, Vector3(0.022, 0.03, 0.012), Vector3(0, 0.09, z), BLACK)
	_cyl(r, 0.02, 0.13, Vector3(0, 0.115, -0.015), BLACK, 0.4)
	_cyl(r, 0.02, 0.035, Vector3(0, 0.115, -0.095), BLACK, 0.4, Vector3.ZERO, 16, 0.026)
	_cyl(r, 0.025, 0.002, Vector3(0, 0.115, -0.113), GLASS, 0.9)
	# Buffer tube and a collapsible stock.
	_cyl(r, 0.014, 0.17, Vector3(0, 0.035, 0.16), BLACK, 0.5)
	_box(r, Vector3(0.042, 0.075, 0.13), Vector3(0, 0.022, 0.22), POLY)
	_box(r, Vector3(0.04, 0.03, 0.08), Vector3(0, -0.02, 0.24), POLY, 0.1, 0.7, Vector3(0.35, 0, 0))
	_box(r, Vector3(0.046, 0.1, 0.012), Vector3(0, 0.012, 0.29), BLACK, 0.0, 0.95)
	return Vector3(0, 0.045, -0.56)


static func _ak47(r: Node3D) -> Vector3:
	# Stamped receiver with its rounded dust cover.
	_box(r, Vector3(0.034, 0.05, 0.27), Vector3(0, 0.03, -0.025), STEEL, 0.6)
	_cyl(r, 0.018, 0.25, Vector3(0, 0.055, -0.02), STEEL, 0.6)
	_box(r, Vector3(0.002, 0.012, 0.08), Vector3(0.0175, 0.045, -0.04), BLACK)
	_box(r, Vector3(0.004, 0.008, 0.07), Vector3(0.019, 0.022, 0.02), STEEL, 0.6, 0.4, Vector3(0, 0, 0.1))
	# Wooden handguards and the gas tube.
	_box(r, Vector3(0.042, 0.042, 0.17), Vector3(0, 0.028, -0.245), WOOD, 0.0, 0.6)
	_cyl(r, 0.014, 0.18, Vector3(0, 0.07, -0.245), WOOD, 0.0)
	_cyl(r, 0.008, 0.08, Vector3(0, 0.07, -0.37), STEEL, 0.7)
	# Barrel, front sight block and slanted muzzle brake.
	_cyl(r, 0.0095, 0.24, Vector3(0, 0.045, -0.44), STEEL, 0.8)
	_box(r, Vector3(0.018, 0.04, 0.02), Vector3(0, 0.07, -0.52), STEEL, 0.6)
	_ring(r, 0.009, 0.0025, Vector3(0, 0.09, -0.52), STEEL, Vector3(PI / 2, 0, 0))
	_cyl(r, 0.013, 0.035, Vector3(0, 0.045, -0.57), BLACK, 0.5)
	_box(r, Vector3(0.026, 0.01, 0.02), Vector3(0, 0.06, -0.582), BLACK, 0.5, 0.5, Vector3(0.5, 0, 0))
	# Rear sight leaf and selector lever.
	_box(r, Vector3(0.02, 0.012, 0.04), Vector3(0, 0.075, -0.13), STEEL)
	_box(r, Vector3(0.002, 0.01, 0.12), Vector3(0.0185, 0.03, -0.03), STEEL, 0.6, 0.4, Vector3(-0.12, 0, 0))
	# The banana magazine.
	_curved_mag(r, Vector3(0, -0.005, -0.075), 6, Vector3(0.024, 0.032, 0.062), 0.14, BAKELITE)
	_grip(r, Vector3(0, -0.01, 0.03), WOOD)
	_ring(r, 0.018, 0.003, Vector3(0, -0.016, -0.015), STEEL, Vector3(0, 0, PI / 2), Vector3(1, 1, 1.5))
	# Tapered wooden stock.
	_box(r, Vector3(0.036, 0.055, 0.15), Vector3(0, 0.012, 0.18), WOOD, 0.0, 0.6, Vector3(0.12, 0, 0))
	_box(r, Vector3(0.04, 0.115, 0.07), Vector3(0, -0.012, 0.29), WOOD, 0.0, 0.6, Vector3(0.18, 0, 0))
	_box(r, Vector3(0.042, 0.12, 0.01), Vector3(0, -0.018, 0.328), STEEL, 0.6, 0.4, Vector3(0.18, 0, 0))
	return Vector3(0, 0.045, -0.6)


static func _lmg(r: Node3D) -> Vector3:
	# Big receiver with a feed cover.
	_box(r, Vector3(0.05, 0.07, 0.3), Vector3(0, 0.03, -0.02), STEEL, 0.5)
	_box(r, Vector3(0.054, 0.022, 0.17), Vector3(0, 0.076, 0.0), BLACK)
	_cyl(r, 0.006, 0.06, Vector3(0, 0.09, 0.07), STEEL, 0.6, Vector3(0, 0, PI / 2))
	# Ammo box under the gun and the belt running into it.
	_box(r, Vector3(0.085, 0.1, 0.11), Vector3(-0.01, -0.06, -0.05), OLIVE, 0.1, 0.7)
	_box(r, Vector3(0.09, 0.012, 0.115), Vector3(-0.01, -0.005, -0.05), OLIVE.darkened(0.3))
	for i in 5:
		_cyl(r, 0.0045, 0.03, Vector3(-0.038, 0.0 + i * 0.008, -0.05 + i * 0.004), BRASS, 0.9, Vector3(0, 0, PI / 2))
	# Barrel with a perforated cooling shroud.
	_cyl(r, 0.026, 0.26, Vector3(0, 0.035, -0.3), BLACK, 0.4)
	for i in 6:
		for side: float in [-1.0, 1.0]:
			_box(r, Vector3(0.004, 0.012, 0.018), Vector3(side * 0.025, 0.035, -0.2 - i * 0.035), Color(0, 0, 0))
	_cyl(r, 0.012, 0.22, Vector3(0, 0.035, -0.53), STEEL, 0.8)
	_cyl(r, 0.018, 0.05, Vector3(0, 0.035, -0.66), BLACK, 0.5, Vector3.ZERO, 16, 0.012)
	# Carry handle (a half ring) and a folded bipod.
	_ring(r, 0.035, 0.006, Vector3(0, 0.075, -0.2), BLACK, Vector3(0, 0, PI / 2), Vector3(1, 1, 1.4))
	for x: float in [-0.012, 0.012]:
		_cyl(r, 0.005, 0.2, Vector3(x, 0.005, -0.48), STEEL, 0.7)
	_grip(r, Vector3(0, -0.005, 0.035), POLY)
	# Skeleton stock.
	_box(r, Vector3(0.03, 0.02, 0.2), Vector3(0, 0.05, 0.22), OLIVE)
	_box(r, Vector3(0.03, 0.02, 0.2), Vector3(0, -0.01, 0.22), OLIVE, 0.1, 0.7, Vector3(-0.15, 0, 0))
	_box(r, Vector3(0.045, 0.11, 0.025), Vector3(0, 0.025, 0.325), BLACK)
	return Vector3(0, 0.035, -0.69)


static func _mg60(r: Node3D) -> Vector3:
	# Long receiver and a hinged feed tray cover with a latch.
	_box(r, Vector3(0.046, 0.06, 0.42), Vector3(0, 0.03, 0.0), BLACK, 0.4)
	_box(r, Vector3(0.05, 0.025, 0.2), Vector3(0, 0.072, -0.02), STEEL, 0.6)
	_box(r, Vector3(0.012, 0.02, 0.02), Vector3(0, 0.09, 0.07), STEEL)
	# Barrel with gas cylinder, carry handle and front sight.
	_cyl(r, 0.012, 0.6, Vector3(0, 0.035, -0.5), STEEL, 0.8)
	_cyl(r, 0.01, 0.35, Vector3(0, 0.0, -0.38), STEEL, 0.6)
	_cyl(r, 0.022, 0.15, Vector3(0, 0.02, -0.28), POLY)
	_ring(r, 0.04, 0.007, Vector3(0, 0.07, -0.42), BLACK, Vector3(0, 0, PI / 2), Vector3(1, 1, 1.5))
	_box(r, Vector3(0.008, 0.035, 0.012), Vector3(0, 0.065, -0.76), STEEL)
	_cyl(r, 0.017, 0.06, Vector3(0, 0.035, -0.82), BLACK, 0.5, Vector3.ZERO, 16, 0.012)
	# Bipod legs unfolded, with feet.
	for side: float in [-1.0, 1.0]:
		var leg := _pivot(r, Vector3(side * 0.012, 0.0, -0.6), Vector3(0.35, 0, side * 0.3))
		_cyl(leg, 0.006, 0.22, Vector3(0, -0.11, 0), STEEL, 0.7, Vector3(PI / 2, 0, 0))
		_sphere(leg, 0.012, Vector3(0, -0.22, 0), BLACK)
	# Ammo belt hanging from the left side.
	for i in 9:
		var t := float(i) / 8.0
		_cyl(r, 0.0055, 0.035, Vector3(-0.04 - t * 0.04, 0.03 - t * t * 0.18, -0.03 + t * 0.03), BRASS, 0.9, Vector3(0, 0, PI / 2))
		_box(r, Vector3(0.012, 0.006, 0.01), Vector3(-0.04 - t * 0.04, 0.03 - t * t * 0.18, -0.03 + t * 0.03), BLACK)
	_grip(r, Vector3(0, -0.005, 0.06), POLY)
	_ring(r, 0.018, 0.003, Vector3(0, -0.01, 0.015), BLACK, Vector3(0, 0, PI / 2), Vector3(1, 1, 1.5))
	# Long solid stock.
	_box(r, Vector3(0.044, 0.08, 0.24), Vector3(0, 0.015, 0.33), POLY)
	_box(r, Vector3(0.046, 0.11, 0.015), Vector3(0, 0.01, 0.455), BLACK)
	return Vector3(0, 0.035, -0.86)


static func _sniper(r: Node3D) -> Vector3:
	# Composite stock: forend, grip area and a butt with a cheek riser.
	_box(r, Vector3(0.042, 0.045, 0.34), Vector3(0, 0.005, -0.2), TAN, 0.0, 0.8)
	_box(r, Vector3(0.04, 0.05, 0.12), Vector3(0, 0.0, 0.07), TAN, 0.0, 0.8, Vector3(0.25, 0, 0))
	_box(r, Vector3(0.04, 0.12, 0.17), Vector3(0, -0.015, 0.24), TAN, 0.0, 0.8)
	_box(r, Vector3(0.036, 0.03, 0.12), Vector3(0, 0.055, 0.22), TAN.darkened(0.15), 0.0, 0.8)
	_box(r, Vector3(0.044, 0.125, 0.015), Vector3(0, -0.015, 0.33), BLACK, 0.0, 0.95)
	# Round receiver and bolt with a knob.
	_cyl(r, 0.017, 0.21, Vector3(0, 0.038, -0.02), STEEL, 0.75)
	_cyl(r, 0.004, 0.05, Vector3(0.03, 0.04, 0.06), STEEL, 0.8, Vector3(0, 0, PI / 2))
	_sphere(r, 0.009, Vector3(0.055, 0.04, 0.06), BLACK)
	# Tapered barrel and muzzle brake.
	_cyl(r, 0.012, 0.5, Vector3(0, 0.038, -0.37), STEEL, 0.85, Vector3.ZERO, 16, 0.008)
	_cyl(r, 0.014, 0.05, Vector3(0, 0.038, -0.645), BLACK, 0.5, Vector3.ZERO, 6)
	for side: float in [-1.0, 1.0]:
		_box(r, Vector3(0.004, 0.008, 0.012), Vector3(side * 0.013, 0.038, -0.645), Color(0, 0, 0))
	# Scope: tube, bells, turrets, lenses and rings.
	_cyl(r, 0.015, 0.3, Vector3(0, 0.09, -0.03), BLACK, 0.4)
	_cyl(r, 0.015, 0.07, Vector3(0, 0.09, -0.215), BLACK, 0.4, Vector3.ZERO, 20, 0.024)
	_cyl(r, 0.02, 0.05, Vector3(0, 0.09, 0.14), BLACK, 0.4, Vector3.ZERO, 20, 0.015)
	_cyl(r, 0.021, 0.002, Vector3(0, 0.09, -0.251), GLASS, 0.95)
	_cyl(r, 0.009, 0.025, Vector3(0, 0.112, -0.03), BLACK, 0.4, Vector3(PI / 2, 0, 0))
	_cyl(r, 0.009, 0.025, Vector3(0.022, 0.09, -0.03), BLACK, 0.4, Vector3(0, 0, PI / 2))
	for z: float in [-0.1, 0.04]:
		_ring(r, 0.017, 0.004, Vector3(0, 0.09, z), STEEL, Vector3(PI / 2, 0, 0))
		_box(r, Vector3(0.014, 0.04, 0.012), Vector3(0, 0.062, z), STEEL)
	# Small box magazine.
	_box(r, Vector3(0.026, 0.05, 0.07), Vector3(0, -0.035, -0.04), BLACK)
	_ring(r, 0.017, 0.003, Vector3(0, -0.01, 0.015), BLACK, Vector3(0, 0, PI / 2), Vector3(1, 1, 1.4))
	return Vector3(0, 0.038, -0.68)


# --- Parts --------------------------------------------------------------------

## A pistol grip, angled back.
static func _grip(r: Node3D, pos: Vector3, color: Color) -> void:
	var g := _pivot(r, pos, Vector3(0.3, 0, 0))
	_box(g, Vector3(0.03, 0.095, 0.042), Vector3(0, -0.048, 0), color, 0.0, 0.85)
	_box(g, Vector3(0.032, 0.05, 0.03), Vector3(0, -0.05, 0.004), color.darkened(0.25), 0.0, 0.95)


## A magazine made of `segments` blocks that curve forward.
static func _curved_mag(r: Node3D, top: Vector3, segments: int, size: Vector3, curve: float, color: Color) -> void:
	var pos := top
	for k in segments:
		var angle := -curve * k
		_box(r, size, pos + Vector3(0, -size.y / 2, 0), color, 0.2, 0.6, Vector3(angle, 0, 0))
		pos += Vector3(0, -cos(angle) * size.y * 0.95, -sin(-angle) * size.y * 0.95)
	_box(r, Vector3(size.x * 1.15, 0.008, size.z * 1.05), pos + Vector3(0, 0.002, 0), color.darkened(0.4), 0.2, 0.6, Vector3(-curve * segments, 0, 0))


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if color == GLASS:
		m.emission_enabled = true
		m.emission = Color(0.1, 0.2, 0.3)
	return m


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, metallic: float, roughness: float, rot := Vector3.ZERO) -> MeshInstance3D:
	mesh.material = _material(color, metallic, roughness)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation = rot
	parent.add_child(m)
	return m


static func _pivot(parent: Node3D, pos: Vector3, rot: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	return n


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metallic := 0.2, roughness := 0.55, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, color, metallic, roughness, rot)


## A cylinder lying along Z (unless `rot` turns it). `top_radius` < 0 means
## the same as `radius`; a different value makes a cone (the -Z end).
static func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color, metallic := 0.3,
		rot := Vector3.ZERO, segments := 16, top_radius := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = length
	mesh.radial_segments = segments
	mesh.rings = 1
	# A CylinderMesh stands along Y; tip it over so it points along -Z.
	var m := _add(parent, mesh, pos, color, metallic, 0.4)
	m.rotation = rot if rot != Vector3.ZERO else Vector3(-PI / 2, 0, 0)
	return m


static func _ring(parent: Node3D, radius: float, thickness: float, pos: Vector3, color: Color, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 24
	mesh.ring_segments = 8
	var m := _add(parent, mesh, pos, color, 0.4, 0.5, rot)
	m.scale = scale
	return m


static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	return _add(parent, mesh, pos, color, 0.3, 0.5)
