class_name HazardZone
extends Area3D
## Hurts any character standing inside it (e.g. sparking exposed wiring).

@export var damage_per_second := 25.0
## Shown on the death screen if this kills you.
@export var cause_of_death := "Electrocuted by exposed wiring"


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		var health := Health.find_on(body)
		if health != null:
			health.take_damage(damage_per_second * delta, self)
