extends Control
## The alternative title screen (a test): "Innovation Inc: Fusion Reactor
## Complex". Behind it is the reactor hall (FusionReactorBackdrop). Built in
## code; the switch button goes back to the classic menu.

const GAME_PATH := "res://scenes/game/game.tscn"
const CREDITS_PATH := "res://scenes/ui/credits.tscn"
const CLASSIC_PATH := "res://scenes/ui/main_menu.tscn"
const ACCENT := Color(0.35, 0.9, 1.0)
const WARM := Color(1.0, 0.62, 0.2)
const TEXT := Color(0.92, 0.94, 0.97)
const DIM := Color(0.55, 0.6, 0.66)

var _time := 0.0
var _watching := false
var _ui_fade: Tween
var _ui: Control
var _hint: Label
var _readouts := {}
var _settings: GameSettings
var _first_button: Button

@onready var camera: Camera3D = $Backdrop/Camera3D
@onready var backdrop: FusionReactorBackdrop = $Backdrop/Reactor
@onready var overlay: NoirOverlay = $NoirOverlay


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settings = GameSettings.load_settings()
	_settings.apply_global()
	_settings.apply_overlay(overlay)
	# Colour shows through here much more than in the rest of the game.
	overlay.set_base_saturation(0.5)
	var music := MenuMusic.new()
	add_child(music)
	music.setup("fusion")
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	move_child(_ui, overlay.get_index())
	_build_side()
	_build_status()
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 18)
	var music_button := music.make_button()
	_style_small(music_button)
	bottom.add_child(music_button)
	bottom.add_child(_label("TEST BUILD  ·  ALT MENU", 13, DIM, 2))
	_ui.add_child(bottom)
	_hint = _label("Press any key to bring the menu back", 14, DIM)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.modulate.a = 0.0
	add_child(_hint)
	move_child(_hint, overlay.get_index())
	_first_button.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	# Slow drift around the open side of the reactor.
	var gap := backdrop.gap_direction()
	var angle := atan2(gap.z, gap.x) + 0.55 + sin(_time * 0.045) * 0.3
	var dist := 24.0 + sin(_time * 0.07) * 1.5
	camera.position = Vector3(cos(angle) * dist, 11.0 + sin(_time * 0.09) * 1.0, sin(angle) * dist)
	camera.look_at(Vector3(0, FusionReactorBackdrop.CORE_HEIGHT - 1.0, 0))
	# Push the reactor to the right of the screen, away from the menu.
	camera.rotate_object_local(Vector3.UP, 0.3)
	_update_readouts()


func _build_side() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 700
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """shader_type canvas_item;
void fragment() {
	float a = mix(0.9, 0.0, smoothstep(0.25, 1.0, UV.x));
	COLOR = vec4(0.01, 0.025, 0.05, a);
}"""
	shade.material = mat
	_ui.add_child(shade)
	# Thin glowing accent line down the left edge.
	var edge := ColorRect.new()
	edge.color = Color(ACCENT, 0.7)
	edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_left = 40
	edge.offset_right = 42
	edge.offset_top = 70
	edge.offset_bottom = -70
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(edge)

	var side := VBoxContainer.new()
	side.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	side.offset_left = 72
	side.offset_top = 62
	side.offset_right = 660
	side.offset_bottom = -40
	side.add_theme_constant_override("separation", 2)
	_ui.add_child(side)

	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 16)
	var logo := InnovationLogo.new()
	logo.accent = ACCENT
	logo.custom_minimum_size = Vector2(72, 72)
	brand.add_child(logo)
	var brand_text := VBoxContainer.new()
	brand_text.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_text.add_theme_constant_override("separation", -2)
	brand_text.add_child(_label("INNOVATION INC.", 22, TEXT, 7))
	brand_text.add_child(_label("ENERGY  ·  RESEARCH  ·  TOMORROW", 11, ACCENT, 4))
	brand.add_child(brand_text)
	side.add_child(brand)
	side.add_child(_spacer(26))
	side.add_child(_label("FUSION REACTOR", 58, TEXT, 2))
	var complex := HBoxContainer.new()
	complex.add_theme_constant_override("separation", 14)
	var dash := ColorRect.new()
	dash.color = WARM
	dash.custom_minimum_size = Vector2(46, 3)
	dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	complex.add_child(dash)
	complex.add_child(_label("C O M P L E X", 30, WARM, 10))
	side.add_child(complex)
	side.add_child(_spacer(10))
	side.add_child(_label("Clean power for a safer tomorrow.", 16, DIM))
	side.add_child(_spacer(34))

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	side.add_child(buttons)
	var entries := [["PLAY", _on_play], ["SETTINGS", _on_settings], ["CREDITS", _on_credits],
		["WATCH", _set_watching.bind(true)], ["CLASSIC MENU", _on_switch], ["QUIT", get_tree().quit]]
	for i in entries.size():
		var b := _menu_button("%02d" % (i + 1), entries[i][0])
		b.pressed.connect(entries[i][1])
		buttons.add_child(b)
		if i == 0:
			_first_button = b
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(fill)
	var note := _label("Innovation Inc. is a fictional company in this game. Unofficial fan game based on the SCP Foundation (scp-wiki.wikidot.com), CC BY-SA 3.0. See Credits.", 12, Color(DIM, 0.8))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(note)


## The reactor status panel, top right.
func _build_status() -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.01, 0.03, 0.06, 0.62)
	box.border_color = Color(ACCENT, 0.45)
	box.border_width_top = 2
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 14
	box.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 36)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(290, 0)
	_ui.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)
	var head := HBoxContainer.new()
	head.add_child(_label("REACTOR STATUS", 13, DIM, 3))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	_readouts["online"] = _label("● ONLINE", 13, Color(0.4, 1.0, 0.55), 2)
	head.add_child(_readouts["online"])
	list.add_child(head)
	for key: String in ["CORE TEMP", "FIELD STRENGTH", "NET OUTPUT", "CONTAINMENT"]:
		var row := HBoxContainer.new()
		row.add_child(_label(key, 14, TEXT, 1))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(gap)
		var value := _label("", 14, ACCENT, 1)
		row.add_child(value)
		_readouts[key] = value
		list.add_child(row)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 3)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.08)
		var fg := StyleBoxFlat.new()
		fg.bg_color = WARM if key == "CORE TEMP" else ACCENT
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fg)
		_readouts[key + "_bar"] = bar
		list.add_child(bar)


func _update_readouts() -> void:
	var temp := 150.0 + sin(_time * 0.7) * 1.8 + sin(_time * 2.9) * 0.4
	var field := 99.4 + sin(_time * 0.4) * 0.4
	var output := 2.41 + sin(_time * 0.5) * 0.03
	(_readouts["CORE TEMP"] as Label).text = "%.1f MK" % temp
	(_readouts["FIELD STRENGTH"] as Label).text = "%.1f %%" % field
	(_readouts["NET OUTPUT"] as Label).text = "%.2f GW" % output
	(_readouts["CONTAINMENT"] as Label).text = "STABLE"
	(_readouts["CORE TEMP_bar"] as ProgressBar).value = temp - 80.0
	(_readouts["FIELD STRENGTH_bar"] as ProgressBar).value = field
	(_readouts["NET OUTPUT_bar"] as ProgressBar).value = output * 33.0
	(_readouts["CONTAINMENT_bar"] as ProgressBar).value = 96.0 + sin(_time * 3.0) * 1.5
	(_readouts["online"] as Label).modulate.a = 0.55 + 0.45 * absf(sin(_time * 1.5))


func _menu_button(number: String, text: String) -> Button:
	var b := Button.new()
	b.text = number + "    " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(340, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", Color(TEXT, 0.72))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var lit := normal.duplicate() as StyleBoxFlat
	lit.bg_color = Color(ACCENT, 0.12)
	lit.border_color = ACCENT
	lit.border_width_left = 3
	lit.content_margin_left = 22
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.mouse_entered.connect(b.grab_focus)
	return b


func _style_small(b: Button) -> void:
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", ACCENT)


func _label(text: String, font_size: int, color: Color, spacing := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if spacing != 0:
		var font := FontVariation.new()
		font.base_font = ThemeDB.fallback_font
		font.spacing_glyph = spacing
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _set_watching(on: bool) -> void:
	_watching = on
	if _ui_fade:
		_ui_fade.kill()
	_ui_fade = create_tween().set_parallel()
	if not on:
		_ui.visible = true
	_ui_fade.tween_property(_ui, "modulate:a", 0.0 if on else 1.0, 1.2)
	_ui_fade.tween_property(_hint, "modulate:a", 1.0 if on else 0.0, 0.6)
	if on:
		_ui_fade.chain().tween_property(_hint, "modulate:a", 0.0, 1.5).set_delay(3.0)
		_ui_fade.chain().tween_callback(func(): _ui.visible = false)
		get_viewport().gui_release_focus()
	else:
		_first_button.grab_focus()


func _input(event: InputEvent) -> void:
	if not _watching or event.is_echo():
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		_set_watching(false)


func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_PATH)


func _on_settings() -> void:
	var menu := SettingsMenu.new()
	add_child(menu)
	menu.changed.connect(func(s: GameSettings):
		s.apply_overlay(overlay)
		_settings = s)
	menu.closed.connect(func(): _first_button.grab_focus())


func _on_credits() -> void:
	get_tree().change_scene_to_file(CREDITS_PATH)


func _on_switch() -> void:
	_settings = GameSettings.load_settings()
	_settings.menu_style = "classic"
	_settings.save()
	get_tree().change_scene_to_file(CLASSIC_PATH)
