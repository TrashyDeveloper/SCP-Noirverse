class_name Health
extends Node
## Hit points for anything that can be hurt (characters, training dummies...).
## Add a child node named "Health" with this script to make something damageable.

signal changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var max_health := 100.0

var current := 0.0


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return current <= 0.0


## `source` is whoever caused the damage (a character, a hazard...), or null.
func take_damage(amount: float, source: Node = null) -> void:
	if is_dead() or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, source)
	changed.emit(current, max_health)
	if is_dead():
		died.emit(source)


## Returns how much was actually healed.
func heal(amount: float) -> float:
	if is_dead():
		return 0.0
	var before := current
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)
	return current - before


func reset() -> void:
	current = max_health
	changed.emit(current, max_health)


## Finds the Health of whatever `node` belongs to (the hit collider may be a
## child, so we walk up the parents). Returns null if it can't be hurt.
static func find_on(node: Node) -> Health:
	while node != null:
		var health := node.get_node_or_null("Health") as Health
		if health != null:
			return health
		node = node.get_parent()
	return null
