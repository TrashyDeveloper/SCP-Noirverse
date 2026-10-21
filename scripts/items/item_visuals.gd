class_name ItemVisuals
extends RefCounted
## Builds simple box-made 3D models for items, so we need no model files.
## The same model is used for pickups on the floor and for the item held in
## your hands. Weapons point along -Z (Godot's "forward").


static func build(data: ItemData) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match data.kind:
		ItemData.Kind.KEYCARD:
			_box(root, Vector3(0.17, 0.008, 0.11), Vector3.ZERO, Color(0.85, 0.85, 0.82))
			# Darker stripe; higher levels get a darker, wider stripe.
			var stripe := 0.025 + 0.01 * data.clearance
			_box(root, Vector3(0.172, 0.01, stripe), Vector3(0, 0, -0.03), data.color)
			_box(root, Vector3(0.03, 0.01, 0.03), Vector3(0.05, 0, 0.025), Color(0.6, 0.55, 0.3), 0.8)
		ItemData.Kind.MEDKIT:
			_box(root, Vector3(0.4, 0.22, 0.28), Vector3.ZERO, Color(0.9, 0.9, 0.88))
			_box(root, Vector3(0.24, 0.225, 0.07), Vector3(0, 0.002, 0), data.color)
			_box(root, Vector3(0.07, 0.225, 0.2), Vector3(0, 0.002, 0), data.color)
			_box(root, Vector3(0.18, 0.03, 0.03), Vector3(0, 0.13, 0), Color(0.15, 0.15, 0.15))
		ItemData.Kind.PISTOL:
			var dark := Color(0.12, 0.12, 0.13)
			_box(root, Vector3(0.035, 0.05, 0.22), Vector3(0, 0.03, -0.03), dark, 0.6)  # slide
			_box(root, Vector3(0.032, 0.12, 0.05), Vector3(0, -0.05, 0.05), dark, 0.3)  # grip
			_box(root, Vector3(0.01, 0.03, 0.04), Vector3(0, -0.015, 0.0), dark, 0.6)  # trigger guard
		ItemData.Kind.AMMO:
			_box(root, Vector3(0.18, 0.1, 0.12), Vector3.ZERO, data.color)
			_box(root, Vector3(0.182, 0.03, 0.122), Vector3(0, 0.02, 0), Color(0.85, 0.85, 0.8))
	return root


## Size of the box used to collide with / aim at the item. A bit bigger than
## the model so small things like keycards are easy to pick up.
static func get_pickup_size(data: ItemData) -> Vector3:
	match data.kind:
		ItemData.Kind.KEYCARD:
			return Vector3(0.22, 0.04, 0.16)
		ItemData.Kind.MEDKIT:
			return Vector3(0.4, 0.24, 0.28)
		ItemData.Kind.PISTOL:
			return Vector3(0.08, 0.17, 0.26)
		_:
			return Vector3(0.18, 0.12, 0.12)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metallic := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.5
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
