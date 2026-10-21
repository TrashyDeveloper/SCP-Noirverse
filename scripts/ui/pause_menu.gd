class_name PauseMenu
extends CanvasLayer
## Shown when Esc is pressed in-game. It only *asks* to resume or leave;
## the Game scene decides what that means.

signal resume_requested
signal main_menu_requested
signal settings_requested


func _ready() -> void:
	$Panel/Buttons/Resume.pressed.connect(resume_requested.emit)
	$Panel/Buttons/MainMenu.pressed.connect(main_menu_requested.emit)
	$Panel/Buttons/Settings.pressed.connect(settings_requested.emit)
	$Panel/Buttons/Quit.pressed.connect(get_tree().quit)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		$Panel/Buttons/Resume.grab_focus()
