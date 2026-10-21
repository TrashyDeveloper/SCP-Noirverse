class_name Music
extends RefCounted
## Finds the menu music. Put your own track in one of these places (the
## first one found is used):
##   1. res://assets/audio/music/menu.ogg (or menu.mp3 / menu.wav) - inside
##      the project folder; Godot imports it the next time you open the editor.
##   2. user://music/menu.ogg (or .mp3 / .wav) - on Windows that's
##      %APPDATA%\SCP-Noirverse\music\ - works without opening Godot.
## Otherwise the built-in placeholders (assets/audio/music/*_placeholder*.wav,
## made by tools/make_music.py) play.

const PROJECT_DIR := "res://assets/audio/music/"
const USER_DIR := "user://music/"
const PLACEHOLDER := "res://assets/audio/music/menu_placeholder.wav"
## The built-in tracks for each menu: [title, file name in PROJECT_DIR].
const BUILT_IN := {
	"menu": [["Last Light", "menu_placeholder"], ["Cold Storage", "menu_placeholder_2"],
		["Night Shift", "menu_placeholder_3"], ["Event Horizon", "menu_placeholder_4"]],
	"fusion": [["Reactor Hum", "fusion_placeholder"], ["Clean Energy", "fusion_placeholder_2"]],
}


## All the tracks a menu can play, as [{title, stream}]: your own track
## first (if you added one), then the built-in ones.
static func playlist(track_name: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var own := load_track(track_name, false, false)
	if own != null:
		list.append({"title": "Your track", "stream": own})
	for entry: Array in BUILT_IN.get(track_name, []):
		var path: String = PROJECT_DIR + entry[1] + ".wav"
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
			list.append({"title": entry[0], "stream": stream})
	return list


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
