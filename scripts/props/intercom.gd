class_name Intercom
extends StaticBody3D
## The facility intercom: press E to speak to the whole site. The
## RoundManager handles cooldowns and who gets priority.

signal use_requested(intercom: Intercom, actor: Node)

## Optional: func(intercom, actor) -> String, set by the RoundManager.
var prompt_provider: Callable

var _status: Label3D


func _ready() -> void:
	PropBuilder.add_box(self, Vector3(0, 0, 0), Vector3(1.0, 0.12, 0.6), PropBuilder.mat("metal_dark"))
	PropBuilder.add_box(self, Vector3(0, 0.25, 0.05), Vector3(0.04, 0.4, 0.04), PropBuilder.mat("metal"))
	PropBuilder.add_box(self, Vector3(0, 0.47, -0.02), Vector3(0.1, 0.1, 0.16), PropBuilder.mat("metal_dark"))
	PropBuilder.add_box(self, Vector3(-0.35, 0.07, -0.15), Vector3(0.12, 0.04, 0.12), PropBuilder.mat("screen_blue"))
	_status = PropBuilder.add_label(self, "READY", Vector3(0.2, 0.08, -0.12), 28)
	_status.rotation.x = -PI / 2
	_status.modulate = Color(0.6, 0.9, 1.0)
	PropBuilder.add_shape(self, Vector3(0, 0.25, 0), Vector3(1.0, 0.6, 0.6))


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func get_interaction_prompt(actor: Node) -> String:
	if PropBuilder.is_disarmed(actor):
		return "You are disarmed"
	if prompt_provider.is_valid():
		return prompt_provider.call(self, actor)
	return "[E] Use intercom"


func interact(actor: Node) -> void:
	if not PropBuilder.is_disarmed(actor):
		use_requested.emit(self, actor)
