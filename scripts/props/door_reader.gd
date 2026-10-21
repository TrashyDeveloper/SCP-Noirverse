class_name DoorReader
extends StaticBody3D
## The card reader next to a door. Pressing E on it works like pressing E on
## the door, and a thrown keycard hitting it swipes the card.


func _get_door() -> Door:
	return get_parent() as Door


func get_interaction_prompt(actor: Node) -> String:
	return _get_door().get_interaction_prompt(actor)


func interact(actor: Node) -> void:
	_get_door().interact(actor)


func on_card_hit(card: ItemData) -> void:
	_get_door().on_card_swiped(card)
