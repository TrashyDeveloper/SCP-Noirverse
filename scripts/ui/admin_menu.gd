class_name AdminMenu
extends CanvasLayer
## The admin menu (N): players list (go to / bring / select), teleport to
## rooms and zones, item giver, role switch, god mode / noclip and warheads.
## It only shows buttons; AdminTools does the work.

var tools: AdminTools
## The admin (the local player's character).
var admin: CharacterController
## Who items/roles/god mode apply to (null = the admin).
var target: CharacterController

var _target_label: Label
var _players: VBoxContainer
var _warheads: VBoxContainer
var _god: CheckBox
var _noclip: CheckBox
var _at_spawn: CheckBox
var _refresh := 0.0
var _theme: Theme


func _ready() -> void:
	layer = 15
	visible = false
	_theme = load("res://resources/noir_theme.tres")
	var root := PanelContainer.new()
	root.theme = _theme
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -480
	root.offset_right = 480
	root.offset_top = -320
	root.offset_bottom = 320
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.035, 0.94)
	style.border_color = Color(0.85, 0.2, 0.15)
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	root.add_theme_stylebox_override("panel", style)
	add_child(root)
	var box := VBoxContainer.new()
	root.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "ADMIN MENU"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	header.add_child(title)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(fill)
	_target_label = Label.new()
	_target_label.add_theme_font_size_override("font_size", 16)
	header.add_child(_target_label)
	header.add_child(_small_button("Target: me", func(): set_target(null)))
	var hint := Label.new()
	hint.text = "N closes this menu  ·  Alt toggles noclip  ·  select a player to give them items or a role"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.56))
	box.add_child(hint)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 16)
	box.add_child(tabs)
	_players = _tab(tabs, "Players")
	_build_teleport(_tab(tabs, "Teleport"))
	_build_items(_tab(tabs, "Items"))
	_build_roles(_tab(tabs, "Roles"))
	_build_cheats(_tab(tabs, "God & Noclip"))
	_warheads = _tab(tabs, "Warheads")


func open(admin_character: CharacterController) -> void:
	admin = admin_character
	if target == null or not is_instance_valid(target):
		target = null
	visible = true
	_rebuild_players()
	_rebuild_warheads()
	_update_target_label()


func set_target(c: CharacterController) -> void:
	target = c
	_update_target_label()


func _who() -> CharacterController:
	return target if target != null and is_instance_valid(target) else admin


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 1.0
		_rebuild_players()
		_rebuild_warheads()
		_update_target_label()


func _update_target_label() -> void:
	var who := _who()
	_target_label.text = "Target: %s   " % ("me" if who == admin else (who.player_name if who != null else "-"))
	if _god != null and who != null:
		_god.set_pressed_no_signal(who.god_mode)
		_noclip.set_pressed_no_signal(who.noclip)


# --- Tabs -----------------------------------------------------------------------

func _tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _rebuild_players() -> void:
	for child in _players.get_children():
		child.queue_free()
	if tools == null:
		return
	for c in tools.get_characters():
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = ("> " if c == _who() else "   ") + tools.describe(c)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 15)
		if not c.is_alive:
			l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.48))
		row.add_child(l)
		row.add_child(_small_button("Select", func(): set_target(c); _rebuild_players()))
		if c != admin and c.is_alive:
			row.add_child(_small_button("Go to", func(): tools.teleport_to(admin, c)))
			row.add_child(_small_button("Bring", func(): tools.bring(c, admin)))
			row.add_child(_small_button("Kill", func(): tools.kill(c)))
		_players.add_child(row)


func _build_teleport(list: VBoxContainer) -> void:
	if tools == null:
		return
	var grid := GridContainer.new()
	grid.columns = 3
	list.add_child(grid)
	for loc in tools.get_locations():
		var pos: Vector3 = loc.position
		var b := _small_button(loc.name, func(): tools.teleport(_who(), pos))
		b.custom_minimum_size.x = 300
		grid.add_child(b)


func _build_items(list: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	list.add_child(grid)
	for id in AdminTools.all_items():
		var data: ItemData = load("res://resources/items/%s.tres" % id)
		var b := _small_button(data.display_name, func(): tools.give_item(_who(), id))
		b.custom_minimum_size.x = 300
		grid.add_child(b)


func _build_roles(list: VBoxContainer) -> void:
	_at_spawn = CheckBox.new()
	_at_spawn.text = "Also move to that role's spawn point"
	_at_spawn.add_theme_font_size_override("font_size", 15)
	list.add_child(_at_spawn)
	var grid := GridContainer.new()
	grid.columns = 3
	list.add_child(grid)
	for id in AdminTools.all_classes():
		var c := RoundManager.load_class(id)
		var b := _small_button(c.display_name, func():
			var result := tools.set_role(_who(), id, _at_spawn.button_pressed)
			if target != null:
				set_target(result))
		b.custom_minimum_size.x = 300
		grid.add_child(b)


func _build_cheats(list: VBoxContainer) -> void:
	_god = CheckBox.new()
	_god.text = "God mode (no damage)"
	_god.toggled.connect(func(on: bool): _who().god_mode = on)
	list.add_child(_god)
	_noclip = CheckBox.new()
	_noclip.text = "Noclip (fly through walls; also Alt)"
	_noclip.toggled.connect(func(on: bool): _who().noclip = on)
	list.add_child(_noclip)
	var row := HBoxContainer.new()
	row.add_child(_small_button("Heal fully", func(): tools.heal(_who())))
	row.add_child(_small_button("Kill target", func(): tools.kill(_who())))
	list.add_child(row)


func _rebuild_warheads() -> void:
	for child in _warheads.get_children():
		child.queue_free()
	if tools == null:
		return
	var rm := tools.round_manager
	for warhead in [WarheadConsole.Warhead.ALPHA, WarheadConsole.Warhead.DELTA, WarheadConsole.Warhead.GAMMA]:
		var row := HBoxContainer.new()
		var l := Label.new()
		var st: int = rm.warhead_state[warhead]
		l.text = "%s:  %s" % [RoundManager.WARHEADS[warhead].name,
			["standby", "COUNTDOWN %ds" % int(rm.warhead_time_left[warhead]), "detonated"][st]]
		l.custom_minimum_size.x = 380
		row.add_child(l)
		row.add_child(_small_button("Start", func(): tools.force_warhead(warhead, "start"); _rebuild_warheads()))
		row.add_child(_small_button("Cancel", func(): tools.force_warhead(warhead, "cancel"); _rebuild_warheads()))
		row.add_child(_small_button("Detonate now", func(): tools.force_warhead(warhead, "detonate"); _rebuild_warheads()))
		_warheads.add_child(row)
	if tools.director == null:
		return
	# Gamma aftermath: choose what the reactor becomes, or make it right now.
	var title := Label.new()
	title.text = "GAMMA AFTERMATH"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_warheads.add_child(title)
	var outcome := HBoxContainer.new()
	var forced: String = tools.director.forced_outcome
	var l := Label.new()
	l.text = "Next Gamma becomes:  %s" % ("random" if forced == "" else forced)
	l.custom_minimum_size.x = 380
	outcome.add_child(l)
	for kind: String in ["", "black", "white", "pulsar"]:
		outcome.add_child(_small_button(["Random", "Black hole", "White hole", "Pulsar"][["", "black", "white", "pulsar"].find(kind)],
			func(): tools.set_gamma_outcome(kind); _rebuild_warheads()))
	_warheads.add_child(outcome)
	var spawn := HBoxContainer.new()
	var hole: Singularity = tools.director.singularity
	var l2 := Label.new()
	l2.text = "Now:  %s" % ("nothing" if hole == null or not is_instance_valid(hole) else "%s%s" % [hole.kind, ", TIME STOPPED" if hole.stasis > 0.0 else ""])
	l2.custom_minimum_size.x = 380
	spawn.add_child(l2)
	spawn.add_child(_small_button("Spawn black hole", func(): tools.spawn_singularity("black"); _rebuild_warheads()))
	spawn.add_child(_small_button("Spawn white hole", func(): tools.spawn_singularity("white"); _rebuild_warheads()))
	spawn.add_child(_small_button("Spawn pulsar", func(): tools.spawn_singularity("pulsar"); _rebuild_warheads()))
	_warheads.add_child(spawn)
	var more := HBoxContainer.new()
	more.add_child(_small_button("Start time-stop protocol now", func(): tools.start_stasis(); _rebuild_warheads()))
	more.add_child(_small_button("Remove hole / pulsar", func(): tools.remove_singularity(); _rebuild_warheads()))
	_warheads.add_child(more)


func _small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	return b
