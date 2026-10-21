class_name Health
extends Node
## Hit points for anything that can be hurt (characters, training dummies...).
## Add a child node named "Health" with this script to make something damageable.
##
## Also supports a temporary shield (absorbs damage first and slowly fades)
## and healing over time.

signal changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var max_health := 100.0
## Shield points lost per second.
@export var shield_decay := 1.5

var current := 0.0
var shield := 0.0
var _regen_per_second := 0.0
var _regen_time_left := 0.0


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	if shield > 0.0:
		shield = maxf(shield - shield_decay * delta, 0.0)
		changed.emit(current, max_health)
	if _regen_time_left > 0.0:
		var step := minf(delta, _regen_time_left)
		_regen_time_left -= step
		heal(_regen_per_second * step)


func is_dead() -> bool:
	return current <= 0.0


## `source` is whoever caused the damage (a character, a hazard...), or null.
func take_damage(amount: float, source: Node = null) -> void:
	if is_dead() or amount <= 0.0:
		return
	var absorbed := minf(shield, amount)
	shield -= absorbed
	current = maxf(current - (amount - absorbed), 0.0)
	damaged.emit(amount, source)
	changed.emit(current, max_health)
	if is_dead():
		_regen_time_left = 0.0
		shield = 0.0
		died.emit(source)


## Returns how much was actually healed.
func heal(amount: float) -> float:
	if is_dead():
		return 0.0
	var before := current
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)
	return current - before


## Heals `amount` spread over `duration` seconds (replaces earlier regen).
func heal_over_time(amount: float, duration: float) -> void:
	if duration <= 0.0:
		heal(amount)
		return
	_regen_per_second = amount / duration
	_regen_time_left = duration


func add_shield(amount: float) -> void:
	shield = maxf(shield, amount)
	changed.emit(current, max_health)


func reset() -> void:
	current = max_health
	shield = 0.0
	_regen_time_left = 0.0
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
