class_name Announcer
extends Node
## The facility announcer: a calm female voice over the PA, using the
## computer's text-to-speech (on Windows the built-in voices, e.g.
## "Microsoft Zira"). A chime plays first and the words are shown as a
## subtitle. If no voice is available, only the subtitle appears.

signal subtitle(text: String)

## Voice names we prefer (female English voices on Windows, macOS, Linux).
const PREFERRED := ["Zira", "Hazel", "Susan", "Aria", "Jenny", "Libby", "Sonia", "Michelle", "Catherine",
	"Samantha", "Victoria", "Karen", "Moira", "Tessa", "Serena", "Fiona", "female", "Female"]

## 0..1, from the Settings.
var volume := 0.9
var enabled := true

var _voice := ""
var _queue: Array[String] = []
var _busy := 0.0


func _ready() -> void:
	_voice = pick_voice()


## The best female English voice available ("" if there is no TTS).
static func pick_voice() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var voices := DisplayServer.tts_get_voices()
	var english := voices.filter(func(v): return String(v.get("language", "")).begins_with("en"))
	for wanted in PREFERRED:
		for v in english + voices:
			if String(v.get("name", "")).contains(wanted):
				return v.get("id", "")
	return english[0].get("id", "") if not english.is_empty() else ""


## Says `text` after a short chime. `urgent` interrupts whatever is playing.
func say(text: String, urgent := false) -> void:
	if urgent:
		_queue.clear()
		if _voice != "":
			DisplayServer.tts_stop()
		_busy = 0.0
	_queue.append(text)


func _process(delta: float) -> void:
	_busy = maxf(_busy - delta, 0.0)
	if _busy > 0.0 or _queue.is_empty():
		return
	var text: String = _queue.pop_front()
	Sfx.play_2d(self, "intercom_chime", -10.0)
	subtitle.emit(text)
	# Roughly how long the sentence takes, so lines don't overlap.
	_busy = 1.2 + text.length() * 0.065
	if enabled and _voice != "" and volume > 0.0:
		get_tree().create_timer(1.1).timeout.connect(func():
			DisplayServer.tts_speak(text, _voice, int(volume * 100.0), 0.95, 0.92))


func stop() -> void:
	_queue.clear()
	if _voice != "":
		DisplayServer.tts_stop()
