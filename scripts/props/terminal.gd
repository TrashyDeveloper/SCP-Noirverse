class_name Terminal
extends StaticBody3D
## A computer terminal. Look at it and press E to read what it knows.
##
## The terminal itself knows nothing: the RoundManager answers, and decides
## how much the person asking may see (most people only get a little).

signal use_requested(terminal: Terminal, actor: Node)

## What this terminal shows: "status", "personnel", "scp999" or "scp055".
@export var kind := "status"


func _ready() -> void:
	PropBuilder.add_box(self, Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.45), PropBuilder.mat("metal_dark"))
	var screen := Node3D.new()
	screen.position = Vector3(0, 1.25, -0.02)
	screen.rotation.x = deg_to_rad(-15)
	add_child(screen)
	PropBuilder.add_box(screen, Vector3.ZERO, Vector3(0.62, 0.44, 0.06), PropBuilder.mat("metal"))
	PropBuilder.add_box(screen, Vector3(0, 0, -0.032), Vector3(0.54, 0.36, 0.01), PropBuilder.mat("screen_blue"))
	var text := PropBuilder.add_label(screen, "SITE-NET\n> _", Vector3(0, 0, -0.04), 24, 0.0022)
	text.rotation.y = PI
	text.modulate = Color(0.75, 0.9, 1.0)
	PropBuilder.add_box(self, Vector3(0, 1.02, -0.18), Vector3(0.5, 0.03, 0.18), PropBuilder.mat("metal"))
	PropBuilder.add_shape(self, Vector3(0, 0.75, 0), Vector3(0.62, 1.5, 0.5))


func get_interaction_prompt(actor: Node) -> String:
	if PropBuilder.is_disarmed(actor):
		return "You are disarmed"
	return "[E] Use terminal"


func interact(actor: Node) -> void:
	if not PropBuilder.is_disarmed(actor):
		use_requested.emit(self, actor)
