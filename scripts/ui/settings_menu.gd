class_name SettingsMenu
extends CanvasLayer
## The Settings screen (from the main menu or the pause menu). Every change
## is applied and saved right away; `changed` lets the game update things
## like mouse speed and field of view.

signal changed(settings: GameSettings)
signal closed

var settings: GameSettings
var _rows: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = GameSettings.load_settings()
	var theme_res: Theme = load("res://resources/noir_theme.tres")
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.theme = theme_res
	add_child(shade)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -330
	panel.offset_bottom = 330
	panel.add_theme_constant_override("separation", 10)
	shade.add_child(panel)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 44)
	panel.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	panel.add_child(_rows)
	_section("CONTROLS")
	_slider("Mouse sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.05, "%.2fx")
	_check("Invert mouse (up/down)", "invert_mouse")
	_slider("Field of view", "fov", 60.0, 110.0, 1.0, "%d°")
	_section("AUDIO")
	_slider("Master volume", "master_volume", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider("Music volume", "music_volume", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider("Effects volume", "sfx_volume", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_section("DISPLAY")
	_check("Fullscreen", "fullscreen")
	_check("V-Sync", "vsync")
	_check("Shadows", "shadows")
	_slider("Film grain", "film_grain", 0.0, 2.0, 0.1, "%.1f")
	_slider("Brightness", "brightness", -0.2, 0.2, 0.01, "%+.2f")
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	panel.add_child(back)
	back.grab_focus()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.56))
	_rows.add_child(l)


func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size.x = 260
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	_rows.add_child(row)
	return row


func _slider(label_text: String, key: String, lo: float, hi: float, step: float, fmt: String, display_scale := 1.0) -> void:
	var row := _row(label_text)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = settings.get(key)
	slider.custom_minimum_size.x = 280
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size.x = 80
	value.add_theme_font_size_override("font_size", 18)
	value.text = fmt % (slider.value * display_scale)
	row.add_child(value)
	slider.value_changed.connect(func(v: float):
		value.text = fmt % (v * display_scale)
		_apply_value(key, v))


func _check(label_text: String, key: String) -> void:
	var row := _row(label_text)
	var box := CheckButton.new()
	box.button_pressed = settings.get(key)
	row.add_child(box)
	box.toggled.connect(func(on: bool): _apply_value(key, on))


func _apply_value(key: String, value: Variant) -> void:
	settings.set(key, value)
	settings.save()
	settings.apply_global()
	changed.emit(settings)
