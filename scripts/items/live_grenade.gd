class_name LiveGrenade
extends RigidBody3D
## A thrown, armed grenade. Explodes (or flashes) when its fuse runs out.

## Emitted when the grenade goes off (the game uses it for screen effects).
signal detonated(origin: Vector3, grenade: ItemData)

var data: ItemData
var thrower: Node

var _fuse := 0.0


func _ready() -> void:
	_fuse = data.fuse_time
	add_child(ItemVisuals.build(data))
	var shape := SphereShape3D.new()
	shape.radius = 0.06
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func _physics_process(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0:
		_detonate()


func _detonate() -> void:
	var origin := global_position + Vector3.UP * 0.1
	if data.grenade_type == ItemData.GrenadeType.HIGH_EXPLOSIVE:
		_explode(origin)
	else:
		_flash(origin)
	_spawn_effect(origin)
	detonated.emit(origin, data)
	queue_free()


func _explode(origin: Vector3) -> void:
	# Damage everything with Health in range that isn't behind a wall.
	var hit_healths: Array[Health] = []
	for body in _bodies_in_radius(origin, data.blast_radius):
		var health := Health.find_on(body)
		if health != null and not hit_healths.has(health) and _has_line_of_sight(origin, body):
			hit_healths.append(health)
			var distance := origin.distance_to((body as Node3D).global_position + Vector3.UP * 0.9)
			var falloff := clampf(1.0 - distance / data.blast_radius, 0.0, 1.0)
			health.take_damage(data.blast_damage * falloff * falloff, self)
		elif body is RigidBody3D:
			var push: Vector3 = (body.global_position - origin)
			body.apply_central_impulse(push.normalized() * 4.0 * (1.0 - push.length() / data.blast_radius))


func _flash(origin: Vector3) -> void:
	for body in _bodies_in_radius(origin, data.blast_radius):
		if body.has_method("apply_flash") and _has_line_of_sight(origin, body):
			body.apply_flash(origin, data.blind_duration)


func _bodies_in_radius(origin: Vector3, radius: float) -> Array[Node3D]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), origin)
	query.collision_mask = 0b110
	var found: Array[Node3D] = []
	for result in get_world_3d().direct_space_state.intersect_shape(query, 64):
		if result.collider != self and not found.has(result.collider):
			found.append(result.collider)
	return found


func _has_line_of_sight(origin: Vector3, body: Node3D) -> bool:
	var target := body.global_position + Vector3.UP * 0.9 if body is CharacterBody3D or body is StaticBody3D else body.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## A short bright flash of light and a fading puff.
func _spawn_effect(origin: Vector3) -> void:
	var effect := Node3D.new()
	get_parent().add_child(effect)
	effect.global_position = origin
	var is_flash := data.grenade_type == ItemData.GrenadeType.FLASHBANG
	var light := OmniLight3D.new()
	light.light_energy = 16.0
	# Fire is orange, a flashbang blue-white: visible while the colour returns.
	light.light_color = Color(0.85, 0.92, 1.0) if is_flash else Color(1.0, 0.5, 0.15)
	light.omni_range = data.blast_radius * 2.0
	effect.add_child(light)
	var puff := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.8) if is_flash else Color(1.0, 0.45, 0.08, 0.9)
	sphere.material = mat
	puff.mesh = sphere
	effect.add_child(puff)
	var size := data.blast_radius * 0.6
	var tween := effect.create_tween().set_parallel()
	tween.tween_property(puff, "scale", Vector3.ONE * size, 0.6).set_ease(Tween.EASE_OUT)
	if not is_flash:
		# Fireball turns into dark smoke.
		tween.tween_property(mat, "albedo_color", Color(0.12, 0.12, 0.12, 0.0), 1.4)
	else:
		tween.tween_property(mat, "albedo_color:a", 0.0, 1.2)
	tween.tween_property(light, "light_energy", 0.0, 0.4)
	tween.chain().tween_callback(effect.queue_free)
