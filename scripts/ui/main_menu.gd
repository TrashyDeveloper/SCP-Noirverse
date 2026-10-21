extends Control
## Title screen. Behind the buttons, a camera slowly looks around a
## facility built from a fixed map seed.

const GAME_PATH := "res://scenes/game/game.tscn"
const CREDITS_PATH := "res://scenes/ui/credits.tscn"
## Always the same backdrop map.
const BACKDROP_SEED := 1947

var _time := 0.0
var _camera_base_yaw := 0.0

@onready var camera: Camera3D = $Backdrop/Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Menu music: see scripts/core/music.gd for where to put your own track.
	var music := AudioStreamPlayer.new()
	music.stream = Music.load_track("menu")
	music.volume_db = -6.0
	add_child(music)
	music.play()
	var facility := FacilityGenerator.new().generate(BACKDROP_SEED)
	$Backdrop.add_child(facility)
	camera.transform = facility.get_meta("showcase")
	_camera_base_yaw = camera.rotation.y
	%Play.pressed.connect(_on_play_pressed)
	%Credits.pressed.connect(_on_credits_pressed)
	%Quit.pressed.connect(get_tree().quit)
	%Play.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	camera.rotation.y = _camera_base_yaw + sin(_time * 0.12) * 0.35


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_PATH)


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file(CREDITS_PATH)
