class_name Elevator
extends Node3D
## A two-stop elevator (e.g. Gate A: Entrance Zone <-> Surface).
##
## The car rides up and down its shaft; the doors at each stop open only when
## the car is there. Use the card reader next to a door to call the car, and
## the button inside the car to travel.

signal arrived(at_top: bool)

@export var travel_height := 20.0
@export var travel_time := 7.0
## Text stenciled on both doors, e.g. "GATE A".
@export var label := "GATE A"
@export var sublabel := "ELEVATOR - SURFACE"

var at_top := false
var moving := false
## A disabled elevator ignores all requests (e.g. after the Delta Warhead).
var disabled := false

@onready var car: AnimatableBody3D = $Car
@onready var bottom_door: Door = $BottomDoor
@onready var top_door: Door = $TopDoor


func _ready() -> void:
	for door in [bottom_door, top_door]:
		door.remote_controlled = true
		door.zone_code = label
		door.zone_name = sublabel
	bottom_door.use_requested.connect(func(_actor: Node): request(false))
	top_door.use_requested.connect(func(_actor: Node): request(true))
	# Labels are set in Door._ready, which already ran; update them now.
	for door in [bottom_door, top_door]:
		for face in [door.get_node("Panel/FaceFront"), door.get_node("Panel/FaceBack")]:
			face.get_node("ZoneCode").text = label
			face.get_node("ZoneName").text = sublabel
	bottom_door.set_open(true)


## Sends the car to the top (true) or bottom (false).
func request(to_top: bool) -> void:
	if disabled or moving:
		return
	if to_top == at_top:
		_door_at(at_top).set_open(true)
		return
	moving = true
	_door_at(at_top).set_open(false)
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(0.8)  # let the door close first
	tween.tween_property(car, "position:y", travel_height if to_top else 0.0, travel_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_arrive.bind(to_top))


func toggle() -> void:
	request(not at_top)


func get_status_text() -> String:
	if disabled:
		return "Elevator offline"
	if moving:
		return "Elevator moving..."
	return "[E] Go down" if at_top else "[E] Go up"


func _arrive(to_top: bool) -> void:
	at_top = to_top
	moving = false
	_door_at(at_top).set_open(true)
	arrived.emit(at_top)


func _door_at(top: bool) -> Door:
	return top_door if top else bottom_door
