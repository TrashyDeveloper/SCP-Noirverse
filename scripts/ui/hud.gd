class_name Hud
extends CanvasLayer
## On-screen info for the local player: crosshair, interaction prompt, hints.

@onready var prompt_label: Label = $Prompt


func bind_character(character: CharacterController) -> void:
	character.interaction_prompt_changed.connect(_on_prompt_changed)
	_on_prompt_changed("")


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""
