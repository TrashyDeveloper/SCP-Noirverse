class_name Elevator
extends Node3D
## A lift with two stops (e.g. Checkpoint A: Light <-> Heavy Containment,
## or Gate A: Entrance Zone <-> Surface).
##
## The cabin rides up and down its shaft. Each stop has two-piece sliding
## doors that only open while the cabin is there, a CALL button and an
## indicator above the doors. Inside the cabin a panel sends it to the other
## stop. The geometry is built by the map generator; this script expects
## these children: Car (with Panel/Display), BottomDoorL, BottomDoorR,
## TopDoorL, TopDoorR, BottomIndicator, TopIndicator.

signal arrived(at_top: bool)

## How far each door panel slides to the side when opening.
const DOOR_SLIDE := 0.88

@export var travel_height := 20.0
@export var travel_time := 6.0
## Name shown on the indicators, e.g. "CHECKPOINT A".
@export var lift_name := "LIFT"
@export var bottom_name := "HCZ"
@export var top_name := "LCZ"

var at_top := false
var moving := false
## A disabled lift ignores all requests (e.g. after the Delta Warhead).
var disabled := false:
	set(value):
		disabled = value
		_update_displays()

var _closed_x := {}

@onready var car: AnimatableBody3D = $Car


func _ready() -> void:
	for panel in _door_panels(false) + _door_panels(true):
		_closed_x[panel] = panel.position.x
	_set_doors(false, true, true)
	_update_displays()


## Sends the cabin to the top (true) or bottom (false) stop.
func request(to_top: bool) -> void:
	if disabled or moving:
		return
	if to_top == at_top:
		_set_doors(at_top, true)
		return
	moving = true
	Sfx.play_3d(self, "lift_move", car.global_position + Vector3.UP * 1.3, -6.0, 1.0, car)
	_set_doors(at_top, false)
	_update_displays()
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(0.9)  # let the doors close first
	tween.tween_property(car, "position:y", travel_height if to_top else 0.0, travel_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_arrive.bind(to_top))


func toggle() -> void:
	request(not at_top)


## Interaction text for the cabin panel (action 0), the bottom call button
## (1) or the top call button (2).
func get_prompt(action: int) -> String:
	if disabled:
		return "Lift offline"
	if moving:
		return "Lift moving..."
	match action:
		1:
			return "Lift is here" if not at_top else "[E] Call lift"
		2:
			return "Lift is here" if at_top else "[E] Call lift"
	return "[E] Go down to %s" % bottom_name if at_top else "[E] Go up to %s" % top_name


func _arrive(to_top: bool) -> void:
	at_top = to_top
	moving = false
	Sfx.play_3d(self, "lift_ding", car.global_position + Vector3.UP * 2.3, -8.0, 1.0, car)
	_set_doors(at_top, true)
	_update_displays()
	arrived.emit(at_top)


func _door_panels(top: bool) -> Array[Node3D]:
	var prefix := "Top" if top else "Bottom"
	var panels: Array[Node3D] = [get_node(prefix + "DoorL"), get_node(prefix + "DoorR")]
	return panels


func _set_doors(top: bool, open: bool, instant := false) -> void:
	for panel in _door_panels(top):
		var direction := -1.0 if panel.name.ends_with("L") else 1.0
		var x: float = _closed_x[panel] + (direction * DOOR_SLIDE if open else 0.0)
		if instant:
			panel.position.x = x
		else:
			var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			tween.tween_property(panel, "position:x", x, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _update_displays() -> void:
	if not is_node_ready():
		return
	var where := top_name if at_top else bottom_name
	var state := "OFFLINE" if disabled else ("MOVING" if moving else "LIFT AT " + where)
	for indicator: Label3D in [$BottomIndicator, $TopIndicator]:
		indicator.text = "%s\n%s" % [lift_name, state]
	var display: Label3D = $Car/Panel/Display
	display.text = "OFFLINE" if disabled else ("..." if moving else where)
