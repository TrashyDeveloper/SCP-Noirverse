class_name WarheadConsole
extends StaticBody3D
## A control console for a warhead. It doesn't decide anything itself: it
## asks the round (RoundManager) via `use_requested`, and shows whatever
## status text the round gives it.

signal use_requested(console: WarheadConsole, actor: Node)

enum Warhead { DELTA, GAMMA }

@export var warhead := Warhead.DELTA

## Set by the round: func(console, actor) -> String, the text to show.
var prompt_provider: Callable

@onready var status_label: Label3D = $StatusLabel


func _ready() -> void:
	$Title.text = "DELTA WARHEAD" if warhead == Warhead.DELTA else "GAMMA WARHEAD"


func get_interaction_prompt(actor: Node) -> String:
	return prompt_provider.call(self, actor) if prompt_provider.is_valid() else ""


func interact(actor: Node) -> void:
	use_requested.emit(self, actor)


func set_status(text: String) -> void:
	status_label.text = text
