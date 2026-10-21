class_name DeathScreen
extends CanvasLayer
## "You died" screen. Like the pause menu, it only asks; Game decides.

signal restart_requested
signal main_menu_requested


func _ready() -> void:
	visible = false
	%Restart.pressed.connect(restart_requested.emit)
	%MainMenu.pressed.connect(main_menu_requested.emit)


func show_death(cause: String) -> void:
	%Cause.text = cause
	visible = true
	# Fade in.
	var panel: Control = $Panel
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 1.5).set_delay(0.6)
	%Restart.grab_focus()
