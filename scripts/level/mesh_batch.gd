class_name MeshBatch
extends RefCounted
## Collects lots of static boxes and turns them into a few meshes.
##
## Thousands of separate box nodes are slow to create and to draw. Instead,
## every box is written into one mesh per 12 m chunk (one surface per
## material), so the engine can still skip chunks that are off screen or out
## of a light's range. All solid boxes also go into one collision shape.

const CHUNK := 12.0

## Chunk key -> {Material: {verts, normals, uvs}}
var _chunks := {}
var _collision := PackedVector3Array()

# Corners of a unit cube and the four corners of each face (outward winding).
const _FACES := [
	[Vector3(1, 0, 0), [Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
	[Vector3(-1, 0, 0), [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)]],
	[Vector3(0, 1, 0), [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
	[Vector3(0, -1, 0), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
	[Vector3(0, 0, 1), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
	[Vector3(0, 0, -1), [Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)]],
]


## Adds a box of `size` placed with `xf` (its centre and rotation, in level
## coordinates).
func add_box(xf: Transform3D, size: Vector3, material: Material, collide := true) -> void:
	var c := xf.origin
	# Chunks line up with the 12 m map cells (cell centres are multiples of 12).
	var key := Vector3i(floori(c.x / CHUNK + 0.5), floori(c.y / 8.0), floori(c.z / CHUNK + 0.5))
	if not _chunks.has(key):
		_chunks[key] = {}
	var chunk: Dictionary = _chunks[key]
	if not chunk.has(material):
		chunk[material] = {"verts": PackedVector3Array(), "normals": PackedVector3Array(), "uvs": PackedVector2Array()}
	var s: Dictionary = chunk[material]
	var half := size / 2.0
	for face in _FACES:
		var n: Vector3 = face[0]
		var corners: Array = face[1]
		var world := []
		for k in corners:
			world.append(xf * (k * half))
		# UVs in meters, so textures keep their size on boxes of any size.
		var u_axis := Vector3(0, 0, 1) if absf(n.x) > 0.5 else Vector3(1, 0, 0)
		var v_axis := Vector3(0, 0, 1) if absf(n.y) > 0.5 else Vector3(0, 1, 0)
		var normal := (xf.basis * n).normalized()
		for i: int in [0, 2, 1, 0, 3, 2]:
			var local: Vector3 = corners[i] * half
			s.verts.append(world[i])
			s.normals.append(normal)
			s.uvs.append(Vector2(local.dot(u_axis), -local.dot(v_axis)))
			if collide:
				_collision.append(world[i])


static func _casts_shadow(material: Material) -> bool:
	var m := material as BaseMaterial3D
	if m == null:
		return true
	return m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not m.emission_enabled


func is_empty() -> bool:
	return _chunks.is_empty()


## Creates the MeshInstances (and one StaticBody3D for collisions) under
## `parent`. `layers` is the render layer mask for the meshes.
func build(parent: Node3D, layers := 1) -> void:
	var keys := _chunks.keys()
	keys.sort()
	for key: Vector3i in keys:
		var chunk: Dictionary = _chunks[key]
		# Glass and glowing materials don't cast shadows, so they go into a
		# second mesh with shadows turned off.
		for shadows in [true, false]:
			var mesh := ArrayMesh.new()
			for material: Material in chunk:
				if _casts_shadow(material) != shadows:
					continue
				var s: Dictionary = chunk[material]
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = s.verts
				arrays[Mesh.ARRAY_NORMAL] = s.normals
				arrays[Mesh.ARRAY_TEX_UV] = s.uvs
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mesh.surface_set_material(mesh.get_surface_count() - 1, material)
			if mesh.get_surface_count() == 0:
				continue
			var instance := MeshInstance3D.new()
			instance.name = "Chunk_%d_%d_%d%s" % [key.x, key.y, key.z, "" if shadows else "_NoShadow"]
			instance.mesh = mesh
			instance.layers = layers
			if not shadows:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(instance)
	if not _collision.is_empty():
		var body := StaticBody3D.new()
		body.name = "Collision"
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(_collision)
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		parent.add_child(body)
