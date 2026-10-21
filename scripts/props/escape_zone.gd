class_name EscapeZone
extends Area3D
## The facility exit. Characters walking in here may escape (the round
## manager decides who can).

signal character_entered(character: CharacterController)


func _ready() -> void:
	body_entered.connect(func(body: Node3D):
		if body is CharacterController:
			character_entered.emit(body))
