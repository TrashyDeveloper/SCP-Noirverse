class_name ItemVisuals
extends RefCounted
## Builds simple 3D models for items out of boxes and cylinders, so we need no
## model files. The same model is used for pickups and for the item held in
## your hands. Weapons point along -Z (Godot's "forward").


static func build(data: ItemData) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match data.kind:
		ItemData.Kind.KEYCARD:
			_box(root, Vector3(0.17, 0.008, 0.11), Vector3.ZERO, Color(0.85, 0.85, 0.82))
			_box(root, Vector3(0.172, 0.01, 0.03), Vector3(0, 0, -0.04), data.color)
			_box(root, Vector3(0.025, 0.01, 0.025), Vector3(0.06, 0, 0.03), Color(0.65, 0.6, 0.3), 0.8)
			# Access pips: one small square per level (containment, armory, admin rows).
			var levels := [data.containment_level, data.armory_level, data.admin_level]
			for row in 3:
				for i in levels[row]:
					_box(root, Vector3(0.012, 0.01, 0.012), Vector3(-0.07 + i * 0.016, 0, -0.005 + row * 0.018), Color(0.1, 0.1, 0.1))
			_label(root, data.display_name.to_upper().replace(" KEYCARD", ""), Vector3(0, 0.006, -0.04), 0.0004)
		ItemData.Kind.MEDICAL:
			match data.medical_effect:
				ItemData.MedicalEffect.HEAL_INSTANT:  # first aid kit
					_box(root, Vector3(0.34, 0.2, 0.24), Vector3.ZERO, data.color)
					_box(root, Vector3(0.2, 0.205, 0.06), Vector3(0, 0.002, 0), Color(0.95, 0.95, 0.92))
					_box(root, Vector3(0.06, 0.205, 0.17), Vector3(0, 0.002, 0), Color(0.95, 0.95, 0.92))
					_box(root, Vector3(0.16, 0.03, 0.03), Vector3(0, 0.12, 0), Color(0.15, 0.15, 0.15))
				ItemData.MedicalEffect.HEAL_OVER_TIME:  # pill bottle
					_cylinder(root, 0.035, 0.11, Vector3.ZERO, data.color)
					_cylinder(root, 0.038, 0.025, Vector3(0, 0.065, 0), Color(0.9, 0.9, 0.88))
					_box(root, Vector3(0.05, 0.05, 0.005), Vector3(0, 0, 0.035), Color(0.92, 0.92, 0.9))
				ItemData.MedicalEffect.ADRENALINE:  # auto-injector pen
					var pen := Node3D.new()
					pen.rotation.x = PI / 2
					root.add_child(pen)
					_cylinder(pen, 0.018, 0.16, Vector3.ZERO, Color(0.85, 0.85, 0.82))
					_cylinder(pen, 0.019, 0.04, Vector3(0, -0.08, 0), data.color)
					_cylinder(pen, 0.019, 0.02, Vector3(0, 0.085, 0), Color(0.2, 0.2, 0.2))
		ItemData.Kind.FIREARM:
			var dark := Color(0.12, 0.12, 0.13)
			_box(root, Vector3(0.035, 0.05, 0.22), Vector3(0, 0.03, -0.03), dark, 0.6)  # slide
			_box(root, Vector3(0.032, 0.12, 0.05), Vector3(0, -0.05, 0.05), dark, 0.3)  # grip
			_box(root, Vector3(0.01, 0.03, 0.04), Vector3(0, -0.015, 0.0), dark, 0.6)  # trigger guard
		ItemData.Kind.GRENADE:
			if data.grenade_type == ItemData.GrenadeType.HIGH_EXPLOSIVE:
				var body := _sphere(root, 0.045, Vector3.ZERO, data.color)
				body.scale = Vector3(1, 1.25, 1)
				_cylinder(root, 0.018, 0.03, Vector3(0, 0.065, 0), Color(0.3, 0.3, 0.3), 0.7)
				_box(root, Vector3(0.012, 0.09, 0.006), Vector3(0.025, 0.03, 0.03), Color(0.35, 0.35, 0.35), 0.7)
			else:
				_cylinder(root, 0.03, 0.12, Vector3.ZERO, data.color)
				_cylinder(root, 0.02, 0.025, Vector3(0, 0.07, 0), Color(0.35, 0.35, 0.35), 0.7)
				_box(root, Vector3(0.01, 0.08, 0.006), Vector3(0.02, 0.03, 0.03), Color(0.35, 0.35, 0.35), 0.7)
		ItemData.Kind.ARMOR:
			# A vest: front plate, two shoulder straps; heavier armor is bulkier.
			var bulk := 0.06 + 0.02 * data.armor_tier
			_box(root, Vector3(0.42, 0.5, bulk), Vector3.ZERO, data.color)
			_box(root, Vector3(0.08, 0.04, 0.3), Vector3(-0.13, 0.23, 0.1), data.color.darkened(0.3))
			_box(root, Vector3(0.08, 0.04, 0.3), Vector3(0.13, 0.23, 0.1), data.color.darkened(0.3))
			_box(root, Vector3(0.3, 0.12, bulk + 0.02), Vector3(0, -0.08, 0), data.color.darkened(0.5))
		ItemData.Kind.BARRICADE:
			# A bundle of planks with a strap and a small toolbox.
			for i in 3:
				_box(root, Vector3(0.5, 0.03, 0.09), Vector3(0, -0.04 + i * 0.035, 0), data.color)
			_box(root, Vector3(0.03, 0.12, 0.1), Vector3(0.12, 0, 0), Color(0.15, 0.15, 0.15))
			_box(root, Vector3(0.14, 0.07, 0.07), Vector3(-0.12, 0.09, 0), Color(0.5, 0.15, 0.1), 0.4)
		ItemData.Kind.AMMO:
			var size := get_pickup_size(data)
			_box(root, size, Vector3.ZERO, data.color)
			_box(root, Vector3(size.x + 0.002, size.y * 0.4, size.z + 0.002), Vector3(0, size.y * 0.1, 0), Color(0.88, 0.88, 0.84))
			_label(root, AmmoTypes.display_name(data.ammo_type), Vector3(0, size.y * 0.1, size.z / 2 + 0.002), 0.0006, false)
	return root


## Size of the box used to collide with / aim at the item. A bit bigger than
## the model so small things like keycards are easy to pick up.
static func get_pickup_size(data: ItemData) -> Vector3:
	match data.kind:
		ItemData.Kind.KEYCARD:
			return Vector3(0.22, 0.04, 0.16)
		ItemData.Kind.MEDICAL:
			match data.medical_effect:
				ItemData.MedicalEffect.HEAL_INSTANT:
					return Vector3(0.34, 0.22, 0.24)
				ItemData.MedicalEffect.HEAL_OVER_TIME:
					return Vector3(0.1, 0.16, 0.1)
				_:
					return Vector3(0.1, 0.1, 0.2)
		ItemData.Kind.FIREARM:
			return Vector3(0.08, 0.17, 0.26)
		ItemData.Kind.GRENADE:
			return Vector3(0.12, 0.16, 0.12)
		ItemData.Kind.ARMOR:
			return Vector3(0.44, 0.52, 0.16)
		ItemData.Kind.BARRICADE:
			return Vector3(0.52, 0.16, 0.14)
		ItemData.Kind.AMMO:
			match data.ammo_type:
				AmmoTypes.BUCKSHOT:
					return Vector3(0.14, 0.09, 0.14)
				AmmoTypes.FORTY_FOUR:
					return Vector3(0.2, 0.05, 0.07)
				_:
					return Vector3(0.18, 0.07, 0.1)
	return Vector3(0.15, 0.15, 0.15)


static func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.5
	return mat


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metallic := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, color, metallic)


static func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, metallic := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _add(parent, mesh, pos, color, metallic)


static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _add(parent, mesh, pos, color, 0.2)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, metallic: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, metallic)
	instance.position = pos
	parent.add_child(instance)
	return instance


## Small printed text. `flat` = lying on top of the item, otherwise on the front.
static func _label(parent: Node3D, text: String, pos: Vector3, pixel_size: float, flat := true) -> void:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel_size
	label.font_size = 64
	label.outline_size = 0
	label.modulate = Color(0.08, 0.08, 0.08)
	label.position = pos
	if flat:
		label.rotation.x = -PI / 2
	parent.add_child(label)
