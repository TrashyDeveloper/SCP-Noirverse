class_name DeathScreen
extends CanvasLayer
## "You died" screen. Like the pause menu, it only asks; Game decides.

signal restart_requested
signal main_menu_requested


func _ready() -> void:
	visible = false
	%Restart.pressed.connect(restart_requested.emit)
	%MainMenu.pressed.connect(main_menu_requested.emit)


## `respawns` = reinforcement waves are on (the player will come back).
func show_death(cause: String, respawns := false) -> void:
	%Cause.text = cause
	if respawns:
		%Cause.text += "\n\nYou will return with the next reinforcement wave\n(the timer is in the top right)."
	%Restart.text = "Skip to a new round" if respawns else "New round"
	visible = true
	# Fade in.
	var panel: Control = $Panel
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 1.5).set_delay(0.6)
	%Restart.grab_focus()
