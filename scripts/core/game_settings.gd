class_name GameSettings
extends RefCounted
## The player's own preferences (not game rules): mouse, field of view,
## volume, display and film effects. Stored in user://settings.cfg (on
## Windows: %APPDATA%\SCP-Noirverse\settings.cfg). Each scene that needs
## them loads them; nothing is kept in a global.

const FILE_PATH := "user://settings.cfg"
## Mouse speed at sensitivity 1.0 (radians per pixel).
const BASE_SENSITIVITY := 0.0025

var mouse_sensitivity := 1.0
var invert_mouse := false
var fov := 80.0
var master_volume := 0.9
var music_volume := 0.7
var sfx_volume := 0.9
## The announcer's text-to-speech voice (0 = off).
var announcer_volume := 0.9
var fullscreen := false
var vsync := true
var shadows := true
## Film grain and scratches (0 = off, 1 = normal, 2 = heavy).
var film_grain := 1.0
var brightness := 0.0

const _KEYS: Array[String] = ["mouse_sensitivity", "invert_mouse", "fov", "master_volume", "music_volume",
	"sfx_volume", "announcer_volume", "fullscreen", "vsync", "shadows", "film_grain", "brightness"]


static func load_settings() -> GameSettings:
	var s := GameSettings.new()
	var file := ConfigFile.new()
	if file.load(FILE_PATH) == OK:
		for key in _KEYS:
			s.set(key, file.get_value("settings", key, s.get(key)))
	return s


func save() -> void:
	var file := ConfigFile.new()
	for key in _KEYS:
		file.set_value("settings", key, get(key))
	file.save(FILE_PATH)


## Applies the settings that affect the whole program (audio, window).
func apply_global() -> void:
	ensure_audio_buses()
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	if not DisplayServer.get_name() == "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


## Applies the film look to a NoirOverlay.
func apply_overlay(overlay: NoirOverlay) -> void:
	if overlay != null:
		overlay.set_film(film_grain, brightness)


## Makes sure the "Music" and "SFX" audio buses exist (both feed Master).
static func ensure_audio_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


static func _set_bus_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index != -1:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.001)
