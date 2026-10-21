class_name Barricade
extends StaticBody3D
## Planks and metal sheets nailed across a closed door. The door can't be
## opened until the barricade is torn down (hold E) or destroyed (shot or
## blown up).

const TEAR_DOWN_TIME := 5.0

@export var max_health := 250.0

var door: Door
var health: Health


func _ready() -> void:
	collision_layer = 0b11
	collision_mask = 0
	var wood := PropBuilder.mat("wood")
	for side: float in [-1.0, 1.0]:
		var z := side * 0.32
		PropBuilder.add_box(self, Vector3(0, 0.6, z), Vector3(2.5, 0.25, 0.06), wood)
		PropBuilder.add_box(self, Vector3(0, -0.4, z), Vector3(2.5, 0.25, 0.06), wood)
		var diag := PropBuilder.add_box(self, Vector3(0, 0.1, z + side * 0.04), Vector3(2.9, 0.22, 0.05), wood)
		diag.rotation.z = 0.6 * side
		PropBuilder.add_box(self, Vector3(-0.5, -0.9, z), Vector3(0.9, 0.7, 0.04), PropBuilder.mat("metal_dark"))
	PropBuilder.add_shape(self, Vector3(0, 0, 0), Vector3(2.4, 2.4, 0.8))
	health = Health.new()
	health.name = "Health"
	health.max_health = max_health
	add_child(health)
	health.died.connect(func(_source: Node): remove())


func remove() -> void:
	if door != null and door.barricade == self:
		door.barricade = null
	queue_free()


func get_interaction_prompt(actor: Node) -> String:
	if PropBuilder.is_disarmed(actor):
		return "Barricaded door"
	return "Barricaded - hold E to tear it down"


func interact(_actor: Node) -> void:
	pass


func get_hold_duration(actor: Node) -> float:
	if PropBuilder.is_disarmed(actor):
		return 0.0
	var fast: bool = actor.has_method("has_perk") and actor.has_perk(&"fast_barricade")
	return TEAR_DOWN_TIME * (0.5 if fast else 1.0)


func complete_hold_action(_actor: Node) -> void:
	remove()
