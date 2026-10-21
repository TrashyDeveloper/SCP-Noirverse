class_name InteractProxy
extends StaticBody3D
## A clickable part of a bigger machine (a dial, a key, a lever). Its owner
## gives it two functions: `prompt.call(actor) -> String` and
## `action.call(actor)`.

var prompt: Callable
var action: Callable


func get_interaction_prompt(actor: Node) -> String:
	if PropBuilder.is_disarmed(actor):
		return "You are disarmed"
	return prompt.call(actor) if prompt.is_valid() else ""


func interact(actor: Node) -> void:
	if not PropBuilder.is_disarmed(actor) and action.is_valid():
		action.call(actor)
