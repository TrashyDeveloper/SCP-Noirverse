class_name Music
extends RefCounted
## Finds the menu music. Put your own track in one of these places (the
## first one found is used):
##   1. res://assets/audio/music/menu.ogg (or menu.mp3 / menu.wav) - inside
##      the project folder; Godot imports it the next time you open the editor.
##   2. user://music/menu.ogg (or .mp3 / .wav) - on Windows that's
##      %APPDATA%\SCP-Noirverse\music\ - works without opening Godot.
## Otherwise the built-in placeholder (assets/audio/music/menu_placeholder.wav)
## plays.

const PROJECT_DIR := "res://assets/audio/music/"
const USER_DIR := "user://music/"
const PLACEHOLDER := "res://assets/audio/music/menu_placeholder.wav"


## Finds a track by name (e.g. "menu" or "warheads/GammaWarheadEnhancedAudio").
## Only the menu falls back to the placeholder; `loop` makes it repeat.
static func load_track(track_name: String, placeholder := true, loop := true) -> AudioStream:
	var stream: AudioStream = null
	for ext: String in ["ogg", "mp3", "wav"]:
		var path := PROJECT_DIR + track_name + "." + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		for ext: String in ["ogg", "mp3", "wav"]:
			var path := USER_DIR + track_name + "." + ext
			if FileAccess.file_exists(path):
				stream = _load_external(path, ext)
				if stream != null:
					break
	if stream == null and placeholder and ResourceLoader.exists(PLACEHOLDER):
		stream = load(PLACEHOLDER)
	if stream != null and loop:
		Sfx.make_looping(stream)
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	return stream


static func _load_external(path: String, ext: String) -> AudioStream:
	match ext:
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null
