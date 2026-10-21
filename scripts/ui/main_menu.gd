extends Control
## Title screen. Behind the menu a camera drifts slowly down a corridor of a
## facility built from a fixed map seed, while music plays.

const GAME_PATH := "res://scenes/game/game.tscn"
const CREDITS_PATH := "res://scenes/ui/credits.tscn"
## Always the same backdrop map.
const BACKDROP_SEED := 1947
const TIPS: Array[String] = [
	"Hold a keycard in your hand (Ctrl) to open doors.",
	"Terminals tell you more if you hold a Containment 2 or Admin keycard.",
	"SCP-914: put items in the Intake booth, set the dial, turn the key.",
	"Barricade Kits keep doors shut until someone tears the planks down.",
	"Escapes, escorts and disarms earn influence for your side.",
	"Hold the right mouse button to aim down the sights.",
	"The facility layout changes every round.",
	"Steam vents in Heavy Containment burst every few seconds.",
]

var _time := 0.0
var _start: Transform3D
var _tip := 0
var _tip_time := 0.0

@onready var camera: Camera3D = $Backdrop/Camera3D
@onready var overlay: NoirOverlay = $NoirOverlay


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var settings := GameSettings.load_settings()
	settings.apply_global()
	settings.apply_overlay(overlay)
	# Menu music: see scripts/core/music.gd for where to put your own track.
	var music := AudioStreamPlayer.new()
	music.stream = Music.load_track("menu")
	music.bus = &"Music"
	add_child(music)
	music.play()
	var facility := FacilityGenerator.new().generate(BACKDROP_SEED)
	$Backdrop.add_child(facility)
	_start = facility.get_meta("showcase")
	camera.transform = _start
	%Play.pressed.connect(_on_play_pressed)
	%Settings.pressed.connect(_on_settings_pressed)
	%Credits.pressed.connect(_on_credits_pressed)
	%Quit.pressed.connect(get_tree().quit)
	_tip = randi() % TIPS.size()
	%Tip.text = "TIP:  " + TIPS[_tip]
	%Play.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	# Drift slowly down the hall and back, looking around a little.
	var forward := -_start.basis.z
	var along := (1.0 - cos(_time * 0.05)) * 9.0
	camera.position = _start.origin + forward * along + Vector3(0, sin(_time * 0.4) * 0.05, 0)
	camera.rotation = _start.basis.get_euler() + Vector3(sin(_time * 0.13) * 0.04, sin(_time * 0.09) * 0.3, 0)
	_tip_time += delta
	if _tip_time > 7.0:
		_tip_time = 0.0
		_tip = (_tip + 1) % TIPS.size()
		%Tip.text = "TIP:  " + TIPS[_tip]


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_PATH)


func _on_settings_pressed() -> void:
	var menu := SettingsMenu.new()
	add_child(menu)
	menu.changed.connect(func(s: GameSettings): s.apply_overlay(overlay))
	menu.closed.connect(func(): %Settings.grab_focus())


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file(CREDITS_PATH)
