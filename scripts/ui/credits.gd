extends Control
## Credits and license attribution.
##
## SCP Foundation content is licensed under Creative Commons
## Attribution-ShareAlike 3.0 (CC BY-SA 3.0), which requires us to credit the
## original authors and link to the source. Keep this list up to date whenever
## a new SCP or other wiki concept is added to the game (see CREDITS.md).

const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"

const CREDITS_BBCODE := """[font_size=40]CREDITS[/font_size]

[font_size=24]SCP: Noirverse[/font_size]
An unofficial, non-commercial fan game set in the SCP universe.
All models, code, sounds and art in this game are original to this project.

[font_size=24]The SCP Foundation[/font_size]
This game is based on the SCP Foundation, a collaborative fiction project by many authors.
SCP Foundation content is licensed under [url=https://creativecommons.org/licenses/by-sa/3.0/]Creative Commons Attribution-ShareAlike 3.0 (CC BY-SA 3.0)[/url].
Main site: [url=https://scp-wiki.wikidot.com]scp-wiki.wikidot.com[/url]

[b]SCP-173[/b] by Moto42 — [url=https://scp-wiki.wikidot.com/scp-173]scp-wiki.wikidot.com/scp-173[/url]
[b]SCP-096[/b] by Dr Dan — [url=https://scp-wiki.wikidot.com/scp-096]scp-wiki.wikidot.com/scp-096[/url]
[b]SCP-049[/b] by Gabriel Jade — [url=https://scp-wiki.wikidot.com/scp-049]scp-wiki.wikidot.com/scp-049[/url]
[b]SCP-914[/b] by Dr Gears — [url=https://scp-wiki.wikidot.com/scp-914]scp-wiki.wikidot.com/scp-914[/url]

The SCP Foundation, the O5 Council, Class-D personnel, Mobile Task Forces (incl. Epsilon-11 "Nine-Tailed Fox", Nu-7 "Hammer Down", Beta-7 "Maz Hatters", Alpha-1 "Red Right Hand", Eta-10 "See No Evil", Zeta-9 "Mole Rats"), the Chaos Insurgency and Delta Command and the facility zone concepts come from the SCP Wiki and its many contributors.
The SCP Foundation emblem on doors is our own redrawing of the SCP Wiki logo (originally by Aelanna, CC BY-SA 3.0 — see [url=https://scp-wiki.wikidot.com/licensing-guide]scp-wiki.wikidot.com/licensing-guide[/url]).
The appearance of SCP-173 in this game is an original design and does not use the sculpture "Untitled 2004" by Izumi Kato, which is not covered by the CC BY-SA license.

[font_size=24]License of this game's content[/font_size]
Because it adapts CC BY-SA 3.0 material, the SCP-derived content of SCP: Noirverse is shared under the same license, [url=https://creativecommons.org/licenses/by-sa/3.0/]CC BY-SA 3.0[/url].
This project is not affiliated with or endorsed by the SCP Wiki, its staff, or any other SCP game.

[font_size=24]Made with Godot Engine[/font_size]
[url=https://godotengine.org]godotengine.org[/url]
"""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var text: RichTextLabel = %Text
	text.text = CREDITS_BBCODE + "\n" + _godot_license_bbcode()
	text.meta_clicked.connect(_on_link_clicked)
	%Back.pressed.connect(_go_back)
	%Back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_go_back()


func _godot_license_bbcode() -> String:
	# The Godot license requires its notice to be shipped with the game.
	var text := Engine.get_license_text().strip_edges()
	var components := PackedStringArray()
	for info in Engine.get_copyright_info():
		components.append(info["name"])
	return "%s\n\n[i]Godot also includes third-party components: %s.[/i]" % [
		text.replace("[", "[lb]"), ", ".join(components)
	]


func _on_link_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
