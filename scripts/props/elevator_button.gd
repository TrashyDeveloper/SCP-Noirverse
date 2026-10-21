class_name ElevatorButton
extends StaticBody3D
## A lift button: the panel inside the cabin, or the CALL button at a stop.

enum Action { TRAVEL, CALL_BOTTOM, CALL_TOP }

@export var action := Action.TRAVEL
@export var elevator_path: NodePath


func _elevator() -> Elevator:
	return get_node(elevator_path) as Elevator


func get_interaction_prompt(_actor: Node) -> String:
	return _elevator().get_prompt(action)


func interact(actor: Node) -> void:
	if actor != null and actor.has_method("is_disarmed") and actor.is_disarmed():
		return
	match action:
		Action.TRAVEL:
			_elevator().toggle()
		Action.CALL_BOTTOM:
			_elevator().request(false)
		Action.CALL_TOP:
			_elevator().request(true)
