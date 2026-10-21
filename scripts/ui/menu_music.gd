class_name MenuMusic
extends AudioStreamPlayer
## Plays a menu's playlist (see Music.playlist): starts on a random track,
## then moves on to the next one when it ends. `make_button()` gives a small
## "now playing" button that skips to the next track.

signal track_changed(title: String)

var _list: Array[Dictionary] = []
var _index := 0
var _button: Button


func setup(track_name: String) -> void:
	bus = &"Music"
	_list = Music.playlist(track_name)
	if _list.is_empty():
		return
	_index = randi() % _list.size()
	finished.connect(next_track)
	_play_current()


func next_track() -> void:
	if _list.is_empty():
		return
	_index = (_index + 1) % _list.size()
	_play_current()


func current_title() -> String:
	return "" if _list.is_empty() else String(_list[_index].title)


## A flat "♪ TRACK NAME  ›" button; click it for the next track.
func make_button() -> Button:
	_button = Button.new()
	_button.flat = true
	_button.focus_mode = Control.FOCUS_NONE
	_button.tooltip_text = "Next track"
	_button.add_theme_font_size_override("font_size", 14)
	_button.pressed.connect(next_track)
	_update_button()
	return _button


func _play_current() -> void:
	stream = _list[_index].stream
	play()
	_update_button()
	track_changed.emit(current_title())


func _update_button() -> void:
	if _button != null:
		_button.text = "♪  " + current_title().to_upper() + "   ›"
