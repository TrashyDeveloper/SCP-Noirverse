class_name ElevatorButton
extends StaticBody3D
## The button panel inside an elevator car.

@export var elevator_path: NodePath = ^"../.."


func _elevator() -> Elevator:
	return get_node(elevator_path) as Elevator


func get_interaction_prompt(_actor: Node) -> String:
	return _elevator().get_status_text()


func interact(actor: Node) -> void:
	if actor != null and actor.has_method("is_disarmed") and actor.is_disarmed():
		return
	_elevator().toggle()
