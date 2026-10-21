class_name Hud
extends CanvasLayer
## On-screen info for the local player: crosshair, prompts, health,
## the held item and its ammo. (The full inventory is the Tab screen.) It only *shows* the character's state; it never
## changes it.

## Emitted when the player confirms (or cancels, with "") an intercom message.
signal intercom_submitted(text: String)

## Set by Game so the HUD can show the round timer and influence.
var round_manager: RoundManager
## The local player's controller (their XP is stored per InputSource).
var player_input: InputSource

var _character: CharacterController
var _role_time := 0.0
var _damage_flash := 0.0
var _blind := 0.0
var _message_time := 0.0
var _hit_marker_time := 0.0
var _terminal_time := 0.0
var _influence_label: Label
var _terminal_panel: PanelContainer
var _terminal_text: Label
var _intercom_panel: PanelContainer
var _intercom_edit: LineEdit

@onready var prompt_label: Label = $Prompt
@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_label: Label = $HealthPanel/HealthLabel
@onready var held_label: Label = $HeldLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var message_label: Label = $Message
@onready var damage_overlay: ColorRect = $DamageFlash
@onready var hit_marker: Label = $HitMarker
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var shield_bar: ProgressBar = $HealthPanel/ShieldBar
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var status_label: Label = $StatusLabel
@onready var role_panel: Control = $Role
@onready var role_title: Label = $Role/Title
@onready var role_class: Label = $Role/ClassName
@onready var role_objective: Label = $Role/Objective
@onready var class_label: Label = $HealthPanel/ClassLabel
@onready var timer_label: Label = $RoundTimer
@onready var warhead_label: Label = $WarheadLabel


func _ready() -> void:
	message_label.text = ""
	hit_marker.modulate.a = 0.0
	progress_bar.visible = false
	status_label.visible = false
	flash_overlay.color.a = 0.0
	role_panel.modulate.a = 0.0
	timer_label.text = ""
	warhead_label.visible = false
	_build_extra_widgets()


## Widgets made in code: influence/XP readout, terminal screen, intercom box.
func _build_extra_widgets() -> void:
	var theme_res: Theme = role_panel.theme
	_influence_label = Label.new()
	_influence_label.theme = theme_res
	_influence_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_influence_label.offset_left = -420.0
	_influence_label.offset_top = 48.0
	_influence_label.offset_right = -24.0
	_influence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_influence_label.add_theme_font_size_override("font_size", 15)
	_influence_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68, 0.9))
	add_child(_influence_label)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.08, 0.9)
	style.border_color = Color(0.3, 0.55, 0.75)
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	_terminal_panel = PanelContainer.new()
	_terminal_panel.theme = theme_res
	_terminal_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_terminal_panel.offset_left = -560.0
	_terminal_panel.offset_top = -170.0
	_terminal_panel.offset_right = -40.0
	_terminal_panel.offset_bottom = 170.0
	_terminal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terminal_panel.add_theme_stylebox_override("panel", style)
	_terminal_text = Label.new()
	_terminal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terminal_text.add_theme_font_size_override("font_size", 15)
	_terminal_text.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0))
	_terminal_panel.add_child(_terminal_text)
	_terminal_panel.visible = false
	add_child(_terminal_panel)

	_intercom_panel = PanelContainer.new()
	_intercom_panel.theme = theme_res
	_intercom_panel.set_anchors_preset(Control.PRESET_CENTER)
	_intercom_panel.offset_left = -320.0
	_intercom_panel.offset_right = 320.0
	_intercom_panel.offset_top = -50.0
	_intercom_panel.offset_bottom = 50.0
	_intercom_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_intercom_panel.add_child(box)
	var title := Label.new()
	title.text = "INTERCOM - type your message, Enter to broadcast, Esc to cancel"
	title.add_theme_font_size_override("font_size", 15)
	box.add_child(title)
	_intercom_edit = LineEdit.new()
	_intercom_edit.max_length = RoundManager.INTERCOM_MAX_LENGTH
	_intercom_edit.placeholder_text = "Attention all personnel..."
	_intercom_edit.text_submitted.connect(func(text: String): _close_intercom(text))
	box.add_child(_intercom_edit)
	_intercom_panel.visible = false
	add_child(_intercom_panel)


## Shows what a terminal says for a few seconds.
func show_terminal(text: String) -> void:
	_terminal_text.text = text
	_terminal_panel.visible = true
	_terminal_time = 10.0


func is_intercom_open() -> bool:
	return _intercom_panel.visible


func open_intercom() -> void:
	_intercom_edit.text = ""
	_intercom_panel.visible = true
	_intercom_edit.grab_focus()


func _close_intercom(text: String) -> void:
	if not _intercom_panel.visible:
		return
	_intercom_panel.visible = false
	_intercom_edit.release_focus()
	intercom_submitted.emit(text)


func _input(event: InputEvent) -> void:
	if _intercom_panel != null and _intercom_panel.visible and event.is_action_pressed("pause"):
		_close_intercom("")
		get_viewport().set_input_as_handled()


func bind_character(character: CharacterController) -> void:
	_character = character
	# After a respawn everything that was hidden on death comes back.
	for node: CanvasItem in [$Crosshair, $HealthPanel, held_label, ammo_label, role_panel]:
		node.visible = true
	status_label.visible = false
	character.interaction_prompt_changed.connect(_on_prompt_changed)
	character.health.changed.connect(_on_health_changed)
	character.health.damaged.connect(_on_damaged)
	character.inventory.changed.connect(_refresh_items)
	character.inventory.item_added.connect(_on_item_added)
	character.items.equipped_changed.connect(func(_slot: int): _refresh_items())
	character.items.weapon_state_changed.connect(_refresh_items)
	character.items.hit_confirmed.connect(_on_hit_confirmed)
	character.died.connect(_on_died)
	character.hold_progress_changed.connect(_on_progress)
	character.items.use_progress_changed.connect(func(p: float, _label: String): _on_progress(p))
	character.flashed.connect(func(duration: float): _blind = maxf(_blind, duration))
	character.disarm_changed.connect(func(disarmed: bool):
		status_label.visible = disarmed
		status_label.text = "YOU HAVE BEEN DISARMED")
	_on_prompt_changed("")
	_on_health_changed(character.health.current, character.health.max_health)
	_refresh_items()


func _process(delta: float) -> void:
	if warhead_label.visible:
		# Blink.
		warhead_label.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 300.0))
	if _role_time > 0.0:
		_role_time -= delta
		role_panel.modulate.a = clampf(_role_time, 0.0, 1.0)
	if round_manager != null:
		var left := round_manager.get_time_left()
		timer_label.text = "" if left < 0.0 else "%d:%02d" % [int(left) / 60, int(left) % 60]
		_update_influence()
	if _terminal_time > 0.0:
		_terminal_time -= delta
		_terminal_panel.modulate.a = clampf(_terminal_time, 0.0, 1.0)
		_terminal_panel.visible = _terminal_time > 0.0
	_damage_flash = maxf(_damage_flash - delta * 1.5, 0.0)
	damage_overlay.color.a = _damage_flash
	# Flashbang: full white, fading out during the last second.
	_blind = maxf(_blind - delta, 0.0)
	flash_overlay.color.a = clampf(_blind, 0.0, 1.0)
	_hit_marker_time = maxf(_hit_marker_time - delta, 0.0)
	hit_marker.modulate.a = _hit_marker_time / 0.25
	if _message_time > 0.0:
		_message_time -= delta
		message_label.modulate.a = clampf(_message_time, 0.0, 1.0)
	if _character != null and _character.items.is_reloading():
		_refresh_ammo()


func _update_influence() -> void:
	if Engine.get_process_frames() % 10 != 0:
		return
	var rm := round_manager
	var f: int = rm.influence[CharacterClass.Side.FOUNDATION]
	var c: int = rm.influence[CharacterClass.Side.INSURGENCY]
	var lines := PackedStringArray([
		"INFLUENCE  Foundation %d %s  |  Chaos %d %s" % [
			f, _tier_pips(rm.get_tier(CharacterClass.Side.FOUNDATION)), c, _tier_pips(rm.get_tier(CharacterClass.Side.INSURGENCY))],
	])
	if player_input != null:
		var xp := rm.get_xp(player_input)
		lines.append("YOUR XP  %d  (%s)" % [xp, RoundManager.XP_RANK_NAMES[RoundManager.xp_rank(xp)]])
	var wave := rm.get_wave_time_left()
	if wave >= 0.0 and _character != null and not _character.is_alive:
		lines.append("REINFORCEMENTS IN %d:%02d" % [int(wave) / 60, int(wave) % 60])
	_influence_label.text = "\n".join(lines)


func _tier_pips(tier: int) -> String:
	return "■".repeat(tier) + "□".repeat(RoundManager.INFLUENCE_TIERS.size() - 1 - tier)


## Big "YOU ARE A ..." text shown for a few seconds at spawn (or escape).
func show_role(character_class: CharacterClass, title := "YOU ARE", unit_name := "") -> void:
	role_title.text = title
	role_class.text = character_class.display_name.to_upper()
	role_objective.text = character_class.objective
	if unit_name != "":
		role_objective.text = unit_name.to_upper() + "\n" + character_class.objective
	if not character_class.perks.is_empty():
		role_objective.text += "\n" + character_class.describe_perks()
	class_label.text = character_class.display_name.to_upper()
	_role_time = 6.0


## Big warning at the top of the screen ("" hides it).
func show_warhead(text: String) -> void:
	warhead_label.text = text
	warhead_label.visible = text != ""


## A full-screen white flash that fades out (warhead detonation).
func flash_white(duration: float) -> void:
	_blind = maxf(_blind, duration)


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	var shield := _character.health.shield
	shield_bar.visible = shield > 0.0
	shield_bar.value = shield
	health_label.text = "HEALTH  %d" % ceili(current)
	if shield >= 1.0:
		health_label.text += "   +%d" % floori(shield)


func _on_progress(progress: float) -> void:
	progress_bar.visible = progress >= 0.0
	progress_bar.value = clampf(progress, 0.0, 1.0)


func _on_damaged(amount: float, _source: Node) -> void:
	_damage_flash = minf(_damage_flash + 0.15 + amount * 0.02, 0.6)


func _on_hit_confirmed() -> void:
	_hit_marker_time = 0.25


func _on_item_added(item: ItemInstance, amount: int) -> void:
	if item.data.kind == ItemData.Kind.AMMO:
		show_message("Picked up: %d x %s" % [amount, AmmoTypes.display_name(item.data.ammo_type)])
	else:
		show_message("Picked up: %s" % item.data.display_name)


func _on_died(_source: Node) -> void:
	for node: CanvasItem in [$Crosshair, prompt_label, $HealthPanel, held_label, ammo_label, role_panel]:
		node.visible = false


func show_message(text: String, duration := 2.5) -> void:
	message_label.text = text
	_message_time = duration


func _refresh_items() -> void:
	var item := _character.items.get_equipped()
	held_label.text = item.data.display_name if item != null else ""
	_refresh_ammo()


func _refresh_ammo() -> void:
	var item := _character.items.get_equipped()
	if item == null or item.data.kind != ItemData.Kind.FIREARM:
		ammo_label.text = ""
	elif _character.items.is_reloading():
		ammo_label.text = "RELOADING..."
	else:
		ammo_label.text = "%d / %d" % [item.ammo, _character.inventory.get_ammo(item.data.ammo_type)]
