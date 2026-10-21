extends Control
## Title screen. Behind the menu: the Class-D cell block after the Gamma
## Warhead - wrecked, a black hole at the end of the hall, time all but
## stopped, debris creeping towards it (see MenuRuin).

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
var _ruin: MenuRuin
## WATCH mode: menu hidden, just the hall and the hole.
var _watching := false
var _ui_fade: Tween
var _hint: Label

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
	_ruin = MenuRuin.new()
	$Backdrop.add_child(_ruin)
	_ruin.build(facility, _start)
	# Time has stopped here: cold, frozen picture.
	overlay.set_stasis(0.75)
	%Play.pressed.connect(_on_play_pressed)
	%Settings.pressed.connect(_on_settings_pressed)
	%Credits.pressed.connect(_on_credits_pressed)
	%Watch.pressed.connect(_set_watching.bind(true))
	%Quit.pressed.connect(get_tree().quit)
	_hint = Label.new()
	_hint.text = "Press any key to bring the menu back"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	move_child(_hint, overlay.get_index())
	_tip = randi() % TIPS.size()
	%Tip.text = "TIP:  " + TIPS[_tip]
	%Play.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	# The camera creeps down the hall towards the hole, looking around a
	# little, then eases back.
	var forward := -_start.basis.z
	var along := (1.0 - cos(_time * 0.03)) * 4.0
	camera.position = _start.origin + forward * along + Vector3(0, sin(_time * 0.2) * 0.04, 0)
	camera.rotation = _start.basis.get_euler() + Vector3(sin(_time * 0.07) * 0.03, sin(_time * 0.05) * 0.18, sin(_time * 0.04) * 0.02)
	_update_lens()
	_tip_time += delta
	if _tip_time > 7.0:
		_tip_time = 0.0
		_tip = (_tip + 1) % TIPS.size()
		%Tip.text = "TIP:  " + TIPS[_tip]


## Light bends around the black hole.
func _update_lens() -> void:
	var hole := _ruin.hole
	if hole == null or camera.is_position_behind(hole.global_position):
		overlay.set_lens(Vector2.ZERO, 0.0, 0.0)
		return
	var size := get_viewport().get_visible_rect().size
	var screen := camera.unproject_position(hole.global_position)
	var edge := camera.unproject_position(hole.global_position + camera.global_basis.x * hole.get_world_radius())
	overlay.set_lens(screen / size, screen.distance_to(edge) / size.y, hole.get_lens_strength())


## Hide (or bring back) everything but the backdrop.
func _set_watching(on: bool) -> void:
	_watching = on
	if _ui_fade:
		_ui_fade.kill()
	_ui_fade = create_tween().set_parallel()
	var a := 0.0 if on else 1.0
	for node: CanvasItem in [$Shade, $Side, $Version]:
		if not on:
			node.visible = true
		_ui_fade.tween_property(node, "modulate:a", a, 1.2)
	# The hint shows for a few seconds, then gets out of the way too.
	_ui_fade.tween_property(_hint, "modulate:a", 1.0 if on else 0.0, 0.6)
	if on:
		_ui_fade.chain().tween_property(_hint, "modulate:a", 0.0, 1.5).set_delay(3.0)
		_ui_fade.chain().tween_callback(func():
			for node: CanvasItem in [$Shade, $Side, $Version]:
				node.visible = false)
		get_viewport().gui_release_focus()
	else:
		%Watch.grab_focus()


func _input(event: InputEvent) -> void:
	if not _watching or event.is_echo():
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed):
		get_viewport().set_input_as_handled()
		_set_watching(false)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_PATH)


func _on_settings_pressed() -> void:
	var menu := SettingsMenu.new()
	add_child(menu)
	menu.changed.connect(func(s: GameSettings): s.apply_overlay(overlay))
	menu.closed.connect(func(): %Settings.grab_focus())


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file(CREDITS_PATH)
