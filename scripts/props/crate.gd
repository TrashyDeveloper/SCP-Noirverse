class_name Crate
extends StaticBody3D
## A wooden crate that can be shot or blown apart. Sometimes there is
## something inside.

@export var size := Vector3.ONE
@export var max_health := 60.0
@export var contents: Array[String] = []

var health: Health


func _ready() -> void:
	# Layer 1 (world: blocks movement) + layer 2 (so grenades hurt it).
	collision_layer = 0b11
	collision_mask = 0
	var wood := PropBuilder.mat("wood")
	PropBuilder.add_box(self, Vector3.ZERO, size, wood)
	for s: float in [-1.0, 1.0]:
		PropBuilder.add_box(self, Vector3(0, s * size.y * 0.3, -size.z / 2 - 0.01), Vector3(size.x * 1.02, 0.1, 0.03), PropBuilder.mat("metal_dark"))
		PropBuilder.add_box(self, Vector3(0, s * size.y * 0.3, size.z / 2 + 0.01), Vector3(size.x * 1.02, 0.1, 0.03), PropBuilder.mat("metal_dark"))
	PropBuilder.add_shape(self, Vector3.ZERO, size)
	health = Health.new()
	health.name = "Health"
	health.max_health = max_health
	add_child(health)
	health.died.connect(_on_broken)


func _on_broken(_source: Node) -> void:
	var pickup_scene: PackedScene = load("res://scenes/items/item_pickup.tscn")
	for id in contents:
		var p: ItemPickup = pickup_scene.instantiate()
		p.item_data = load("res://resources/items/%s.tres" % id)
		get_parent().add_child(p)
		p.global_position = global_position + Vector3(0, 0.2, 0)
	# A few splinters fly off.
	for i in 5:
		var chip := RigidBody3D.new()
		chip.collision_layer = 0
		chip.collision_mask = 1
		PropBuilder.add_box(chip, Vector3.ZERO, Vector3(0.3, 0.06, 0.12), PropBuilder.mat("wood"))
		PropBuilder.add_shape(chip, Vector3.ZERO, Vector3(0.3, 0.06, 0.12))
		get_parent().add_child(chip)
		chip.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
		chip.linear_velocity = Vector3(randf_range(-3, 3), randf_range(2, 4), randf_range(-3, 3))
		chip.get_tree().create_timer(6.0).timeout.connect(chip.queue_free)
	queue_free()
