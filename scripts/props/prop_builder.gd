class_name PropBuilder
extends RefCounted
## Small helpers for props that build their own simple box visuals in code.


static func mat(material_name: String) -> Material:
	return load("res://resources/materials/%s.tres" % material_name)


static func add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = material
	m.position = pos
	parent.add_child(m)
	return m


static func add_shape(body: CollisionObject3D, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)
	return col


static func add_label(parent: Node3D, text: String, pos: Vector3, font_size: int, pixel := 0.003) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = font_size
	l.pixel_size = pixel
	l.outline_size = 0
	parent.add_child(l)
	return l


static func is_disarmed(actor: Node) -> bool:
	return actor != null and actor.has_method("is_disarmed") and actor.is_disarmed()


## The keycard an actor holds in their hands (or null).
static func held_card(actor: Node) -> ItemData:
	if actor == null or not actor.has_method("get_held_item"):
		return null
	var held: ItemInstance = actor.get_held_item()
	if held == null or held.data.kind != ItemData.Kind.KEYCARD:
		return null
	return held.data
