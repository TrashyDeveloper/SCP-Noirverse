class_name Scp999
extends Node3D
## SCP-999: a friendly orange blob that wanders around its pen and slowly
## heals anyone close to it. Harmless (an "ambient" SCP).

@export var heal_per_second := 3.0
@export var heal_range := 3.0
## Where it may wander, in its parent's coordinates (x/z).
@export var pen := Rect2(-3, -3, 6, 6)

var _target := Vector3.ZERO
var _wait := 0.0
var _time := 0.0
var _body: MeshInstance3D


func _ready() -> void:
	_body = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.7
	_body.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.55, 0.15)
	m.roughness = 0.2
	m.emission_enabled = true
	m.emission = Color(0.4, 0.2, 0.05)
	_body.material_override = m
	_body.position.y = 0.35
	add_child(_body)
	_target = position


func _physics_process(delta: float) -> void:
	_time += delta
	# Squishy bounce.
	var squash := sin(_time * 6.0) * 0.08
	_body.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash)
	if _wait > 0.0:
		_wait -= delta
	else:
		var to := _target - position
		to.y = 0.0
		if to.length() < 0.1:
			_wait = randf_range(1.0, 3.5)
			_target = Vector3(randf_range(pen.position.x, pen.end.x), position.y, randf_range(pen.position.y, pen.end.y))
		else:
			position += to.normalized() * minf(0.9 * delta, to.length())
	if Engine.get_physics_frames() % 10 == 0:
		_heal_nearby(delta * 10.0)


func _heal_nearby(step: float) -> void:
	for node in get_tree().get_nodes_in_group(&"characters"):
		if node is CharacterController and node.is_alive \
				and node.global_position.distance_to(global_position) < heal_range:
			node.health.heal(heal_per_second * step)
