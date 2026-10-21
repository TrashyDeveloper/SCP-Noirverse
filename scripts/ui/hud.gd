class_name Hud
extends CanvasLayer
## On-screen info for the local player: crosshair, prompts, health,
## the held item and its ammo. (The full inventory is the Tab screen.) It only *shows* the character's state; it never
## changes it.

var _character: CharacterController
var _damage_flash := 0.0
var _message_time := 0.0
var _hit_marker_time := 0.0

@onready var prompt_label: Label = $Prompt
@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_label: Label = $HealthPanel/HealthLabel
@onready var held_label: Label = $HeldLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var message_label: Label = $Message
@onready var damage_overlay: ColorRect = $DamageFlash
@onready var hit_marker: Label = $HitMarker


func _ready() -> void:
	message_label.text = ""
	hit_marker.modulate.a = 0.0


func bind_character(character: CharacterController) -> void:
	_character = character
	character.interaction_prompt_changed.connect(_on_prompt_changed)
	character.health.changed.connect(_on_health_changed)
	character.health.damaged.connect(_on_damaged)
	character.inventory.changed.connect(_refresh_items)
	character.inventory.item_added.connect(_on_item_added)
	character.items.equipped_changed.connect(func(_slot: int): _refresh_items())
	character.items.weapon_state_changed.connect(_refresh_items)
	character.items.hit_confirmed.connect(_on_hit_confirmed)
	character.died.connect(_on_died)
	_on_prompt_changed("")
	_on_health_changed(character.health.current, character.health.max_health)
	_refresh_items()


func _process(delta: float) -> void:
	_damage_flash = maxf(_damage_flash - delta * 1.5, 0.0)
	damage_overlay.color.a = _damage_flash
	_hit_marker_time = maxf(_hit_marker_time - delta, 0.0)
	hit_marker.modulate.a = _hit_marker_time / 0.25
	if _message_time > 0.0:
		_message_time -= delta
		message_label.modulate.a = clampf(_message_time, 0.0, 1.0)
	if _character != null and _character.items.is_reloading():
		_refresh_ammo()


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HEALTH  %d" % ceili(current)


func _on_damaged(amount: float, _source: Node) -> void:
	_damage_flash = minf(_damage_flash + 0.15 + amount * 0.02, 0.6)


func _on_hit_confirmed() -> void:
	_hit_marker_time = 0.25


func _on_item_added(item: ItemInstance) -> void:
	show_message("Picked up: %s" % item.data.display_name)


func _on_died(_source: Node) -> void:
	for node: CanvasItem in [$Crosshair, prompt_label, $HealthPanel, held_label, ammo_label]:
		node.visible = false


func show_message(text: String) -> void:
	message_label.text = text
	_message_time = 2.5


func _refresh_items() -> void:
	var item := _character.items.get_equipped()
	held_label.text = item.data.display_name if item != null else ""
	_refresh_ammo()


func _refresh_ammo() -> void:
	var item := _character.items.get_equipped()
	if item == null or item.data.kind != ItemData.Kind.PISTOL:
		ammo_label.text = ""
	elif _character.items.is_reloading():
		ammo_label.text = "RELOADING..."
	else:
		ammo_label.text = "%d / %d" % [item.ammo, _character.inventory.get_ammo(item.data.ammo_type)]
