class_name Door
extends Node3D
## A sliding facility door. Look at it and press E to open/close.
##
## `required_clearance` is the keycard level needed (0 = anyone can open).
## A character opens it if they carry a keycard of that level or higher.

signal opened
signal closed

@export_range(0, 5) var required_clearance := 0
@export var start_open := false
## How far the panel slides sideways when opening, in meters.
@export var slide_distance := 2.1
@export var open_time := 0.6

var is_open := false
var _tween: Tween

@onready var panel: AnimatableBody3D = $Panel
@onready var indicator: MeshInstance3D = $Panel/Indicator
@onready var _closed_position: Vector3 = panel.position


func _ready() -> void:
	if start_open:
		is_open = true
		panel.position = _open_position()
	_update_indicator()


## Can this actor operate the door?
func can_operate(actor: Node) -> bool:
	if required_clearance == 0:
		return true
	return actor != null and actor.has_method("get_clearance") \
		and actor.get_clearance() >= required_clearance


func get_interaction_prompt(actor: Node) -> String:
	if not can_operate(actor):
		return "Locked - Level %d keycard required" % required_clearance
	if required_clearance > 0 and not is_open:
		return "[E] Open door (Level %d)" % required_clearance
	return "[E] Close door" if is_open else "[E] Open door"


func interact(actor: Node) -> void:
	if not can_operate(actor):
		return
	set_open(not is_open)


func set_open(value: bool) -> void:
	if value == is_open:
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


func _update_indicator() -> void:
	var mat := indicator.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	# Green = open, red = closed and needs a keycard, yellow = closed.
	var color := Color(0.3, 1.0, 0.3)
	if not is_open:
		color = Color(1.0, 0.2, 0.2) if required_clearance > 0 else Color(1.0, 0.85, 0.3)
	mat.emission = color
	mat.albedo_color = color
