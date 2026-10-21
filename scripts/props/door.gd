class_name Door
extends Node3D
## A sliding facility door with a card reader on each side.
##
## Keycard doors need a held keycard with enough access of the door's type
## (e.g. "Containment level 2"). Look at the door or a reader and press E,
## or throw a keycard at a reader.

signal opened
signal closed
## Emitted instead of opening when a remote-controlled door is used.
signal use_requested(actor: Node)

enum Access { NONE, CONTAINMENT, ARMORY, ADMIN }

const KEYCARD_DOOR_GROUP := &"keycard_doors"
const ACCESS_NAMES := {
	Access.NONE: "None", Access.CONTAINMENT: "Containment", Access.ARMORY: "Armory", Access.ADMIN: "Admin",
}

## Text stenciled on both sides of the door.
@export var zone_code := "LCZ"
@export var zone_name := "LIGHT CONTAINMENT ZONE"
## Which kind of keycard access opens this door (None = anyone).
@export var access := Access.NONE
## Access level needed (1-3).
@export_range(0, 3) var required_level := 1
@export var start_open := false
## Controlled by something else (e.g. an elevator): pressing E only asks
## that system via `use_requested` instead of opening the door.
@export var remote_controlled := false
## Prompt shown for remote-controlled doors.
@export var remote_prompt := "[E] Call elevator"
## How far the panel slides sideways when opening, in meters.
@export var slide_distance := 2.1
@export var open_time := 0.6

var is_open := false
## Planks nailed across the door (it can't open while this exists).
var barricade: Barricade
var _tween: Tween
var _denied_time := 0.0
var _indicator_materials: Array[StandardMaterial3D] = []

@onready var panel: AnimatableBody3D = $Panel
@onready var _closed_position: Vector3 = panel.position


func _ready() -> void:
	add_to_group(KEYCARD_DOOR_GROUP)
	# Not every door has stencilled faces or card readers (e.g. cell doors).
	for face in [get_node_or_null("Panel/FaceFront"), get_node_or_null("Panel/FaceBack")]:
		if face != null:
			face.get_node("ZoneCode").text = zone_code
			face.get_node("ZoneName").text = zone_name
	for path in ["ReaderFront/Light", "ReaderBack/Light", "Panel/Indicator"]:
		var mesh := get_node_or_null(path) as MeshInstance3D
		if mesh == null:
			continue
		var mat := mesh.get_active_material(0).duplicate() as StandardMaterial3D
		mesh.material_override = mat
		_indicator_materials.append(mat)
	if start_open:
		is_open = true
		panel.position = _open_position()
	_update_indicator()


func _process(delta: float) -> void:
	if _denied_time > 0.0:
		_denied_time -= delta
		if _denied_time <= 0.0:
			_update_indicator()


func requires_keycard() -> bool:
	return access != Access.NONE and required_level > 0


## Does this keycard (item data) open the door?
func card_opens(card: ItemData) -> bool:
	if not requires_keycard():
		return true
	return card != null and card.grants_access(access, required_level)


func is_barricaded() -> bool:
	return is_instance_valid(barricade)


## Can a barricade be nailed across this door right now?
func can_barricade() -> bool:
	return not is_open and not remote_controlled and not is_barricaded() \
			and (_tween == null or not _tween.is_running())


func add_barricade(_builder: Node) -> Barricade:
	barricade = Barricade.new()
	barricade.name = "Barricade"
	barricade.door = self
	barricade.position = Vector3(0, 1.3, 0)
	add_child(barricade)
	return barricade


## Can this actor operate the door right now?
func can_operate(actor: Node) -> bool:
	if actor != null and actor.has_method("is_disarmed") and actor.is_disarmed():
		return false
	if is_barricaded():
		return false
	if not requires_keycard():
		return true
	var held: ItemInstance = actor.get_held_item() if actor != null and actor.has_method("get_held_item") else null
	return held != null and card_opens(held.data)


func get_access_text() -> String:
	return "%s Level %d" % [ACCESS_NAMES[access], required_level]


func get_interaction_prompt(actor: Node) -> String:
	if actor != null and actor.has_method("is_disarmed") and actor.is_disarmed():
		return "You are disarmed"
	if remote_controlled:
		return remote_prompt
	if is_barricaded():
		return "Barricaded - hold E on the planks to tear them down"
	if not can_operate(actor):
		return "Requires %s keycard  (hold a keycard: Ctrl)" % get_access_text()
	return "[E] Close door" if is_open else "[E] Open door"


func interact(actor: Node) -> void:
	if remote_controlled:
		if not (actor != null and actor.has_method("is_disarmed") and actor.is_disarmed()):
			use_requested.emit(actor)
		return
	if can_operate(actor):
		set_open(not is_open)
	else:
		_deny()


## Called by a card reader when a thrown keycard hits it.
func on_card_swiped(card: ItemData) -> void:
	if remote_controlled or is_barricaded():
		return
	if card_opens(card):
		set_open(not is_open)
	else:
		_deny()


func set_open(value: bool) -> void:
	if value == is_open or (value and is_barricaded()):
		return
	is_open = value
	if _tween:
		_tween.kill()
	_tween = create_tween()
	# Move in physics steps so characters get pushed correctly.
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var target := _open_position() if is_open else _closed_position
	_tween.tween_property(panel, "position", target, open_time)
	_update_indicator()
	if is_open:
		opened.emit()
	else:
		closed.emit()


func _open_position() -> Vector3:
	return _closed_position + Vector3(slide_distance, 0.0, 0.0)


func _deny() -> void:
	_denied_time = 0.6
	_set_indicator_color(Color(1.0, 0.1, 0.1))


func _update_indicator() -> void:
	# Green = open, red = closed and needs a keycard, yellow = closed.
	var color := Color(0.3, 1.0, 0.3)
	if not is_open:
		color = Color(1.0, 0.3, 0.2) if requires_keycard() or remote_controlled else Color(1.0, 0.85, 0.3)
	_set_indicator_color(color)


func _set_indicator_color(color: Color) -> void:
	for mat in _indicator_materials:
		mat.albedo_color = color
		mat.emission = color
