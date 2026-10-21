class_name Sfx
extends RefCounted
## Plays sound effects from res://assets/audio/sfx/ by name, e.g.
## Sfx.play_3d(self, "door_open", global_position).
##
## A name with numbered variants (footstep_1.wav, footstep_2.wav...) picks
## one at random. Names ending in "_loop" loop forever. To replace a sound,
## drop a new file with the same name (.wav or .ogg) into that folder.
## Only cached sound files live here (no game state).

const DIR := "res://assets/audio/sfx/"

static var _cache := {}


## The sound for `sound_name` (a random variant if there are several), or null.
static func get_stream(sound_name: String) -> AudioStream:
	if not _cache.has(sound_name):
		var variants: Array[AudioStream] = []
		var single := _load(sound_name)
		if single != null:
			variants.append(single)
		else:
			var i := 1
			while true:
				var v := _load("%s_%d" % [sound_name, i])
				if v == null:
					break
				variants.append(v)
				i += 1
		_cache[sound_name] = variants
	var list: Array = _cache[sound_name]
	return null if list.is_empty() else list.pick_random()


static func _load(file: String) -> AudioStream:
	for ext: String in [".wav", ".ogg", ".mp3"]:
		if ResourceLoader.exists(DIR + file + ext):
			var stream: AudioStream = load(DIR + file + ext)
			if file.ends_with("_loop"):
				make_looping(stream)
			return stream
	return null


static func make_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true


## Plays a sound at a position in the world. With `attach`, the sound moves
## with that node (e.g. a lift cabin). Returns the player (or null).
static func play_3d(context: Node, sound_name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0,
		attach: Node3D = null, max_distance := 45.0) -> AudioStreamPlayer3D:
	var stream := get_stream(sound_name)
	if stream == null or context == null or not context.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = max_distance
	player.unit_size = 6.0
	player.bus = &"SFX"
	if attach != null:
		attach.add_child(player)
		player.global_position = pos
	else:
		var parent := context.get_tree().current_scene if context.get_tree().current_scene != null else context.get_tree().root
		parent.add_child(player)
		player.global_position = pos
	player.play()
	if not sound_name.ends_with("_loop"):
		player.finished.connect(player.queue_free)
	return player


## Plays a sound that isn't in the world (UI, announcements).
static func play_2d(context: Node, sound_name: String, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var stream := get_stream(sound_name)
	if stream == null or context == null or not context.is_inside_tree():
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = &"SFX"
	context.add_child(player)
	player.play()
	if not sound_name.ends_with("_loop"):
		player.finished.connect(player.queue_free)
	return player
